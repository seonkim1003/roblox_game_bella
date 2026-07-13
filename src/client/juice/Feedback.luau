-- Juice library. M0 no-op stub so the Director & Show lane can call it now.
-- The Player Experience lane (Agent A) fills these with real particles/squish/camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local Feedback: Types.FeedbackApi = {
	pop = function(_position: Vector3, _options: { [string]: any }?) end,
	confetti = function(_options: { [string]: any }?) end,
	squish = function(_target: Instance, _options: { [string]: any }?) end,
	cameraKick = function(_strength: number) end,
}

return Feedback
