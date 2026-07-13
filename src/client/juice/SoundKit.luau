--!strict
-- Named ASMR / SFX playback for the Star (and finale consumers).
-- Sounds are gentle by default — Config.guardrails.suddenLoudNoises stays off.
-- Asset ids are soft stock Roblox library picks; missing assets fail quietly.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Config = require(Shared.Config)

-- Named catalog. Keep volumes low; Feedback callers can still pass options.volume.
local CATALOG: { [string]: { id: string, volume: number, speed: number } } = {
	plop = { id = "rbxassetid://9125412681", volume = 0.35, speed = 1.05 },
	squelch = { id = "rbxassetid://9114225473", volume = 0.28, speed = 0.9 },
	pop = { id = "rbxassetid://9117482890", volume = 0.3, speed = 1.15 },
	cheer = { id = "rbxassetid://9114500962", volume = 0.25, speed = 1.1 },
	wobble = { id = "rbxassetid://9113825223", volume = 0.22, speed = 0.85 },
	crumble = { id = "rbxassetid://9113825223", volume = 0.3, speed = 0.7 },
	confetti = { id = "rbxassetid://9117482890", volume = 0.28, speed = 1.3 },
	softChime = { id = "rbxassetid://9125412681", volume = 0.2, speed = 1.4 },
}

local SoftCap = if Config.guardrails.suddenLoudNoises == false then 0.45 else 0.85

local SoundKit: Types.SoundApi = {
	play = function(name: string, options: { [string]: any }?)
		local entry = CATALOG[name]
		if not entry then
			return
		end

		local volume = entry.volume
		if options and type(options.volume) == "number" then
			volume = options.volume
		end
		volume = math.clamp(volume, 0, SoftCap)

		local speed = entry.speed
		if options and type(options.speed) == "number" then
			speed = options.speed
		end

		local sound = Instance.new("Sound")
		sound.Name = `Bash_{name}`
		sound.SoundId = entry.id
		sound.Volume = volume
		sound.PlaybackSpeed = speed
		sound.RollOffMaxDistance = 80
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 4)
	end,
}

return SoundKit
