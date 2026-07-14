--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisualConfig = require(Shared.VisualConfig)

local P = VisualConfig.palette
local FONTS = VisualConfig.fonts
local RADIUS = VisualConfig.radius

local ShowTimeline = {}

local PHASE_LABELS: { [string]: string } = {
	Lobby = "Lobby",
	Invitation = "Invitation",
	Lounge = "Moonlit Lounge",
	ActIntroduction = "Act Introduction",
	Minigame = "Act Live",
	ActResult = "Act Result",
	Interlude = "Interlude",
	HeadlinerFinale = "Headliner Finale",
	KeepsakeResult = "Keepsake",
}

-- Five glanceable stops the whole show moves through, and which one each phase
-- lights up. A real progression bar instead of one line of text.
local STOP_NAMES = { "Welcome", "Lounge", "Acts", "Interlude", "Finale" }
local STOP_FOR_PHASE: { [string]: number } = {
	Lobby = 1,
	Invitation = 1,
	Lounge = 2,
	ActIntroduction = 3,
	Minigame = 3,
	ActResult = 3,
	Interlude = 4,
	HeadlinerFinale = 5,
	KeepsakeResult = 5,
}

function ShowTimeline.new(parent: Instance): { set: (string, number) -> () }
	local container = Instance.new("Frame")
	container.Name = "ShowTimeline"
	container.BackgroundColor3 = P.plumDeep
	container.BackgroundTransparency = 0.25
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1, 0, 0, 58)
	container.Parent = parent

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, RADIUS.card)
	containerCorner.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = container

	-- Row of pips, one per stop.
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 8)
	row.Parent = container

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 6)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row

	local pips: { Frame } = {}
	for index = 1, #STOP_NAMES do
		local pip = Instance.new("Frame")
		pip.Name = `Pip{index}`
		pip.BackgroundColor3 = P.plum
		pip.BorderSizePixel = 0
		pip.LayoutOrder = index
		pip.Size = UDim2.fromScale(0.16, 1)
		pip.Parent = row
		local pipCorner = Instance.new("UICorner")
		pipCorner.CornerRadius = UDim.new(1, 0)
		pipCorner.Parent = pip
		pips[index] = pip
	end

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.fromScale(0.5, 1)
	caption.Size = UDim2.new(1, 0, 0, 18)
	caption.Font = FONTS.heading
	caption.Text = "INVITATION"
	caption.TextColor3 = P.cream
	caption.TextSize = 13
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.Parent = container

	return {
		set = function(phase: string, actIndex: number)
			local active = STOP_FOR_PHASE[phase] or 1
			for index, pip in pips do
				-- Passed stops glow butter; the current one is blush; the rest rest.
				if index < active then
					pip.BackgroundColor3 = P.butter
				elseif index == active then
					pip.BackgroundColor3 = P.blush
				else
					pip.BackgroundColor3 = P.plum
				end
			end
			local label = PHASE_LABELS[phase] or phase
			if active == 3 then
				caption.Text = `{label}  ·  Act {math.clamp(actIndex, 0, 3)}/3`
			else
				caption.Text = label
			end
		end,
	}
end

return ShowTimeline
