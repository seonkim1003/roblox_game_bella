-- Personalization. Placeholders now; fill in before the real show.
-- See docs/BIRTHDAY_BASH_PLAN.md section 2 for the full checklist.

local Config = {
	starName = "Bella",
	directorUserId = 0, -- your Roblox userId (assigns you the Director role)
	starUserId = 0, -- Bella's Roblox userId (assigns her the Star role)
	birthday = "TODO",

	palette = {
		primary = Color3.fromRGB(255, 143, 196),
		accent = Color3.fromRGB(126, 200, 255),
		cozy = Color3.fromRGB(38, 30, 54),
	},

	dogs = {
		{ name = "Gigi", color = Color3.fromRGB(196, 130, 74), personality = "TODO" },
		{ name = "Rambo", color = Color3.fromRGB(54, 40, 32), personality = "TODO" },
	},

	finaleMessage = {
		"Happy Birthday, Bella.",
		"(placeholder -- your real message goes here)",
	},

	-- false = keep it out of the show (default: all guardrails on).
	guardrails = {
		jumpScares = false,
		suddenLoudNoises = false,
		spiders = false,
		hardPlatforming = false,
	},
}

return Config
