--!strict

export type Result = {
	roundId: string,
	gameId: string,
	score: number,
	grade: string,
	metrics: { [string]: number },
}

export type ActGrade = {
	gameId: string,
	grade: string,
	score: number,
}

export type Options = {
	starName: string,
	mood: string?,
	directorCueGrade: string,
	finaleEnergy: number,
}

export type Summary = {
	title: string,
	featuredTrophy: string,
	bestMoment: string,
	bestAct: string,
	dogPose: string,
	lightingAccent: string,
	ratthewCallback: string,
	confettiTreatment: string,
	actGrades: { ActGrade },
	directorCueGrade: string,
	finaleEnergy: number,
	overallGrade: string,
}

local PerformanceSummary = {}

local GRADE_VALUE: { [string]: number } = { D = 1, C = 2, B = 3, A = 4, S = 5 }
local GAME_NAMES: { [string]: string } = {
	CheeseTower = "Cheese Atelier",
	DogDash = "Garden Dash",
	SatisfyStation = "Dream Studio",
}

local function gradeFor(value: number): string
	if value >= 4.6 then
		return "S"
	elseif value >= 3.7 then
		return "A"
	elseif value >= 2.7 then
		return "B"
	elseif value >= 1.7 then
		return "C"
	end
	return "D"
end

local function metricMoment(result: Result): (number, string)
	local candidates = {
		{ key = "Perfects", label = "perfect moments", scale = 0.12 },
		{ key = "Combo", label = "combo streak", scale = 0.1 },
		{ key = "Friendship", label = "friendship finish", scale = 1 },
		{ key = "Flow", label = "dream flow", scale = 1 },
		{ key = "Accuracy", label = "precision moment", scale = 1 },
	}
	local bestValue = -1
	local bestLabel = "standout finish"
	for _, candidate in candidates do
		local value = result.metrics[candidate.key]
		if type(value) == "number" then
			local normalized = math.clamp(value * candidate.scale, 0, 1)
			if normalized > bestValue then
				bestValue = normalized
				bestLabel = candidate.label
			end
		end
	end
	return math.max(0, bestValue), bestLabel
end

function PerformanceSummary.build(results: { Result }, options: Options): Summary
	local actGrades: { ActGrade } = {}
	local gradeTotal = 0
	local bestAct = "Premiere"
	local bestGameId = ""
	local bestRank = -math.huge
	local bestMoment = "A night made together"
	local bestMomentRank = -math.huge

	for index, result in results do
		local gradeValue = GRADE_VALUE[result.grade] or 1
		gradeTotal += gradeValue
		table.insert(actGrades, {
			gameId = result.gameId,
			grade = if GRADE_VALUE[result.grade] then result.grade else "D",
			score = math.max(0, math.floor(result.score)),
		})
		local rank = gradeValue * 1_000_000 + math.max(0, result.score) - index * 0.001
		if rank > bestRank then
			bestRank = rank
			bestGameId = result.gameId
			bestAct = GAME_NAMES[result.gameId] or result.gameId
		end
		local momentValue, momentLabel = metricMoment(result)
		local momentRank = momentValue * 10 + gradeValue - index * 0.001
		if momentRank > bestMomentRank then
			bestMomentRank = momentRank
			bestMoment = `{GAME_NAMES[result.gameId] or result.gameId}: {momentLabel}`
		end
	end

	local average = if #results > 0 then gradeTotal / #results else 1
	local overallGrade = gradeFor(average)
	local title = if average >= 4.6
		then `{options.starName}, Headliner of the Night`
		elseif average >= 3.7 then `{options.starName}, Birthday Showstopper`
		else `{options.starName}, Heart of the Show`
	local featuredTrophy = if bestGameId == "CheeseTower"
		then "Golden Cheese Crown"
		elseif bestGameId == "DogDash" then "Moonlit Paw Cup"
		elseif bestGameId == "SatisfyStation" then "Dreammaker Ribbon"
		else "Premiere Keepsake"
	local dogPose = if bestGameId == "DogDash" or average >= 4
		then "VictoryTandem"
		else "CozyCuddle"
	local lightingAccent = if options.mood == "Dreamy"
		then "Sky"
		elseif options.mood == "Playful" then "Blush"
		elseif bestGameId == "SatisfyStation" then "Mint"
		else "Butter"
	local finaleEnergy = math.clamp(math.floor(options.finaleEnergy + 0.5), 0, 100)
	local confettiTreatment = if finaleEnergy >= 75
		then "StarlightCascade"
		elseif finaleEnergy >= 40 then "RibbonDrift"
		else "GentlePetals"

	return {
		title = title,
		featuredTrophy = featuredTrophy,
		bestMoment = bestMoment,
		bestAct = bestAct,
		dogPose = dogPose,
		lightingAccent = lightingAccent,
		ratthewCallback = if bestGameId == "CheeseTower"
			then "Ratthew declares the crown perfectly aged."
			else "Ratthew saved one tiny victory cheese for the encore.",
		confettiTreatment = confettiTreatment,
		actGrades = actGrades,
		directorCueGrade = options.directorCueGrade,
		finaleEnergy = finaleEnergy,
		overallGrade = overallGrade,
	}
end

return table.freeze(PerformanceSummary)
