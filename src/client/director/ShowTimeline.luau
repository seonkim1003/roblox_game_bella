--!strict

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

function ShowTimeline.new(parent: Instance): { set: (string, number) -> () }
	local label = Instance.new("TextLabel")
	label.Name = "ShowTimeline"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.new(1, 0, 0, 48)
	label.Text = "INVITATION  ·  ACT 1  ·  ACT 2  ·  ACT 3  ·  FINALE"
	label.TextColor3 = Color3.fromRGB(255, 244, 225)
	label.TextSize = 13
	label.TextWrapped = true
	label.Parent = parent
	return {
		set = function(phase: string, actIndex: number)
			label.Text = `{PHASE_LABELS[phase] or phase}  ·  Act {math.clamp(actIndex, 0, 3)}/3`
		end,
	}
end

return ShowTimeline
