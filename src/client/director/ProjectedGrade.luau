--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualConfig = require(ReplicatedStorage:WaitForChild("Shared").VisualConfig)
local DirectorDashboardModel = require(script.Parent.DirectorDashboardModel)

local ProjectedGrade = {}
local P = VisualConfig.palette

function ProjectedGrade.new(parent: Instance): { set: (number) -> () }
	local root = Instance.new("Frame")
	root.Name = "ProjectedGrade"
	root.BackgroundColor3 = P.plum
	root.BorderSizePixel = 0
	root.Size = UDim2.new(1, 0, 0, 82)
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.fromOffset(12, 7)
	title.Size = UDim2.new(0.62, -12, 0, 20)
	title.Text = "PROJECTED GRADE"
	title.TextColor3 = P.linen
	title.TextSize = 11
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = root

	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = Enum.Font.GothamBlack
	valueLabel.Position = UDim2.new(0.62, 0, 0, 4)
	valueLabel.Size = UDim2.new(0.38, -12, 0, 24)
	valueLabel.Text = "--"
	valueLabel.TextColor3 = P.butter
	valueLabel.TextSize = 18
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = root

	local track = Instance.new("Frame")
	track.Name = "GradeBands"
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromOffset(12, 34)
	track.Size = UDim2.new(1, -24, 0, 18)
	track.Parent = root

	local bandColors = { P.rain, P.terracotta, P.sky, P.mint, P.butter }
	local bands = DirectorDashboardModel.gradeBands()
	for index, band in bands do
		local bandFrame = Instance.new("Frame")
		bandFrame.Name = `Band{band.grade}`
		bandFrame.BackgroundColor3 = bandColors[index]
		bandFrame.BackgroundTransparency = 0.16
		bandFrame.BorderSizePixel = 0
		bandFrame.Position = UDim2.fromScale(band.minimum / 100, 0)
		bandFrame.Size = UDim2.fromScale((band.maximum - band.minimum + 1) / 100, 1)
		bandFrame.Parent = track
		local bandLabel = Instance.new("TextLabel")
		bandLabel.BackgroundTransparency = 1
		bandLabel.Font = Enum.Font.GothamBold
		bandLabel.Size = UDim2.fromScale(1, 1)
		bandLabel.Text = band.grade
		bandLabel.TextColor3 = P.ink
		bandLabel.TextSize = 10
		bandLabel.Parent = bandFrame
	end

	local target = DirectorDashboardModel.targetBand("A")
	local targetOutline = Instance.new("Frame")
	targetOutline.Name = "TargetBand"
	targetOutline.BackgroundTransparency = 1
	targetOutline.BorderSizePixel = 0
	targetOutline.Position = UDim2.new(target.minimum / 100, -2, 0, -2)
	targetOutline.Size = UDim2.new((target.maximum - target.minimum + 1) / 100, 4, 1, 4)
	targetOutline.Parent = track
	local targetStroke = Instance.new("UIStroke")
	targetStroke.Color = P.cream
	targetStroke.Thickness = 2
	targetStroke.Parent = targetOutline

	local pointer = Instance.new("Frame")
	pointer.Name = "ProjectionPointer"
	pointer.AnchorPoint = Vector2.new(0.5, 0)
	pointer.BackgroundColor3 = P.cream
	pointer.BorderSizePixel = 0
	pointer.Position = UDim2.fromScale(0, 0)
	pointer.Size = UDim2.fromOffset(3, 18)
	pointer.Visible = false
	pointer.ZIndex = 3
	pointer.Parent = track

	local targetLabel = Instance.new("TextLabel")
	targetLabel.BackgroundTransparency = 1
	targetLabel.Font = Enum.Font.GothamMedium
	targetLabel.Position = UDim2.fromOffset(12, 57)
	targetLabel.Size = UDim2.new(1, -24, 0, 17)
	targetLabel.Text = `TARGET {target.grade} / {target.minimum}-{target.maximum}`
	targetLabel.TextColor3 = P.mint
	targetLabel.TextSize = 10
	targetLabel.TextXAlignment = Enum.TextXAlignment.Left
	targetLabel.Parent = root

	return {
		set = function(value: number)
			local score = math.clamp(value, 0, 100)
			valueLabel.Text = `{DirectorDashboardModel.gradeFor(score)} / {math.round(score)}`
			pointer.Position = UDim2.fromScale(score / 100, 0)
			pointer.Visible = true
		end,
	}
end

return ProjectedGrade
