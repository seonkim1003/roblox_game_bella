--!strict

local ProgressWidget = {}

function ProgressWidget.new(parent: Instance): { set: (number) -> () }
	local root = Instance.new("Frame")
	root.Name = "ProgressWidget"
	root.BackgroundColor3 = Color3.fromRGB(49, 37, 61)
	root.BorderSizePixel = 0
	root.Size = UDim2.new(1, 0, 0, 38)
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = root
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(143, 202, 224)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = root
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "ACT PROGRESS  0%"
	label.TextColor3 = Color3.fromRGB(255, 244, 225)
	label.TextSize = 13
	label.Parent = root
	return {
		set = function(value: number)
			local normalized = math.clamp(value, 0, 1)
			fill.Size = UDim2.fromScale(normalized, 1)
			label.Text = `ACT PROGRESS  {math.round(normalized * 100)}%`
		end,
	}
end

return ProgressWidget
