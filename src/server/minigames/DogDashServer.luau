--!strict
-- Gigi & Rambo Dash -- SERVER half.
-- Owns RoundInput ingress for Jump/SwitchDog/Charge/Lunge/Route/Complete,
-- telemetry tags (active dog), significant moments, and Director card hooks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Config = require(Shared.Config)

local DogDashRules = require(script.Parent.lib.DogDashRules)
local GameplayHooks = require(script.Parent.lib.GameplayHooks)

local id: Types.MinigameId = "DogDash"

local difficultyWatch: RBXScriptConnection? = nil
local completeThread: thread? = nil
local activeCtx: Types.ShowContext? = nil
local tracker: GameplayHooks.Tracker = GameplayHooks.newTracker()
local rules = DogDashRules.newState()
local segmentToken = 0

local function stopWatch()
	if difficultyWatch then
		difficultyWatch:Disconnect()
		difficultyWatch = nil
	end
end

local function cancelComplete()
	segmentToken += 1
	if completeThread then
		task.cancel(completeThread)
		completeThread = nil
	end
end

local function dogName(): string
	local dog = Config.dogs[rules.activeDogIndex]
	return if dog and type(dog.name) == "string" then dog.name else "Gigi"
end

local function syncTracker()
	tracker.score = rules.score
	tracker.combo = rules.combo
	tracker.progress = rules.progress
	tracker.accuracy = rules.accuracy
	tracker.validAttempts = rules.validAttempts
	tracker.friendship = rules.friendship
	tracker.activeDog = dogName()
	tracker.completed = rules.completed
end

local function publishLive()
	local ctx = activeCtx
	if not ctx then
		return
	end
	syncTracker()
	for _, sample in GameplayHooks.telemetrySamples(tracker, ctx.roundConfig.roundId, id) do
		ctx.publishTelemetry({
			roundId = sample.roundId,
			metric = sample.metric :: Types.TelemetryMetric,
			value = sample.value,
			tag = sample.tag,
		})
	end
end

local function finishRound(label: string)
	local ctx = activeCtx
	if not ctx or rules.completed then
		return
	end
	rules.completed = true
	rules.progress = 1
	syncTracker()
	ctx.recordMoment({
		roundId = ctx.roundConfig.roundId,
		sequence = math.max(1, math.floor(tracker.score)),
		kind = "Finish",
		serverTime = workspace:GetServerTimeNow(),
		value = tracker.score,
		label = label,
	})
	ctx.complete(GameplayHooks.result(tracker, ctx.roundConfig.roundId) :: any)
end

local DogDashServer: Types.MinigameServer = {
	id = id,

	start = function(_self, ctx)
		activeCtx = ctx
		tracker = GameplayHooks.newTracker()
		rules = DogDashRules.newState()
		syncTracker()
		stopWatch()
		cancelComplete()

		local lastDifficulty = ctx.difficulty()
		ctx.broadcast("DogDashBegin", {
			difficulty = lastDifficulty,
			roundId = ctx.roundConfig.roundId,
			seed = ctx.roundConfig.seed,
			segmentSeconds = DogDashRules.SEGMENT_SECONDS,
		})

		difficultyWatch = RunService.Heartbeat:Connect(function()
			local d = ctx.difficulty()
			if math.abs(d - lastDifficulty) > 1e-3 then
				lastDifficulty = d
				ctx.broadcast("DogDashDifficulty", { difficulty = d })
			end
		end)

		local token = segmentToken
		completeThread = task.delay(DogDashRules.SEGMENT_SECONDS, function()
			completeThread = nil
			if token ~= segmentToken or activeCtx ~= ctx then
				return
			end
			finishRound("Dash segment complete")
		end)
	end,

	stop = function(_self)
		stopWatch()
		cancelComplete()
		if activeCtx then
			activeCtx.broadcast("DogDashEnd", nil)
			activeCtx = nil
		end
	end,

	handleInput = function(_self, _player: Player, input: Types.RoundInput)
		local ctx = activeCtx
		if not ctx or rules.completed or input.roundId ~= ctx.roundConfig.roundId then
			return
		end

		local value = if type(input.value) == "number" then input.value else 0
		if input.action == "SwitchDog" then
			if not DogDashRules.applySwitch(rules) then
				return
			end
			syncTracker()
			ctx.recordMoment({
				roundId = ctx.roundConfig.roundId,
				sequence = input.sequence,
				kind = "Tandem",
				serverTime = workspace:GetServerTimeNow(),
				value = rules.activeDogIndex,
				label = `Leading {tracker.activeDog}`,
			})
		elseif input.action == "Jump" or input.action == "Lunge" or input.action == "Charge" then
			local beforeCombo = rules.combo
			if not DogDashRules.applySkill(rules, value) then
				return
			end
			if rules.combo >= 3 and rules.combo > beforeCombo then
				ctx.recordMoment({
					roundId = ctx.roundConfig.roundId,
					sequence = input.sequence,
					kind = "Combo",
					serverTime = workspace:GetServerTimeNow(),
					value = rules.combo,
					label = `Treat combo x{rules.combo}`,
				})
			end
		elseif input.action == "Route" then
			-- Progress is server-owned; Route remains a validated heartbeat only.
			DogDashRules.applyRoute(rules, value)
		elseif input.action == "Complete" then
			if not DogDashRules.canComplete(rules) then
				return
			end
			finishRound("Dash finished")
			return
		else
			return
		end

		publishLive()
	end,
}

(function()
	local server = DogDashServer :: any
	server.applyDirectorEffect = function(_self: any, effect: { [string]: any })
		local ctx = activeCtx
		if not ctx then
			return false
		end
		local cardId =
			GameplayHooks.applyDirectorEffect(tracker, effect, workspace:GetServerTimeNow())
		if not cardId then
			return false
		end
		ctx.broadcast("DogDashCard", {
			cardId = cardId,
			duration = effect.duration,
			strength = effect.strength,
		})
		publishLive()
		return true
	end
end)()

return DogDashServer
