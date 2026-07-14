-- Personalization used by the authoritative Premiere flow.

local Config = {
	starName = "Bella",
	directorUserId = 0, -- Optional reservation; 0 lets any player choose Director.
	starUserId = 0, -- Optional reservation; 0 lets any player choose Bella.
	birthday = "Bella's Birthday Premiere",

	palette = {
		primary = Color3.fromRGB(255, 143, 196),
		accent = Color3.fromRGB(126, 200, 255),
		cozy = Color3.fromRGB(38, 30, 54),
	},

	dogs = {
		{
			name = "Gigi",
			color = Color3.fromRGB(196, 130, 74),
			personality = "bright, curious, and always ready for the spotlight",
		},
		{
			name = "Rambo",
			color = Color3.fromRGB(54, 40, 32),
			personality = "steady, sweet, and happiest right beside Bella",
		},
	},

	finaleMessage = {
		"Happy Birthday, Bella.",
		"Tonight's little world was made to celebrate the joy you bring to ours.",
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
