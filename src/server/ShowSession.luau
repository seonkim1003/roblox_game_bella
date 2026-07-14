--!strict

-- Pure authoritative Premiere session state. Roblox services remain in the
-- orchestration layer so every transition can be tested under Lune.

export type Phase =
	"Lobby"
	| "Invitation"
	| "Lounge"
	| "ActIntroduction"
	| "Minigame"
	| "ActResult"
	| "Interlude"
	| "HeadlinerFinale"
	| "KeepsakeResult"

export type Mood = "Cozy" | "Playful" | "Dreamy"

export type Result = {
	roundId: string,
	gameId: string,
	score: number,
	grade: string,
	metrics: { [string]: number },
}

export type State = {
	sessionId: string,
	phase: Phase,
	revision: number,
	mood: Mood?,
	actIndex: number,
	activeGameId: string?,
	results: { Result },
	finaleSkipDirector: boolean,
	finaleSkipStar: boolean,
	encoreRequested: boolean,
	phaseStartedAt: number,
}

export type Transition = {
	state: State,
	changed: boolean,
	error: string?,
}

local VALID_MOODS: { [string]: boolean } = { Cozy = true, Playful = true, Dreamy = true }
local ORDINARY_CINEMATICS: { [string]: boolean } = {
	ActIntroduction = true,
	ActResult = true,
	Interlude = true,
}

local ShowSession = {}

local function copyResults(results: { Result }): { Result }
	local copy = {}
	for _, result in results do
		table.insert(copy, {
			roundId = result.roundId,
			gameId = result.gameId,
			score = result.score,
			grade = result.grade,
			metrics = table.clone(result.metrics),
		})
	end
	return copy
end

local function clone(state: State): State
	return {
		sessionId = state.sessionId,
		phase = state.phase,
		revision = state.revision,
		mood = state.mood,
		actIndex = state.actIndex,
		activeGameId = state.activeGameId,
		results = copyResults(state.results),
		finaleSkipDirector = state.finaleSkipDirector,
		finaleSkipStar = state.finaleSkipStar,
		encoreRequested = state.encoreRequested,
		phaseStartedAt = state.phaseStartedAt,
	}
end

local function reject(state: State, reason: string): Transition
	return { state = clone(state), changed = false, error = reason }
end

local function accept(state: State, phase: Phase, now: number): Transition
	state.phase = phase
	state.phaseStartedAt = now
	state.revision += 1
	return { state = state, changed = true, error = nil }
end

function ShowSession.new(sessionId: string, now: number): State
	return {
		sessionId = sessionId,
		phase = "Lobby",
		revision = 0,
		mood = nil,
		actIndex = 0,
		activeGameId = nil,
		results = {},
		finaleSkipDirector = false,
		finaleSkipStar = false,
		encoreRequested = false,
		phaseStartedAt = now,
	}
end

function ShowSession.openInvitation(state: State, now: number): Transition
	if state.phase ~= "Lobby" then
		return reject(state, "invitation is only available from the lobby")
	end
	return accept(clone(state), "Invitation", now)
end

function ShowSession.chooseMood(state: State, mood: string, now: number): Transition
	if state.phase ~= "Invitation" then
		return reject(state, "mood can only be chosen from the invitation")
	end
	if not VALID_MOODS[mood] then
		return reject(state, "unknown mood")
	end
	local nextState = clone(state)
	nextState.mood = mood :: Mood
	return accept(nextState, "Lounge", now)
end

function ShowSession.introduceAct(state: State, gameId: string, now: number): Transition
	if state.phase ~= "Lounge" and state.phase ~= "Interlude" then
		return reject(state, "the next act cannot be introduced now")
	end
	if gameId == "" then
		return reject(state, "game id is required")
	end
	local nextState = clone(state)
	nextState.activeGameId = gameId
	nextState.actIndex += 1
	return accept(nextState, "ActIntroduction", now)
end

function ShowSession.beginAct(state: State, now: number): Transition
	if state.phase ~= "ActIntroduction" or state.activeGameId == nil then
		return reject(state, "there is no introduced act")
	end
	return accept(clone(state), "Minigame", now)
end

function ShowSession.completeAct(state: State, result: Result, now: number): Transition
	if state.phase ~= "Minigame" or state.activeGameId ~= result.gameId then
		return reject(state, "result does not match the active act")
	end
	local nextState = clone(state)
	table.insert(nextState.results, {
		roundId = result.roundId,
		gameId = result.gameId,
		score = result.score,
		grade = result.grade,
		metrics = table.clone(result.metrics),
	})
	return accept(nextState, "ActResult", now)
end

function ShowSession.advance(state: State, actCount: number, now: number): Transition
	if state.phase == "ActResult" then
		if #state.results >= actCount then
			local nextState = clone(state)
			nextState.activeGameId = nil
			return accept(nextState, "HeadlinerFinale", now)
		end
		return accept(clone(state), "Interlude", now)
	elseif state.phase == "Interlude" then
		return reject(state, "the next act must be selected")
	elseif state.phase == "HeadlinerFinale" then
		return reject(state, "both players must confirm a finale skip")
	end
	return reject(state, "the show cannot advance from this phase")
end

function ShowSession.skipOrdinary(state: State, actCount: number, now: number): Transition
	if not ORDINARY_CINEMATICS[state.phase] then
		return reject(state, "this moment cannot be skipped by one player")
	end
	if state.phase == "ActIntroduction" then
		return ShowSession.beginAct(state, now)
	end
	return ShowSession.advance(state, actCount, now)
end

function ShowSession.confirmFinaleSkip(state: State, role: string, now: number): Transition
	if state.phase ~= "HeadlinerFinale" then
		return reject(state, "the finale is not active")
	end
	if role ~= "Director" and role ~= "Star" then
		return reject(state, "unknown role")
	end
	local nextState = clone(state)
	if role == "Director" then
		nextState.finaleSkipDirector = true
	else
		nextState.finaleSkipStar = true
	end
	if nextState.finaleSkipDirector and nextState.finaleSkipStar then
		return accept(nextState, "KeepsakeResult", now)
	end
	nextState.revision += 1
	return { state = nextState, changed = true, error = nil }
end

function ShowSession.completeFinale(state: State, now: number): Transition
	if state.phase ~= "HeadlinerFinale" then
		return reject(state, "the finale is not active")
	end
	return accept(clone(state), "KeepsakeResult", now)
end

function ShowSession.requestEncore(state: State): Transition
	if state.phase ~= "KeepsakeResult" then
		return reject(state, "encore is only available from the keepsake")
	end
	if state.encoreRequested then
		return reject(state, "encore was already requested")
	end
	local nextState = clone(state)
	nextState.encoreRequested = true
	nextState.revision += 1
	return { state = nextState, changed = true, error = nil }
end

function ShowSession.replay(state: State, now: number): Transition
	if state.phase ~= "KeepsakeResult" then
		return reject(state, "replay is only available from the keepsake")
	end
	local nextState = ShowSession.new(state.sessionId, now)
	nextState.phase = "Lounge"
	nextState.mood = state.mood
	nextState.revision = state.revision + 1
	return { state = nextState, changed = true, error = nil }
end

function ShowSession.snapshot(state: State): State
	return clone(state)
end

return ShowSession
