--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisualConfig = require(Shared.VisualConfig)

local Motion = require(script.Parent.Parent.juice.Motion)

local P = VisualConfig.palette
local FONTS = VisualConfig.fonts

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
		label.Font = FONTS.body
		label.Size = UDim2.new(1, 0, 0, 22)
		label.Text = ""
		label.TextColor3 = P.linen
		label.TextSize = 12
		label.TextTransparency = 0
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = root
		table.insert(labels, label)
	end
	return {
		push = function(kind: string, detail: string?)
			-- Older entries fade back as they slide down the list.
			for index = #labels, 2, -1 do
				labels[index].Text = labels[index - 1].Text
				labels[index].TextTransparency = math.min(0.15 * (index - 1), 0.55)
			end
			local newest = labels[1]
			newest.Text = `◆ {kind}{if detail then ` · {detail}` else ""}`
			newest.TextColor3 = P.cream
			-- Gentle fade-in so a fresh moment catches the eye.
			if Motion.reduced() then
				newest.TextTransparency = 0
			else
				newest.TextTransparency = 1
				TweenService:Create(
					newest,
					TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ TextTransparency = 0 }
				):Play()
			end
		end,
	}
end

return RecentMoments
