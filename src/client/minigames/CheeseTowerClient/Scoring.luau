--!strict
-- Pure scoring / overhang math for Ratthew's Cheese Tower.
--
-- This module deliberately touches NO Roblox APIs (no Vector3, Color3, game,
-- task, etc.) so it can be required both from the client simulation (via a
-- Roblox instance path) and from a Lune unit test (via a filesystem path).
-- It lives as a CHILD of CheeseTowerClient so the client/minigames folder
-- loader (owned by the Star shell) never mistakes it for a MinigameClient.
-- Keep it pure.

local Scoring = {}

-- Tuning knobs. Widths are in studs (the cheese-wheel diameter along the drop axis).
Scoring.BaseWidth = 8 -- wheel width at difficulty 0 (easiest)
Scoring.MinWidth = 3 -- wheel width at difficulty 1 (hardest)
Scoring.PerfectFraction = 0.06 -- |offset| <= supportWidth * this  => perfect
Scoring.PerfectRegrow = 0.12 -- fraction a perfect drop grows the wheel back
Scoring.PerfectBonus = 2 -- flat bonus points on a perfect drop
Scoring.WobbleFactor = 0.5 -- overhang -> wobble amount (a juice hint, 0..1)

export type DropResult = {
	placed: boolean, -- false means no overlap: the tower topples
	perfect: boolean, -- landed inside the perfect window
	newCenter: number, -- center of the (possibly trimmed) wheel now on top
	newWidth: number, -- width carried up to the next drop
	overhang: number, -- total width trimmed away on this drop
	points: number, -- score awarded for this drop (0 when not placed)
	wobble: number, -- 0..1 hint for how hard the stack should jiggle
}

export type TowerConfig = {
	wheelWidth: number,
	pendulumSpeed: number, -- swing speed multiplier (radians/sec feed)
	pendulumRange: number, -- swing amplitude in studs
}

-- Half-width of the "perfect" landing window for a support of the given width.
function Scoring.perfectWindow(supportWidth: number): number
	return supportWidth * Scoring.PerfectFraction
end

-- Resolve one dropped wheel (dropWidth, centered at dropCenter) landing onto a
-- support wheel (supportWidth, centered at supportCenter). `combo` is the count
-- of consecutive perfects BEFORE this drop and feeds the perfect bonus.
function Scoring.resolveDrop(
	supportCenter: number,
	supportWidth: number,
	dropCenter: number,
	dropWidth: number,
	combo: number
): DropResult
	local offset = dropCenter - supportCenter

	local halfSupport = supportWidth / 2
	local halfDrop = dropWidth / 2
	local overlapLeft = math.max(supportCenter - halfSupport, dropCenter - halfDrop)
	local overlapRight = math.min(supportCenter + halfSupport, dropCenter + halfDrop)
	local overlapWidth = overlapRight - overlapLeft

	if overlapWidth <= 0 then
		-- Missed the stack entirely: the wheel slides off and the tower topples.
		return {
			placed = false,
			perfect = false,
			newCenter = dropCenter,
			newWidth = 0,
			overhang = dropWidth,
			points = 0,
			wobble = 1,
		}
	end

	local perfect = math.abs(offset) <= Scoring.perfectWindow(supportWidth)

	local newCenter: number
	local newWidth: number
	local overhang: number
	if perfect then
		-- Snap dead center and regrow a little toward the base width: this is the
		-- forgiving mechanic that keeps the game from spiralling into a sliver.
		newCenter = supportCenter
		newWidth = math.min(Scoring.BaseWidth, dropWidth * (1 + Scoring.PerfectRegrow))
		overhang = 0
	else
		newCenter = (overlapLeft + overlapRight) / 2
		newWidth = overlapWidth
		overhang = dropWidth - overlapWidth
	end

	local points = 1
	if perfect then
		points += Scoring.PerfectBonus + combo
	end

	local wobble = 0
	if dropWidth > 0 then
		wobble = math.clamp((overhang / dropWidth) * Scoring.WobbleFactor, 0, 1)
	end

	return {
		placed = true,
		perfect = perfect,
		newCenter = newCenter,
		newWidth = newWidth,
		overhang = overhang,
		points = points,
		wobble = wobble,
	}
end

-- Map the live 0..1 difficulty dial to concrete tower parameters. Higher
-- difficulty = smaller wheels, faster and wider swing.
function Scoring.configFor(difficulty: number): TowerConfig
	local d = math.clamp(difficulty, 0, 1)
	local wheelWidth = Scoring.BaseWidth - d * (Scoring.BaseWidth - Scoring.MinWidth)
	local pendulumSpeed = 1.5 + d * 2.5 -- 1.5 .. 4.0
	local pendulumRange = 6 + d * 6 -- 6 .. 12 studs
	return {
		wheelWidth = wheelWidth,
		pendulumSpeed = pendulumSpeed,
		pendulumRange = pendulumRange,
	}
end

return Scoring
