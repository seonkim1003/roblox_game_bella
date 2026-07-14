--!strict
-- Shared Premiere helpers for Agent A minigame servers.
-- Tracks live metrics from normalized RoundInput, records significant moments,
-- and exposes applyDirectorEffect to the integrated server dispatch layer.
-- Kept under minigames/lib so ShowDirectorService folder-loading ignores it.

local function loadGradePolicy(): any
	local robloxOk, robloxMod = pcall(function()
		return (require :: any)(
			game:GetService("ReplicatedStorage"):WaitForChild("Shared").GradePolicy
		)
	end)
	if robloxOk then
		return robloxMod
	end
	return (require :: any)("../../../shared/GradePolicy")
end

local GradePolicy = loadGradePolicy()

export type Tracker = {
	score: number,
	combo: number,
	perfects: number,
	rescues: number,
	progress: number,
	accuracy: number?,
	validAttempts: number,
	flow: number,
	instability: number,
	friendship: number,
	activeDog: string?,
	remainingObjects: number?,
	completed: boolean,
	modifiers: { [string]: { strength: number, expiresAt: number } },
}

export type TelemetrySample = {
	roundId: string,
	metric: string,
	value: number,
	tag: string?,
}

export type RoundResult = {
	roundId: string,
	score: number,
	grade: string,
	metrics: { [string]: number },
}

local GameplayHooks = {}

function GameplayHooks.newTracker(): Tracker
	return {
		score = 0,
		combo = 0,
		perfects = 0,
		rescues = 0,
		progress = 0,
		accuracy = nil,
		validAttempts = 0,
		flow = 0.55,
		instability = 0.3,
		friendship = 0,
		activeDog = nil,
		remainingObjects = nil,
		completed = false,
		modifiers = {},
	}
end

function GameplayHooks.gradeFor(tracker: Tracker): string
	return GradePolicy.gradeFromAccuracy(tracker.accuracy, tracker.validAttempts, tracker.perfects)
end

function GameplayHooks.result(tracker: Tracker, roundId: string): RoundResult
	local projected = GradePolicy.projectedScore(tracker.accuracy)
	return {
		roundId = roundId,
		score = math.max(0, math.floor(tracker.score + 0.5)),
		grade = GameplayHooks.gradeFor(tracker),
		metrics = {
			Score = tracker.score,
			Combo = tracker.combo,
			Accuracy = if tracker.accuracy ~= nil then tracker.accuracy else 0,
			ValidAttempts = tracker.validAttempts,
			Perfects = tracker.perfects,
			Progress = tracker.progress,
			Instability = tracker.instability,
			Flow = tracker.flow,
			Friendship = tracker.friendship,
			ProjectedGrade = projected,
		},
	}
end

function GameplayHooks.applyDirectorEffect(
	tracker: Tracker,
	effect: { [string]: any },
	now: number
): string?
	local cardId = effect.cardId
	if type(cardId) ~= "string" then
		return nil
	end
	local duration = if type(effect.duration) == "number" then effect.duration else 4
	local strength = if type(effect.strength) == "number" then effect.strength else 1
	tracker.modifiers[cardId] = {
		strength = strength,
		expiresAt = now + duration,
	}
	-- Helpful-only: cards never grant score or rewards directly.
	if cardId == "DogAssist" or cardId == "TreatRain" then
		tracker.friendship = math.clamp(tracker.friendship + 0.08 * strength, 0, 1)
	elseif cardId == "PerfectZone" or cardId == "DreamModeBoost" then
		-- Only nudge accuracy after gameplay has established a baseline.
		if tracker.accuracy ~= nil and tracker.validAttempts > 0 then
			tracker.accuracy = math.clamp(tracker.accuracy + 0.04 * strength, 0, 1)
		end
		tracker.flow = math.clamp(tracker.flow + 0.05 * strength, 0, 1)
	elseif cardId == "RescueSpotlight" then
		tracker.instability = math.clamp(tracker.instability - 0.08 * strength, 0, 1)
	elseif cardId == "SlowMotion" then
		tracker.flow = math.clamp(tracker.flow + 0.03 * strength, 0, 1)
	end
	return cardId
end

function GameplayHooks.activeModifier(tracker: Tracker, cardId: string, now: number): number?
	local modifier = tracker.modifiers[cardId]
	if not modifier then
		return nil
	end
	if now > modifier.expiresAt then
		tracker.modifiers[cardId] = nil
		return nil
	end
	return modifier.strength
end

function GameplayHooks.telemetrySamples(
	tracker: Tracker,
	roundId: string,
	gameId: string
): { TelemetrySample }
	local projected = GradePolicy.projectedScore(tracker.accuracy)
	local samples: { TelemetrySample } = {
		{ roundId = roundId, metric = "Score", value = tracker.score },
		{ roundId = roundId, metric = "Progress", value = tracker.progress },
		{
			roundId = roundId,
			metric = "Accuracy",
			value = if tracker.accuracy ~= nil then tracker.accuracy else 0,
		},
		{
			roundId = roundId,
			metric = "ProjectedGrade",
			value = projected,
		},
		{ roundId = roundId, metric = "Combo", value = tracker.combo },
	}

	if gameId == "CheeseTower" then
		table.insert(samples, {
			roundId = roundId,
			metric = "Instability",
			value = tracker.instability,
			tag = if tracker.remainingObjects ~= nil
				then `remaining:{tracker.remainingObjects}`
				else nil,
		})
	elseif gameId == "DogDash" then
		table.insert(samples, {
			roundId = roundId,
			metric = "Friendship",
			value = tracker.friendship,
			tag = if tracker.activeDog then `dog:{tracker.activeDog}` else nil,
		})
	else
		table.insert(samples, {
			roundId = roundId,
			metric = "Flow",
			value = tracker.flow,
			tag = if tracker.remainingObjects ~= nil
				then `remaining:{tracker.remainingObjects}`
				else nil,
		})
	end

	return samples
end

return GameplayHooks
