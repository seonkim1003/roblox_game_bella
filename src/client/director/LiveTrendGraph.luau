--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VisualConfig = require(ReplicatedStorage:WaitForChild("Shared").VisualConfig)
local DirectorDashboardModel = require(script.Parent.DirectorDashboardModel)

local LiveTrendGraph = {}
local SEGMENT_COUNT = 300 -- 60 seconds at five validated samples per second.
local P = VisualConfig.palette

export type Graph = {
	push: (self: Graph, value: number, marker: string?) -> (),
	setMetric: (self: Graph, label: string) -> (),
}

local function addLegendItem(
	parent: Instance,
	name: string,
	text: string,
	color: Color3,
	diamond: boolean
)
	local item = Instance.new("Frame")
	item.Name = name
	item.AutomaticSize = Enum.AutomaticSize.X
	item.BackgroundTransparency = 1
	item.Size = UDim2.fromOffset(0, 18)
	item.Parent = parent
	local itemLayout = Instance.new("UIListLayout")
	itemLayout.FillDirection = Enum.FillDirection.Horizontal
	itemLayout.Padding = UDim.new(0, 6)
	itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	itemLayout.Parent = item
	local swatch = Instance.new("Frame")
	swatch.BackgroundColor3 = color
	swatch.BorderSizePixel = 0
	swatch.Rotation = if diamond then 45 else 0
	swatch.Size = UDim2.fromOffset(7, 7)
	swatch.Parent = item
	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = if diamond then UDim.new(0, 1) else UDim.new(1, 0)
	swatchCorner.Parent = swatch
	local itemLabel = Instance.new("TextLabel")
	itemLabel.AutomaticSize = Enum.AutomaticSize.X
	itemLabel.BackgroundTransparency = 1
	itemLabel.Font = Enum.Font.GothamMedium
	itemLabel.Size = UDim2.fromOffset(0, 18)
	itemLabel.Text = text
	itemLabel.TextColor3 = P.linen
	itemLabel.TextSize = 10
	itemLabel.Parent = item
end

function LiveTrendGraph.new(parent: Instance): Graph
	local root = Instance.new("Frame")
	root.Name = "LiveTrendGraph"
	root.BackgroundColor3 = P.plumDeep
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Size = UDim2.new(1, 0, 0, 188)
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = root

	local metric = Instance.new("TextLabel")
	metric.BackgroundTransparency = 1
	metric.Font = Enum.Font.GothamBold
	metric.Position = UDim2.fromOffset(12, 6)
	metric.Size = UDim2.new(1, -24, 0, 22)
	metric.Text = "MOMENTUM / 60 SECONDS"
	metric.TextColor3 = P.linen
	metric.TextSize = 11
	metric.TextXAlignment = Enum.TextXAlignment.Left
	metric.Parent = root

	local legend = Instance.new("Frame")
	legend.Name = "MarkerLegend"
	legend.BackgroundTransparency = 1
	legend.Position = UDim2.fromOffset(12, 28)
	legend.Size = UDim2.new(1, -24, 0, 20)
	legend.Parent = root
	local legendLayout = Instance.new("UIListLayout")
	legendLayout.FillDirection = Enum.FillDirection.Horizontal
	legendLayout.Padding = UDim.new(0, 16)
	legendLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	legendLayout.Parent = legend
	addLegendItem(legend, "DirectorCard", "DIRECTOR CUE", P.butter, true)
	addLegendItem(legend, "SignificantMoment", "SIGNIFICANT MOMENT", P.blush, false)

	local plot = Instance.new("Frame")
	plot.BackgroundTransparency = 1
	plot.Position = UDim2.fromOffset(8, 52)
	plot.Size = UDim2.new(1, -16, 1, -60)
	plot.Parent = root

	local segments: { Frame } = {}
	local markers: { Frame } = {}
	for index = 1, SEGMENT_COUNT do
		local segment = Instance.new("Frame")
		segment.Name = `Segment{index}`
		segment.AnchorPoint = Vector2.new(0, 0.5)
		segment.BackgroundColor3 = P.sky
		segment.BorderSizePixel = 0
		segment.Position = UDim2.fromScale((index - 1) / SEGMENT_COUNT, 0.8)
		segment.Rotation = 0
		segment.Size = UDim2.new(1 / SEGMENT_COUNT + 0.001, 0, 0, 2)
		segment.Visible = false
		segment.Parent = plot
		table.insert(segments, segment)

		local marker = Instance.new("Frame")
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.BackgroundColor3 = P.blush
		marker.BorderSizePixel = 0
		marker.Position = UDim2.fromScale((index - 0.5) / SEGMENT_COUNT, 0.5)
		marker.Size = UDim2.fromOffset(6, 6)
		marker.Visible = false
		marker.ZIndex = 2
		marker.Parent = plot
		local markerCorner = Instance.new("UICorner")
		markerCorner.CornerRadius = UDim.new(1, 0)
		markerCorner.Parent = marker
		table.insert(markers, marker)
	end

	local cursor = 0
	local previous = 0.5
	local graph = {} :: any
	function graph:push(value: number, markerKind: string?)
		cursor = (cursor % SEGMENT_COUNT) + 1
		local normalized = math.clamp(value, 0, 1)
		local segment = segments[cursor]
		local xScale = (cursor - 1) / SEGMENT_COUNT
		local yScale = 1 - (previous + normalized) * 0.5
		local dy = (normalized - previous) * plot.AbsoluteSize.Y
		local dx = math.max(1, plot.AbsoluteSize.X / SEGMENT_COUNT)
		segment.Visible = true
		segment.Position = UDim2.fromScale(xScale, yScale)
		segment.Rotation = math.deg(math.atan2(-dy, dx))
		TweenService:Create(
			segment,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 2) }
		):Play()
		local marker = markers[cursor]
		local category = DirectorDashboardModel.markerCategory(markerKind)
		marker.Visible = category ~= nil
		marker.BackgroundColor3 = if category == "Card" then P.butter else P.blush
		marker.Rotation = if category == "Card" then 45 else 0
		marker.Position = UDim2.fromScale(xScale, 1 - normalized)
		previous = normalized
	end
	function graph:setMetric(label: string)
		metric.Text = string.upper(label) .. " / 60 SECONDS"
	end
	return graph :: Graph
end

return LiveTrendGraph
