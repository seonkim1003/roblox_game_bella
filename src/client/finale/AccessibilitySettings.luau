--!strict

local SoundService = game:GetService("SoundService")

local AccessibilityModel = require(script.Parent.AccessibilityModel)

local AccessibilitySettings = {}
local state = AccessibilityModel.new()
local changed = Instance.new("BindableEvent")
local soundCue = Instance.new("BindableEvent")
local ORIGINAL_VOLUME_ATTRIBUTE = "BashAccessibilityOriginalVolume"

local function applySound(sound: Sound)
	if state.mutedAudio then
		if sound:GetAttribute(ORIGINAL_VOLUME_ATTRIBUTE) == nil then
			sound:SetAttribute(ORIGINAL_VOLUME_ATTRIBUTE, sound.Volume)
		end
		sound.Volume = 0
	else
		local original = sound:GetAttribute(ORIGINAL_VOLUME_ATTRIBUTE)
		if type(original) == "number" then
			sound.Volume = math.clamp(original, 0, 10)
			sound:SetAttribute(ORIGINAL_VOLUME_ATTRIBUTE, nil)
		end
	end
end

local function applyAllSounds()
	for _, descendant in SoundService:GetDescendants() do
		if descendant:IsA("Sound") then
			applySound(descendant)
		end
	end
end

SoundService.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Sound") then
		applySound(descendant)
	end
end)

function AccessibilitySettings.get(): AccessibilityModel.State
	return state
end

function AccessibilitySettings.setMutedAudio(muted: boolean)
	if state.mutedAudio == muted then
		return
	end
	state = AccessibilityModel.withMutedAudio(state, muted)
	applyAllSounds()
	changed:Fire(state)
end

function AccessibilitySettings.setReducedMotion(reduced: boolean)
	if state.reducedMotion == reduced then
		return
	end
	state = AccessibilityModel.withReducedMotion(state, reduced)
	changed:Fire(state)
end

function AccessibilitySettings.onChanged(
	callback: (AccessibilityModel.State) -> ()
): RBXScriptConnection
	return changed.Event:Connect(callback)
end

function AccessibilitySettings.emitSoundCue(label: string)
	if state.mutedAudio then
		soundCue:Fire(label)
	end
end

function AccessibilitySettings.onSoundCue(callback: (string) -> ()): RBXScriptConnection
	return soundCue.Event:Connect(callback)
end

return AccessibilitySettings
