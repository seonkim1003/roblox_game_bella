--!strict

-- Frozen visual language shared by server-built sets and client presentation.
-- Asset IDs intentionally remain empty until reviewed exports are uploaded.

local VisualConfig = {
	palette = {
		ink = Color3.fromRGB(39, 31, 49),
		plum = Color3.fromRGB(70, 50, 82),
		plumDeep = Color3.fromRGB(35, 27, 46),
		cream = Color3.fromRGB(255, 244, 225),
		blush = Color3.fromRGB(244, 157, 181),
		rose = Color3.fromRGB(202, 104, 137),
		sky = Color3.fromRGB(143, 202, 224),
		mint = Color3.fromRGB(157, 211, 186),
		butter = Color3.fromRGB(244, 207, 121),
		terracotta = Color3.fromRGB(185, 112, 79),
		walnut = Color3.fromRGB(91, 58, 48),
		wood = Color3.fromRGB(151, 98, 70),
		linen = Color3.fromRGB(226, 207, 190),
		night = Color3.fromRGB(24, 29, 45),
		rain = Color3.fromRGB(74, 100, 126),
		flame = Color3.fromRGB(255, 190, 92),
	},
	-- Typography + shape tokens. New/edited UI should read these instead of
	-- re-picking fonts and magic-number corner radii inline.
	fonts = {
		title = Enum.Font.GothamBlack,
		heading = Enum.Font.GothamBold,
		body = Enum.Font.GothamMedium,
	},
	radius = {
		card = 16,
		chip = 12,
		pill = 999,
	},
	lighting = {
		hubClockTime = 17.65,
		hubBrightness = 2.35,
		finaleClockTime = 22.8,
		finaleBrightness = 1.2,
	},
	budget = {
		maxHubLights = 10,
		maxFinaleLights = 8,
		maxSurpriseParticles = 120,
		maxTransparentDecorations = 28,
	},
	assets = {
		partyRugTexture = "",
		woodSurfaceTexture = "",
		wallpaperTexture = "",
		rainTexture = "",
		confettiTexture = "",
	},
}

return table.freeze(VisualConfig)
