--!strict
-- Pure tests for Agent A GameplayHooks (grades, tags, helpful card modifiers).

local GameplayHooks = require("../src/server/minigames/lib/GameplayHooks")

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
	tracker.accuracy = 0.95
	tracker.perfects = 3
	check("grade S for elite accuracy", GameplayHooks.gradeFor(tracker) == "S")
	tracker.accuracy = 0.5
	check("grade C for mid accuracy", GameplayHooks.gradeFor(tracker) == "C")
end

do
	local tracker = GameplayHooks.newTracker()
	tracker.score = 42.6
	tracker.progress = 0.5
	local result = GameplayHooks.result(tracker, "round-test")
	check("result uses round id", result.roundId == "round-test")
	check("result floors score", result.score == 43)
	check("result exposes accuracy metric", type(result.metrics.Accuracy) == "number")
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
	check("perfect zone raises accuracy", tracker.accuracy > 0.8)
	check("modifier is active", GameplayHooks.activeModifier(tracker, "PerfectZone", 11) ~= nil)
	check("modifier expires", GameplayHooks.activeModifier(tracker, "PerfectZone", 14) == nil)
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
