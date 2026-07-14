--!strict
-- Single official grading policy for Premiere results and director projections.
-- Accuracy starts unset (nil). Grades require at least one valid scoring attempt.

local GradePolicy = {}

export type GradeBand = {
	grade: string,
	minimum: number,
	maximum: number,
}

GradePolicy.MIN_VALID_ATTEMPTS = 1
GradePolicy.S_MIN_PERFECTS = 3

local GRADE_BANDS: { GradeBand } = {
	{ grade = "D", minimum = 0, maximum = 47 },
	{ grade = "C", minimum = 48, maximum = 64 },
	{ grade = "B", minimum = 65, maximum = 79 },
	{ grade = "A", minimum = 80, maximum = 91 },
	{ grade = "S", minimum = 92, maximum = 100 },
}

local VALID_GRADES: { [string]: boolean } = {
	S = true,
	A = true,
	B = true,
	C = true,
	D = true,
}

function GradePolicy.bands(): { GradeBand }
	return GRADE_BANDS
end

function GradePolicy.isValidGrade(grade: string?): boolean
	return type(grade) == "string" and VALID_GRADES[grade] == true
end

function GradePolicy.projectedScore(accuracy: number?): number
	if accuracy == nil then
		return 0
	end
	return math.clamp(accuracy * 100, 0, 100)
end

function GradePolicy.gradeFromProjected(projected: number): string
	local score = math.clamp(projected, 0, 100)
	for _, band in GRADE_BANDS do
		if score <= band.maximum then
			return band.grade
		end
	end
	return "S"
end

function GradePolicy.gradeFromAccuracy(
	accuracy: number?,
	validAttempts: number,
	perfects: number?
): string
	if validAttempts < GradePolicy.MIN_VALID_ATTEMPTS or accuracy == nil then
		return "D"
	end

	local grade = GradePolicy.gradeFromProjected(GradePolicy.projectedScore(accuracy))
	local perfectCount = if type(perfects) == "number" then math.max(0, math.floor(perfects)) else 0
	if grade == "S" and perfectCount < GradePolicy.S_MIN_PERFECTS then
		return "A"
	end
	return grade
end

function GradePolicy.targetBand(targetGrade: string?): GradeBand
	local target = targetGrade or "A"
	for _, band in GRADE_BANDS do
		if band.grade == target then
			return band
		end
	end
	return GRADE_BANDS[4]
end

return table.freeze(GradePolicy)
