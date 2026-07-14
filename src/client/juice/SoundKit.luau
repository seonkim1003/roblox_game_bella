--!strict
-- Named ASMR / SFX playback for the Star (and finale consumers).
-- Sounds are gentle by default — Config.guardrails.suddenLoudNoises stays off.
-- Soft-requires Agent B's AccessibilitySettings when present to honor mute.

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Config = require(Shared.Config)

-- Named catalog. Keep volumes low; Feedback callers can still pass options.volume.
-- Distinct verbs share soft library ids with different default pitch/volume profiles.
local CATALOG: { [string]: { id: string, volume: number, speed: number } } = {
	plop = { id = "rbxassetid://9113856075", volume = 0.35, speed = 1.05 },
	squelch = { id = "rbxassetid://9114225473", volume = 0.28, speed = 0.9 },
	pop = { id = "rbxassetid://9117482890", volume = 0.3, speed = 1.15 },
	cheer = { id = "rbxassetid://9114500962", volume = 0.25, speed = 1.1 },
	wobble = { id = "rbxassetid://9113825223", volume = 0.22, speed = 0.85 },
	crumble = { id = "rbxassetid://9113825223", volume = 0.3, speed = 0.7 },
	confetti = { id = "rbxassetid://9117482890", volume = 0.28, speed = 1.3 },
	softChime = { id = "rbxassetid://9116394545", volume = 0.2, speed = 1.15 },
	-- Verb-specific soft profiles (same gentle library, different feel).
	nudge = { id = "rbxassetid://9116394545", volume = 0.14, speed = 1.35 },
	rescue = { id = "rbxassetid://9113856075", volume = 0.26, speed = 0.85 },
	bank = { id = "rbxassetid://9114500962", volume = 0.22, speed = 0.95 },
	topper = { id = "rbxassetid://9117482890", volume = 0.26, speed = 0.9 },
	jump = { id = "rbxassetid://9117482890", volume = 0.22, speed = 0.75 },
	charge = { id = "rbxassetid://9114500962", volume = 0.18, speed = 1.25 },
	switchDog = { id = "rbxassetid://9116394545", volume = 0.18, speed = 0.95 },
	peel = { id = "rbxassetid://9114225473", volume = 0.24, speed = 1.2 },
	pipe = { id = "rbxassetid://9113856075", volume = 0.24, speed = 1.3 },
}

local SoftCap = if Config.guardrails.suddenLoudNoises == false then 0.45 else 0.85

local accessibilityModule: any = nil
local accessibilityResolved = false

local function accessibility()
	if accessibilityResolved then
		return accessibilityModule
	end
	accessibilityResolved = true
	local finale = script.Parent.Parent:FindFirstChild("finale")
	local settings = finale and finale:FindFirstChild("AccessibilitySettings")
	if settings and settings:IsA("ModuleScript") then
		local ok, result = pcall(function()
			return (require :: any)(settings)
		end)
		if ok then
			accessibilityModule = result
		end
	end
	return accessibilityModule
end

local function isMuted(): boolean
	local settings = accessibility()
	if settings and type(settings.get) == "function" then
		local state = settings.get()
		return type(state) == "table" and state.mutedAudio == true
	end
	return false
end

local function emitVisualCue(label: string)
	local settings = accessibility()
	if settings and type(settings.emitSoundCue) == "function" then
		settings.emitSoundCue(label)
	end
end

local SoundKit: Types.SoundApi = {
	play = function(name: string, options: { [string]: any }?)
		if isMuted() then
			emitVisualCue(name)
			return
		end

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
