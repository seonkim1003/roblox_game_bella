--!strict
-- Pure ASMR Satisfy Station logic: slice/squish/pop, gentle combos, difficulty.
-- No Roblox APIs — safe for Lune unit tests.

local Logic = {}

Logic.BasePoints = 5
Logic.ComboBonus = 3
Logic.PerfectBonus = 4
Logic.WrongPenalty = 0 -- playful: wrong action just breaks combo
Logic.TraySizeEasy = 6
Logic.TraySizeHard = 10

export type ActionKind = "Slice" | "Squish" | "Pop"

export type Item = {
	id: number,
	kind: ActionKind,
	resolved: boolean,
}

export type Config = {
	comboWindow: number, -- seconds between actions to keep the combo
	perfectWindow: number, -- tighter window inside comboWindow for a perfect
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

function Logic.configFor(difficulty: number): Config
	local d = math.clamp(difficulty, 0, 1)
	-- Higher difficulty = tighter (but still gentle) timing windows.
	local comboWindow = 1.35 - d * 0.55 -- 1.35 .. 0.8
	return {
		comboWindow = comboWindow,
		perfectWindow = comboWindow * (0.55 - d * 0.15), -- ~0.55x .. ~0.4x of window
		traySize = math.floor(
			Logic.TraySizeEasy + d * (Logic.TraySizeHard - Logic.TraySizeEasy) + 0.5
		),
	}
end

local function kindAt(index: number): ActionKind
	local slot = ((index - 1) % 3) + 1
	if slot == 1 then
		return "Slice" :: ActionKind
	elseif slot == 2 then
		return "Squish" :: ActionKind
	end
	return "Pop" :: ActionKind
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

function Logic.newState(difficulty: number, now: number?): State
	local config = Logic.configFor(difficulty)
	local state: State = {
		score = 0,
		combo = 0,
		items = {},
		nextId = 1,
		lastActionAt = nil,
		finished = false,
		resolvedCount = 0,
	}
	for i = 1, config.traySize do
		-- Cycle kinds, then sprinkle a little determinism without Roblox Random.
		local kind: ActionKind = kindAt(i)
		if (i * 17 + config.traySize) % 5 == 0 then
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
	local fresh = Logic.newState(difficulty)
	state.score = fresh.score
	state.combo = fresh.combo
	state.items = fresh.items
	state.nextId = fresh.nextId
	state.lastActionAt = nil
	state.finished = false
	state.resolvedCount = 0
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

-- Apply an action to a specific tray item at time `now` (seconds, monotonic).
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

	if item.kind ~= action then
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
		-- First successful action starts the chain and never counts as "perfect timing".
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
