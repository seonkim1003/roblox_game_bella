--!strict

local PerformanceSummary = require("../src/server/PerformanceSummary")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local results: { PerformanceSummary.Result } = {
	{
		roundId = "r1",
		gameId = "CheeseTower",
		score = 840,
		grade = "A",
		metrics = { Combo = 4, Accuracy = 0.82 },
	},
	{
		roundId = "r2",
		gameId = "DogDash",
		score = 980,
		grade = "S",
		metrics = { Friendship = 0.96 },
	},
	{
		roundId = "r3",
		gameId = "SatisfyStation",
		score = 720,
		grade = "B",
		metrics = { Flow = 0.75 },
	},
}

local summary = PerformanceSummary.build(results, {
	starName = "Bella",
	mood = "Dreamy",
	directorCueGrade = "A",
	finaleEnergy = 82.4,
})
expect(summary.bestAct == "Garden Dash", "best authoritative act is selected")
expect(summary.featuredTrophy == "Moonlit Paw Cup", "trophy follows best act")
expect(summary.dogPose == "VictoryTandem", "dog pose follows performance")
expect(summary.lightingAccent == "Sky", "mood selects lighting accent")
expect(summary.confettiTreatment == "StarlightCascade", "energy selects confetti")
expect(summary.directorCueGrade == "A", "Director grade is preserved")
expect(summary.finaleEnergy == 82, "finale energy is bounded and rounded")
expect(#summary.actGrades == 3 and summary.actGrades[2].grade == "S", "all grades remain")
expect(string.find(summary.title, "Bella") ~= nil, "title is personalized")
expect(string.find(summary.bestMoment, "Garden Dash") ~= nil, "best moment is data-driven")

local empty = PerformanceSummary.build({}, {
	starName = "Bella",
	mood = nil,
	directorCueGrade = "B",
	finaleEnergy = -20,
})
expect(empty.bestAct == "Premiere", "empty summary has safe fallback")
expect(empty.finaleEnergy == 0, "energy clamps low")
expect(empty.overallGrade == "D", "empty summary has deterministic grade")

print(`PASS PerformanceSummary.spec ({assertions} assertions)`)
