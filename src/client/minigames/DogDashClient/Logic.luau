--!strict
-- Pure Gigi & Rambo Dash logic: lanes, dogs, jump, charge, lunge, route, finish.
-- No Roblox APIs — safe for Lune unit tests.

local Logic = {}

Logic.LaneCount = 3 -- lanes indexed 0 .. LaneCount-1
Logic.DefaultLane = 1
Logic.CatchZ = 0 -- dog plane; entities move toward decreasing z
Logic.DespawnZ = -2
Logic.SpawnZ = 42
Logic.TreatPoints = 10
Logic.ComboBonus = 2
Logic.PuddlePenalty = 5
Logic.RunDistance = 220 -- distance goal before the run "finishes"
Logic.JumpDuration = 0.55
Logic.ChargeDuration = 1.1
Logic.ChargeSpeedBonus = 6

export type HazardKind = "Treat" | "Puddle"
export type DogLead = number -- 1 = Gigi lead, 2 = Rambo lead

export type Entity = {
	id: number,
	kind: HazardKind,
	lane: number,
	z: number,
}

export type Config = {
	baseSpeed: number,
	speedRamp: number,
	spawnInterval: number,
	puddleChance: number,
}

export type State = {
	lane: number,
	score: number,
	combo: number,
	distance: number,
	spawnTimer: number,
	nextId: number,
	speed: number,
	entities: { Entity },
	finished: boolean,
	hitStreak: number,
	leadDog: DogLead,
	jumpUntil: number,
	chargeUntil: number,
	seed: number,
}

export type TickEvent =
	{ kind: "Catch", points: number, combo: number, entityId: number }
	| { kind: "Hit", penalty: number, comboBroken: boolean, entityId: number }
	| { kind: "Spawn", entity: Entity }
	| { kind: "Finish", score: number, distance: number }
	| { kind: "Jump", untilTime: number }
	| { kind: "Charge", untilTime: number }
	| { kind: "SwitchDog", leadDog: DogLead }

local function clampLane(lane: number): number
	return math.clamp(math.floor(lane + 0.5), 0, Logic.LaneCount - 1)
end

local function nextUnit(state: State): number
	-- Pure LCG so Lune tests and Roblox share deterministic spawns from round seeds.
	state.seed = (state.seed * 1_103_515_245 + 12_345) % 2_147_483_648
	return state.seed / 2_147_483_648
end

local function nextInt(state: State, maxExclusive: number): number
	return math.floor(nextUnit(state) * maxExclusive)
end

function Logic.configFor(difficulty: number): Config
	local d = math.clamp(difficulty, 0, 1)
	return {
		baseSpeed = 10 + d * 8, -- 10 .. 18
		speedRamp = 0.015 + d * 0.035, -- per stud of distance
		spawnInterval = 1.15 - d * 0.55, -- 1.15 .. 0.6
		puddleChance = 0.22 + d * 0.38, -- 0.22 .. 0.6
	}
end

function Logic.newState(difficulty: number, seed: number?): State
	local config = Logic.configFor(difficulty)
	return {
		lane = Logic.DefaultLane,
		score = 0,
		combo = 0,
		distance = 0,
		spawnTimer = 0.35,
		nextId = 1,
		speed = config.baseSpeed,
		entities = {},
		finished = false,
		hitStreak = 0,
		leadDog = 1,
		jumpUntil = 0,
		chargeUntil = 0,
		seed = if seed ~= nil then math.floor(seed) else 1,
	}
end

function Logic.reset(state: State, difficulty: number, seed: number?)
	local fresh = Logic.newState(difficulty, seed or state.seed)
	state.lane = fresh.lane
	state.score = fresh.score
	state.combo = fresh.combo
	state.distance = fresh.distance
	state.spawnTimer = fresh.spawnTimer
	state.nextId = fresh.nextId
	state.speed = fresh.speed
	table.clear(state.entities)
	state.finished = false
	state.hitStreak = 0
	state.leadDog = 1
	state.jumpUntil = 0
	state.chargeUntil = 0
	state.seed = fresh.seed
end

function Logic.setLane(state: State, lane: number): number
	state.lane = clampLane(lane)
	return state.lane
end

function Logic.shiftLane(state: State, direction: number): number
	return Logic.setLane(state, state.lane + (if direction < 0 then -1 else 1))
end

function Logic.switchDog(state: State): DogLead
	state.leadDog = if state.leadDog == 1 then 2 else 1
	return state.leadDog
end

function Logic.isJumping(state: State, now: number): boolean
	return now < state.jumpUntil
end

function Logic.isCharging(state: State, now: number): boolean
	return now < state.chargeUntil
end

function Logic.jump(state: State, now: number): boolean
	if state.finished or Logic.isJumping(state, now) then
		return false
	end
	state.jumpUntil = now + Logic.JumpDuration
	return true
end

function Logic.charge(state: State, now: number): boolean
	if state.finished or Logic.isCharging(state, now) then
		return false
	end
	state.chargeUntil = now + Logic.ChargeDuration
	return true
end

local function spawnEntity(state: State, config: Config): Entity
	local lane = nextInt(state, Logic.LaneCount)
	local kind: HazardKind = if nextUnit(state) < config.puddleChance then "Puddle" else "Treat"
	if kind == "Puddle" and lane == state.lane and nextUnit(state) < 0.45 then
		lane = (lane + 1 + nextInt(state, Logic.LaneCount - 1)) % Logic.LaneCount
	end
	local entity: Entity = {
		id = state.nextId,
		kind = kind,
		lane = lane,
		z = Logic.SpawnZ,
	}
	state.nextId += 1
	table.insert(state.entities, entity)
	return entity
end

function Logic.tick(state: State, dt: number, config: Config, now: number?): { TickEvent }
	local events: { TickEvent } = {}
	if state.finished or dt <= 0 then
		return events
	end
	local clock = if now ~= nil then now else state.distance / math.max(state.speed, 0.1)

	local chargeBonus = if Logic.isCharging(state, clock) then Logic.ChargeSpeedBonus else 0
	state.distance += (state.speed + chargeBonus) * dt
	state.speed = config.baseSpeed + state.distance * config.speedRamp

	state.spawnTimer -= dt
	while state.spawnTimer <= 0 and not state.finished do
		local entity = spawnEntity(state, config)
		table.insert(events, { kind = "Spawn", entity = entity })
		state.spawnTimer += config.spawnInterval
	end

	local remaining: { Entity } = {}
	local jumping = Logic.isJumping(state, clock)
	for _, entity in state.entities do
		local previousZ = entity.z
		entity.z -= (state.speed + chargeBonus) * dt
		local crossed = previousZ > Logic.CatchZ and entity.z <= Logic.CatchZ
		if crossed and entity.lane == state.lane then
			if entity.kind == "Treat" then
				state.combo += 1
				state.hitStreak = 0
				local points = Logic.TreatPoints + Logic.ComboBonus * math.max(0, state.combo - 1)
				state.score += points
				table.insert(events, {
					kind = "Catch",
					points = points,
					combo = state.combo,
					entityId = entity.id,
				})
			elseif not jumping then
				state.combo = 0
				state.hitStreak = 1
				local penalty = Logic.PuddlePenalty
				state.score = math.max(0, state.score - penalty)
				table.insert(events, {
					kind = "Hit",
					penalty = penalty,
					comboBroken = true,
					entityId = entity.id,
				})
			end
			-- Jumping over a puddle consumes it silently.
		elseif entity.z > Logic.DespawnZ then
			table.insert(remaining, entity)
		end
	end
	state.entities = remaining

	if state.distance >= Logic.RunDistance then
		state.finished = true
		table.insert(events, {
			kind = "Finish",
			score = state.score,
			distance = state.distance,
		})
	end

	return events
end

return Logic
