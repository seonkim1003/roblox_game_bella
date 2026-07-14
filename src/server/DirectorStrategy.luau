--!strict

export type CardId =
	"DogAssist"
	| "SlowMotion"
	| "PerfectZone"
	| "TreatRain"
	| "RescueSpotlight"
	| "DreamModeBoost"
	| "DoubleOrNothingTopper"
	| "ConfettiFinish"

export type CardDefinition = {
	id: CardId,
	cost: number,
	games: { [string]: boolean },
	contexts: { [string]: boolean },
}

export type State = {
	energy: number,
	finaleEnergy: number,
	hand: { CardId },
	drawIndex: number,
	seed: number,
	updatedAt: number,
	prediction: string?,
	predictionResolved: boolean,
	encoreRequested: boolean,
	lastCueAt: number?,
	cueScore: number,
	cuesPlayed: number,
}

export type Availability = {
	id: CardId,
	available: boolean,
	reason: string?,
	cost: number,
}

export type PlayResult = {
	state: State,
	accepted: boolean,
	reason: string?,
	effect: { [string]: any }?,
}

local MAX_ENERGY = 10
local ENERGY_PER_SECOND = 0.55
local MAX_FINALE_ENERGY = 100

local CARD_ORDER: { CardId } = {
	"DogAssist",
	"SlowMotion",
	"PerfectZone",
	"TreatRain",
	"RescueSpotlight",
	"DreamModeBoost",
	"DoubleOrNothingTopper",
	"ConfettiFinish",
}

local DEFINITIONS: { [CardId]: CardDefinition } = {
	DogAssist = { id = "DogAssist", cost = 3, games = {}, contexts = { Minigame = true } },
	SlowMotion = { id = "SlowMotion", cost = 3, games = {}, contexts = { Minigame = true } },
	PerfectZone = {
		id = "PerfectZone",
		cost = 2,
		games = { CheeseTower = true },
		contexts = { Minigame = true },
	},
	TreatRain = {
		id = "TreatRain",
		cost = 2,
		games = { DogDash = true },
		contexts = { Minigame = true },
	},
	RescueSpotlight = {
		id = "RescueSpotlight",
		cost = 2,
		games = { CheeseTower = true },
		contexts = { Minigame = true },
	},
	DreamModeBoost = {
		id = "DreamModeBoost",
		cost = 2,
		games = { SatisfyStation = true },
		contexts = { Minigame = true },
	},
	DoubleOrNothingTopper = {
		id = "DoubleOrNothingTopper",
		cost = 4,
		games = { CheeseTower = true },
		contexts = { Minigame = true },
	},
	ConfettiFinish = {
		id = "ConfettiFinish",
		cost = 4,
		games = {},
		contexts = { ActResult = true, HeadlinerFinale = true },
	},
}

local DirectorStrategy = {}

local function clone(state: State): State
	return {
		energy = state.energy,
		finaleEnergy = state.finaleEnergy,
		hand = table.clone(state.hand),
		drawIndex = state.drawIndex,
		seed = state.seed,
		updatedAt = state.updatedAt,
		prediction = state.prediction,
		predictionResolved = state.predictionResolved,
		encoreRequested = state.encoreRequested,
		lastCueAt = state.lastCueAt,
		cueScore = state.cueScore,
		cuesPlayed = state.cuesPlayed,
	}
end

local function deterministicIndex(seed: number, index: number): number
	local value = (seed * 1_103_515_245 + index * 12_345) % 2_147_483_647
	return (value % #CARD_ORDER) + 1
end

local function draw(state: State): CardId
	state.drawIndex += 1
	return CARD_ORDER[deterministicIndex(state.seed, state.drawIndex)]
end

local function refillHand(state: State)
	local attempts = 0
	while #state.hand < 3 and attempts < 32 do
		attempts += 1
		local candidate = draw(state)
		if not table.find(state.hand, candidate) then
			table.insert(state.hand, candidate)
		end
	end
end

function DirectorStrategy.new(seed: number, now: number): State
	local state: State = {
		energy = 6,
		finaleEnergy = 0,
		hand = {},
		drawIndex = 0,
		seed = seed,
		updatedAt = now,
		prediction = nil,
		predictionResolved = false,
		encoreRequested = false,
		lastCueAt = nil,
		cueScore = 0,
		cuesPlayed = 0,
	}
	refillHand(state)
	return state
end

function DirectorStrategy.tick(state: State, now: number): State
	local nextState = clone(state)
	local elapsed = math.max(0, now - nextState.updatedAt)
	nextState.energy = math.min(MAX_ENERGY, nextState.energy + elapsed * ENERGY_PER_SECOND)
	nextState.updatedAt = now
	return nextState
end

function DirectorStrategy.availability(
	state: State,
	cardId: CardId,
	phase: string,
	gameId: string?
): Availability
	local definition = DEFINITIONS[cardId]
	if not definition then
		return { id = cardId, available = false, reason = "Unknown cue", cost = 0 }
	end
	if not table.find(state.hand, cardId) then
		return { id = cardId, available = false, reason = "Not in hand", cost = definition.cost }
	end
	if not definition.contexts[phase] then
		return {
			id = cardId,
			available = false,
			reason = "Wait for the right moment",
			cost = definition.cost,
		}
	end
	if next(definition.games) ~= nil and (gameId == nil or not definition.games[gameId]) then
		return { id = cardId, available = false, reason = "For another act", cost = definition.cost }
	end
	if state.energy < definition.cost then
		return {
			id = cardId,
			available = false,
			reason = "Cue energy is recharging",
			cost = definition.cost,
		}
	end
	return { id = cardId, available = true, reason = nil, cost = definition.cost }
end

function DirectorStrategy.handView(state: State, phase: string, gameId: string?): { Availability }
	local view = {}
	for _, cardId in state.hand do
		table.insert(view, DirectorStrategy.availability(state, cardId :: CardId, phase, gameId))
	end
	return view
end

function DirectorStrategy.play(
	state: State,
	cardId: CardId,
	phase: string,
	gameId: string?,
	now: number,
	momentTime: number?
): PlayResult
	local nextState = DirectorStrategy.tick(state, now)
	local availability = DirectorStrategy.availability(nextState, cardId, phase, gameId)
	if not availability.available then
		return { state = nextState, accepted = false, reason = availability.reason, effect = nil }
	end
	nextState.energy -= availability.cost
	local handIndex = table.find(nextState.hand, cardId)
	if handIndex then
		table.remove(nextState.hand, handIndex)
	end
	refillHand(nextState)

	local timingDistance = if momentTime then math.abs(now - momentTime) else 1.5
	local timing = math.clamp(1 - timingDistance / 2, 0.25, 1)
	nextState.cuesPlayed += 1
	nextState.cueScore += timing
	nextState.finaleEnergy = math.min(MAX_FINALE_ENERGY, nextState.finaleEnergy + 8 + timing * 12)
	nextState.lastCueAt = now

	return {
		state = nextState,
		accepted = true,
		reason = nil,
		effect = {
			cardId = cardId,
			duration = if cardId == "SlowMotion" then 2.5 else 4,
			strength = 1,
			timing = timing,
		},
	}
end

function DirectorStrategy.predict(state: State, prediction: string): State
	local nextState = clone(state)
	if prediction ~= "Perfect" and prediction ~= "Rescue" and prediction ~= "Finish" then
		return nextState
	end
	nextState.prediction = prediction
	nextState.predictionResolved = false
	return nextState
end

function DirectorStrategy.resolvePrediction(state: State, momentKind: string): State
	local nextState = clone(state)
	if nextState.prediction == nil or nextState.predictionResolved then
		return nextState
	end
	nextState.predictionResolved = true
	if nextState.prediction == momentKind then
		nextState.energy = math.min(MAX_ENERGY, nextState.energy + 2)
		nextState.finaleEnergy = math.min(MAX_FINALE_ENERGY, nextState.finaleEnergy + 15)
	end
	return nextState
end

function DirectorStrategy.requestEncore(state: State): State
	local nextState = clone(state)
	nextState.encoreRequested = true
	return nextState
end

function DirectorStrategy.cueGrade(state: State): string
	if state.cuesPlayed == 0 then
		return "B"
	end
	local average = state.cueScore / state.cuesPlayed
	if average >= 0.9 then
		return "S"
	elseif average >= 0.72 then
		return "A"
	elseif average >= 0.5 then
		return "B"
	end
	return "C"
end

function DirectorStrategy.chooseShowrunnerCue(state: State, phase: string, gameId: string?): CardId?
	for _, availability in DirectorStrategy.handView(state, phase, gameId) do
		if availability.available then
			return availability.id
		end
	end
	return nil
end

return DirectorStrategy
