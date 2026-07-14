--!strict
-- ASMR Satisfy Station -- SERVER half.
-- Owns RoundInput ingress for Trace/Squish/Pop/Peel/Pipe/Complete, remaining-
-- object telemetry tags, significant moments, and Director card hooks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local GameplayHooks = require(script.Parent.lib.GameplayHooks)

local id: Types.MinigameId = "SatisfyStation"
local SEGMENT_SECONDS = 55

local difficultyWatch: RBXScriptConnection? = nil
local completeThread: thread? = nil
local activeCtx: Types.ShowContext? = nil
local tracker: GameplayHooks.Tracker = GameplayHooks.newTracker()
local segmentToken = 0
local resolved = 0
local traySize = 8

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

local function publishLive()
	local ctx = activeCtx
	if not ctx then
		return
	end
	tracker.remainingObjects = math.max(0, traySize - resolved)
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
	tracker.remainingObjects = 0
	ctx.recordMoment({
		roundId = ctx.roundConfig.roundId,
		sequence = math.max(1, resolved),
		kind = "Finish",
		serverTime = workspace:GetServerTimeNow(),
		value = tracker.score,
		label = label,
	})
	ctx.complete(GameplayHooks.result(tracker, ctx.roundConfig.roundId) :: any)
end

local SatisfyStationServer: Types.MinigameServer = {
	id = id,

	start = function(_self, ctx)
		activeCtx = ctx
		tracker = GameplayHooks.newTracker()
		resolved = 0
		local difficulty = ctx.difficulty()
		traySize = math.floor(6 + math.clamp(difficulty, 0, 1) * 4 + 0.5)
		tracker.remainingObjects = traySize
		stopWatch()
		cancelComplete()

		local lastDifficulty = difficulty
		ctx.broadcast("SatisfyStationBegin", {
			difficulty = lastDifficulty,
			roundId = ctx.roundConfig.roundId,
			seed = ctx.roundConfig.seed,
			traySize = traySize,
		})

		difficultyWatch = RunService.Heartbeat:Connect(function()
			local d = ctx.difficulty()
			if math.abs(d - lastDifficulty) > 1e-3 then
				lastDifficulty = d
				ctx.broadcast("SatisfyStationDifficulty", { difficulty = d })
			end
		end)

		local token = segmentToken
		completeThread = task.delay(SEGMENT_SECONDS, function()
			completeThread = nil
			if token ~= segmentToken or activeCtx ~= ctx then
				return
			end
			finishRound("Station segment complete")
		end)
	end,

	stop = function(_self)
		stopWatch()
		cancelComplete()
		if activeCtx then
			activeCtx.broadcast("SatisfyStationEnd", nil)
			activeCtx = nil
		end
	end,

	handleInput = function(_self, _player: Player, input: Types.RoundInput)
		local ctx = activeCtx
		if not ctx or tracker.completed or input.roundId ~= ctx.roundConfig.roundId then
			return
		end

		local value = if type(input.value) == "number" then input.value else 0
		if
			input.action == "Trace"
			or input.action == "Squish"
			or input.action == "Pop"
			or input.action == "Peel"
			or input.action == "Pipe"
		then
			local accepted = value >= 0.35
			if accepted then
				resolved += 1
				local perfect = value >= 0.85
				local points = 5 + tracker.combo * 3 + (if perfect then 4 else 0)
				tracker.score += points
				tracker.combo += 1
				tracker.flow = tracker.flow * 0.7 + value * 0.3
				tracker.accuracy = tracker.accuracy * 0.7 + value * 0.3
				tracker.progress = math.clamp(resolved / math.max(traySize, 1), 0, 1)
				tracker.remainingObjects = math.max(0, traySize - resolved)
				if perfect then
					tracker.perfects += 1
					ctx.recordMoment({
						roundId = ctx.roundConfig.roundId,
						sequence = input.sequence,
						kind = "Perfect",
						serverTime = workspace:GetServerTimeNow(),
						value = value,
						label = `Perfect {input.action}`,
					})
				end
				if tracker.combo >= 3 then
					ctx.recordMoment({
						roundId = ctx.roundConfig.roundId,
						sequence = input.sequence,
						kind = "Combo",
						serverTime = workspace:GetServerTimeNow(),
						value = tracker.combo,
						label = `ASMR combo x{tracker.combo}`,
					})
				end
				if
					GameplayHooks.activeModifier(
						tracker,
						"DreamModeBoost",
						workspace:GetServerTimeNow()
					)
				then
					ctx.recordMoment({
						roundId = ctx.roundConfig.roundId,
						sequence = input.sequence,
						kind = "DreamMode",
						serverTime = workspace:GetServerTimeNow(),
						value = value,
						label = "Dream Mode flow",
					})
				end
				if resolved >= traySize then
					finishRound("Tray cleared")
					return
				end
			else
				tracker.combo = 0
				tracker.flow = math.clamp(tracker.flow - 0.05, 0, 1)
			end
		elseif input.action == "Complete" then
			finishRound("Station finished")
			return
		end

		publishLive()
	end,
}

(function()
	local server = SatisfyStationServer :: any
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
		ctx.broadcast("SatisfyStationCard", {
			cardId = cardId,
			duration = effect.duration,
			strength = effect.strength,
		})
		publishLive()
		return true
	end
end)()

return SatisfyStationServer
