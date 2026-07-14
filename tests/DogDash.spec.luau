--!strict
-- Lune unit tests for Gigi & Rambo Dash pure logic.
-- Run via scripts/validate.ps1 (every tests/*.spec.luau).

local Logic = require("../src/client/minigames/DogDashClient/Logic")

local passed = 0
local failed = 0

local function check(label: string, condition: boolean)
	if condition then
		passed += 1
	else
		failed += 1
		print(`  [FAIL] {label}`)
	end
end

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- 1. Difficulty bounds: speed up, denser spawns, more puddles; clamps outside 0..1.
do
	local easy = Logic.configFor(0)
	local mid = Logic.configFor(0.5)
	local hard = Logic.configFor(1)
	check(
		"config: baseSpeed rises",
		easy.baseSpeed < mid.baseSpeed and mid.baseSpeed < hard.baseSpeed
	)
	check("config: spawnInterval falls", easy.spawnInterval > hard.spawnInterval)
	check("config: puddleChance rises", easy.puddleChance < hard.puddleChance)
	check("config: clamps below 0", approx(Logic.configFor(-3).baseSpeed, easy.baseSpeed))
	check("config: clamps above 1", approx(Logic.configFor(4).baseSpeed, hard.baseSpeed))
end

-- 2. Lane switching clamps at edges.
do
	local state = Logic.newState(0.5)
	check("lane: starts mid", state.lane == Logic.DefaultLane)
	Logic.shiftLane(state, -1)
	Logic.shiftLane(state, -1)
	Logic.shiftLane(state, -1)
	check("lane: left clamp", state.lane == 0)
	Logic.setLane(state, 99)
	check("lane: right clamp via setLane", state.lane == Logic.LaneCount - 1)
end

-- 3. Catching a treat in-lane awards points and builds combo.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	config.spawnInterval = 999
	config.puddleChance = 0
	state.entities = {
		{ id = 1, kind = "Treat", lane = state.lane, z = 1 },
	}
	state.nextId = 2
	local events = Logic.tick(state, 0.2, config)
	local caught = false
	for _, event in events do
		if event.kind == "Catch" then
			caught = true
			check("catch: combo starts at 1", event.combo == 1)
			check("catch: awards treat points", event.points == Logic.TreatPoints)
		end
	end
	check("catch: treat event fired", caught)
	check("catch: score updated", state.score == Logic.TreatPoints)
	check("catch: entity removed", #state.entities == 0)
end

-- 4. Combo scales treat points; puddle breaks combo and penalizes.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	config.spawnInterval = 999
	state.combo = 3
	state.score = 40
	state.entities = {
		{ id = 1, kind = "Treat", lane = state.lane, z = 1 },
	}
	local events = Logic.tick(state, 0.2, config)
	local points = 0
	for _, event in events do
		if event.kind == "Catch" then
			points = event.points
		end
	end
	check("combo: points include bonus", points == Logic.TreatPoints + Logic.ComboBonus * 3)

	state.entities = {
		{ id = 2, kind = "Puddle", lane = state.lane, z = 1 },
	}
	local hitEvents = Logic.tick(state, 0.2, config)
	local hit = false
	for _, event in hitEvents do
		if event.kind == "Hit" then
			hit = true
			check("puddle: combo broken flag", event.comboBroken)
			check("puddle: penalty", event.penalty == Logic.PuddlePenalty)
		end
	end
	check("puddle: hit event fired", hit)
	check("puddle: combo reset", state.combo == 0)
end

-- 5. Wrong-lane hazards pass through without scoring.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	config.spawnInterval = 999
	Logic.setLane(state, 0)
	state.entities = {
		{ id = 1, kind = "Treat", lane = 2, z = 1 },
	}
	local events = Logic.tick(state, 0.2, config)
	check("miss: no catch/hit events", #events == 0)
	check("miss: score unchanged", state.score == 0)
	check("miss: entity still alive past plane", #state.entities == 1 and state.entities[1].z < 0)
end

-- 6. Reset clears score/combo/entities/finished.
do
	local state = Logic.newState(0.4)
	state.score = 99
	state.combo = 4
	state.finished = true
	state.entities = { { id = 9, kind = "Puddle", lane = 1, z = 3 } }
	Logic.reset(state, 0.4)
	check("reset: score 0", state.score == 0)
	check("reset: combo 0", state.combo == 0)
	check("reset: not finished", not state.finished)
	check("reset: entities cleared", #state.entities == 0)
	check("reset: lane restored", state.lane == Logic.DefaultLane)
end

-- 7. Reaching run distance emits Finish once and sticks finished.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	config.spawnInterval = 999
	config.baseSpeed = Logic.RunDistance
	config.speedRamp = 0
	state.speed = Logic.RunDistance
	local first = Logic.tick(state, 1, config)
	local finished = false
	for _, event in first do
		if event.kind == "Finish" then
			finished = true
		end
	end
	check("finish: event fired", finished)
	check("finish: state.finished", state.finished)
	local second = Logic.tick(state, 1, config)
	check("finish: no further events while finished", #second == 0)
end

-- 8. Jump clears puddles; Charge and SwitchDog mutate state.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	config.spawnInterval = 999
	local now = 10
	check("jump: arms", Logic.jump(state, now))
	check("jump: active", Logic.isJumping(state, now + 0.1))
	state.entities = {
		{ id = 1, kind = "Puddle", lane = state.lane, z = 1 },
	}
	state.nextId = 2
	state.score = 20
	local events = Logic.tick(state, 0.2, config, now + 0.1)
	local hit = false
	for _, event in events do
		if event.kind == "Hit" then
			hit = true
		end
	end
	check("jump: puddle cleared without hit", not hit)
	check("jump: score preserved", state.score == 20)

	local state2 = Logic.newState(0)
	check("charge: arms", Logic.charge(state2, 5))
	check("charge: active", Logic.isCharging(state2, 5.2))
	local lead = Logic.switchDog(state2)
	check("switch: flips lead", lead == 2)
	check("switch: toggles back", Logic.switchDog(state2) == 1)
end

-- 9. Seeded spawns are repeatable for the same seed.
do
	local a = Logic.newState(0, 99)
	local b = Logic.newState(0, 99)
	local config = Logic.configFor(0)
	config.spawnInterval = 0.01
	-- Initial spawnTimer is 0.35; advance past it so the first spawn fires.
	local firstA = Logic.tick(a, 0.4, config, 0)
	local firstB = Logic.tick(b, 0.4, config, 0)
	local spawnA = firstA[1]
	local spawnB = firstB[1]
	check("seed: both spawned", spawnA ~= nil and spawnB ~= nil and spawnA.kind == "Spawn")
	if spawnA and spawnB and spawnA.kind == "Spawn" and spawnB.kind == "Spawn" then
		check("seed: same lane", spawnA.entity.lane == spawnB.entity.lane)
		check("seed: same kind", spawnA.entity.kind == spawnB.entity.kind)
	end
end

if failed > 0 then
	error(`DogDash.spec: {failed} check(s) failed ({passed} passed)`)
end
print(`DogDash.spec: all {passed} checks passed`)
