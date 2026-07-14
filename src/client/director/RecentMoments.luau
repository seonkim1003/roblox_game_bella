--!strict

local RecentMoments = {}

function RecentMoments.new(parent: Instance): { push: (string, string?) -> () }
	local root = Instance.new("Frame")
	root.Name = "RecentMoments"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, 104)
	root.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = root
	local labels: { TextLabel } = {}
	for _ = 1, 4 do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.Size = UDim2.new(1, 0, 0, 22)
		label.Text = ""
		label.TextColor3 = Color3.fromRGB(226, 207, 190)
		label.TextSize = 12
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = root
		table.insert(labels, label)
	end
	return {
		push = function(kind: string, detail: string?)
			for index = #labels, 2, -1 do
				labels[index].Text = labels[index - 1].Text
			end
			labels[1].Text = `◆ {kind}{if detail then ` · {detail}` else ""}`
		end,
	}
end

return RecentMoments
