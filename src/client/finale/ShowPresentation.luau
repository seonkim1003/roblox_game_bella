--!strict

-- Shared Premiere overlays for invitation, transitions, results, and reconnect.
-- Gameplay UI remains owned by the Star minigame lane.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local VisualConfig = require(Shared.VisualConfig)
local AccessibilityControls = require(script.Parent.AccessibilityControls)

type Payload = { [string]: any }

local ShowPresentation = {}
local started = false

local P = VisualConfig.palette
local gui: ScreenGui? = nil
local shadeFrame: Frame? = nil
local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local bodyLabel: TextLabel? = nil
local summaryLabel: TextLabel? = nil
local actionRow: Frame? = nil
local cinematicFight = false
local panelConstraint: UISizeConstraint? = nil

local GAME_NAMES: { [string]: string } = {
	CheeseTower = "Cheese Atelier",
	DogDash = "Moonlight Dash",
	SatisfyStation = "ASMR Dream Studio",
}

local function corner(parent: Instance, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

local function clearActions()
	local row = actionRow
	if not row then
		return
	end
	for _, child in row:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
end

local function send(action: string, payload: Payload?)
	Net.get(Net.DirectorCommand):FireServer({ action = action, payload = payload })
end

local function button(text: string, color: Color3, callback: () -> ()): TextButton?
	local row = actionRow
	if not row then
		return nil
	end
	local result = Instance.new("TextButton")
	result.AutoButtonColor = true
	result.BackgroundColor3 = color
	result.BorderSizePixel = 0
	result.Font = Enum.Font.GothamBold
	result.Text = text
	result.TextColor3 = P.ink
	result.TextSize = 16
	result.TextWrapped = true
	result.Selectable = true
	result.Size = UDim2.new(0.32, -8, 1, 0)
	result.Parent = row
	corner(result, 14)
	result.Activated:Connect(callback)
	return result
end

local function setVisible(visible: boolean)
	if gui then
		gui.Enabled = visible
	end
	if
		not visible
		and GuiService.SelectedObject
		and panel
		and GuiService.SelectedObject:IsDescendantOf(panel)
	then
		GuiService.SelectedObject = nil
	end
end

local function setModalLayout()
	cinematicFight = false
	if shadeFrame then
		shadeFrame.BackgroundTransparency = 0.2
	end
	if panel then
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.BackgroundTransparency = 0
		panel.Size = UDim2.new(0.88, 0, 0, 290)
	end
	if panelConstraint then
		panelConstraint.MaxSize = Vector2.new(620, 440)
		panelConstraint.MinSize = Vector2.new(286, 270)
	end
	if titleLabel then
		titleLabel.Position = UDim2.fromOffset(24, 30)
		titleLabel.Size = UDim2.new(1, -48, 0, 58)
	end
	if bodyLabel then
		bodyLabel.Position = UDim2.fromOffset(24, 96)
		bodyLabel.Size = UDim2.new(1, -48, 0, 78)
	end
	if actionRow then
		actionRow.Position = UDim2.new(0, 24, 1, -82)
		actionRow.Size = UDim2.new(1, -48, 0, 58)
	end
	if summaryLabel then
		summaryLabel.Visible = false
	end
end

local function setCinematicLayout()
	cinematicFight = true
	if shadeFrame then
		shadeFrame.BackgroundTransparency = 1
	end
	if panel then
		panel.AnchorPoint = Vector2.new(0.5, 1)
		panel.Position = UDim2.new(0.5, 0, 1, -28)
		panel.BackgroundTransparency = 0.08
		panel.Size = UDim2.new(0.72, 0, 0, 148)
	end
	if panelConstraint then
		panelConstraint.MaxSize = Vector2.new(560, 160)
		panelConstraint.MinSize = Vector2.new(260, 120)
	end
	if titleLabel then
		titleLabel.Position = UDim2.fromOffset(20, 12)
		titleLabel.Size = UDim2.new(1, -40, 0, 32)
	end
	if bodyLabel then
		bodyLabel.Position = UDim2.fromOffset(20, 44)
		bodyLabel.Size = UDim2.new(1, -40, 0, 40)
	end
	if actionRow then
		actionRow.Position = UDim2.new(0, 20, 1, -52)
		actionRow.Size = UDim2.new(1, -40, 0, 40)
	end
	if summaryLabel then
		summaryLabel.Visible = false
	end
end

local function present(title: string, body: string)
	setModalLayout()
	if titleLabel then
		titleLabel.Text = title
	end
	if bodyLabel then
		bodyLabel.Text = body
	end
	if summaryLabel then
		summaryLabel.Text = ""
		summaryLabel.Visible = false
	end
	if panel then
		panel.Size = UDim2.new(0.88, 0, 0, 290)
	end
	clearActions()
	setVisible(true)
end

local function presentFightCaption(title: string, body: string)
	setCinematicLayout()
	if titleLabel then
		titleLabel.Text = title
	end
	if bodyLabel then
		bodyLabel.Text = body
	end
	if summaryLabel then
		summaryLabel.Text = ""
		summaryLabel.Visible = false
	end
	clearActions()
	button("Skip", P.linen, function()
		send("SkipCinematic", {})
	end)
	setVisible(true)
end

local function updateFightLine(line: string)
	if not cinematicFight then
		presentFightCaption("RAMBO VS GIGI", line)
		return
	end
	if bodyLabel then
		bodyLabel.Text = line
	end
	setVisible(true)
end

local function role(): string?
	local value = Players.LocalPlayer:GetAttribute("BashRole")
	return if type(value) == "string" then value else nil
end

local function keepsakeLines(summary: Payload): string
	local lines = {}
	local actGrades = summary.actGrades
	if type(actGrades) == "table" then
		for _, act in actGrades do
			if type(act) == "table" and type(act.gameId) == "string" then
				local grade = if type(act.grade) == "string" then act.grade else "—"
				table.insert(lines, `{GAME_NAMES[act.gameId] or act.gameId}: {grade}`)
			end
		end
	end
	local cueGrade = if type(summary.directorCueGrade) == "string"
		then summary.directorCueGrade
		else "—"
	table.insert(lines, `Director cue grade: {cueGrade}`)
	if type(summary.bestAct) == "string" then
		table.insert(lines, `Best act: {summary.bestAct}`)
	end
	if type(summary.dogPose) == "string" then
		table.insert(lines, `Gigi + Rambo: {summary.dogPose}`)
	end
	return table.concat(lines, "\n")
end

local function presentKeepsake(payload: Payload, encoreHighlight: boolean?)
	local summary = if type(payload.summary) == "table"
		then payload.summary
		elseif type(payload.performanceSummary) == "table" then payload.performanceSummary
		else {}
	local title = if type(summary.title) == "string" then summary.title else "A NIGHT TO KEEP"
	local trophy = if type(summary.featuredTrophy) == "string"
		then summary.featuredTrophy
		else "Premiere Keepsake"
	local moment = if type(summary.bestMoment) == "string"
		then summary.bestMoment
		else "A night made together"
	present(if encoreHighlight then "ENCORE HIGHLIGHT" else title, `{trophy} · {moment}`)
	if panel then
		panel.Size = UDim2.new(0.88, 0, 0, 420)
	end
	if summaryLabel then
		summaryLabel.Text = keepsakeLines(summary)
		summaryLabel.Visible = true
	end
	local session = if type(payload.session) == "table" then payload.session else payload
	local encoreRequested = encoreHighlight == true or session.encoreRequested == true
	if role() == "Star" and not encoreRequested then
		button("Encore", P.blush, function()
			send("RequestEncore", {})
		end)
	end
	button("Replay", P.sky, function()
		send("ReplayShow", {})
	end)
end

local function presentInvitation()
	present("YOUR PREMIERE AWAITS", "Bella, choose the mood that will color tonight's show.")
	if role() == "Star" then
		local first = button("Cozy", P.butter, function()
			send("ChooseMood", { mood = "Cozy" })
		end)
		button("Playful", P.blush, function()
			send("ChooseMood", { mood = "Playful" })
		end)
		button("Dreamy", P.sky, function()
			send("ChooseMood", { mood = "Dreamy" })
		end)
		if first then
			GuiService.SelectedObject = first
		end
	else
		if bodyLabel then
			bodyLabel.Text = "Bella is choosing the mood. Your first cue is waiting in the wings."
		end
	end
end

local function presentPhase(phase: string, payload: Payload)
	if phase == "Invitation" then
		presentInvitation()
	elseif phase == "Lounge" or phase == "Minigame" then
		cinematicFight = false
		setVisible(false)
	elseif phase == "ActIntroduction" then
		local gameId = payload.activeGameId or payload.gameId
		if gameId == "DogDash" or payload.dogFight == true then
			presentFightCaption(
				"RAMBO VS GIGI",
				"Play fight in the garden — Gigi's going for gold."
			)
			return
		end
		local name = if type(gameId) == "string" then GAME_NAMES[gameId] or gameId else "Next Act"
		present("NEXT ACT", name)
		button("Skip", P.linen, function()
			send("SkipCinematic", {})
		end)
	elseif phase == "ActResult" then
		local results = payload.results
		local result = if type(results) == "table" then results[#results] else nil
		local grade = if type(result) == "table" and type(result.grade) == "string"
			then result.grade
			else "—"
		present("ACT COMPLETE", `Grade {grade} · A new favorite moment is in the books.`)
		button("Continue", P.mint, function()
			send("SkipCinematic", {})
		end)
	elseif phase == "Interlude" then
		if payload.dogFight == true or payload.nextGameId == "DogDash" then
			presentFightCaption("RAMBO VS GIGI", "The pups take the rug. Who comes out on top?")
			return
		end
		present("INTERLUDE", "The set is changing. The next act begins in a few seconds.")
		button("Next act now", P.sky, function()
			send("SkipCinematic", {})
		end)
	elseif phase == "HeadlinerFinale" then
		present(
			"HEADLINER FINALE",
			"This personalized moment only skips when both players confirm."
		)
		button("Confirm skip", P.linen, function()
			send("SkipCinematic", {})
		end)
	elseif phase == "KeepsakeResult" then
		presentKeepsake(payload, false)
	end
end

local function build()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local old = playerGui:FindFirstChild("PremierePresentation")
	if old then
		old:Destroy()
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "PremierePresentation"
	screen.DisplayOrder = 80
	screen.IgnoreGuiInset = false
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = playerGui

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = P.night
	shade.BackgroundTransparency = 0.2
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = screen

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = P.cream
	card.BorderSizePixel = 0
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.new(0.88, 0, 0, 290)
	card.Parent = shade
	corner(card, 26)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(620, 440)
	constraint.MinSize = Vector2.new(286, 270)
	constraint.Parent = card

	local accent = Instance.new("Frame")
	accent.BackgroundColor3 = P.blush
	accent.BorderSizePixel = 0
	accent.Size = UDim2.new(1, 0, 0, 10)
	accent.Parent = card
	corner(accent, 26)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Position = UDim2.fromOffset(24, 30)
	title.Size = UDim2.new(1, -48, 0, 58)
	title.TextColor3 = P.plumDeep
	title.TextScaled = true
	title.TextWrapped = true
	title.Parent = card
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 30
	titleSize.MinTextSize = 20
	titleSize.Parent = title

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.Position = UDim2.fromOffset(24, 96)
	body.Size = UDim2.new(1, -48, 0, 78)
	body.TextColor3 = P.plum
	body.TextSize = 17
	body.TextWrapped = true
	body.Parent = card

	local summary = Instance.new("TextLabel")
	summary.BackgroundTransparency = 1
	summary.Font = Enum.Font.GothamMedium
	summary.Position = UDim2.fromOffset(24, 172)
	summary.Size = UDim2.new(1, -48, 0, 154)
	summary.Text = ""
	summary.TextColor3 = P.plum
	summary.TextSize = 14
	summary.TextWrapped = true
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextYAlignment = Enum.TextYAlignment.Top
	summary.Visible = false
	summary.Parent = card

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.new(0, 24, 1, -82)
	row.Size = UDim2.new(1, -48, 0, 58)
	row.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = row

	gui = screen
	shadeFrame = shade
	panel = card
	panelConstraint = constraint
	titleLabel = title
	bodyLabel = body
	summaryLabel = summary
	actionRow = row
end

function ShowPresentation.start()
	if started then
		return
	end
	started = true
	AccessibilityControls.start()
	build()
	Net.get(Net.ShowEvent).OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" or type(message.event) ~= "string" then
			return
		end
		local payload = if type(message.payload) == "table" then message.payload else {}
		if message.event == "PlayableInvitation" then
			presentInvitation()
		elseif message.event == "ShowState" then
			local session = payload.session
			if type(session) == "table" and type(session.phase) == "string" then
				local presentation = table.clone(session)
				presentation.performanceSummary = payload.performanceSummary
				presentPhase(session.phase, presentation)
			end
		elseif message.event == "PremierePhaseChanged" then
			local phase = payload.phase
			if type(phase) == "string" then
				presentPhase(phase, payload)
			end
		elseif message.event == "ActIntroduction" then
			presentPhase("ActIntroduction", payload)
		elseif message.event == "InterludeStarted" then
			presentPhase("Interlude", payload)
		elseif message.event == "DogFightStarted" then
			presentFightCaption(
				"RAMBO VS GIGI",
				"Play fight in the garden — Gigi's going for gold."
			)
		elseif message.event == "DogFightBeat" then
			local line = payload.line
			if type(line) == "string" then
				updateFightLine(line)
			end
		elseif message.event == "DogFightEnded" then
			cinematicFight = false
			setVisible(false)
		elseif message.event == "FinaleStarted" then
			presentFightCaption(
				"HEADLINER FINALE",
				"Watch the moment. Confirm skip only if both of you want to move on."
			)
			clearActions()
			button("Confirm skip", P.linen, function()
				send("SkipCinematic", {})
			end)
		elseif message.event == "FinaleSkipConfirmed" then
			local complete = payload.complete == true
			if complete then
				setVisible(false)
			elseif bodyLabel then
				bodyLabel.Text = "Waiting for the other player to confirm skip…"
				setVisible(true)
			end
		elseif message.event == "KeepsakeResult" then
			presentKeepsake(payload, false)
		elseif message.event == "EncoreRequested" then
			presentKeepsake(payload, true)
		end
	end)
end

return ShowPresentation
