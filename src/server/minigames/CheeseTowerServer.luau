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

local CheeseTowerRules = require(script.Parent.lib.CheeseTowerRules)
local GameplayHooks = require(script.Parent.lib.GameplayHooks)

local id: Types.MinigameId = "CheeseTower"

local difficultyWatch: RBXScriptConnection? = nil
local activeCtx: Types.ShowContext? = nil
local tracker: GameplayHooks.Tracker = GameplayHooks.newTracker()
local rules = CheeseTowerRules.newState()

local function stopWatch()
	if difficultyWatch then
		difficultyWatch:Disconnect()
		difficultyWatch = nil
	end
end

local function syncTracker()
	tracker.score = rules.score
	tracker.combo = rules.combo
	tracker.perfects = rules.perfects
	tracker.rescues = rules.rescues
	tracker.progress = rules.progress
	tracker.accuracy = rules.accuracy
	tracker.validAttempts = rules.validAttempts
	tracker.instability = rules.instability
	tracker.remainingObjects = math.max(0, CheeseTowerRules.MAX_PLACES - rules.places)
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

local function finishRound()
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
		sequence = rules.places,
		kind = "Finish",
		serverTime = workspace:GetServerTimeNow(),
		value = tracker.score,
		label = "Tower banked",
	})
	ctx.complete(GameplayHooks.result(tracker, ctx.roundConfig.roundId) :: any)
end

local CheeseTowerServer: Types.MinigameServer = {
	id = id,

	start = function(_self, ctx)
		activeCtx = ctx
		tracker = GameplayHooks.newTracker()
		rules = CheeseTowerRules.newState()
		syncTracker()
		stopWatch()

		local lastDifficulty = ctx.difficulty()
		ctx.broadcast("CheeseTowerBegin", {
			difficulty = lastDifficulty,
			roundId = ctx.roundConfig.roundId,
			seed = ctx.roundConfig.seed,
			maxPlaces = CheeseTowerRules.MAX_PLACES,
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
		if not ctx or rules.completed or input.roundId ~= ctx.roundConfig.roundId then
			return
		end

		local value = if type(input.value) == "number" then input.value else 0
		local now = workspace:GetServerTimeNow()
		local doubleTopper = GameplayHooks.activeModifier(tracker, "DoubleOrNothingTopper", now)
			~= nil

		if input.action == "Place" then
			local ok = CheeseTowerRules.applyPlace(rules, value, 1, false)
			if not ok then
				return
			end
			if value >= 0.92 then
				ctx.recordMoment({
					roundId = ctx.roundConfig.roundId,
					sequence = input.sequence,
					kind = "Perfect",
					serverTime = now,
					value = value,
					label = "Perfect cheese drop",
				})
			end
			if rules.combo >= 3 then
				ctx.recordMoment({
					roundId = ctx.roundConfig.roundId,
					sequence = input.sequence,
					kind = "Combo",
					serverTime = now,
					value = rules.combo,
					label = `Combo x{rules.combo}`,
				})
			end
		elseif input.action == "Nudge" then
			rules.instability = math.clamp(rules.instability - 0.05, 0, 1)
		elseif input.action == "Rescue" then
			local beforePlaces = rules.places
			local ok = CheeseTowerRules.applyRescue(rules, if value > 0 then value else nil)
			if not ok then
				return
			end
			ctx.recordMoment({
				roundId = ctx.roundConfig.roundId,
				sequence = input.sequence,
				kind = "Rescue",
				serverTime = now,
				value = value,
				label = "Cheese rescue",
			})
			if rules.places > beforePlaces and value >= 0.92 then
				ctx.recordMoment({
					roundId = ctx.roundConfig.roundId,
					sequence = input.sequence,
					kind = "Perfect",
					serverTime = now,
					value = value,
					label = "Perfect cheese drop",
				})
			end
		elseif input.action == "Topper" then
			local ok = CheeseTowerRules.applyTopper(rules, value, doubleTopper)
			if not ok then
				return
			end
			ctx.recordMoment({
				roundId = ctx.roundConfig.roundId,
				sequence = input.sequence,
				kind = "Perfect",
				serverTime = now,
				value = value,
				label = "Topper locked",
			})
		elseif input.action == "Bank" then
			local ok = CheeseTowerRules.applyBank(rules)
			if not ok then
				return
			end
		elseif input.action == "Complete" then
			if not CheeseTowerRules.canComplete(rules) then
				return
			end
			finishRound()
			return
		else
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
		if cardId == "DoubleOrNothingTopper" then
			CheeseTowerRules.armTopper(rules)
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
