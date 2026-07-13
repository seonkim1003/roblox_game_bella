--!strict
-- Bella's ScreenGui: live score, Director messages, light surprise flashes.
-- Minigames and StarController drive this; the Director never sees it.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local StarHud = {}
StarHud.__index = StarHud

export type StarHudApi = {
	mount: (self: StarHudApi) -> (),
	destroy: (self: StarHudApi) -> (),
	setScore: (self: StarHudApi, score: number, detail: string?) -> (),
	setHint: (self: StarHudApi, text: string) -> (),
	showMessage: (self: StarHudApi, text: string) -> (),
	flashSurprise: (self: StarHudApi, kind: string) -> (),
	setGameplayVisible: (self: StarHudApi, visible: boolean) -> (),
	setVisible: (self: StarHudApi, visible: boolean) -> (),
}

function StarHud.new(): StarHudApi
	local self = setmetatable({
		_gui = nil :: ScreenGui?,
		_scoreLabel = nil :: TextLabel?,
		_hintLabel = nil :: TextLabel?,
		_banner = nil :: TextLabel?,
		_flash = nil :: Frame?,
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
	score.Size = UDim2.fromOffset(220, 48)
	score.Font = Enum.Font.GothamBold
	score.TextSize = 28
	score.TextColor3 = Color3.new(1, 1, 1)
	score.Text = "0"
	score.Visible = false
	score.Parent = gui

	local scoreCorner = Instance.new("UICorner")
	scoreCorner.CornerRadius = UDim.new(0, 12)
	scoreCorner.Parent = score

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.fromScale(0.5, 0.94)
	hint.Size = UDim2.fromScale(0.8, 0.06)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 22
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.4
	hint.Text = "Tap / click / Space to drop"
	hint.Visible = false
	hint.Parent = gui

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

	self._gui = gui
	self._scoreLabel = score
	self._hintLabel = hint
	self._banner = banner
	self._flash = flash
end

function StarHud.destroy(self: any)
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
	self._scoreLabel = nil
	self._hintLabel = nil
	self._banner = nil
	self._flash = nil
end

function StarHud.setScore(self: any, score: number, detail: string?)
	if not self._scoreLabel then
		return
	end
	if detail and detail ~= "" then
		self._scoreLabel.Text = `{math.floor(score)}  ·  {detail}`
	else
		self._scoreLabel.Text = tostring(math.floor(score))
	end
end

function StarHud.setHint(self: any, text: string)
	if not self._hintLabel then
		return
	end
	self._hintLabel.Text = text
	self._hintLabel.Visible = text ~= ""
end

function StarHud.showMessage(self: any, text: string)
	local banner = self._banner
	if not banner then
		return
	end
	banner.Text = text
	banner.Position = UDim2.fromScale(0.5, -0.2)
	TweenService:Create(
		banner,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.12) }
	):Play()

	task.delay(3.5, function()
		if banner.Parent then
			TweenService:Create(
				banner,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromScale(0.5, -0.2) }
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

	flash.BackgroundTransparency = 0.55
	TweenService
		:Create(flash, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		:Play()
end

function StarHud.setGameplayVisible(self: any, visible: boolean)
	if self._scoreLabel then
		self._scoreLabel.Visible = visible
	end
	if self._hintLabel then
		self._hintLabel.Visible = visible and self._hintLabel.Text ~= ""
	end
end

function StarHud.setVisible(self: any, visible: boolean)
	if self._gui then
		self._gui.Enabled = visible
	end
end

return StarHud
