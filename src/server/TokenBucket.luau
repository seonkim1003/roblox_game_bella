--!strict

export type Bucket = {
	tokens: number,
	updatedAt: number,
}

local TokenBucket = {}

function TokenBucket.consume(
	bucket: Bucket?,
	now: number,
	capacity: number,
	refillPerSecond: number,
	cost: number?
): (boolean, Bucket)
	local requested = cost or 1
	local current = bucket or { tokens = capacity, updatedAt = now }
	local elapsed = math.max(0, now - current.updatedAt)
	local available = math.min(capacity, current.tokens + elapsed * refillPerSecond)
	local accepted = requested > 0 and available >= requested

	return accepted,
		{
			tokens = if accepted then available - requested else available,
			updatedAt = now,
		}
end

return TokenBucket
