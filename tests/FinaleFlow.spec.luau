--!strict

local PerformanceSummary = require("../src/server/PerformanceSummary")
local ShowSession = require("../src/server/ShowSession")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local games = { "CheeseTower", "DogDash", "SatisfyStation" }
local grades = { "A", "S", "B" }
local scores = { 910, 980, 840 }
local state = ShowSession.new("premiere-integration", 0)
state = ShowSession.openInvitation(state, 1).state
state = ShowSession.chooseMood(state, "Dreamy", 2).state

for index, gameId in games do
	state = ShowSession.introduceAct(state, gameId, index * 10).state
	state = ShowSession.beginAct(state, index * 10 + 1).state
	state = ShowSession.completeAct(state, {
		roundId = `round-{index}`,
		gameId = gameId,
		score = scores[index],
		grade = grades[index],
		metrics = if gameId == "DogDash" then { Friendship = 0.98 } else { Accuracy = 0.9 },
	}, index * 10 + 2).state
	state = ShowSession.advance(state, 3, index * 10 + 3).state
end

expect(state.phase == "HeadlinerFinale", "full three-act path reaches the finale")
local reconnectSnapshot = ShowSession.snapshot(state)
reconnectSnapshot.results[1].metrics.Accuracy = 0
expect(
	state.results[1].metrics.Accuracy == 0.9,
	"reconnect snapshots cannot mutate authoritative results"
)

local summary = PerformanceSummary.build(state.results, {
	starName = "Bella",
	mood = state.mood,
	directorCueGrade = "A",
	finaleEnergy = 82,
})
expect(summary.bestAct == "Garden Dash", "summary deterministically selects the highest act")
expect(
	summary.confettiTreatment == "StarlightCascade",
	"finale energy selects the premium treatment"
)

state = ShowSession.completeFinale(state, 50).state
expect(state.phase == "KeepsakeResult", "natural finale completion reaches the keepsake")
expect(#state.results == 3, "keepsake preserves every authoritative act result")

local encore = ShowSession.requestEncore(state)
expect(
	encore.changed and encore.state.encoreRequested,
	"Bella can request one deterministic encore"
)
expect(not ShowSession.requestEncore(encore.state).changed, "a repeated encore request is rejected")

local replay = ShowSession.replay(encore.state, 60)
expect(replay.state.phase == "Lounge", "replay returns to the selected-mood lounge")
expect(
	replay.state.mood == "Dreamy" and #replay.state.results == 0,
	"replay retains mood and clears results"
)

print(`PASS FinaleFlow.spec ({assertions} assertions)`)
