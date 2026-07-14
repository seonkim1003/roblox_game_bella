--!strict
-- Bella's ScreenGui: live score, Director messages, soft-action chrome, surprise flashes.
-- Minigames and StarController drive this; the Director never sees it.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local SoundKit = require(script.Parent.Parent.juice.SoundKit)

local StarHud = {}
StarHud.__index = StarHud

export type SoftAction = {
	id: string,
	label: string,
	armed: boolean?,
}

export type SoftActionHandler = (id: string) -> ()

export type ScoreMood = "good" | "miss" | "neutral"

export type StarHudApi = {
	mount: (self: StarHudApi) -> (),
	destroy: (self: StarHudApi) -> (),
	setScore: (self: StarHudApi, score: number, detail: string?, mood: ScoreMood?) -> (),
	setHint: (self: StarHudApi, text: string) -> (),
	showMessage: (self: StarHudApi, text: string) -> (),
	flashSurprise: (self: StarHudApi, kind: string) -> (),
	setGameplayVisible: (self: StarHudApi, visible: boolean) -> (),
	setVisible: (self: StarHudApi, visible: boolean) -> (),
	setSoftActions: (self: StarHudApi, actions: { SoftAction }, onPress: SoftActionHandler?) -> (),
	clearSoftActions: (self: StarHudApi) -> (),
	showSoundCue: (self: StarHudApi, label: string) -> (),
}

local SCORE_BASE = Color3.new(1, 1, 1)
local SCORE_GOOD = Color3.fromRGB(255, 230, 170)
local SCORE_MISS = Color3.fromRGB(200, 210, 230)

local accessibilityModule: any = nil
local accessibilityResolved = false

local function accessibility()
	if accessibilityResolved then
		return accessibilityModule
	end
	accessibilityResolved = true
	local finale = script.Parent.Parent:FindFirstChild("finale")
	local settings = finale and finale:FindFirstChild("AccessibilitySettings")
	if settings and settings:IsA("ModuleScript") then
		local ok, result = pcall(function()
			return (require :: any)(settings)
		end)
		if ok then
			accessibilityModule = result
		end
	end
	return accessibilityModule
end

local function reducedMotion(): boolean
	local settings = accessibility()
	if settings and type(settings.get) == "function" then
		local state = settings.get()
		return type(state) == "table" and state.reducedMotion == true
	end
	return false
end

local function prefersTouchChrome(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function insetPad(): (number, number)
	local inset = GuiService:GetGuiInset()
	local top = math.max(inset.Y, 12) + 8
	-- Extra bottom pad for home-indicator devices when TouchEnabled.
	local bottomExtra = if UserInputService.TouchEnabled then 18 else 8
	local bottom = math.max(inset.Y * 0.15, bottomExtra)
	return top, bottom
end

local function layoutChrome(self: any)
	if not self._gui then
		return
	end
	local top, bottom = insetPad()
	local softVisible = self._softBar ~= nil and self._softBar.Visible

	if self._scoreLabel then
		self._scoreLabel.Position = UDim2.new(0.5, 0, 0, top)
	end
	if self._softBar then
		self._softBar.Position = UDim2.new(0.5, 0, 1, -(bottom + 12))
	end
	if self._hintLabel then
		local hintLift = if softVisible then 70 else 10
		self._hintLabel.Position = UDim2.new(0.5, 0, 1, -(bottom + hintLift))
	end
	if self._banner then
		-- Resting off-screen uses top inset so reduced-motion snaps still clear.
		self._bannerRestY = -(top + 80)
	end
	if self._cueLabel then
		self._cueLabel.Position = UDim2.new(1, -16, 1, -(bottom + 88))
	end
end

function StarHud.new(): StarHudApi
	local self = setmetatable({
		_gui = nil :: ScreenGui?,
		_scoreLabel = nil :: TextLabel?,
		_scoreScale = nil :: UIScale?,
		_hintLabel = nil :: TextLabel?,
		_banner = nil :: TextLabel?,
		_bannerRestY = -120,
		_flash = nil :: Frame?,
		_softBar = nil :: Frame?,
		_cueLabel = nil :: TextLabel?,
		_softHandler = nil :: SoftActionHandler?,
		_softButtons = {} :: { TextButton },
		_scoreToken = 0,
		_cueToken = 0,
		_cueConn = nil :: RBXScriptConnection?,
		_insetConn = nil :: RBXScriptConnection?,
	}, StarHud)
	return (self :: any) :: StarHudApi
end

function StarHud.mount(self: any)
	if self._gui then
		return
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "BashStarHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = playerGui

	local score = Instance.new("TextLabel")
	score.Name = "Score"
	score.BackgroundTransparency = 0.25
	score.BackgroundColor3 = Config.palette.cozy
	score.BorderSizePixel = 0
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.fromScale(0.5, 0.04)
	score.AutomaticSize = Enum.AutomaticSize.X
	score.Size = UDim2.fromOffset(0, if prefersTouchChrome() then 52 else 48)
	score.Font = Enum.Font.GothamBold
	score.TextSize = if prefersTouchChrome() then 26 else 28
	score.TextColor3 = SCORE_BASE
	score.Text = "0"
	score.Visible = false
	score.Parent = gui

	local scorePad = Instance.new("UIPadding")
	scorePad.PaddingLeft = UDim.new(0, 18)
	scorePad.PaddingRight = UDim.new(0, 18)
	scorePad.Parent = score

	local scoreSize = Instance.new("UISizeConstraint")
	scoreSize.MinSize = Vector2.new(160, 44)
	scoreSize.MaxSize = Vector2.new(520, 64)
	scoreSize.Parent = score

	local scoreCorner = Instance.new("UICorner")
	scoreCorner.CornerRadius = UDim.new(0, 12)
	scoreCorner.Parent = score

	local scoreScale = Instance.new("UIScale")
	scoreScale.Scale = 1
	scoreScale.Parent = score

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.fromScale(0.5, 0.94)
	hint.Size = UDim2.fromScale(0.88, 0.05)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = if prefersTouchChrome() then 18 else 20
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.4
	hint.TextWrapped = true
	hint.Text = "Tap / click / Space to drop"
	hint.Visible = false
	hint.Parent = gui

	local softBar = Instance.new("Frame")
	softBar.Name = "SoftActions"
	softBar.BackgroundTransparency = 1
	softBar.AnchorPoint = Vector2.new(0.5, 1)
	softBar.Position = UDim2.fromScale(0.5, 0.88)
	softBar.Size = UDim2.new(0.94, 0, 0, if prefersTouchChrome() then 56 else 48)
	softBar.Visible = false
	softBar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = softBar

	local banner = Instance.new("TextLabel")
	banner.Name = "MessageBanner"
	banner.BackgroundTransparency = 0.15
	banner.BackgroundColor3 = Config.palette.primary
	banner.BorderSizePixel = 0
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.fromScale(0.5, -0.2)
	banner.Size = UDim2.fromScale(0.7, 0.1)
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 26
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.TextWrapped = true
	banner.Text = ""
	banner.Parent = gui

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 14)
	bannerCorner.Parent = banner

	local flash = Instance.new("Frame")
	flash.Name = "SurpriseFlash"
	flash.BackgroundColor3 = Config.palette.accent
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 0
	flash.Parent = gui

	local cue = Instance.new("TextLabel")
	cue.Name = "SoundCue"
	cue.BackgroundTransparency = 0.2
	cue.BackgroundColor3 = Config.palette.primary
	cue.BorderSizePixel = 0
	cue.AnchorPoint = Vector2.new(1, 1)
	cue.Position = UDim2.fromScale(0.98, 0.82)
	cue.AutomaticSize = Enum.AutomaticSize.XY
	cue.Font = Enum.Font.GothamBold
	cue.TextSize = 14
	cue.TextColor3 = Color3.new(1, 1, 1)
	cue.Text = ""
	cue.Visible = false
	cue.ZIndex = 5
	cue.Parent = gui

	local cuePad = Instance.new("UIPadding")
	cuePad.PaddingLeft = UDim.new(0, 10)
	cuePad.PaddingRight = UDim.new(0, 10)
	cuePad.PaddingTop = UDim.new(0, 6)
	cuePad.PaddingBottom = UDim.new(0, 6)
	cuePad.Parent = cue

	local cueCorner = Instance.new("UICorner")
	cueCorner.CornerRadius = UDim.new(0, 10)
	cueCorner.Parent = cue

	self._gui = gui
	self._scoreLabel = score
	self._scoreScale = scoreScale
	self._hintLabel = hint
	self._banner = banner
	self._flash = flash
	self._softBar = softBar
	self._cueLabel = cue

	layoutChrome(self)
	pcall(function()
		self._insetConn = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
			layoutChrome(self)
		end)
	end)

	local settings = accessibility()
	if settings and type(settings.onSoundCue) == "function" then
		self._cueConn = settings.onSoundCue(function(label: string)
			StarHud.showSoundCue(self, label)
		end)
	end
end

local function clearSoftButtons(self: any)
	for _, button in self._softButtons do
		button:Destroy()
	end
	table.clear(self._softButtons)
	if self._softBar then
		self._softBar.Visible = false
	end
	layoutChrome(self)
end

function StarHud.destroy(self: any)
	clearSoftButtons(self)
	if self._cueConn then
		self._cueConn:Disconnect()
		self._cueConn = nil
	end
	if self._insetConn then
		self._insetConn:Disconnect()
		self._insetConn = nil
	end
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self._scoreLabel = nil
	self._scoreScale = nil
	self._hintLabel = nil
	self._banner = nil
	self._flash = nil
	self._softBar = nil
	self._cueLabel = nil
	self._softHandler = nil
end

local function punchScore(self: any, mood: ScoreMood)
	local label = self._scoreLabel
	local scale = self._scoreScale
	if not label or not scale then
		return
	end
	self._scoreToken += 1
	local token = self._scoreToken

	if mood == "good" then
		label.TextColor3 = SCORE_GOOD
	elseif mood == "miss" then
		label.TextColor3 = SCORE_MISS
	else
		label.TextColor3 = SCORE_BASE
	end

	if reducedMotion() or mood == "neutral" then
		task.delay(0.35, function()
			if token == self._scoreToken and label.Parent then
				label.TextColor3 = SCORE_BASE
			end
		end)
		return
	end

	local peak = if mood == "good" then 1.12 else 0.94
	scale.Scale = peak
	TweenService:Create(
		scale,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
	task.delay(0.4, function()
		if token == self._scoreToken and label.Parent then
			label.TextColor3 = SCORE_BASE
		end
	end)
end

function StarHud.setScore(self: any, score: number, detail: string?, mood: ScoreMood?)
	if not self._scoreLabel then
		return
	end
	if detail and detail ~= "" then
		self._scoreLabel.Text = `{math.floor(score)}  ·  {detail}`
	else
		self._scoreLabel.Text = tostring(math.floor(score))
	end
	punchScore(self, mood or "neutral")
end

function StarHud.setHint(self: any, text: string)
	if not self._hintLabel then
		return
	end
	self._hintLabel.Text = text
	self._hintLabel.Visible = text ~= ""
	layoutChrome(self)
end

function StarHud.showMessage(self: any, text: string)
	local banner = self._banner
	if not banner then
		return
	end
	banner.Text = text
	local top = select(1, insetPad())
	local shown = UDim2.new(0.5, 0, 0, top + 8)
	local hidden = UDim2.new(0.5, 0, 0, self._bannerRestY)

	if reducedMotion() then
		banner.Position = shown
		banner.TextTransparency = 0
		banner.BackgroundTransparency = 0.15
		task.delay(3.5, function()
			if banner.Parent then
				banner.Position = hidden
			end
		end)
		return
	end

	banner.Position = hidden
	TweenService:Create(
		banner,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = shown }
	):Play()

	task.delay(3.5, function()
		if banner.Parent then
			TweenService:Create(
				banner,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = hidden }
			):Play()
		end
	end)
end

function StarHud.flashSurprise(self: any, kind: string)
	local flash = self._flash
	if not flash then
		return
	end
	if kind == "Cake" then
		flash.BackgroundColor3 = Color3.fromRGB(255, 190, 220)
	elseif kind == "Balloons" then
		flash.BackgroundColor3 = Config.palette.accent
	elseif kind == "AsmrBurst" then
		flash.BackgroundColor3 = Color3.fromRGB(200, 255, 230)
	else
		flash.BackgroundColor3 = Config.palette.primary
	end

	if reducedMotion() then
		flash.BackgroundTransparency = 0.82
		TweenService
			:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			})
			:Play()
		return
	end

	flash.BackgroundTransparency = 0.55
	TweenService
		:Create(flash, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		:Play()
end

function StarHud.showSoundCue(self: any, label: string)
	local cue = self._cueLabel
	if not cue then
		return
	end
	self._cueToken += 1
	local token = self._cueToken
	cue.Text = string.upper(label)
	cue.Visible = true
	cue.BackgroundTransparency = 0.15
	cue.TextTransparency = 0
	layoutChrome(self)
	task.delay(0.85, function()
		if token ~= self._cueToken or not cue.Parent then
			return
		end
		TweenService:Create(cue, TweenInfo.new(0.2), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
		task.delay(0.22, function()
			if token == self._cueToken and cue.Parent then
				cue.Visible = false
			end
		end)
	end)
end

function StarHud.setGameplayVisible(self: any, visible: boolean)
	if self._scoreLabel then
		self._scoreLabel.Visible = visible
	end
	if self._hintLabel then
		self._hintLabel.Visible = visible and self._hintLabel.Text ~= ""
	end
	if self._softBar then
		self._softBar.Visible = visible and #self._softButtons > 0
	end
	layoutChrome(self)
end

function StarHud.setVisible(self: any, visible: boolean)
	if self._gui then
		self._gui.Enabled = visible
	end
end

function StarHud.clearSoftActions(self: any)
	self._softHandler = nil
	clearSoftButtons(self)
end

function StarHud.setSoftActions(self: any, actions: { SoftAction }, onPress: SoftActionHandler?)
	if not self._softBar then
		return
	end
	clearSoftButtons(self)
	self._softHandler = onPress

	if #actions == 0 then
		return
	end

	local touch = prefersTouchChrome()
	local height = if touch then 52 else 44
	local width = if touch then 118 else 100

	for index, action in actions do
		local armed = action.armed == true
		local button = Instance.new("TextButton")
		button.Name = `Soft_{action.id}`
		button.AutoButtonColor = false
		button.BackgroundColor3 = if armed then Config.palette.accent else Config.palette.cozy
		button.BackgroundTransparency = if armed then 0.05 else 0.12
		button.BorderSizePixel = 0
		button.Size = UDim2.fromOffset(width, height)
		button.Font = Enum.Font.GothamBold
		button.TextSize = if touch then 17 else 16
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Text = action.label
		button.LayoutOrder = index
		button.Parent = self._softBar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Color = if armed then Color3.new(1, 1, 1) else Config.palette.primary
		stroke.Thickness = if armed then 2.2 else 1.5
		stroke.Transparency = if armed then 0.15 else 0.35
		stroke.Parent = button

		local scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = button

		button.Activated:Connect(function()
			if not reducedMotion() then
				scale.Scale = 0.92
				TweenService:Create(
					scale,
					TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
			SoundKit.play("nudge", { volume = 0.1 })
			local handler = self._softHandler
			if handler then
				handler(action.id)
			end
		end)

		table.insert(self._softButtons, button)
	end

	self._softBar.Visible = true
	layoutChrome(self)
end

return StarHud
