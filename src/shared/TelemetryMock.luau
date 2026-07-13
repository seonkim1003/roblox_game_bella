--!strict

-- Deterministic fake telemetry for Director graph development before gameplay wiring.

export type Sample = {
	roundId: string,
	metric: string,
	value: number,
	tag: string?,
}

local TelemetryMock = {}

local function noise(seed: number, tick: number): number
	local value = math.sin(seed * 0.013 + tick * 12.9898) * 43_758.5453
	return value - math.floor(value)
end

function TelemetryMock.sampleAt(
	roundId: string,
	gameId: string,
	seed: number,
	tick: number
): { Sample }
	local progress = math.clamp(tick / 300, 0, 1)
	local wobble = (noise(seed, tick) - 0.5) * 0.08
	local accuracy = math.clamp(0.78 + progress * 0.14 + wobble, 0, 1)
	local samples: { Sample } = {
		{ roundId = roundId, metric = "Progress", value = progress },
		{ roundId = roundId, metric = "Accuracy", value = accuracy },
		{ roundId = roundId, metric = "ProjectedGrade", value = accuracy * 100 },
	}

	if gameId == "CheeseTower" then
		table.insert(samples, {
			roundId = roundId,
			metric = "Instability",
			value = math.clamp(0.34 - progress * 0.2 - wobble, 0, 1),
		})
	elseif gameId == "DogDash" then
		table.insert(samples, {
			roundId = roundId,
			metric = "Friendship",
			value = math.clamp(progress * 1.1, 0, 1),
		})
	else
		table.insert(samples, {
			roundId = roundId,
			metric = "Flow",
			value = math.clamp(0.55 + progress * 0.4 + wobble, 0, 1),
		})
	end

	return samples
end

return TelemetryMock
