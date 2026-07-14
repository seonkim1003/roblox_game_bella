--!strict

local ContractValidation = require("../src/shared/ContractValidation")
local TelemetryMock = require("../src/shared/TelemetryMock")
local TokenBucket = require("../src/server/TokenBucket")

local assertions = 0

local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local function validInput(sequence: number): { [string]: any }
	return {
		roundId = "round-1",
		sequence = sequence,
		action = "Place",
		value = 0.5,
		clientTime = 100,
	}
end

expect(
	ContractValidation.validateRoundInput(validInput(1), "round-1", 0, 100, "CheeseTower"),
	"valid input"
)
expect(
	not ContractValidation.validateRoundInput(validInput(1), "round-2", 0, 100, "CheeseTower"),
	"stale round rejected"
)
expect(
	not ContractValidation.validateRoundInput(validInput(1), "round-1", 1, 100, "CheeseTower"),
	"replayed sequence rejected"
)
expect(
	not ContractValidation.validateRoundInput(validInput(2_000), "round-1", 1, 100, "CheeseTower"),
	"sequence jump rejected"
)
expect(
	not ContractValidation.validateRoundInput(validInput(1), "round-1", 0, 120, "CheeseTower"),
	"timestamp drift rejected"
)

local wrongAction = validInput(2)
wrongAction.action = "Jump"
expect(
	not ContractValidation.validateRoundInput(wrongAction, "round-1", 1, 100, "CheeseTower"),
	"cross-game action rejected"
)

local outOfRange = validInput(2)
outOfRange.value = 1.5
expect(
	not ContractValidation.validateRoundInput(outOfRange, "round-1", 1, 100, "CheeseTower"),
	"value above schema max rejected"
)

local missingValue = validInput(2)
missingValue.value = nil
expect(
	not ContractValidation.validateRoundInput(missingValue, "round-1", 1, 100, "CheeseTower"),
	"required Place value rejected when missing"
)

expect(
	not ContractValidation.validateActionInterval("DogDash", "Jump", 10.05, 10),
	"jump frequency limit rejected"
)

local cyclic: { [string]: any } = {}
cyclic.self = cyclic
expect(not ContractValidation.isBoundedPayload(cyclic), "cyclic payload rejected")

local deep = { a = { b = { c = { d = { e = true } } } } }
expect(not ContractValidation.isBoundedPayload(deep), "deep payload rejected")
local oversized: { [string]: string } = {}
for index = 1, 20 do
	oversized[`field{index}`] = string.rep("x", 150)
end
expect(not ContractValidation.isBoundedPayload(oversized), "oversized payload rejected")
expect(
	ContractValidation.validateTelemetry({
		roundId = "round-1",
		metric = "Progress",
		value = 0.4,
	}, "round-1"),
	"valid telemetry"
)
expect(not ContractValidation.validateTelemetry({
	roundId = "round-1",
	metric = "RawInternalKey",
	value = 0.4,
}, "round-1"), "unknown telemetry metric rejected")

local accepted, bucket = TokenBucket.consume(nil, 0, 2, 1)
expect(accepted and bucket.tokens == 1, "new bucket consumes one token")
accepted, bucket = TokenBucket.consume(bucket, 0, 2, 1)
expect(accepted and bucket.tokens == 0, "bucket permits configured burst")
accepted, bucket = TokenBucket.consume(bucket, 0, 2, 1)
expect(not accepted, "empty bucket rejects")
accepted, bucket = TokenBucket.consume(bucket, 0.5, 2, 1)
expect(not accepted and bucket.tokens == 0.5, "partial refill remains rejected")
accepted, bucket = TokenBucket.consume(bucket, 1, 2, 1)
expect(accepted and bucket.tokens == 0, "refilled token is accepted")

local first = TelemetryMock.sampleAt("round-1", "CheeseTower", 42, 20)
local second = TelemetryMock.sampleAt("round-1", "CheeseTower", 42, 20)
expect(#first == 4, "mock emits focused metric set")
for index, sample in first do
	expect(sample.metric == second[index].metric, "mock metric is deterministic")
	expect(sample.value == second[index].value, "mock value is deterministic")
	expect(sample.roundId == "round-1", "mock binds every sample to the round")
end

print(`PASS ContractValidation.spec ({assertions} assertions)`)
