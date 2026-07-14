--!strict
-- Ratthew's Cheese Tower -- SERVER half.
--
-- Client simulates juice; this module owns Premiere ingress for Place/Nudge/Rescue/
-- Bank/Topper/Complete, telemetry publication, significant moments, and Director
-- card hooks Agent B can call via applyDirectorEffect.
-- Loaded by ShowDirectorService because it exports `id`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local GameplayHooks = require(script.Parent.lib.GameplayHooks)

local id: Types.MinigameId = "CheeseTower"

local difficultyWatch: RBXScriptConnection? = nil
local activeCtx: Types.ShowContext? = nil
local tracker: GameplayHooks.Tracker = GameplayHooks.newTracker()
local places = 0

local function stopWatch()
	if difficultyWatch then
		difficultyWatch:Disconnect()
		difficultyWatch = nil
	end
end

local function publishLive()
	local ctx = activeCtx
	if not ctx then
		return
	end
	for _, sample in GameplayHooks.telemetrySamples(tracker, ctx.roundConfig.roundId, id) do
		ctx.publishTelemetry({
			roundId = sample.roundId,
			metric = sample.metric :: Types.TelemetryMetric,
			value = sample.value,
			tag = sample.tag,
		})
	end
end

local function finishRound()
	local ctx = activeCtx
	if not ctx or tracker.completed then
		return
	end
	tracker.completed = true
	tracker.progress = 1
	tracker.remainingObjects = 0
	ctx.recordMoment({
		roundId = ctx.roundConfig.roundId,
		sequence = places,
		kind = "Finish",
		serverTime = workspace:GetServerTimeNow(),
		value = tracker.score,
		label = "Tower banked",
	})
	ctx.complete(GameplayHooks.result(tracker, ctx.roundConfig.roundId) :: any)
end

local function applyPlacement(
	ctx: Types.ShowContext,
	input: Types.RoundInput,
	accuracy: number,
	pointScale: number
)
	places += 1
	local points = math.floor((1 + math.floor(accuracy * 4)) * pointScale + 0.5)
	if
		GameplayHooks.activeModifier(tracker, "DoubleOrNothingTopper", workspace:GetServerTimeNow())
	then
		points *= 2
	end
	tracker.score += points
	tracker.progress = math.clamp(places / 12, 0, 1)
	tracker.remainingObjects = math.max(0, 12 - places)
	tracker.accuracy = tracker.accuracy * 0.7 + accuracy * 0.3
	tracker.instability = math.clamp(1 - accuracy, 0, 1)
	if accuracy >= 0.92 then
		tracker.perfects += 1
		tracker.combo += 1
		ctx.recordMoment({
			roundId = ctx.roundConfig.roundId,
			sequence = input.sequence,
			kind = "Perfect",
			serverTime = workspace:GetServerTimeNow(),
			value = accuracy,
			label = "Perfect cheese drop",
		})
	else
		tracker.combo = 0
	end
	if tracker.combo >= 3 then
		ctx.recordMoment({
			roundId = ctx.roundConfig.roundId,
			sequence = input.sequence,
			kind = "Combo",
			serverTime = workspace:GetServerTimeNow(),
			value = tracker.combo,
			label = `Combo x{tracker.combo}`,
		})
	end
end

local CheeseTowerServer: Types.MinigameServer = {
	id = id,

	start = function(_self, ctx)
		activeCtx = ctx
		tracker = GameplayHooks.newTracker()
		places = 0
		tracker.remainingObjects = 12
		stopWatch()

		local lastDifficulty = ctx.difficulty()
		ctx.broadcast("CheeseTowerBegin", {
			difficulty = lastDifficulty,
			roundId = ctx.roundConfig.roundId,
			seed = ctx.roundConfig.seed,
		})

		difficultyWatch = RunService.Heartbeat:Connect(function()
			local d = ctx.difficulty()
			if math.abs(d - lastDifficulty) > 1e-3 then
				lastDifficulty = d
				ctx.broadcast("CheeseTowerDifficulty", { difficulty = d })
			end
		end)
	end,

	stop = function(_self)
		stopWatch()
		if activeCtx then
			activeCtx.broadcast("CheeseTowerEnd", nil)
			activeCtx = nil
		end
	end,

	handleInput = function(_self, _player: Player, input: Types.RoundInput)
		local ctx = activeCtx
		if not ctx or tracker.completed or input.roundId ~= ctx.roundConfig.roundId then
			return
		end

		local value = if type(input.value) == "number" then input.value else 0
		if input.action == "Place" then
			applyPlacement(ctx, input, math.clamp(value, 0, 1), 1)
		elseif input.action == "Nudge" then
			tracker.instability = math.clamp(tracker.instability - 0.05, 0, 1)
		elseif input.action == "Rescue" then
			-- Armed rescue drop: value is placement accuracy (client sends after a place).
			tracker.rescues += 1
			tracker.instability = math.clamp(tracker.instability - 0.2, 0, 1)
			if value > 0 then
				applyPlacement(ctx, input, math.clamp(value, 0, 1), 1)
			end
			ctx.recordMoment({
				roundId = ctx.roundConfig.roundId,
				sequence = input.sequence,
				kind = "Rescue",
				serverTime = workspace:GetServerTimeNow(),
				value = value,
				label = "Cheese rescue",
			})
		elseif input.action == "Topper" then
			applyPlacement(ctx, input, math.clamp(value, 0, 1), 2)
		elseif input.action == "Bank" then
			local height = math.max(0, places)
			local bonus = math.floor(tracker.score * 0.1 + height * 2 + 0.5)
			tracker.score += bonus
			tracker.progress = math.clamp(tracker.progress + 0.1, 0, 1)
		elseif input.action == "Complete" then
			finishRound()
			return
		end

		publishLive()
	end,
}

(function()
	local server = CheeseTowerServer :: any
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
		ctx.broadcast("CheeseTowerCard", {
			cardId = cardId,
			duration = effect.duration,
			strength = effect.strength,
		})
		publishLive()
		return true
	end
end)()

return CheeseTowerServer
