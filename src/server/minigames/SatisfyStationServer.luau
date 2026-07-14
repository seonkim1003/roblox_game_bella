--!strict
-- ASMR Satisfy Station -- SERVER half.
-- Owns RoundInput ingress for Trace/Squish/Pop/Peel/Pipe/Complete, remaining-
-- object telemetry tags, significant moments, and Director card hooks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local GameplayHooks = require(script.Parent.lib.GameplayHooks)
local SatisfyStationRules = require(script.Parent.lib.SatisfyStationRules)

local id: Types.MinigameId = "SatisfyStation"

local difficultyWatch: RBXScriptConnection? = nil
local completeThread: thread? = nil
local activeCtx: Types.ShowContext? = nil
local tracker: GameplayHooks.Tracker = GameplayHooks.newTracker()
local rules = SatisfyStationRules.newState(0.5, 1)
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

local function syncTracker()
	tracker.score = rules.score
	tracker.combo = rules.combo
	tracker.perfects = rules.perfects
	tracker.progress = rules.progress
	tracker.accuracy = rules.accuracy
	tracker.validAttempts = rules.validAttempts
	tracker.flow = rules.flow
	tracker.remainingObjects = math.max(0, rules.traySize - rules.resolved)
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
	tracker.remainingObjects = 0
	ctx.recordMoment({
		roundId = ctx.roundConfig.roundId,
		sequence = math.max(1, rules.resolved),
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
		local difficulty = ctx.difficulty()
		rules = SatisfyStationRules.newState(difficulty, ctx.roundConfig.seed)
		syncTracker()
		stopWatch()
		cancelComplete()

		local lastDifficulty = difficulty
		local trayPayload = {}
		for _, item in rules.items do
			table.insert(trayPayload, { id = item.id, kind = item.kind })
		end
		ctx.broadcast("SatisfyStationBegin", {
			difficulty = lastDifficulty,
			roundId = ctx.roundConfig.roundId,
			seed = ctx.roundConfig.seed,
			traySize = rules.traySize,
			tray = trayPayload,
		})

		difficultyWatch = RunService.Heartbeat:Connect(function()
			local d = ctx.difficulty()
			if math.abs(d - lastDifficulty) > 1e-3 then
				lastDifficulty = d
				ctx.broadcast("SatisfyStationDifficulty", { difficulty = d })
			end
		end)

		local token = segmentToken
		completeThread = task.delay(SatisfyStationRules.SEGMENT_SECONDS, function()
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
		if not ctx or rules.completed or input.roundId ~= ctx.roundConfig.roundId then
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
			local objectId = if type(input.objectId) == "number" then input.objectId else nil
			local accepted, item =
				SatisfyStationRules.applyAction(rules, input.action, value, objectId)
			if accepted and item then
				if value >= SatisfyStationRules.PERFECT_THRESHOLD then
					ctx.recordMoment({
						roundId = ctx.roundConfig.roundId,
						sequence = input.sequence,
						kind = "Perfect",
						serverTime = workspace:GetServerTimeNow(),
						value = value,
						label = `Perfect {input.action}`,
					})
				end
				if rules.combo >= 3 then
					ctx.recordMoment({
						roundId = ctx.roundConfig.roundId,
						sequence = input.sequence,
						kind = "Combo",
						serverTime = workspace:GetServerTimeNow(),
						value = rules.combo,
						label = `ASMR combo x{rules.combo}`,
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
				if rules.resolved >= rules.traySize then
					finishRound("Tray cleared")
					return
				end
			end
		elseif input.action == "Complete" then
			if not SatisfyStationRules.canComplete(rules) then
				return
			end
			finishRound("Station finished")
			return
		else
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
