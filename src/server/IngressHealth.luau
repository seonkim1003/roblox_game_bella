--!strict

export type Category = "StaleRound" | "Sequence" | "TimestampDrift" | "RateLimit" | "Other"
export type Counts = {
	StaleRound: number,
	Sequence: number,
	TimestampDrift: number,
	RateLimit: number,
	Other: number,
}

export type IngressHealthApi = {
	new: () -> Counts,
	category: (reason: string?) -> Category,
	record: (counts: Counts, reason: string?) -> (Counts, Category),
	total: (counts: Counts) -> number,
}

local function newCounts(): Counts
	return { StaleRound = 0, Sequence = 0, TimestampDrift = 0, RateLimit = 0, Other = 0 }
end

local function category(reason: string?): Category
	if reason == "stale round" or reason == "no active round" then
		return "StaleRound" :: Category
	elseif reason == "sequence must increase" then
		return "Sequence" :: Category
	elseif reason == "timestamp drift" or reason == "invalid timestamp" then
		return "TimestampDrift" :: Category
	elseif reason == "rate limit" then
		return "RateLimit" :: Category
	else
		return "Other" :: Category
	end
end

local function record(counts: Counts, reason: string?): (Counts, Category)
	local nextCounts: Counts = {
		StaleRound = counts.StaleRound,
		Sequence = counts.Sequence,
		TimestampDrift = counts.TimestampDrift,
		RateLimit = counts.RateLimit,
		Other = counts.Other,
	}
	local resolved: Category
	if reason == "stale round" or reason == "no active round" then
		nextCounts.StaleRound += 1
		resolved = "StaleRound" :: Category
	elseif reason == "sequence must increase" then
		nextCounts.Sequence += 1
		resolved = "Sequence" :: Category
	elseif reason == "timestamp drift" or reason == "invalid timestamp" then
		nextCounts.TimestampDrift += 1
		resolved = "TimestampDrift" :: Category
	elseif reason == "rate limit" then
		nextCounts.RateLimit += 1
		resolved = "RateLimit" :: Category
	else
		nextCounts.Other += 1
		resolved = "Other" :: Category
	end
	return nextCounts, resolved
end

local function total(counts: Counts): number
	return counts.StaleRound
		+ counts.Sequence
		+ counts.TimestampDrift
		+ counts.RateLimit
		+ counts.Other
end

local api: IngressHealthApi = {
	new = newCounts,
	category = category,
	record = record,
	total = total,
}

return api
