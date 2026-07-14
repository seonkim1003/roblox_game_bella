--!strict
-- Pure Satisfy Station authority rules (Lune-safe). Server owns tray object IDs
-- and rejects wrong-kind / already-resolved / duplicate clears.

local SatisfyStationRules = {}

SatisfyStationRules.SEGMENT_SECONDS = 55
SatisfyStationRules.ACCEPT_THRESHOLD = 0.35
SatisfyStationRules.PERFECT_THRESHOLD = 0.85
SatisfyStationRules.MAX_SCORE = 500

export type TrayItem = {
	id: number,
	kind: string,
	resolved: boolean,
}

export type State = {
	items: { TrayItem },
	traySize: number,
	resolved: number,
	score: number,
	combo: number,
	accuracy: number?,
	validAttempts: number,
	perfects: number,
	flow: number,
	progress: number,
	completed: boolean,
	seed: number,
}

local KINDS = { "Trace", "Squish", "Pop", "Peel", "Pipe" }

local function kindAt(index: number): string
	return KINDS[((index - 1) % #KINDS) + 1]
end

function SatisfyStationRules.traySizeFor(difficulty: number): number
	return math.floor(6 + math.clamp(difficulty, 0, 1) * 4 + 0.5)
end

function SatisfyStationRules.buildTray(seed: number, traySize: number): { TrayItem }
	local items: { TrayItem } = {}
	local size = math.max(1, math.floor(traySize))
	local useSeed = math.floor(seed)
	for i = 1, size do
		local kind = kindAt(i)
		local sprinkle = (useSeed * 17 + i * 31) % 5
		if sprinkle == 0 then
			kind = kindAt(i + 1)
		end
		table.insert(items, {
			id = i,
			kind = kind,
			resolved = false,
		})
	end
	return items
end

function SatisfyStationRules.newState(difficulty: number, seed: number): State
	local traySize = SatisfyStationRules.traySizeFor(difficulty)
	return {
		items = SatisfyStationRules.buildTray(seed, traySize),
		traySize = traySize,
		resolved = 0,
		score = 0,
		combo = 0,
		accuracy = nil,
		validAttempts = 0,
		perfects = 0,
		flow = 0.55,
		progress = 0,
		completed = false,
		seed = math.floor(seed),
	}
end

function SatisfyStationRules.findUnresolved(state: State, kind: string): TrayItem?
	for _, item in state.items do
		if not item.resolved and item.kind == kind then
			return item
		end
	end
	return nil
end

function SatisfyStationRules.findById(state: State, objectId: number): TrayItem?
	for _, item in state.items do
		if item.id == objectId then
			return item
		end
	end
	return nil
end

function SatisfyStationRules.canComplete(state: State): boolean
	return not state.completed and state.resolved >= state.traySize
end

function SatisfyStationRules.applyAction(
	state: State,
	action: string,
	qualityInput: number,
	objectId: number?
): (boolean, TrayItem?)
	if state.completed then
		return false, nil
	end

	local item: TrayItem? = nil
	if type(objectId) == "number" then
		local byId = SatisfyStationRules.findById(state, math.floor(objectId))
		if not byId or byId.resolved or byId.kind ~= action then
			state.combo = 0
			state.flow = math.clamp(state.flow - 0.05, 0, 1)
			return false, nil
		end
		item = byId
	else
		item = SatisfyStationRules.findUnresolved(state, action)
		if not item then
			state.combo = 0
			state.flow = math.clamp(state.flow - 0.05, 0, 1)
			return false, nil
		end
	end

	local quality = math.clamp(qualityInput, 0, 1)
	state.validAttempts += 1
	if quality < SatisfyStationRules.ACCEPT_THRESHOLD then
		state.combo = 0
		state.flow = math.clamp(state.flow - 0.05, 0, 1)
		if state.accuracy == nil then
			state.accuracy = quality
		else
			state.accuracy = state.accuracy * 0.7 + quality * 0.3
		end
		return false, item
	end

	local resolved = item :: TrayItem
	resolved.resolved = true
	state.resolved += 1
	local perfect = quality >= SatisfyStationRules.PERFECT_THRESHOLD
	local points = 5 + state.combo * 3 + (if perfect then 4 else 0)
	state.score = math.min(SatisfyStationRules.MAX_SCORE, state.score + points)
	state.combo += 1
	state.flow = state.flow * 0.7 + quality * 0.3
	if state.accuracy == nil then
		state.accuracy = quality
	else
		state.accuracy = state.accuracy * 0.7 + quality * 0.3
	end
	state.progress = math.clamp(state.resolved / math.max(state.traySize, 1), 0, 1)
	if perfect then
		state.perfects += 1
	end
	return true, resolved
end

return SatisfyStationRules
