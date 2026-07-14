--!strict
-- Pure ASMR Satisfy Station logic: Trace/Squish/Pop/Peel/Pipe, gentle combos.
-- No Roblox APIs — safe for Lune unit tests.
-- Local "Slice" stays as an alias for Trace so existing juice/input naming works.

local Logic = {}

Logic.BasePoints = 5
Logic.ComboBonus = 3
Logic.PerfectBonus = 4
Logic.WrongPenalty = 0 -- playful: wrong action just breaks combo
Logic.TraySizeEasy = 6
Logic.TraySizeHard = 10

export type ActionKind = "Slice" | "Trace" | "Squish" | "Pop" | "Peel" | "Pipe"

export type Item = {
	id: number,
	kind: ActionKind,
	resolved: boolean,
}

export type Config = {
	comboWindow: number,
	perfectWindow: number,
	traySize: number,
}

export type State = {
	score: number,
	combo: number,
	items: { Item },
	nextId: number,
	lastActionAt: number?,
	finished: boolean,
	resolvedCount: number,
	seed: number,
}

export type ActionResult = {
	accepted: boolean,
	perfect: boolean,
	points: number,
	combo: number,
	comboBroken: boolean,
	remaining: number,
	finished: boolean,
	itemId: number?,
}

local KINDS: { ActionKind } = { "Slice", "Squish", "Pop", "Peel", "Pipe" }

function Logic.configFor(difficulty: number): Config
	local d = math.clamp(difficulty, 0, 1)
	local comboWindow = 1.35 - d * 0.55 -- 1.35 .. 0.8
	return {
		comboWindow = comboWindow,
		perfectWindow = comboWindow * (0.55 - d * 0.15),
		traySize = math.floor(
			Logic.TraySizeEasy + d * (Logic.TraySizeHard - Logic.TraySizeEasy) + 0.5
		),
	}
end

local function normalizeKind(kind: ActionKind): ActionKind
	if kind == "Trace" then
		return "Slice"
	end
	return kind
end

local function kindAt(index: number): ActionKind
	return KINDS[((index - 1) % #KINDS) + 1]
end

local function makeItem(state: State, kind: ActionKind): Item
	local item: Item = {
		id = state.nextId,
		kind = kind,
		resolved = false,
	}
	state.nextId += 1
	return item
end

function Logic.newState(difficulty: number, now: number?, seed: number?, traySize: number?): State
	local config = Logic.configFor(difficulty)
	local size = if traySize ~= nil then math.max(1, math.floor(traySize)) else config.traySize
	local state: State = {
		score = 0,
		combo = 0,
		items = {},
		nextId = 1,
		lastActionAt = nil,
		finished = false,
		resolvedCount = 0,
		seed = if seed ~= nil then math.floor(seed) else math.floor(difficulty * 10_000 + size),
	}
	for i = 1, size do
		local kind: ActionKind = kindAt(i)
		local sprinkle = (state.seed * 17 + i * 31) % 5
		if sprinkle == 0 then
			kind = kindAt(i + 1)
		end
		table.insert(state.items, makeItem(state, kind))
	end
	if now ~= nil then
		state.lastActionAt = nil
	end
	return state
end

function Logic.reset(state: State, difficulty: number)
	local fresh = Logic.newState(difficulty, nil, state.seed, #state.items)
	state.score = fresh.score
	state.combo = fresh.combo
	state.items = fresh.items
	state.nextId = fresh.nextId
	state.lastActionAt = nil
	state.finished = false
	state.resolvedCount = 0
	state.seed = fresh.seed
end

function Logic.remaining(state: State): number
	local count = 0
	for _, item in state.items do
		if not item.resolved then
			count += 1
		end
	end
	return count
end

function Logic.findItem(state: State, itemId: number): Item?
	for _, item in state.items do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

function Logic.roundActionFor(kind: ActionKind): string
	local normalized = normalizeKind(kind)
	if normalized == "Slice" then
		return "Trace"
	end
	return normalized
end

function Logic.applyAction(
	state: State,
	itemId: number,
	action: ActionKind,
	now: number,
	config: Config
): ActionResult
	if state.finished then
		return {
			accepted = false,
			perfect = false,
			points = 0,
			combo = state.combo,
			comboBroken = false,
			remaining = 0,
			finished = true,
			itemId = itemId,
		}
	end

	local item = Logic.findItem(state, itemId)
	if not item or item.resolved then
		return {
			accepted = false,
			perfect = false,
			points = 0,
			combo = state.combo,
			comboBroken = false,
			remaining = Logic.remaining(state),
			finished = state.finished,
			itemId = itemId,
		}
	end

	local wanted = normalizeKind(item.kind)
	local performed = normalizeKind(action)
	if wanted ~= performed then
		state.combo = 0
		state.lastActionAt = now
		return {
			accepted = false,
			perfect = false,
			points = Logic.WrongPenalty,
			combo = 0,
			comboBroken = true,
			remaining = Logic.remaining(state),
			finished = false,
			itemId = itemId,
		}
	end

	item.resolved = true
	state.resolvedCount += 1

	local perfect = false
	local withinCombo = false
	if state.lastActionAt ~= nil then
		local gap = now - state.lastActionAt
		withinCombo = gap <= config.comboWindow
		perfect = gap <= config.perfectWindow
	else
		withinCombo = true
		perfect = false
	end

	if withinCombo then
		state.combo += 1
	else
		state.combo = 1
		perfect = false
	end

	local points = Logic.BasePoints + Logic.ComboBonus * math.max(0, state.combo - 1)
	if perfect then
		points += Logic.PerfectBonus
	end
	state.score += points
	state.lastActionAt = now

	local remaining = Logic.remaining(state)
	if remaining <= 0 then
		state.finished = true
	end

	return {
		accepted = true,
		perfect = perfect,
		points = points,
		combo = state.combo,
		comboBroken = false,
		remaining = remaining,
		finished = state.finished,
		itemId = itemId,
	}
end

return Logic
