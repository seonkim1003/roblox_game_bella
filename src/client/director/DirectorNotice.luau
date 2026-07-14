--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisualConfig = require(Shared.VisualConfig)

local P = VisualConfig.palette
local FONTS = VisualConfig.fonts
local RADIUS = VisualConfig.radius

local DirectorNotice = {}

function DirectorNotice.new(parent: Instance): { set: (string, boolean?) -> () }
	local pill = Instance.new("Frame")
	pill.Name = "DirectorNotice"
	pill.BackgroundColor3 = P.plumDeep
	pill.BackgroundTransparency = 0.2
	pill.BorderSizePixel = 0
	pill.Size = UDim2.new(1, 0, 0, 38)
	pill.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, RADIUS.chip)
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color = P.rain
	stroke.Thickness = 1.5
	stroke.Transparency = 0.5
	stroke.Parent = pill

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	icon.Size = UDim2.fromOffset(20, 20)
	icon.Font = FONTS.heading
	icon.Text = "•"
	icon.TextColor3 = P.mint
	icon.TextSize = 16
	icon.Parent = pill

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 40, 0.5, 0)
	label.Size = UDim2.new(1, -52, 1, 0)
	label.Font = FONTS.body
	label.Text = "Show link ready"
	label.TextColor3 = P.linen
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Parent = pill

	return {
		set = function(text: string, isError: boolean?)
			label.Text = text
			-- Icon carries the state too, so it reads without colour alone.
			if isError then
				icon.Text = "⚠"
				icon.TextColor3 = P.blush
				stroke.Color = P.blush
				label.TextColor3 = P.blush
			else
				icon.Text = "ℹ"
				icon.TextColor3 = P.mint
				stroke.Color = P.mint
				label.TextColor3 = P.linen
			end
			-- Brief stroke pulse so even a repeated/similar notice visibly refreshes.
			stroke.Transparency = 0
			TweenService:Create(
				stroke,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 0.5 }
			):Play()
		end,
	}
end

return DirectorNotice
