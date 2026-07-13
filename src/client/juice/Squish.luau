--!strict
-- Soft scale-punch helper used by Feedback.squish and any minigame that wants
-- a quick "squash and settle" on a BasePart.

local TweenService = game:GetService("TweenService")

local Squish = {}

local DEFAULT_SQUASH = Vector3.new(1.18, 0.82, 1.18)
local DEFAULT_TIME = 0.12

function Squish.punch(target: Instance, options: { [string]: any }?)
	if not target:IsA("BasePart") then
		return
	end

	local part = target :: BasePart
	local strength = if options and type(options.strength) == "number" then options.strength else 1
	local duration = if options and type(options.duration) == "number"
		then options.duration
		else DEFAULT_TIME
	local original = part.Size
	local squash = Vector3.new(
		original.X * (1 + (DEFAULT_SQUASH.X - 1) * strength),
		original.Y * (1 - (1 - DEFAULT_SQUASH.Y) * strength),
		original.Z * (1 + (DEFAULT_SQUASH.Z - 1) * strength)
	)

	local down = TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = squash }
	)
	local up = TweenService:Create(
		part,
		TweenInfo.new(duration * 1.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Size = original }
	)

	down:Play()
	down.Completed:Once(function()
		if part.Parent then
			up:Play()
		end
	end)
end

return Squish
