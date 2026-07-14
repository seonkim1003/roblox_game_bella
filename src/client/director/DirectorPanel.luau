--!strict

-- Responsive, controller-friendly Director console. The panel contains no
-- networking code; it emits intent and renders only server-confirmed state.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local VisualConfig = require(Shared.VisualConfig)
local Packages = ReplicatedStorage:WaitForChild("Packages")
-- Wally alias modules can briefly be absent when Studio connects after the
-- package index has already synced. Resolve the pinned package directly as a
-- fallback so the Director console still boots in that valid Rojo state.
local TroveModule = Packages:FindFirstChild("Trove")
	or Packages:WaitForChild("_Index"):WaitForChild("sleitnick_trove@1.8.0"):WaitForChild("trove")
local Trove = (require :: any)(TroveModule :: ModuleScript)

type Payload = { [string]: any }
type SendCommand = (action: string, payload: Payload?) -> ()

export type Panel = {
	applyState: (payload: Payload) -> (),
	setPhase: (phase: string, activeMinigame: string?) -> (),
	setDifficulty: (level: number) -> (),
	setStarConnection: (connected: boolean, name: string?) -> (),
	setScore: (id: string, score: number, data: Payload?) -> (),
	setNotice: (text: string, isError: boolean?) -> (),
	commandResult: (action: string, accepted: boolean, detail: string?) -> (),
	destroy: () -> (),
}

local PANEL_NAME = "BirthdayBashDirectorPanel"
local MESSAGE_LIMIT = 160

local COLORS = {
	background = VisualConfig.palette.plumDeep,
	card = VisualConfig.palette.plum,
	cardRaised = VisualConfig.palette.plum:Lerp(VisualConfig.palette.cream, 0.1),
	text = VisualConfig.palette.cream,
	muted = VisualConfig.palette.linen,
	outline = VisualConfig.palette.plum:Lerp(VisualConfig.palette.cream, 0.28),
	good = VisualConfig.palette.mint,
	warning = VisualConfig.palette.butter,
	error = Color3.fromRGB(230, 112, 126),
	primary = VisualConfig.palette.blush,
	accent = VisualConfig.palette.sky,
}

local DirectorPanel = {}

local function addCorner(gui: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
end

local function addStroke(gui: GuiObject, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or COLORS.outline
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0.2
	stroke.Parent = gui
	return stroke
end

local function addPadding(gui: GuiObject, amount: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.Parent = gui
end

local function createLabel(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	font: Enum.Font,
	textSize: number,
	color: Color3?
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.Text = text
	label.TextColor3 = color or COLORS.text
	label.TextSize = textSize
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

local function createCard(parent: Instance, name: string, height: number): Frame
	local card = Instance.new("Frame")
	card.Name = name
	card.BackgroundColor3 = COLORS.card
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, height)
	card.Parent = parent
	addCorner(card, 18)
	addStroke(card)
	return card
end

local function createButton(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = COLORS.text
	button.TextSize = 15
	button.TextWrapped = true
	button.Selectable = true
	button.Size = UDim2.fromOffset(150, 50)
	button.Parent = parent
	addCorner(button, 12)
	local stroke = addStroke(button, color:Lerp(Color3.new(1, 1, 1), 0.35), 1)
	stroke.Transparency = 0.35

	button.SelectionGained:Connect(function()
		stroke.Color = COLORS.text
		stroke.Thickness = 3
		stroke.Transparency = 0
	end)
	button.SelectionLost:Connect(function()
		stroke.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
		stroke.Thickness = 1
		stroke.Transparency = 0.35
	end)

	return button
end

local function setButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.Selectable = enabled
	button.TextTransparency = if enabled then 0 else 0.52
	button.BackgroundTransparency = if enabled then 0 else 0.48
end

local function displayGameName(id: string?): string
	if id == "CheeseTower" then
		return "Ratthew's Cheese Tower"
	elseif id == "DogDash" then
		return "Gigi & Rambo Dash"
	elseif id == "SatisfyStation" then
		return "ASMR Satisfy Station"
	end
	return "No game running"
end

local function displayPhase(phase: string): string
	if phase == "Lobby" then
		return "Waiting in the wings"
	elseif phase == "Hub" then
		return "Party Hub"
	elseif phase == "Minigame" then
		return "Live Minigame"
	elseif phase == "Finale" then
		return "Grand Finale"
	end
	return phase
end

function DirectorPanel.new(sendCommand: SendCommand): Panel
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local previous = playerGui:FindFirstChild(PANEL_NAME)
	if previous then
		previous:Destroy()
	end

	local trove = Trove.new()
	local gui = Instance.new("ScreenGui")
	gui.Name = PANEL_NAME
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = COLORS.background
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = gui

	-- This control intentionally lives beside the backdrop, not inside it, so
	-- the Director can always restore the console after hiding it.
	local consoleToggle = createButton(gui, "Hide Console  ·  F2", COLORS.cardRaised)
	consoleToggle.Name = "ConsoleToggle"
	consoleToggle.AnchorPoint = Vector2.new(1, 1)
	consoleToggle.Position = UDim2.new(1, -18, 1, -14)
	consoleToggle.Size = UDim2.fromOffset(176, 42)
	consoleToggle.TextSize = 13
	consoleToggle.ZIndex = 100

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.background),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 29, 57)),
	})
	gradient.Rotation = 25
	gradient.Parent = backdrop

	local title = createLabel(
		backdrop,
		"BELLA'S BIRTHDAY BASH",
		UDim2.new(1, -300, 0, 34),
		UDim2.fromOffset(28, 18),
		Enum.Font.GothamBlack,
		24,
		COLORS.text
	)
	title.TextWrapped = false
	createLabel(
		backdrop,
		"DIRECTOR CONSOLE  •  Every cue waits for your call",
		UDim2.new(1, -300, 0, 24),
		UDim2.fromOffset(29, 51),
		Enum.Font.GothamMedium,
		13,
		COLORS.muted
	)

	local connectionPill = Instance.new("Frame")
	connectionPill.BackgroundColor3 = Color3.fromRGB(79, 58, 91)
	connectionPill.BorderSizePixel = 0
	connectionPill.AnchorPoint = Vector2.new(1, 0)
	connectionPill.Position = UDim2.new(1, -28, 0, 24)
	connectionPill.Size = UDim2.fromOffset(245, 42)
	connectionPill.Parent = backdrop
	addCorner(connectionPill, 21)

	local connectionDot = Instance.new("Frame")
	connectionDot.BackgroundColor3 = COLORS.warning
	connectionDot.BorderSizePixel = 0
	connectionDot.Position = UDim2.fromOffset(15, 13)
	connectionDot.Size = UDim2.fromOffset(16, 16)
	connectionDot.Parent = connectionPill
	addCorner(connectionDot, 8)

	local connectionLabel = createLabel(
		connectionPill,
		"Waiting for Bella…",
		UDim2.new(1, -48, 1, 0),
		UDim2.fromOffset(42, 0),
		Enum.Font.GothamBold,
		14,
		COLORS.text
	)
	connectionLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local notice = createLabel(
		backdrop,
		"Console ready. Start the hub when Bella is connected.",
		UDim2.new(1, -56, 0, 34),
		UDim2.new(0, 28, 1, -42),
		Enum.Font.GothamMedium,
		14,
		COLORS.muted
	)
	notice.TextXAlignment = Enum.TextXAlignment.Center

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Active = true
	content.AutomaticCanvasSize = Enum.AutomaticSize.None
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.fromOffset(0, 640)
	content.Position = UDim2.fromOffset(28, 88)
	content.ScrollBarImageColor3 = COLORS.outline
	content.ScrollBarThickness = 6
	content.Size = UDim2.new(1, -56, 1, -142)
	content.Parent = backdrop

	local leftColumn = Instance.new("Frame")
	leftColumn.BackgroundTransparency = 1
	leftColumn.Position = UDim2.fromOffset(0, 0)
	leftColumn.Size = UDim2.new(0.56, -10, 0, 625)
	leftColumn.Parent = content

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 16)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftColumn

	local rightColumn = Instance.new("Frame")
	rightColumn.BackgroundTransparency = 1
	rightColumn.Position = UDim2.new(0.56, 10, 0, 0)
	rightColumn.Size = UDim2.new(0.44, -10, 0, 625)
	rightColumn.Parent = content

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 16)
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Parent = rightColumn

	local runCard = createCard(leftColumn, "RunShow", 376)
	createLabel(
		runCard,
		"RUN THE SHOW",
		UDim2.new(1, -36, 0, 28),
		UDim2.fromOffset(18, 15),
		Enum.Font.GothamBlack,
		18,
		COLORS.primary
	)
	createLabel(
		runCard,
		"Launch, switch, or end Bella's current activity.",
		UDim2.new(1, -36, 0, 24),
		UDim2.fromOffset(18, 43),
		Enum.Font.Gotham,
		13,
		COLORS.muted
	)

	local startHubButton = createButton(runCard, "Start Party Hub", COLORS.primary)
	startHubButton.Position = UDim2.fromOffset(18, 81)
	startHubButton.Size = UDim2.new(0.5, -27, 0, 52)
	local endButton = createButton(runCard, "End Current Game", Color3.fromRGB(158, 78, 101))
	endButton.AnchorPoint = Vector2.new(1, 0)
	endButton.Position = UDim2.new(1, -18, 0, 81)
	endButton.Size = UDim2.new(0.5, -27, 0, 52)

	createLabel(
		runCard,
		"MINIGAMES",
		UDim2.new(1, -36, 0, 23),
		UDim2.fromOffset(18, 151),
		Enum.Font.GothamBold,
		13,
		COLORS.muted
	)

	local gameGrid = Instance.new("Frame")
	gameGrid.BackgroundTransparency = 1
	gameGrid.Position = UDim2.fromOffset(18, 181)
	gameGrid.Size = UDim2.new(1, -36, 0, 168)
	gameGrid.Parent = runCard

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.CellSize = UDim2.new(0.5, -5, 0, 74)
	grid.FillDirectionMaxCells = 2
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gameGrid

	local launchButtons: { [string]: TextButton } = {}
	launchButtons.CheeseTower = createButton(gameGrid, "Ratthew's\nCheese Tower", COLORS.accent)
	launchButtons.DogDash =
		createButton(gameGrid, "Gigi & Rambo\nDash", Color3.fromRGB(126, 173, 238))
	launchButtons.SatisfyStation =
		createButton(gameGrid, "ASMR Satisfy\nStation", Color3.fromRGB(177, 123, 214))
	local finaleButton = createButton(gameGrid, "Start Grand\nFinale", Color3.fromRGB(99, 88, 145))

	local difficultyCard = createCard(leftColumn, "Difficulty", 207)
	createLabel(
		difficultyCard,
		"LIVE DIFFICULTY",
		UDim2.new(1, -140, 0, 28),
		UDim2.fromOffset(18, 15),
		Enum.Font.GothamBlack,
		18,
		COLORS.accent
	)
	local difficultyValue = createLabel(
		difficultyCard,
		"50%",
		UDim2.fromOffset(100, 28),
		UDim2.new(1, -118, 0, 15),
		Enum.Font.GothamBlack,
		18,
		COLORS.text
	)
	difficultyValue.TextXAlignment = Enum.TextXAlignment.Right

	local easierLabel = createLabel(
		difficultyCard,
		"EASIER",
		UDim2.fromOffset(70, 22),
		UDim2.fromOffset(66, 71),
		Enum.Font.GothamBold,
		11,
		COLORS.muted
	)
	easierLabel.TextXAlignment = Enum.TextXAlignment.Center
	local harderLabel = createLabel(
		difficultyCard,
		"HARDER",
		UDim2.fromOffset(70, 22),
		UDim2.new(1, -136, 0, 71),
		Enum.Font.GothamBold,
		11,
		COLORS.muted
	)
	harderLabel.TextXAlignment = Enum.TextXAlignment.Center

	local minusButton = createButton(difficultyCard, "−", COLORS.cardRaised)
	minusButton.Position = UDim2.fromOffset(18, 101)
	minusButton.Size = UDim2.fromOffset(46, 46)
	minusButton.TextSize = 24
	local plusButton = createButton(difficultyCard, "+", COLORS.cardRaised)
	plusButton.AnchorPoint = Vector2.new(1, 0)
	plusButton.Position = UDim2.new(1, -18, 0, 101)
	plusButton.Size = UDim2.fromOffset(46, 46)
	plusButton.TextSize = 23

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Active = true
	sliderTrack.BackgroundColor3 = Color3.fromRGB(78, 63, 95)
	sliderTrack.BorderSizePixel = 0
	sliderTrack.Position = UDim2.fromOffset(78, 117)
	sliderTrack.Size = UDim2.new(1, -156, 0, 14)
	sliderTrack.Parent = difficultyCard
	addCorner(sliderTrack, 7)

	local sliderFill = Instance.new("Frame")
	sliderFill.BackgroundColor3 = COLORS.accent
	sliderFill.BorderSizePixel = 0
	sliderFill.Size = UDim2.fromScale(0.5, 1)
	sliderFill.Parent = sliderTrack
	addCorner(sliderFill, 7)

	local sliderKnob = Instance.new("Frame")
	sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	sliderKnob.BackgroundColor3 = COLORS.text
	sliderKnob.BorderSizePixel = 0
	sliderKnob.Position = UDim2.fromScale(0.5, 0.5)
	sliderKnob.Size = UDim2.fromOffset(28, 28)
	sliderKnob.Parent = sliderTrack
	addCorner(sliderKnob, 14)
	addStroke(sliderKnob, COLORS.accent, 3)

	local difficultyHelp = createLabel(
		difficultyCard,
		"Changes are live and server-confirmed. Use −/+ with a controller.",
		UDim2.new(1, -36, 0, 38),
		UDim2.fromOffset(18, 157),
		Enum.Font.Gotham,
		12,
		COLORS.muted
	)
	difficultyHelp.TextYAlignment = Enum.TextYAlignment.Top

	local statusCard = createCard(rightColumn, "LiveStatus", 190)
	createLabel(
		statusCard,
		"LIVE STATUS",
		UDim2.new(1, -36, 0, 28),
		UDim2.fromOffset(18, 15),
		Enum.Font.GothamBlack,
		18,
		COLORS.good
	)
	local phaseLabel = createLabel(
		statusCard,
		"Waiting in the wings",
		UDim2.new(1, -36, 0, 31),
		UDim2.fromOffset(18, 52),
		Enum.Font.GothamBold,
		18,
		COLORS.text
	)
	local gameLabel = createLabel(
		statusCard,
		"No game running",
		UDim2.new(1, -36, 0, 25),
		UDim2.fromOffset(18, 84),
		Enum.Font.Gotham,
		14,
		COLORS.muted
	)
	local scoreLabel = createLabel(
		statusCard,
		"Score  —",
		UDim2.new(1, -36, 0, 31),
		UDim2.fromOffset(18, 118),
		Enum.Font.GothamBlack,
		22,
		COLORS.primary
	)
	local progressLabel = createLabel(
		statusCard,
		"Progress will appear when Bella starts playing.",
		UDim2.new(1, -36, 0, 30),
		UDim2.fromOffset(18, 151),
		Enum.Font.Gotham,
		12,
		COLORS.muted
	)

	local dogsCard = createCard(rightColumn, "Dogs", 175)
	createLabel(
		dogsCard,
		"SUMMON GIGI & RAMBO",
		UDim2.new(1, -36, 0, 28),
		UDim2.fromOffset(18, 15),
		Enum.Font.GothamBlack,
		17,
		COLORS.warning
	)
	createLabel(
		dogsCard,
		"Pick their entrance. A new cue replaces the previous one.",
		UDim2.new(1, -36, 0, 36),
		UDim2.fromOffset(18, 43),
		Enum.Font.Gotham,
		12,
		COLORS.muted
	)

	local dogButtonsFrame = Instance.new("Frame")
	dogButtonsFrame.BackgroundTransparency = 1
	dogButtonsFrame.Position = UDim2.fromOffset(18, 93)
	dogButtonsFrame.Size = UDim2.new(1, -36, 0, 56)
	dogButtonsFrame.Parent = dogsCard
	local dogLayout = Instance.new("UIListLayout")
	dogLayout.FillDirection = Enum.FillDirection.Horizontal
	dogLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dogLayout.Padding = UDim.new(0, 8)
	dogLayout.Parent = dogButtonsFrame
	local dogButtons: { [string]: TextButton } = {
		TrotIn = createButton(dogButtonsFrame, "Trot In", Color3.fromRGB(139, 106, 77)),
		Spin = createButton(dogButtonsFrame, "Spin", Color3.fromRGB(139, 106, 77)),
		Cuddle = createButton(dogButtonsFrame, "Cuddle", Color3.fromRGB(139, 106, 77)),
	}
	for _, button in dogButtons do
		button.Size = UDim2.new(0.333, -6, 0, 50)
	end

	local surpriseCard = createCard(rightColumn, "Surprises", 175)
	createLabel(
		surpriseCard,
		"SURPRISE BELLA",
		UDim2.new(1, -36, 0, 28),
		UDim2.fromOffset(18, 15),
		Enum.Font.GothamBlack,
		17,
		COLORS.accent
	)
	createLabel(
		surpriseCard,
		"Fire a quick celebratory cue during the hub or a game.",
		UDim2.new(1, -36, 0, 36),
		UDim2.fromOffset(18, 43),
		Enum.Font.Gotham,
		12,
		COLORS.muted
	)

	local surpriseButtonsFrame = Instance.new("Frame")
	surpriseButtonsFrame.BackgroundTransparency = 1
	surpriseButtonsFrame.Position = UDim2.fromOffset(18, 91)
	surpriseButtonsFrame.Size = UDim2.new(1, -36, 0, 58)
	surpriseButtonsFrame.Parent = surpriseCard
	local surpriseGrid = Instance.new("UIGridLayout")
	surpriseGrid.CellPadding = UDim2.fromOffset(8, 8)
	surpriseGrid.CellSize = UDim2.new(0.5, -4, 0, 25)
	surpriseGrid.FillDirectionMaxCells = 2
	surpriseGrid.SortOrder = Enum.SortOrder.LayoutOrder
	surpriseGrid.Parent = surpriseButtonsFrame
	local surpriseButtons: { [string]: TextButton } = {
		Confetti = createButton(surpriseButtonsFrame, "Confetti", COLORS.primary),
		Cake = createButton(surpriseButtonsFrame, "Cake", Color3.fromRGB(221, 151, 105)),
		Balloons = createButton(surpriseButtonsFrame, "Balloons", COLORS.accent),
		AsmrBurst = createButton(surpriseButtonsFrame, "ASMR Burst", Color3.fromRGB(177, 123, 214)),
	}
	for _, button in surpriseButtons do
		button.TextSize = 12
	end

	local messageCard = createCard(rightColumn, "Message", 228)
	createLabel(
		messageCard,
		"MESSAGE FOR BELLA",
		UDim2.new(1, -130, 0, 28),
		UDim2.fromOffset(18, 15),
		Enum.Font.GothamBlack,
		17,
		COLORS.primary
	)
	local countLabel = createLabel(
		messageCard,
		`0/{MESSAGE_LIMIT}`,
		UDim2.fromOffset(95, 25),
		UDim2.new(1, -113, 0, 16),
		Enum.Font.GothamMedium,
		12,
		COLORS.muted
	)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right

	local messageBox = Instance.new("TextBox")
	messageBox.BackgroundColor3 = Color3.fromRGB(34, 27, 48)
	messageBox.BorderSizePixel = 0
	messageBox.ClearTextOnFocus = false
	messageBox.Font = Enum.Font.Gotham
	messageBox.MultiLine = true
	messageBox.PlaceholderColor3 = Color3.fromRGB(141, 128, 157)
	messageBox.PlaceholderText = "Type something warm, funny, or delightfully dramatic…"
	messageBox.Position = UDim2.fromOffset(18, 55)
	messageBox.Size = UDim2.new(1, -36, 0, 100)
	messageBox.Text = ""
	messageBox.TextColor3 = COLORS.text
	messageBox.TextSize = 14
	messageBox.TextWrapped = true
	messageBox.TextXAlignment = Enum.TextXAlignment.Left
	messageBox.TextYAlignment = Enum.TextYAlignment.Top
	messageBox.Parent = messageCard
	addCorner(messageBox, 12)
	addStroke(messageBox)
	addPadding(messageBox, 12)

	local sendButton = createButton(messageCard, "Send to Bella", COLORS.primary)
	sendButton.AnchorPoint = Vector2.new(1, 0)
	sendButton.Position = UDim2.new(1, -18, 0, 169)
	sendButton.Size = UDim2.fromOffset(160, 44)

	local currentPhase = "Lobby"
	local currentDifficulty = 0.5
	local confirmedDifficulty = 0.5
	local currentMinigame: string? = nil
	local starConnected = false
	local available: { [string]: boolean } = {}
	local draggingSlider = false
	local lastSliderSend = 0
	local sliderSendGeneration = 0
	local controllerNavigationActive = false
	local consoleVisible = true

	local function showNotice(text: string, isError: boolean?)
		notice.Text = text
		notice.TextColor3 = if isError then COLORS.error else COLORS.muted
	end

	local function focusFirstAvailable(force: boolean?)
		if not backdrop.Visible then
			GuiService.SelectedObject = consoleToggle
			return
		end

		local selected = GuiService.SelectedObject
		if not force and selected and selected.Selectable then
			return
		end

		local focusCandidates: { TextButton } = {
			startHubButton,
			launchButtons.CheeseTower,
			launchButtons.DogDash,
			launchButtons.SatisfyStation,
			finaleButton,
			endButton,
			minusButton,
			plusButton,
		}
		for _, candidate in focusCandidates do
			if candidate.Selectable then
				GuiService.SelectedObject = candidate
				return
			end
		end
	end

	local function setConsoleVisible(visible: boolean)
		consoleVisible = visible
		backdrop.Visible = visible
		consoleToggle.Text = if visible then "Hide Console  ·  F2" else "Open Console  ·  F2"

		if controllerNavigationActive then
			-- This path only runs after genuine gamepad input, so Studio's GUI
			-- selection context is initialized (see the startup-crash guard below).
			task.defer(function()
				if gui.Parent then
					focusFirstAvailable(true)
				end
			end)
		end
	end

	local function toggleConsole()
		setConsoleVisible(not consoleVisible)
	end

	local function refreshControls()
		local livePhase = currentPhase == "Hub" or currentPhase == "Minigame"
		setButtonEnabled(startHubButton, currentPhase == "Lobby")
		setButtonEnabled(endButton, currentPhase == "Minigame")
		setButtonEnabled(finaleButton, currentPhase == "Hub" and starConnected)
		setButtonEnabled(minusButton, currentPhase ~= "Finale")
		setButtonEnabled(plusButton, currentPhase ~= "Finale")

		for id, button in launchButtons do
			local enabled = livePhase
				and starConnected
				and available[id] == true
				and currentMinigame ~= id
			setButtonEnabled(button, enabled)
		end
		for _, button in dogButtons do
			setButtonEnabled(button, livePhase and starConnected)
		end
		for _, button in surpriseButtons do
			setButtonEnabled(button, livePhase and starConnected)
		end
		setButtonEnabled(sendButton, livePhase and starConnected and messageBox.Text ~= "")

		if controllerNavigationActive then
			focusFirstAvailable()
		end
	end

	local function renderDifficultyPreview(level: number)
		currentDifficulty = math.clamp(level, 0, 1)
		difficultyValue.Text = `{math.round(currentDifficulty * 100)}%`
		sliderFill.Size = UDim2.fromScale(currentDifficulty, 1)
		sliderKnob.Position = UDim2.fromScale(currentDifficulty, 0.5)
	end

	local function confirmDifficulty(level: number)
		confirmedDifficulty = math.clamp(level, 0, 1)
		renderDifficultyPreview(confirmedDifficulty)
	end

	local function sendDifficulty(level: number, force: boolean?)
		local clamped = math.clamp(level, 0, 1)
		renderDifficultyPreview(clamped)
		sliderSendGeneration += 1
		local generation = sliderSendGeneration
		local now = os.clock()
		local waitTime = math.max(0, 0.08 - (now - lastSliderSend))
		local function dispatch()
			if generation ~= sliderSendGeneration then
				return
			end
			lastSliderSend = os.clock()
			sendCommand("SetDifficulty", { level = clamped })
		end
		if waitTime == 0 then
			dispatch()
		elseif force then
			task.delay(waitTime, dispatch)
		end
	end

	local function sliderLevelAt(screenX: number): number
		if sliderTrack.AbsoluteSize.X <= 0 then
			return currentDifficulty
		end
		return math.clamp(
			(screenX - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X,
			0,
			1
		)
	end

	trove:Add(UserInputService.LastInputTypeChanged:Connect(function(inputType: Enum.UserInputType)
		controllerNavigationActive = string.sub(inputType.Name, 1, 7) == "Gamepad"
		if controllerNavigationActive then
			-- Studio's selection context is not guaranteed to exist while the
			-- PlayClient is still booting. Only touch SelectedObject after actual
			-- gamepad input, when navigation is initialized.
			task.defer(function()
				if gui.Parent then
					focusFirstAvailable()
				end
			end)
		end
	end))
	trove:Add(consoleToggle.Activated:Connect(toggleConsole))
	trove:Add(UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.F2 or input.KeyCode == Enum.KeyCode.ButtonSelect then
			toggleConsole()
		end
	end))

	trove:Add(startHubButton.Activated:Connect(function()
		sendCommand("StartHub", nil)
	end))
	trove:Add(endButton.Activated:Connect(function()
		sendCommand("EndMinigame", nil)
	end))
	trove:Add(finaleButton.Activated:Connect(function()
		sendCommand("StartFinale", nil)
	end))
	for id, button in launchButtons do
		trove:Add(button.Activated:Connect(function()
			sendCommand("LaunchMinigame", { id = id })
		end))
	end
	for trick, button in dogButtons do
		trove:Add(button.Activated:Connect(function()
			sendCommand("SummonDogs", { trick = trick })
		end))
	end
	for kind, button in surpriseButtons do
		trove:Add(button.Activated:Connect(function()
			sendCommand("Surprise", { kind = kind })
		end))
	end
	trove:Add(minusButton.Activated:Connect(function()
		sendDifficulty(currentDifficulty - 0.05, true)
	end))
	trove:Add(plusButton.Activated:Connect(function()
		sendDifficulty(currentDifficulty + 0.05, true)
	end))
	trove:Add(sliderTrack.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			draggingSlider = true
			sendDifficulty(sliderLevelAt(input.Position.X), true)
		end
	end))
	trove:Add(UserInputService.InputChanged:Connect(function(input: InputObject)
		if not draggingSlider then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			sendDifficulty(sliderLevelAt(input.Position.X), false)
		end
	end))
	trove:Add(UserInputService.InputEnded:Connect(function(input: InputObject)
		if not draggingSlider then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			draggingSlider = false
			sendDifficulty(sliderLevelAt(input.Position.X), true)
		end
	end))

	local function submitMessage()
		if messageBox.Text == "" then
			showNotice("Write a message before sending it.", true)
			return
		end
		sendCommand("SendMessage", { text = messageBox.Text })
		showNotice("Filtering and sending your message…", false)
	end

	trove:Add(sendButton.Activated:Connect(submitMessage))
	trove:Add(messageBox.ReturnPressedFromOnScreenKeyboard:Connect(submitMessage))
	trove:Add(messageBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed and not messageBox.MultiLine then
			submitMessage()
		end
	end))
	trove:Add(messageBox:GetPropertyChangedSignal("Text"):Connect(function()
		local length = utf8.len(messageBox.Text) or #messageBox.Text
		if length > MESSAGE_LIMIT then
			local endByte = utf8.offset(messageBox.Text, MESSAGE_LIMIT + 1)
			if endByte then
				messageBox.Text = string.sub(messageBox.Text, 1, endByte - 1)
				length = MESSAGE_LIMIT
			end
		end
		countLabel.Text = `{length}/{MESSAGE_LIMIT}`
		countLabel.TextColor3 = if length >= MESSAGE_LIMIT then COLORS.warning else COLORS.muted
		refreshControls()
	end))

	local function applyResponsiveLayout()
		local narrow = content.AbsoluteSize.X < 840
		if narrow then
			leftColumn.Position = UDim2.fromOffset(0, 0)
			leftColumn.Size = UDim2.new(1, -8, 0, 615)
			rightColumn.Position = UDim2.fromOffset(0, 631)
			rightColumn.Size = UDim2.new(1, -8, 0, 816)
			content.CanvasSize = UDim2.fromOffset(0, 1463)
		else
			leftColumn.Position = UDim2.fromOffset(0, 0)
			leftColumn.Size = UDim2.new(0.56, -10, 0, 816)
			rightColumn.Position = UDim2.new(0.56, 10, 0, 0)
			rightColumn.Size = UDim2.new(0.44, -10, 0, 816)
			content.CanvasSize = UDim2.fromOffset(0, 832)
		end
	end
	trove:Add(content:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout))
	task.defer(applyResponsiveLayout)

	local function setPhase(phase: string, activeMinigame: string?)
		currentPhase = phase
		currentMinigame = activeMinigame
		phaseLabel.Text = displayPhase(phase)
		gameLabel.Text = displayGameName(activeMinigame)
		if phase ~= "Minigame" then
			scoreLabel.Text = "Score  —"
			progressLabel.Text = "Progress will appear when Bella starts playing."
		end
		refreshControls()
	end

	local function setStarConnection(connected: boolean, name: string?)
		starConnected = connected
		connectionDot.BackgroundColor3 = if connected then COLORS.good else COLORS.warning
		connectionLabel.Text = if connected
			then `{name or Config.starName} is connected`
			else "Waiting for Bella…"
		refreshControls()
	end

	local function setScore(id: string, score: number, data: Payload?)
		currentMinigame = id
		gameLabel.Text = displayGameName(id)
		scoreLabel.Text = `Score  {math.floor(score)}`

		local details = {}
		if data then
			for key, value in data do
				if #details >= 3 then
					break
				end
				table.insert(details, `{key}: {tostring(value)}`)
			end
		end
		progressLabel.Text = if #details > 0
			then table.concat(details, "  •  ")
			else "Live score received"
	end

	local function applyState(payload: Payload)
		local phase = payload.phase
		local activeId = payload.activeMinigame
		if type(phase) == "string" then
			setPhase(phase, if type(activeId) == "string" then activeId else nil)
		end
		if type(payload.difficulty) == "number" then
			confirmDifficulty(payload.difficulty)
		end
		if type(payload.starConnected) == "boolean" then
			setStarConnection(
				payload.starConnected,
				if type(payload.starName) == "string" then payload.starName else nil
			)
		end
		if type(payload.availableMinigames) == "table" then
			table.clear(available)
			for _, id in payload.availableMinigames do
				if type(id) == "string" then
					available[id] = true
				end
			end
		end
		refreshControls()
	end

	local function commandResult(action: string, accepted: boolean, detail: string?)
		if accepted then
			if action == "SendMessage" then
				messageBox.Text = ""
				showNotice(
					if detail == "StudioPreview"
						then "Studio preview delivered. Published messages will use Roblox filtering."
						else "Filtered message delivered to Bella.",
					false
				)
			elseif action == "SummonDogs" then
				showNotice(`Gigi and Rambo are performing: {detail or "cue received"}.`, false)
			elseif action == "LaunchMinigame" then
				showNotice(`Launching {displayGameName(detail)}.`, false)
			elseif action == "StartHub" then
				showNotice("The party hub is live.", false)
			elseif action == "EndMinigame" then
				showNotice("The minigame ended cleanly.", false)
			elseif action == "Surprise" then
				showNotice(`Surprise fired: {detail or "cue received"}.`, false)
			elseif action == "StartFinale" then
				showNotice("The grand finale is underway.", false)
			end
		else
			if action == "SetDifficulty" then
				confirmDifficulty(confirmedDifficulty)
			end
			showNotice(detail or "The server declined that cue.", true)
		end
	end

	confirmDifficulty(currentDifficulty)
	setPhase(currentPhase, currentMinigame)
	setStarConnection(false, nil)
	refreshControls()

	return {
		applyState = applyState,
		setPhase = setPhase,
		setDifficulty = confirmDifficulty,
		setStarConnection = setStarConnection,
		setScore = setScore,
		setNotice = showNotice,
		commandResult = commandResult,
		destroy = function()
			trove:Destroy()
			gui:Destroy()
		end,
	}
end

return DirectorPanel
