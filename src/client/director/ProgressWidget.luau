--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisualConfig = require(Shared.VisualConfig)

local Motion = require(script.Parent.Parent.juice.Motion)

local P = VisualConfig.palette
local FONTS = VisualConfig.fonts
local RADIUS = VisualConfig.radius

local ProgressWidget = {}

function ProgressWidget.new(parent: Instance): { set: (number) -> () }
	local root = Instance.new("Frame")
	root.Name = "ProgressWidget"
	root.BackgroundColor3 = P.plumDeep
	root.BorderSizePixel = 0
	root.Size = UDim2.new(1, 0, 0, 38)
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, RADIUS.chip)
	corner.Parent = root
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = P.sky
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = root
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONTS.heading
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "ACT PROGRESS  0%"
	label.TextColor3 = P.cream
	label.TextSize = 13
	label.Parent = root
	return {
		set = function(value: number)
			local normalized = math.clamp(value, 0, 1)
			Motion.tween(fill, Motion.ease(0.35), { Size = UDim2.fromScale(normalized, 1) })
			label.Text = `ACT PROGRESS  {math.round(normalized * 100)}%`
		end,
	}
end

return ProgressWidget
