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

-- Nudge the swinging cheese toward the support center (helpful micro-adjust).
function Scoring.nudgeToward(
	dropCenter: number,
	supportCenter: number,
	amount: number
): (number, number)
	local delta = supportCenter - dropCenter
	if math.abs(delta) < 1e-6 then
		return dropCenter, 1
	end
	local step = math.clamp(amount, 0.15, 2.5) * (if delta > 0 then 1 else -1)
	if math.abs(step) > math.abs(delta) then
		step = delta
	end
	local nudged = dropCenter + step
	local alignment = 1 - math.clamp(math.abs(supportCenter - nudged) / 8, 0, 1)
	return nudged, alignment
end

-- Rescue a near-miss: if overlap would fail but the miss is slight, place a thin wheel.
function Scoring.rescueDrop(
	supportCenter: number,
	supportWidth: number,
	dropCenter: number,
	dropWidth: number,
	combo: number
): DropResult
	local normal = Scoring.resolveDrop(supportCenter, supportWidth, dropCenter, dropWidth, combo)
	if normal.placed then
		-- Soft recenter when the stack is shaky but still standing.
		if normal.wobble >= 0.35 then
			return Scoring.resolveDrop(supportCenter, supportWidth, supportCenter, dropWidth, combo)
		end
		return normal
	end

	local halfSupport = supportWidth / 2
	local halfDrop = dropWidth / 2
	local gap = math.abs(dropCenter - supportCenter) - (halfSupport + halfDrop)
	if gap > 1.75 then
		return normal
	end

	local rescuedWidth = math.max(Scoring.MinWidth * 0.75, supportWidth * 0.55)
	return {
		placed = true,
		perfect = false,
		newCenter = supportCenter,
		newWidth = rescuedWidth,
		overhang = math.max(0, dropWidth - rescuedWidth),
		points = 1,
		wobble = 0.55,
	}
end

-- Soft bank of the current tower: bonus scales with height, never punitive.
function Scoring.bankPoints(height: number, score: number): number
	local safeHeight = math.max(0, height)
	return math.floor(score * 0.1 + safeHeight * 2 + 0.5)
end

-- Topper places a celebratory finish wheel; multiplier for its points.
function Scoring.topperMultiplier(risky: boolean): number
	return if risky then 2 else 1.5
end

return Scoring
