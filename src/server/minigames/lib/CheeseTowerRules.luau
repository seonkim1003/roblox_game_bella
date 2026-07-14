--!strict
-- Pure Cheese Tower authority rules (Lune-safe). Placement caps, one Bank,
-- gated Topper, and Complete requirements — no Roblox APIs.

local CheeseTowerRules = {}

CheeseTowerRules.MAX_PLACES = 12
CheeseTowerRules.MAX_PLACE_POINTS = 5
CheeseTowerRules.TOPPER_SCALE = 2
CheeseTowerRules.MAX_SCORE = 160

export type State = {
	places: number,
	score: number,
	banked: boolean,
	topperUsed: boolean,
	topperArmed: boolean,
	completed: boolean,
	validAttempts: number,
	accuracy: number?,
	perfects: number,
	combo: number,
	rescues: number,
	instability: number,
	progress: number,
}

function CheeseTowerRules.newState(): State
	return {
		places = 0,
		score = 0,
		banked = false,
		topperUsed = false,
		topperArmed = false,
		completed = false,
		validAttempts = 0,
		accuracy = nil,
		perfects = 0,
		combo = 0,
		rescues = 0,
		instability = 0.3,
		progress = 0,
	}
end

function CheeseTowerRules.armTopper(state: State)
	if not state.topperUsed and not state.completed then
		state.topperArmed = true
	end
end

local function blendAccuracy(state: State, sample: number)
	local clamped = math.clamp(sample, 0, 1)
	if state.accuracy == nil then
		state.accuracy = clamped
	else
		state.accuracy = state.accuracy * 0.7 + clamped * 0.3
	end
	state.validAttempts += 1
end

local function applyPoints(
	state: State,
	accuracy: number,
	pointScale: number,
	doublePoints: boolean
)
	local points = math.floor((1 + math.floor(accuracy * 4)) * pointScale + 0.5)
	if doublePoints then
		points *= 2
	end
	state.score = math.min(CheeseTowerRules.MAX_SCORE, state.score + points)
end

function CheeseTowerRules.canPlace(state: State): boolean
	return not state.completed and not state.banked and state.places < CheeseTowerRules.MAX_PLACES
end

function CheeseTowerRules.canTopper(state: State): boolean
	return CheeseTowerRules.canPlace(state) and not state.topperUsed
end

function CheeseTowerRules.canBank(state: State): boolean
	return not state.completed and not state.banked and state.places > 0
end

function CheeseTowerRules.canComplete(state: State): boolean
	return not state.completed and (state.banked or state.places >= CheeseTowerRules.MAX_PLACES)
end

function CheeseTowerRules.applyPlace(
	state: State,
	accuracyInput: number,
	pointScale: number,
	doublePoints: boolean
): boolean
	if not CheeseTowerRules.canPlace(state) then
		return false
	end
	local accuracy = math.clamp(accuracyInput, 0, 1)
	state.places += 1
	applyPoints(state, accuracy, pointScale, doublePoints)
	blendAccuracy(state, accuracy)
	state.instability = math.clamp(1 - accuracy, 0, 1)
	state.progress = math.clamp(state.places / CheeseTowerRules.MAX_PLACES, 0, 1)
	if accuracy >= 0.92 then
		state.perfects += 1
		state.combo += 1
	else
		state.combo = 0
	end
	return true
end

function CheeseTowerRules.applyTopper(
	state: State,
	accuracyInput: number,
	doublePoints: boolean
): boolean
	if not CheeseTowerRules.canTopper(state) then
		return false
	end
	local ok = CheeseTowerRules.applyPlace(
		state,
		accuracyInput,
		CheeseTowerRules.TOPPER_SCALE,
		doublePoints
	)
	if ok then
		state.topperUsed = true
		state.topperArmed = false
	end
	return ok
end

function CheeseTowerRules.applyBank(state: State): boolean
	if not CheeseTowerRules.canBank(state) then
		return false
	end
	local height = state.places
	local bonus = math.floor(state.score * 0.1 + height * 2 + 0.5)
	state.score = math.min(CheeseTowerRules.MAX_SCORE, state.score + bonus)
	state.banked = true
	state.progress = math.clamp(state.progress + 0.1, 0, 1)
	state.topperArmed = false
	return true
end

function CheeseTowerRules.applyRescue(state: State, accuracyInput: number?): boolean
	if state.completed or state.banked then
		return false
	end
	state.rescues += 1
	state.instability = math.clamp(state.instability - 0.2, 0, 1)
	if type(accuracyInput) == "number" and accuracyInput > 0 then
		return CheeseTowerRules.applyPlace(state, accuracyInput, 1, false)
	end
	return true
end

return CheeseTowerRules
