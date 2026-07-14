--!strict

local DirectorDashboardModel = {}

export type MarkerCategory = "Card" | "Moment"
export type GradeBand = {
	grade: string,
	minimum: number,
	maximum: number,
}

export type TelemetryContext = {
	activeDog: string?,
	remainingObjects: number?,
}

export type ConnectionHealth = {
	text: string,
	severity: "Healthy" | "Warning" | "Error",
}

local CARD_IDS: { [string]: boolean } = {
	DogAssist = true,
	SlowMotion = true,
	PerfectZone = true,
	TreatRain = true,
	RescueSpotlight = true,
	DreamModeBoost = true,
	DoubleOrNothingTopper = true,
	ConfettiFinish = true,
}

local GRADE_BANDS: { GradeBand } = {
	{ grade = "D", minimum = 0, maximum = 47 },
	{ grade = "C", minimum = 48, maximum = 64 },
	{ grade = "B", minimum = 65, maximum = 79 },
	{ grade = "A", minimum = 80, maximum = 91 },
	{ grade = "S", minimum = 92, maximum = 100 },
}

function DirectorDashboardModel.gradeBands(): { GradeBand }
	return GRADE_BANDS
end

function DirectorDashboardModel.gradeFor(value: number): string
	local score = math.clamp(value, 0, 100)
	for _, band in GRADE_BANDS do
		if score <= band.maximum then
			return band.grade
		end
	end
	return "S"
end

function DirectorDashboardModel.targetBand(targetGrade: string?): GradeBand
	local target = targetGrade or "A"
	for _, band in GRADE_BANDS do
		if band.grade == target then
			return band
		end
	end
	return GRADE_BANDS[4]
end

function DirectorDashboardModel.markerCategory(markerKind: string?): MarkerCategory?
	if markerKind == nil then
		return nil
	end
	return if CARD_IDS[markerKind] == true then "Card" else "Moment"
end

function DirectorDashboardModel.telemetryContext(tag: any): TelemetryContext
	if type(tag) ~= "string" then
		return { activeDog = nil, remainingObjects = nil }
	end
	local dog = string.match(tag, "^dog:([^:]+)$")
	if dog and #dog <= 32 then
		return { activeDog = dog, remainingObjects = nil }
	end
	local remaining = string.match(tag, "^remaining:(%d+)$")
	if remaining then
		local count = tonumber(remaining)
		if count and count >= 0 and count <= 999 then
			return { activeDog = nil, remainingObjects = math.floor(count) }
		end
	end
	return { activeDog = nil, remainingObjects = nil }
end

function DirectorDashboardModel.debugSeed(raw: any): number?
	if type(raw) ~= "string" or string.match(raw, "^%d+$") == nil then
		return nil
	end
	local value = tonumber(raw)
	if not value or value < 1 then
		return nil
	end
	return math.clamp(math.floor(value), 1, 2_147_483_647)
end

function DirectorDashboardModel.connectionHealth(payload: any): ConnectionHealth
	if type(payload) ~= "table" then
		return { text = "LINK CHECK / WAITING FOR VALIDATION", severity = "Warning" }
	end
	if payload.status == "Healthy" then
		return { text = "LINK CHECK / ROUND VALIDATION RECOVERED", severity = "Healthy" }
	end
	local counts = if type(payload.counts) == "table" then payload.counts else {}
	local category = if type(payload.reason) == "string" then payload.reason else "Other"
	local count = if type(counts[category]) == "number" then math.floor(counts[category]) else 1
	local labels: { [string]: string } = {
		StaleRound = "STALE ROUND REJECTED",
		Sequence = "SEQUENCE REJECTED",
		TimestampDrift = "CLOCK DRIFT REJECTED",
		RateLimit = "RATE BURST LIMITED",
		Other = "PAYLOAD REJECTED",
	}
	if payload.recoveryPending == true and type(payload.total) == "number" then
		return {
			text = `LINK CHECK / {math.floor(payload.total)} REJECTIONS / WATCHING RECOVERY`,
			severity = "Warning",
		}
	end
	return {
		text = `LINK CHECK / {labels[category] or labels.Other} / {math.max(1, count)}`,
		severity = if category == "Other" then "Error" else "Warning",
	}
end

return table.freeze(DirectorDashboardModel)
