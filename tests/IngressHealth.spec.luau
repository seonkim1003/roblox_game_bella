--!strict

local IngressHealth = require("../src/server/IngressHealth")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local counts = IngressHealth.new()
expect(IngressHealth.total(counts) == 0, "health starts clean")

local category: string
counts, category = IngressHealth.record(counts, "stale round")
expect(category == "StaleRound" and counts.StaleRound == 1, "stale rounds are classified")
counts, category = IngressHealth.record(counts, "sequence must increase")
expect(category == "Sequence" and counts.Sequence == 1, "sequence failures are classified")
counts, category = IngressHealth.record(counts, "timestamp drift")
expect(category == "TimestampDrift" and counts.TimestampDrift == 1, "drift is classified")
counts, category = IngressHealth.record(counts, "rate limit")
expect(category == "RateLimit" and counts.RateLimit == 1, "rate bursts are classified")
counts, category = IngressHealth.record(counts, "invalid action")
expect(category == "Other" and counts.Other == 1, "other failures remain visible")
expect(IngressHealth.total(counts) == 5, "health totals all categories")

print(`PASS IngressHealth.spec ({assertions} assertions)`)
