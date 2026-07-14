--!strict

local ProjectedGrade = {}

local function grade(value: number): string
	if value >= 92 then
		return "S"
	elseif value >= 80 then
		return "A"
	elseif value >= 65 then
		return "B"
	elseif value >= 48 then
		return "C"
	end
	return "D"
end

function ProjectedGrade.new(parent: Instance): { set: (number) -> () }
	local label = Instance.new("TextLabel")
	label.Name = "ProjectedGrade"
	label.BackgroundColor3 = Color3.fromRGB(70, 50, 82)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.new(1, 0, 0, 56)
	label.Text = "PROJECTED GRADE  —"
	label.TextColor3 = Color3.fromRGB(244, 207, 121)
	label.TextSize = 18
	label.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = label
	return {
		set = function(value: number)
			label.Text = `PROJECTED GRADE  {grade(value)}`
		end,
	}
end

return ProjectedGrade
