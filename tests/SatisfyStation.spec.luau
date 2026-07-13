--!strict
-- Lune unit tests for ASMR Satisfy Station pure logic.
-- Run via scripts/validate.ps1 (every tests/*.spec.luau).

local Logic = require("../src/client/minigames/SatisfyStationClient/Logic")

local passed = 0
local failed = 0

local function check(label: string, condition: boolean)
	if condition then
		passed += 1
	else
		failed += 1
		print(`  [FAIL] {label}`)
	end
end

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- 1. Difficulty tightens windows and grows the tray; clamps out of range.
do
	local easy = Logic.configFor(0)
	local hard = Logic.configFor(1)
	check("config: comboWindow shrinks", easy.comboWindow > hard.comboWindow)
	check("config: perfectWindow shrinks", easy.perfectWindow > hard.perfectWindow)
	check("config: tray grows", easy.traySize < hard.traySize)
	check("config: clamp low", approx(Logic.configFor(-2).comboWindow, easy.comboWindow))
	check("config: clamp high", approx(Logic.configFor(9).comboWindow, hard.comboWindow))
	check("config: traySize easy bound", easy.traySize == Logic.TraySizeEasy)
	check("config: traySize hard bound", hard.traySize == Logic.TraySizeHard)
end

-- 2. Matching action resolves the item and awards base points.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	local first = state.items[1]
	local result = Logic.applyAction(state, first.id, first.kind, 10, config)
	check("match: accepted", result.accepted)
	check("match: not perfect on first", not result.perfect)
	check("match: base points", result.points == Logic.BasePoints)
	check("match: combo starts at 1", result.combo == 1)
	check("match: item resolved", first.resolved)
	check("match: remaining decreased", result.remaining == #state.items - 1)
end

-- 3. Wrong action rejects, breaks combo, leaves the item.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	state.combo = 4
	local target = state.items[1]
	local wrong: Logic.ActionKind = if target.kind == "Slice" then "Pop" else "Slice"
	local result = Logic.applyAction(state, target.id, wrong, 1, config)
	check("wrong: rejected", not result.accepted)
	check("wrong: combo broken", result.comboBroken and result.combo == 0)
	check("wrong: item still open", not target.resolved)
	check("wrong: score unchanged", state.score == 0)
end

-- 4. Gentle combo timing: within window builds; outside resets to 1.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	local a = state.items[1]
	local b = state.items[2]
	Logic.applyAction(state, a.id, a.kind, 1.0, config)
	-- Land between perfectWindow and comboWindow so combo stacks without a perfect.
	local midGap = (config.perfectWindow + config.comboWindow) * 0.5
	local mid = Logic.applyAction(state, b.id, b.kind, 1.0 + midGap, config)
	check("combo: within window stacks", mid.accepted and mid.combo == 2)
	check("combo: points include bonus", mid.points == Logic.BasePoints + Logic.ComboBonus)
	check("combo: mid gap is not perfect", not mid.perfect)

	local state2 = Logic.newState(0)
	local c = state2.items[1]
	local d = state2.items[2]
	Logic.applyAction(state2, c.id, c.kind, 5.0, config)
	local late = Logic.applyAction(state2, d.id, d.kind, 5.0 + config.comboWindow + 0.05, config)
	check("combo: outside window resets to 1", late.combo == 1)
	check("combo: late is not perfect", not late.perfect)
end

-- 5. Perfect window awards bonus inside the tighter gap.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	local a = state.items[1]
	local b = state.items[2]
	Logic.applyAction(state, a.id, a.kind, 2.0, config)
	local perfect = Logic.applyAction(state, b.id, b.kind, 2.0 + config.perfectWindow * 0.5, config)
	check("perfect: flagged", perfect.perfect)
	check(
		"perfect: includes PerfectBonus",
		perfect.points == Logic.BasePoints + Logic.ComboBonus + Logic.PerfectBonus
	)
end

-- 6. Clearing the tray marks finished; further actions rejected.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	-- Shrink to two items for a focused finish check.
	state.items = {
		{ id = 1, kind = "Pop", resolved = false },
		{ id = 2, kind = "Squish", resolved = false },
	}
	state.nextId = 3
	Logic.applyAction(state, 1, "Pop", 1, config)
	local last = Logic.applyAction(state, 2, "Squish", 1.2, config)
	check("finish: remaining 0", last.remaining == 0)
	check("finish: result.finished", last.finished)
	check("finish: state.finished", state.finished)
	local after = Logic.applyAction(state, 2, "Squish", 1.4, config)
	check("finish: later action rejected", not after.accepted and after.finished)
end

-- 7. Reset restores a fresh tray and clears score/combo.
do
	local state = Logic.newState(0.6)
	state.score = 50
	state.combo = 3
	state.finished = true
	state.items[1].resolved = true
	Logic.reset(state, 0.6)
	check("reset: score 0", state.score == 0)
	check("reset: combo 0", state.combo == 0)
	check("reset: not finished", not state.finished)
	check("reset: tray rebuilt", #state.items == Logic.configFor(0.6).traySize)
	check("reset: all open", Logic.remaining(state) == #state.items)
end

-- 8. Unknown / already-resolved item ids are rejected safely.
do
	local state = Logic.newState(0)
	local config = Logic.configFor(0)
	local missing = Logic.applyAction(state, 999, "Pop", 1, config)
	check("missing: rejected", not missing.accepted)
	local item = state.items[1]
	Logic.applyAction(state, item.id, item.kind, 1, config)
	local again = Logic.applyAction(state, item.id, item.kind, 1.1, config)
	check("resolved: second apply rejected", not again.accepted)
end

if failed > 0 then
	error(`SatisfyStation.spec: {failed} check(s) failed ({passed} passed)`)
end
print(`SatisfyStation.spec: all {passed} checks passed`)
