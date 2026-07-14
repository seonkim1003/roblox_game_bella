--!strict
-- Gigi & Rambo Dash -- SERVER half.
-- Owns RoundInput ingress for Jump/SwitchDog/Charge/Lunge/Route/Complete,
-- telemetry tags (active dog), significant moments, and Director card hooks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Config = require(Shared.Config)

local GameplayHooks = require(script.Parent.lib.GameplayHooks)

local id: Types.MinigameId = "DogDash"
local SEGMENT_SECONDS = 50

local difficultyWatch: RBXScriptConnection? = nil
local completeThread: thread? = nil
local activeCtx: Types.ShowContext? = nil
local tracker: GameplayHooks.Tracker = GameplayHooks.newTracker()
local segmentToken = 0
local activeDogIndex = 1

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
	local dog = Config.dogs[activeDogIndex]
	return if dog and type(dog.name) == "string" then dog.name else "Gigi"
end

local function publishLive()
	local ctx = activeCtx
	if not ctx then
		return
	end
	tracker.activeDog = dogName()
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
	if not ctx or tracker.completed then
		return
	end
	tracker.completed = true
	tracker.progress = 1
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
		activeDogIndex = 1
		tracker.activeDog = dogName()
		stopWatch()
		cancelComplete()

		local lastDifficulty = ctx.difficulty()
		ctx.broadcast("DogDashBegin", {
			difficulty = lastDifficulty,
			roundId = ctx.roundConfig.roundId,
			seed = ctx.roundConfig.seed,
		})

		difficultyWatch = RunService.Heartbeat:Connect(function()
			local d = ctx.difficulty()
			if math.abs(d - lastDifficulty) > 1e-3 then
				lastDifficulty = d
				ctx.broadcast("DogDashDifficulty", { difficulty = d })
			end
		end)

		local token = segmentToken
		completeThread = task.delay(SEGMENT_SECONDS, function()
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
		if not ctx or tracker.completed or input.roundId ~= ctx.roundConfig.roundId then
			return
		end

		local value = if type(input.value) == "number" then input.value else 0
		if input.action == "SwitchDog" then
			activeDogIndex = if activeDogIndex == 1 then 2 else 1
			tracker.activeDog = dogName()
			ctx.recordMoment({
				roundId = ctx.roundConfig.roundId,
				sequence = input.sequence,
				kind = "Tandem",
				serverTime = workspace:GetServerTimeNow(),
				value = activeDogIndex,
				label = `Leading {tracker.activeDog}`,
			})
		elseif input.action == "Jump" or input.action == "Lunge" or input.action == "Charge" then
			local success = value >= 0.45
			if success then
				tracker.score += 10 + tracker.combo * 2
				tracker.combo += 1
				tracker.friendship = math.clamp(tracker.friendship + 0.04, 0, 1)
				tracker.accuracy = tracker.accuracy * 0.75 + value * 0.25
				if tracker.combo >= 3 then
					ctx.recordMoment({
						roundId = ctx.roundConfig.roundId,
						sequence = input.sequence,
						kind = "Combo",
						serverTime = workspace:GetServerTimeNow(),
						value = tracker.combo,
						label = `Treat combo x{tracker.combo}`,
					})
				end
			else
				tracker.combo = 0
				tracker.score = math.max(0, tracker.score - 5)
				tracker.accuracy = tracker.accuracy * 0.85
			end
			tracker.progress = math.clamp(value, tracker.progress, 1)
		elseif input.action == "Route" then
			tracker.progress = math.clamp(math.max(tracker.progress, value), 0, 1)
		elseif input.action == "Complete" then
			finishRound("Dash finished")
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
