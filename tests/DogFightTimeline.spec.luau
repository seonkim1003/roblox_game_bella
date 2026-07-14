--!strict

local DogFightTimeline = require("../src/server/DogFightTimeline")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local function namesFor(
	events: { DogFightTimeline.Event },
	kind: DogFightTimeline.EventKind
): { string }
	local names: { string } = {}
	for _, event in events do
		if event.kind == kind and event.name then
			table.insert(names, event.name)
		end
	end
	return names
end

local full = DogFightTimeline.new()
local allEvents = DogFightTimeline.advance(full, DogFightTimeline.duration())
local beatNames = namesFor(allEvents, "Beat")
expect(
	table.concat(beatNames, ",") == "FaceOff,Charge,Clash,Tussle,GigiStrike,GigiWins,VictoryPose",
	"beats emit once in authored order"
)
expect(allEvents[#allEvents].kind == "Complete", "completion is the final timeline event")
expect(full.status == "Complete", "full timeline reaches complete state")
expect(DogFightTimeline.remaining(full) == 0, "completed timeline has no remaining time")

local cancelled = DogFightTimeline.new()
local opening = DogFightTimeline.advance(cancelled, 1.2)
expect(table.concat(namesFor(opening, "Beat"), ",") == "FaceOff,Charge", "opening beats emit")
expect(DogFightTimeline.cancel(cancelled), "active timeline cancels once")
expect(cancelled.status == "Cancelled", "cancel transitions to cancelled")
expect(#DogFightTimeline.advance(cancelled, 100) == 0, "cancelled timeline emits no later events")
expect(not DogFightTimeline.cancel(cancelled), "repeated cancellation is idempotent")
expect(DogFightTimeline.remaining(cancelled) == 0, "cancelled timeline has no remaining time")

local replay = DogFightTimeline.new()
local replayOpening = DogFightTimeline.advance(replay, 0.1)
expect(
	table.concat(namesFor(replayOpening, "Beat"), ",") == "FaceOff",
	"replay starts from the first beat"
)
expect(replay.status == "Playing", "replay has independent active state")

local completed = DogFightTimeline.new()
local firstCompletion = DogFightTimeline.advance(completed, DogFightTimeline.duration())
local completionCount = 0
for _, event in firstCompletion do
	if event.kind == "Complete" then
		completionCount += 1
	end
end
expect(completionCount == 1, "completion emits exactly once")
expect(
	#DogFightTimeline.advance(completed, DogFightTimeline.duration() + 10) == 0,
	"completed timeline cannot emit duplicate cleanup"
)
expect(not DogFightTimeline.cancel(completed), "completed timeline cannot be cancelled afterward")

local ordered = DogFightTimeline.new()
local first = DogFightTimeline.advance(ordered, 2.4)
local second = DogFightTimeline.advance(ordered, 1)
expect(#namesFor(first, "Beat") == 3, "advance emits all due beats")
expect(#second == 0, "out-of-order clock input cannot replay events")

print(`PASS DogFightTimeline.spec ({assertions} assertions)`)
