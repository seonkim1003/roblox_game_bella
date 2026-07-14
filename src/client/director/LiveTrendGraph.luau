--!strict

local TweenService = game:GetService("TweenService")

local LiveTrendGraph = {}
local SEGMENT_COUNT = 300 -- 60 seconds at five validated samples per second.

export type Graph = {
	push: (self: Graph, value: number, marker: string?) -> (),
	setMetric: (self: Graph, label: string) -> (),
}

function LiveTrendGraph.new(parent: Instance): Graph
	local root = Instance.new("Frame")
	root.Name = "LiveTrendGraph"
	root.BackgroundColor3 = Color3.fromRGB(35, 27, 46)
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Size = UDim2.new(1, 0, 0, 170)
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = root

	local metric = Instance.new("TextLabel")
	metric.BackgroundTransparency = 1
	metric.Font = Enum.Font.GothamBold
	metric.Position = UDim2.fromOffset(12, 6)
	metric.Size = UDim2.new(1, -24, 0, 22)
	metric.Text = "MOMENTUM · 60 SECONDS"
	metric.TextColor3 = Color3.fromRGB(226, 207, 190)
	metric.TextSize = 11
	metric.TextXAlignment = Enum.TextXAlignment.Left
	metric.Parent = root

	local plot = Instance.new("Frame")
	plot.BackgroundTransparency = 1
	plot.Position = UDim2.fromOffset(8, 32)
	plot.Size = UDim2.new(1, -16, 1, -40)
	plot.Parent = root

	local segments: { Frame } = {}
	local markers: { Frame } = {}
	for index = 1, SEGMENT_COUNT do
		local segment = Instance.new("Frame")
		segment.Name = `Segment{index}`
		segment.AnchorPoint = Vector2.new(0, 0.5)
		segment.BackgroundColor3 = Color3.fromRGB(143, 202, 224)
		segment.BorderSizePixel = 0
		segment.Position = UDim2.fromScale((index - 1) / SEGMENT_COUNT, 0.8)
		segment.Rotation = 0
		segment.Size = UDim2.new(1 / SEGMENT_COUNT + 0.001, 0, 0, 2)
		segment.Visible = false
		segment.Parent = plot
		table.insert(segments, segment)

		local marker = Instance.new("Frame")
		marker.AnchorPoint = Vector2.new(0.5, 0.5)
		marker.BackgroundColor3 = Color3.fromRGB(244, 207, 121)
		marker.BorderSizePixel = 0
		marker.Position = UDim2.fromScale((index - 0.5) / SEGMENT_COUNT, 0.5)
		marker.Size = UDim2.fromOffset(6, 6)
		marker.Visible = false
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
		marker.Visible = markerKind ~= nil
		marker.Position = UDim2.fromScale(xScale, 1 - normalized)
		previous = normalized
	end
	function graph:setMetric(label: string)
		metric.Text = string.upper(label) .. " · 60 SECONDS"
	end
	return graph :: Graph
end

return LiveTrendGraph
