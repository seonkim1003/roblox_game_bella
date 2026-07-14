--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VisualConfig = require(ReplicatedStorage:WaitForChild("Shared").VisualConfig)
local DirectorDashboardModel = require(script.Parent.DirectorDashboardModel)

type Payload = { [string]: any }
type Send = (string, Payload?) -> ()

export type Widget = {
	setTelemetry: (enabled: boolean) -> (),
}

local StudioDashboard = {}
local P = VisualConfig.palette
local GAMES = { "CheeseTower", "DogDash", "SatisfyStation" }
local LABELS: { [string]: string } = {
	CheeseTower = "CHEESE",
	DogDash = "DASH",
	SatisfyStation = "ASMR",
}

local function corner(parent: Instance, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

function StudioDashboard.new(parent: Instance, send: Send): Widget?
	if not RunService:IsStudio() then
		return nil
	end

	local root = Instance.new("Frame")
	root.Name = "StudioRoundLab"
	root.BackgroundColor3 = P.night
	root.BorderSizePixel = 0
	root.Size = UDim2.new(1, 0, 0, 144)
	root.Parent = parent
	corner(root, 14)

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.Position = UDim2.fromOffset(12, 7)
	heading.Size = UDim2.new(0.5, -12, 0, 20)
	heading.Text = "STUDIO ROUND LAB"
	heading.TextColor3 = P.linen
	heading.TextSize = 11
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = root

	local telemetry = Instance.new("TextButton")
	telemetry.AnchorPoint = Vector2.new(1, 0)
	telemetry.AutoButtonColor = true
	telemetry.BackgroundColor3 = P.plum
	telemetry.BorderSizePixel = 0
	telemetry.Font = Enum.Font.GothamBold
	telemetry.Position = UDim2.new(1, -12, 0, 5)
	telemetry.Selectable = true
	telemetry.Size = UDim2.fromOffset(146, 24)
	telemetry.TextColor3 = P.cream
	telemetry.TextSize = 10
	telemetry.Parent = root
	corner(telemetry, 8)

	local gameRow = Instance.new("Frame")
	gameRow.BackgroundTransparency = 1
	gameRow.Position = UDim2.fromOffset(12, 36)
	gameRow.Size = UDim2.new(1, -24, 0, 38)
	gameRow.Parent = root
	local gameLayout = Instance.new("UIListLayout")
	gameLayout.FillDirection = Enum.FillDirection.Horizontal
	gameLayout.Padding = UDim.new(0, 8)
	gameLayout.Parent = gameRow

	local selectedGame = GAMES[1]
	local telemetryEnabled = false
	local gameButtons: { [string]: TextButton } = {}
	local function renderGames()
		for gameId, button in gameButtons do
			local selected = gameId == selectedGame
			button.BackgroundColor3 = if selected then P.sky else P.plum
			button.TextColor3 = if selected then P.ink else P.cream
		end
	end
	local function renderTelemetry()
		telemetry.Text = if telemetryEnabled then "FAKE TELEMETRY ON" else "FAKE TELEMETRY OFF"
		telemetry.BackgroundColor3 = if telemetryEnabled then P.mint else P.plum
		telemetry.TextColor3 = if telemetryEnabled then P.ink else P.cream
	end

	for _, gameId in GAMES do
		local button = Instance.new("TextButton")
		button.Name = `Debug{gameId}`
		button.AutoButtonColor = true
		button.BackgroundColor3 = P.plum
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.Selectable = true
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		button.Text = LABELS[gameId]
		button.TextColor3 = P.cream
		button.TextSize = 11
		button.Parent = gameRow
		corner(button, 10)
		gameButtons[gameId] = button
		button.Activated:Connect(function()
			selectedGame = gameId
			renderGames()
		end)
	end

	local launchRow = Instance.new("Frame")
	launchRow.BackgroundTransparency = 1
	launchRow.Position = UDim2.fromOffset(12, 84)
	launchRow.Size = UDim2.new(1, -24, 0, 46)
	launchRow.Parent = root
	local launchLayout = Instance.new("UIListLayout")
	launchLayout.FillDirection = Enum.FillDirection.Horizontal
	launchLayout.Padding = UDim.new(0, 8)
	launchLayout.Parent = launchRow

	local seed = Instance.new("TextBox")
	seed.BackgroundColor3 = P.plum
	seed.BorderSizePixel = 0
	seed.ClearTextOnFocus = false
	seed.Font = Enum.Font.GothamMedium
	seed.PlaceholderText = "SEED"
	seed.PlaceholderColor3 = P.linen
	seed.Selectable = true
	seed.Size = UDim2.new(0.36, -4, 1, 0)
	seed.Text = "1"
	seed.TextColor3 = P.cream
	seed.TextSize = 12
	seed.Parent = launchRow
	corner(seed, 10)

	local launch = Instance.new("TextButton")
	launch.AutoButtonColor = true
	launch.BackgroundColor3 = P.blush
	launch.BorderSizePixel = 0
	launch.Font = Enum.Font.GothamBold
	launch.Selectable = true
	launch.Size = UDim2.new(0.64, -4, 1, 0)
	launch.Text = "LAUNCH SEEDED ROUND"
	launch.TextColor3 = P.ink
	launch.TextSize = 11
	launch.Parent = launchRow
	corner(launch, 10)

	telemetry.Activated:Connect(function()
		send("SetDebugTelemetry", { enabled = not telemetryEnabled })
	end)
	launch.Activated:Connect(function()
		local value = DirectorDashboardModel.debugSeed(seed.Text)
		if not value then
			seed.Text = "1"
			value = 1
		end
		send("DebugLaunch", {
			gameId = selectedGame,
			seed = value,
			fakeTelemetry = telemetryEnabled,
		})
	end)

	renderGames()
	renderTelemetry()
	return {
		setTelemetry = function(enabled: boolean)
			telemetryEnabled = enabled
			renderTelemetry()
		end,
	}
end

return StudioDashboard
