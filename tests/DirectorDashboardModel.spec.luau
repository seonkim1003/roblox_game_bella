--!strict

local Dashboard = require("../src/client/director/DirectorDashboardModel")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

expect(Dashboard.gradeFor(-10) == "D", "grade clamps below zero")
expect(Dashboard.gradeFor(47) == "D", "D upper boundary")
expect(Dashboard.gradeFor(48) == "C", "C lower boundary")
expect(Dashboard.gradeFor(65) == "B", "B lower boundary")
expect(Dashboard.gradeFor(80) == "A", "A target lower boundary")
expect(Dashboard.gradeFor(91) == "A", "A target upper boundary")
expect(Dashboard.gradeFor(92) == "S", "S lower boundary")
expect(Dashboard.gradeFor(110) == "S", "grade clamps above 100")

local target = Dashboard.targetBand("A")
expect(target.minimum == 80 and target.maximum == 91, "A target band is explicit")
expect(Dashboard.targetBand("unknown").grade == "A", "invalid target falls back to A")
expect(Dashboard.markerCategory("DogAssist") == "Card", "cue card gets card marker")
expect(Dashboard.markerCategory("Perfect") == "Moment", "telemetry moment gets moment marker")
expect(Dashboard.markerCategory(nil) == nil, "absent marker stays absent")

local dog = Dashboard.telemetryContext("dog:Gigi")
expect(dog.activeDog == "Gigi", "active dog tag is parsed")
local remaining = Dashboard.telemetryContext("remaining:7")
expect(remaining.remainingObjects == 7, "remaining-object tag is parsed")
expect(
	Dashboard.telemetryContext("remaining:-1").remainingObjects == nil,
	"negative count fails closed"
)
expect(Dashboard.telemetryContext("dog:").activeDog == nil, "empty dog tag fails closed")
expect(Dashboard.telemetryContext({}).activeDog == nil, "non-string tag fails closed")

expect(Dashboard.debugSeed("42") == 42, "debug seed parses")
expect(Dashboard.debugSeed("999999999999") == 2_147_483_647, "debug seed clamps")
expect(Dashboard.debugSeed("4.2") == nil, "fractional seed text fails closed")
expect(Dashboard.debugSeed("seed") == nil, "non-numeric seed fails closed")

local staleHealth = Dashboard.connectionHealth({
	status = "Rejected",
	reason = "StaleRound",
	counts = { StaleRound = 2 },
})
expect(staleHealth.severity == "Warning", "stale round is a warning")
expect(string.find(staleHealth.text, "STALE ROUND") ~= nil, "stale detail is visible")
local badHealth = Dashboard.connectionHealth({
	status = "Rejected",
	reason = "Other",
	counts = { Other = 1 },
})
expect(badHealth.severity == "Error", "unknown rejection is an error")
expect(
	Dashboard.connectionHealth({ status = "Healthy" }).severity == "Healthy",
	"valid traffic reports recovery"
)

print(`PASS DirectorDashboardModel.spec ({assertions} assertions)`)
