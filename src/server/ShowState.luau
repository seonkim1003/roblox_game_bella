--!strict

-- Pure show-state reducer. This module intentionally has no Roblox dependencies so
-- the authoritative transition rules can be exercised by Lune.

export type ShowPhase = "Lobby" | "Hub" | "Minigame" | "Finale"
export type MinigameId = "CheeseTower" | "DogDash" | "SatisfyStation"

export type State = {
	phase: ShowPhase,
	difficulty: number,
	activeMinigame: MinigameId?,
}

export type TransitionResult = {
	state: State,
	changed: boolean,
	error: string?,
}

local MIN_DIFFICULTY = 0
local MAX_DIFFICULTY = 1

local VALID_MINIGAMES: { [string]: boolean } = {
	CheeseTower = true,
	DogDash = true,
	SatisfyStation = true,
}

local ShowState = {}

local function cloneState(state: State): State
	return {
		phase = state.phase,
		difficulty = state.difficulty,
		activeMinigame = state.activeMinigame,
	}
end

local function unchanged(state: State): TransitionResult
	return {
		state = cloneState(state),
		changed = false,
		error = nil,
	}
end

local function rejected(state: State, reason: string): TransitionResult
	return {
		state = cloneState(state),
		changed = false,
		error = reason,
	}
end

local function accepted(state: State): TransitionResult
	return {
		state = state,
		changed = true,
		error = nil,
	}
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

function ShowState.new(defaultDifficulty: number?): State
	local requested = defaultDifficulty or 0.5
	local difficulty = if isFinite(requested)
		then math.clamp(requested, MIN_DIFFICULTY, MAX_DIFFICULTY)
		else 0.5

	return {
		phase = "Lobby",
		difficulty = difficulty,
		activeMinigame = nil,
	}
end

function ShowState.transition(
	state: State,
	action: string,
	payload: { [string]: any }?
): TransitionResult
	if action == "StartHub" then
		if state.phase == "Hub" then
			return unchanged(state)
		end
		if state.phase ~= "Lobby" then
			return rejected(state, "StartHub is only available from the lobby")
		end

		local nextState = cloneState(state)
		nextState.phase = "Hub"
		nextState.activeMinigame = nil
		return accepted(nextState)
	elseif action == "LaunchMinigame" then
		if state.phase ~= "Hub" and state.phase ~= "Minigame" then
			return rejected(state, "Minigames can only launch from the hub")
		end

		local id = if payload then payload.id else nil
		if type(id) ~= "string" or not VALID_MINIGAMES[id] then
			return rejected(state, "Unknown minigame")
		end
		if state.phase == "Minigame" and state.activeMinigame == id then
			return rejected(state, "That minigame is already running")
		end

		local nextState = cloneState(state)
		nextState.phase = "Minigame"
		nextState.activeMinigame = id :: MinigameId
		return accepted(nextState)
	elseif action == "EndMinigame" then
		if state.phase ~= "Minigame" or state.activeMinigame == nil then
			return rejected(state, "There is no active minigame")
		end

		local nextState = cloneState(state)
		nextState.phase = "Hub"
		nextState.activeMinigame = nil
		return accepted(nextState)
	elseif action == "MinigameComplete" then
		local id = if payload then payload.id else nil
		if state.phase ~= "Minigame" or state.activeMinigame == nil then
			return rejected(state, "There is no active minigame")
		end
		if id ~= state.activeMinigame then
			return rejected(state, "Completion came from a stale minigame")
		end

		local nextState = cloneState(state)
		nextState.phase = "Hub"
		nextState.activeMinigame = nil
		return accepted(nextState)
	elseif action == "SetDifficulty" then
		if state.phase == "Finale" then
			return rejected(state, "Difficulty is locked during the finale")
		end

		local level = if payload then payload.level else nil
		if type(level) ~= "number" or not isFinite(level) then
			return rejected(state, "Difficulty must be a finite number")
		end

		local clamped = math.clamp(level, MIN_DIFFICULTY, MAX_DIFFICULTY)
		if clamped == state.difficulty then
			return unchanged(state)
		end

		local nextState = cloneState(state)
		nextState.difficulty = clamped
		return accepted(nextState)
	elseif action == "StartFinale" then
		if state.phase ~= "Hub" then
			return rejected(state, "The finale can only start from the hub")
		end

		local nextState = cloneState(state)
		nextState.phase = "Finale"
		nextState.activeMinigame = nil
		return accepted(nextState)
	end

	return rejected(state, "Unknown state transition")
end

function ShowState.canUseLiveEffect(state: State): boolean
	return state.phase == "Hub" or state.phase == "Minigame"
end

return ShowState
