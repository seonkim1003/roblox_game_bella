--!strict
-- Pure tests for Agent A GameplayHooks (grades, tags, helpful card modifiers).

local GameplayHooks = require("../src/server/minigames/lib/GameplayHooks")
local GradePolicy = require("../src/shared/GradePolicy")

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

do
	local tracker = GameplayHooks.newTracker()
	check("accuracy starts unset", tracker.accuracy == nil)
	check("zero-attempt grade is D", GameplayHooks.gradeFor(tracker) == "D")
	check("zero-attempt result is D", GameplayHooks.result(tracker, "r0").grade == "D")
end

do
	local tracker = GameplayHooks.newTracker()
	tracker.accuracy = 0.95
	tracker.validAttempts = 4
	tracker.perfects = 3
	check("grade S for elite accuracy", GameplayHooks.gradeFor(tracker) == "S")
	tracker.accuracy = 0.5
	tracker.validAttempts = 2
	tracker.perfects = 0
	check("grade C for mid accuracy", GameplayHooks.gradeFor(tracker) == "C")
end

do
	local tracker = GameplayHooks.newTracker()
	tracker.score = 42.6
	tracker.progress = 0.5
	tracker.accuracy = 0.7
	tracker.validAttempts = 1
	local result = GameplayHooks.result(tracker, "round-test")
	check("result uses round id", result.roundId == "round-test")
	check("result floors score", result.score == 43)
	check("result exposes accuracy metric", type(result.metrics.Accuracy) == "number")
	check("result exposes valid attempts", result.metrics.ValidAttempts == 1)
	check(
		"projected grade uses policy",
		result.metrics.ProjectedGrade == GradePolicy.projectedScore(0.7)
	)
end

do
	local tracker = GameplayHooks.newTracker()
	local before = tracker.score
	GameplayHooks.applyDirectorEffect(
		tracker,
		{ cardId = "PerfectZone", duration = 3, strength = 1 },
		10
	)
	check("cards never grant score", tracker.score == before)
	check("perfect zone does not invent accuracy", tracker.accuracy == nil)
	check("zero attempts stay D after card", GameplayHooks.gradeFor(tracker) == "D")
	tracker.accuracy = 0.8
	tracker.validAttempts = 1
	GameplayHooks.applyDirectorEffect(
		tracker,
		{ cardId = "PerfectZone", duration = 3, strength = 1 },
		12
	)
	check(
		"perfect zone raises established accuracy",
		tracker.accuracy ~= nil and tracker.accuracy > 0.8
	)
	check("modifier is active", GameplayHooks.activeModifier(tracker, "PerfectZone", 13) ~= nil)
	check("modifier expires", GameplayHooks.activeModifier(tracker, "PerfectZone", 16) == nil)
end

do
	local tracker = GameplayHooks.newTracker()
	tracker.activeDog = "Gigi"
	tracker.remainingObjects = 4
	local dogSamples = GameplayHooks.telemetrySamples(tracker, "r1", "DogDash")
	local stationSamples = GameplayHooks.telemetrySamples(tracker, "r1", "SatisfyStation")
	local cheeseSamples = GameplayHooks.telemetrySamples(tracker, "r1", "CheeseTower")
	local dogTag: string? = nil
	local remainingTag: string? = nil
	local cheeseTag: string? = nil
	for _, sample in dogSamples do
		if sample.metric == "Friendship" then
			dogTag = sample.tag
		end
	end
	for _, sample in stationSamples do
		if sample.metric == "Flow" then
			remainingTag = sample.tag
		end
	end
	for _, sample in cheeseSamples do
		if sample.metric == "Instability" then
			cheeseTag = sample.tag
		end
	end
	check("dog telemetry tag", dogTag == "dog:Gigi")
	check("remaining object telemetry tag", remainingTag == "remaining:4")
	check("cheese remaining telemetry tag", cheeseTag == "remaining:4")
end

print(`GameplayHooks.spec: {passed} passed, {failed} failed`)
if failed > 0 then
	error("GameplayHooks.spec failed")
end
