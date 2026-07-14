--!strict
-- Pure Dog Dash authority rules (Lune-safe). Progress is server-owned and
-- advances only through successful actions, not client Route jumps.

local DogDashRules = {}

DogDashRules.SEGMENT_SECONDS = 50
DogDashRules.SUCCESS_THRESHOLD = 0.45
DogDashRules.PROGRESS_PER_SUCCESS = 0.08
DogDashRules.COMPLETE_PROGRESS = 0.95
DogDashRules.MAX_SCORE = 400

export type State = {
	score: number,
	combo: number,
	progress: number,
	accuracy: number?,
	validAttempts: number,
	friendship: number,
	completed: boolean,
	activeDogIndex: number,
}

function DogDashRules.newState(): State
	return {
		score = 0,
		combo = 0,
		progress = 0,
		accuracy = nil,
		validAttempts = 0,
		friendship = 0,
		completed = false,
		activeDogIndex = 1,
	}
end

function DogDashRules.canComplete(state: State): boolean
	return not state.completed and state.progress >= DogDashRules.COMPLETE_PROGRESS
end

function DogDashRules.applySwitch(state: State): boolean
	if state.completed then
		return false
	end
	state.activeDogIndex = if state.activeDogIndex == 1 then 2 else 1
	return true
end

function DogDashRules.applySkill(state: State, valueInput: number): boolean
	if state.completed then
		return false
	end
	local value = math.clamp(valueInput, 0, 1)
	state.validAttempts += 1
	local success = value >= DogDashRules.SUCCESS_THRESHOLD
	if success then
		local points = 10 + state.combo * 2
		state.score = math.min(DogDashRules.MAX_SCORE, state.score + points)
		state.combo += 1
		state.friendship = math.clamp(state.friendship + 0.04, 0, 1)
		if state.accuracy == nil then
			state.accuracy = value
		else
			state.accuracy = state.accuracy * 0.75 + value * 0.25
		end
		state.progress = math.clamp(state.progress + DogDashRules.PROGRESS_PER_SUCCESS, 0, 1)
	else
		state.combo = 0
		state.score = math.max(0, state.score - 5)
		if state.accuracy ~= nil then
			state.accuracy = state.accuracy * 0.85
		else
			state.accuracy = math.clamp(value, 0, 1)
		end
	end
	return true
end

-- Route is cosmetic/heartbeat only. Absolute client progress is ignored.
function DogDashRules.applyRoute(_state: State, _valueInput: number): boolean
	return true
end

return DogDashRules
