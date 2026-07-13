-- ASMR/SFX playback. M0 no-op stub.
-- The Player Experience lane (Agent A) wires real named sound playback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local SoundKit: Types.SoundApi = {
	play = function(_name: string, _options: { [string]: any }?) end,
}

return SoundKit
