--!strict
-- Lune unit tests for Ratthew's Cheese Tower scoring / overhang math.
-- Run standalone by `lune run tests/CheeseTower.spec.luau` (scripts/validate.ps1
-- runs every tests/*.spec.luau). It requires ONLY the pure Scoring module, which
-- touches no Roblox APIs, so it runs outside Studio.

local Scoring = require("../src/client/minigames/CheeseTowerClient/Scoring")

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

-- 1. A dead-center drop is perfect: no overhang, full score + bonus, centered.
do
	local r = Scoring.resolveDrop(0, 8, 0, 8, 0)
	check("perfect: placed", r.placed)
	check("perfect: flagged perfect", r.perfect)
	check("perfect: zero overhang", approx(r.overhang, 0))
	check("perfect: recentred on support", approx(r.newCenter, 0))
	check("perfect: points = 1 + bonus + combo", r.points == 1 + Scoring.PerfectBonus + 0)
	check("perfect: no wobble", approx(r.wobble, 0))
end

-- 2. Combo raises the perfect payout by the combo count.
do
	local r0 = Scoring.resolveDrop(0, 8, 0, 8, 0)
	local r3 = Scoring.resolveDrop(0, 8, 0, 8, 3)
	check("combo: bonus scales with combo", r3.points == r0.points + 3)
end

-- 3. A partial-overlap drop trims to the overlap, awards 1, and is not perfect.
--    support [-4,4], drop centred at 3 with width 8 -> [-1,7]; overlap [-1,4] = 5 wide.
do
	local r = Scoring.resolveDrop(0, 8, 3, 8, 0)
	check("partial: placed", r.placed)
	check("partial: not perfect", not r.perfect)
	check("partial: newWidth = overlap (5)", approx(r.newWidth, 5))
	check("partial: newCenter = overlap midpoint (1.5)", approx(r.newCenter, 1.5))
	check("partial: overhang = dropWidth - overlap (3)", approx(r.overhang, 3))
	check("partial: awards 1 point", r.points == 1)
	check("partial: some wobble", r.wobble > 0)
end

-- 4. Overhang trimming is symmetric: mirror offset gives the mirror centre,
--    identical width/overhang/score.
do
	local right = Scoring.resolveDrop(0, 8, 3, 8, 0)
	local left = Scoring.resolveDrop(0, 8, -3, 8, 0)
	check("symmetry: mirrored centre", approx(left.newCenter, -right.newCenter))
	check("symmetry: same width", approx(left.newWidth, right.newWidth))
	check("symmetry: same overhang", approx(left.overhang, right.overhang))
end

-- 5. No overlap at all => the tower topples (not placed), zero score.
do
	-- support [-4,4], drop centred at 10 width 8 -> [6,14]; no overlap.
	local r = Scoring.resolveDrop(0, 8, 10, 8, 0)
	check("miss: not placed", not r.placed)
	check("miss: zero points", r.points == 0)
	check("miss: full width is overhang", approx(r.overhang, 8))
	check("miss: max wobble", approx(r.wobble, 1))
end

-- 6. Exactly touching edges (overlap == 0) counts as a miss, not a place.
do
	-- support [-4,4], drop [4,12] centred at 8: overlapWidth == 0.
	local r = Scoring.resolveDrop(0, 8, 8, 8, 0)
	check("edge: zero overlap is a miss", not r.placed)
end

-- 7. The perfect window scales with the support width.
do
	check(
		"window: scales with width",
		approx(Scoring.perfectWindow(8), 8 * Scoring.PerfectFraction)
	)
	local wide = Scoring.perfectWindow(8)
	-- An offset just outside the window is NOT perfect but still a valid place.
	local r = Scoring.resolveDrop(0, 8, wide + 0.01, 8, 0)
	check("window: just outside is not perfect", not r.perfect)
	check("window: just outside still places", r.placed)
	-- An offset just inside the window IS perfect.
	local rIn = Scoring.resolveDrop(0, 8, wide - 0.01, 8, 0)
	check("window: just inside is perfect", rIn.perfect)
end

-- 8. A perfect drop never shrinks the wheel and regrows it up to BaseWidth.
do
	local r = Scoring.resolveDrop(0, 5, 0, 5, 0)
	check("regrow: perfect keeps/grows width", r.newWidth >= 5)
	check("regrow: capped at BaseWidth", r.newWidth <= Scoring.BaseWidth + 1e-6)
	local rBig = Scoring.resolveDrop(0, Scoring.BaseWidth, 0, Scoring.BaseWidth, 0)
	check("regrow: never exceeds BaseWidth", approx(rBig.newWidth, Scoring.BaseWidth))
end

-- 9. configFor is monotonic in difficulty and clamps out-of-range input.
do
	local easy = Scoring.configFor(0)
	local mid = Scoring.configFor(0.5)
	local hard = Scoring.configFor(1)
	check(
		"config: wheel shrinks with difficulty",
		easy.wheelWidth > mid.wheelWidth and mid.wheelWidth > hard.wheelWidth
	)
	check("config: pendulum speeds up", easy.pendulumSpeed < hard.pendulumSpeed)
	check("config: swing widens", easy.pendulumRange < hard.pendulumRange)
	check("config: easiest width = BaseWidth", approx(easy.wheelWidth, Scoring.BaseWidth))
	check("config: hardest width = MinWidth", approx(hard.wheelWidth, Scoring.MinWidth))

	local below = Scoring.configFor(-5)
	local above = Scoring.configFor(5)
	check("config: clamps below 0 to easiest", approx(below.wheelWidth, easy.wheelWidth))
	check("config: clamps above 1 to hardest", approx(above.wheelWidth, hard.wheelWidth))
end

-- 10. A short worst-case chain of imperfect drops keeps trimming toward zero and
--     eventually topples once overlap runs out (sanity check on the loop).
do
	local center, width = 0, Scoring.BaseWidth
	local total, toppled = 0, false
	for _ = 1, 12 do
		-- A constant absolute offset trims a fixed slice each time, so the
		-- support eventually gets narrower than the offset and overlap runs out.
		local r = Scoring.resolveDrop(center, width, center + 2.5, width, 0)
		if not r.placed then
			toppled = true
			break
		end
		center, width = r.newCenter, r.newWidth
		total += r.points
	end
	check("chain: trimming eventually topples", toppled)
	check("chain: accumulated some score before toppling", total > 0)
end

-- 11. Nudge moves the drop toward support and reports alignment.
do
	local nudged, alignment = Scoring.nudgeToward(3, 0, 1.25)
	check("nudge: moves closer", math.abs(nudged) < 3)
	check("nudge: positive alignment", alignment > 0.5)
	local centered, perfectAlign = Scoring.nudgeToward(0, 0, 1)
	check("nudge: already centered stays", approx(centered, 0))
	check("nudge: centered alignment is 1", approx(perfectAlign, 1))
end

-- 12. Rescue saves near-misses and soft-recenters shaky places.
do
	local miss = Scoring.resolveDrop(0, 8, 10, 8, 0)
	check("rescue precondition: miss", not miss.placed)
	local rescued = Scoring.rescueDrop(0, 8, 9.2, 8, 0)
	check("rescue: near miss places", rescued.placed)
	check("rescue: not perfect", not rescued.perfect)
	local shaky = Scoring.rescueDrop(0, 8, 3, 8, 0)
	check("rescue: shaky still places", shaky.placed)
end

-- 13. Bank / topper helpers stay helpful.
do
	check("bank: positive bonus", Scoring.bankPoints(5, 20) > 0)
	check("topper: risky doubles", approx(Scoring.topperMultiplier(true), 2))
	check("topper: safe is 1.5", approx(Scoring.topperMultiplier(false), 1.5))
end

if failed > 0 then
	error(`CheeseTower.spec: {failed} check(s) failed ({passed} passed)`)
end
print(`CheeseTower.spec: all {passed} checks passed`)
