--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local VisualConfig = require(Shared.VisualConfig)

local palette = VisualConfig.palette

local RoleChoiceScreen = {}

local gui: ScreenGui? = nil
local statusLabel: TextLabel? = nil
local buttons: { TextButton } = {}
local waitingForServer = false

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0.15
	stroke.Parent = parent
end

local function setButtonsEnabled(enabled: boolean)
	for _, button in buttons do
		button.Active = enabled
		button.AutoButtonColor = enabled
		button.BackgroundTransparency = if enabled then 0 else 0.35
	end
end

local function choose(role: Types.Role)
	if waitingForServer then
		return
	end

	waitingForServer = true
	setButtonsEnabled(false)
	if statusLabel then
		statusLabel.Text = "Joining..."
		statusLabel.TextColor3 = palette.cream
	end
	Net.get(Net.RoleSelection):FireServer({ role = role })
end

local function makeButton(
	parent: Instance,
	text: string,
	color: Color3,
	role: Types.Role,
	layoutOrder: number
)
	local button = Instance.new("TextButton")
	button.Name = text .. "Button"
	button.Size = UDim2.new(1, 0, 0, 64)
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = palette.ink
	button.TextScaled = true
	button.AutoButtonColor = true
	button.Selectable = true
	button.LayoutOrder = layoutOrder
	button.Parent = parent
	addCorner(button, 16)
	addStroke(button, palette.cream, 2)

	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MaxTextSize = 30
	textSizeConstraint.MinTextSize = 18
	textSizeConstraint.Parent = button

	button.Activated:Connect(function()
		choose(role)
	end)
	table.insert(buttons, button)
end

function RoleChoiceScreen.show()
	if gui then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RoleChoiceScreen"
	screenGui.DisplayOrder = 1000
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = palette.plumDeep
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "ChoicePanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.86, 0, 0, 310)
	panel.BackgroundColor3 = palette.plum
	panel.BorderSizePixel = 0
	panel.Parent = backdrop
	addCorner(panel, 24)
	addStroke(panel, palette.blush, 3)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(460, 310)
	sizeConstraint.MinSize = Vector2.new(280, 310)
	sizeConstraint.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 24)
	padding.PaddingBottom = UDim.new(0, 20)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 58)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "Who are you?"
	title.TextColor3 = palette.cream
	title.TextScaled = true
	title.LayoutOrder = 1
	title.Parent = panel

	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MaxTextSize = 36
	titleConstraint.MinTextSize = 22
	titleConstraint.Parent = title

	makeButton(panel, "Host", palette.sky, "Director", 2)
	makeButton(panel, "Bella", palette.blush, "Star", 3)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, 0, 0, 34)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.Text = "Choose how you want to join"
	status.TextColor3 = palette.linen
	status.TextSize = 16
	status.TextWrapped = true
	status.LayoutOrder = 4
	status.Parent = panel

	gui = screenGui
	statusLabel = status
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function RoleChoiceScreen.showError(message: string)
	waitingForServer = false
	setButtonsEnabled(true)
	if statusLabel then
		statusLabel.Text = message
		statusLabel.TextColor3 = palette.butter
	end
end

function RoleChoiceScreen.hide()
	if GuiService.SelectedObject and gui and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	if gui then
		gui:Destroy()
	end
	gui = nil
	statusLabel = nil
	buttons = {}
	waitingForServer = false
	local finaleFolder = script.Parent:FindFirstChild("finale")
	local presentationModule = if finaleFolder
		then finaleFolder:FindFirstChild("ShowPresentation")
		else nil
	if presentationModule and presentationModule:IsA("ModuleScript") then
		local success, presentation = pcall(function()
			return (require :: any)(presentationModule)
		end)
		if success and type(presentation) == "table" and type(presentation.start) == "function" then
			presentation.start()
		end
	end
end

return RoleChoiceScreen
