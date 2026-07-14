--!strict

-- Star-only finale presentation: hard-cut camera shots + message cards.
-- Character motion/animation are server-authored; this module only frames them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local VisualConfig = require(Shared.VisualConfig)

local Feedback = require(script.Parent.Parent.juice.Feedback)
local SoundKit = require(script.Parent.Parent.juice.SoundKit)
local AccessibilitySettings = require(script.Parent.AccessibilitySettings)
local CutsceneCamera = require(script.Parent.CutsceneCamera)

type Payload = { [string]: any }

local FinalePresenter = {
	id = "Finale",
}

local active = false
local generation = 0
local gui: ScreenGui? = nil
local titleLabel: TextLabel? = nil
local messageLabel: TextLabel? = nil
local shade: Frame? = nil
local messageCard: Frame? = nil
local finaleFolder: Folder? = nil

local function tween(object: Instance, duration: number, properties: { [string]: any })
	if AccessibilitySettings.get().reducedMotion then
		for property, value in properties do
			(object :: any)[property] = value
		end
		return nil
	end
	local value = TweenService:Create(
		object,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		properties
	)
	value:Play()
	return value
end

local function playSound(name: string, visualLabel: string)
	if AccessibilitySettings.get().mutedAudio then
		AccessibilitySettings.emitSoundCue(visualLabel)
	else
		SoundKit.play(name, nil)
	end
end

local function gentleConfetti()
	if not AccessibilitySettings.get().reducedMotion then
		Feedback.confetti({ gentle = true })
	end
end

local function performanceConfetti(summary: Payload?)
	if AccessibilitySettings.get().reducedMotion then
		return
	end
	local treatment = if summary then summary.confettiTreatment else nil
	Feedback.confetti({
		gentle = treatment ~= "StarlightCascade",
		amount = if treatment == "StarlightCascade"
			then 56
			elseif treatment == "RibbonDrift" then 34
			else 20,
	})
end

local function mount()
	if gui and gui.Parent then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "BirthdayFinaleGui"
	screen.DisplayOrder = 90
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = playerGui
	gui = screen

	local backdrop = Instance.new("Frame")
	backdrop.Name = "CinematicShade"
	backdrop.BackgroundColor3 = VisualConfig.palette.night
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = screen
	shade = backdrop

	local vignette = Instance.new("UIGradient")
	vignette.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 29, 47)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(55, 42, 70)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 18, 30)),
	})
	vignette.Rotation = 90
	vignette.Parent = backdrop

	for _, position in { UDim2.fromScale(0.5, 0), UDim2.fromScale(0.5, 1) } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, if position.Y.Scale == 0 then 0 else 1)
		bar.BackgroundColor3 = Color3.fromRGB(10, 12, 19)
		bar.BorderSizePixel = 0
		bar.Position = position
		bar.Size = UDim2.fromScale(1, 0.07)
		bar.Parent = backdrop
	end

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamMedium
	title.Position = UDim2.fromScale(0.5, 0.1)
	title.Size = UDim2.new(0.85, 0, 0, 44)
	title.Text = "ONE LAST SURPRISE"
	title.TextColor3 = VisualConfig.palette.linen
	title.TextScaled = true
	title.TextTransparency = 1
	title.Parent = backdrop
	titleLabel = title

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.BackgroundColor3 = VisualConfig.palette.plumDeep
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.Position = UDim2.fromScale(0.5, 0.9)
	card.Size = UDim2.fromScale(0.82, 0.2)
	card.Parent = backdrop
	messageCard = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = VisualConfig.palette.butter
	stroke.Thickness = 1.5
	stroke.Transparency = 0.45
	stroke.Parent = card
	local accent = Instance.new("Frame")
	accent.AnchorPoint = Vector2.new(0.5, 0)
	accent.BackgroundColor3 = VisualConfig.palette.blush
	accent.BorderSizePixel = 0
	accent.Position = UDim2.fromScale(0.5, 0)
	accent.Size = UDim2.new(0.22, 0, 0, 4)
	accent.Parent = card
	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(1, 0)
	accentCorner.Parent = accent

	local message = Instance.new("TextLabel")
	message.AnchorPoint = Vector2.new(0.5, 1)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamBold
	message.Position = UDim2.fromScale(0.5, 0.92)
	message.Size = UDim2.fromScale(0.9, 0.82)
	message.Text = ""
	message.TextColor3 = VisualConfig.palette.cream
	message.TextScaled = true
	message.TextTransparency = 1
	message.TextWrapped = true
	message.Parent = card
	messageLabel = message
end

local function waitForFinaleFolder(token: number): Folder?
	local folder = Workspace:WaitForChild("BirthdayFinale", 5)
	if token ~= generation or not folder or not folder:IsA("Folder") then
		return nil
	end
	finaleFolder = folder
	return folder
end

local function cut(shotFocus: string, offset: Vector3, lookHeight: number?, fade: boolean?)
	if AccessibilitySettings.get().reducedMotion then
		-- Still snap for framing; skip the fade wipe when motion is reduced.
		fade = false
	end
	local folder = finaleFolder or Workspace:FindFirstChild("BirthdayFinale")
	if not folder or not folder:IsA("Folder") then
		return
	end
	CutsceneCamera.cutTo(folder, {
		focusName = shotFocus,
		offset = offset,
		lookHeight = lookHeight,
		fade = fade == true,
	})
end

local function validLines(raw: any): { string }
	local lines = {}
	if type(raw) == "table" then
		for _, value in raw do
			if type(value) == "string" and value ~= "" and #lines < 8 then
				table.insert(lines, value)
			end
		end
	end
	if #lines == 0 then
		for _, value in Config.finaleMessage do
			table.insert(lines, value)
		end
	end
	return lines
end

local function begin(lines: { string }, summary: Payload?)
	if active then
		return
	end
	active = true
	generation += 1
	local token = generation
	mount()

	local screen = gui
	local backdrop = shade
	local title = titleLabel
	local message = messageLabel
	local card = messageCard
	if not screen or not backdrop or not title or not message or not card then
		return
	end

	screen.Enabled = true
	if summary and type(summary.title) == "string" then
		title.Text = string.upper(summary.title)
	else
		title.Text = "ONE LAST SURPRISE"
	end
	backdrop.BackgroundTransparency = 1
	title.TextTransparency = 1
	message.TextTransparency = 1
	card.BackgroundTransparency = 1
	tween(backdrop, 1.1, { BackgroundTransparency = 0.55 })
	tween(title, 0.7, { TextTransparency = 0.15 })
	tween(card, 0.9, { BackgroundTransparency = 0.2 })
	playSound("softChime", "Soft chime")

	CutsceneCamera.begin()
	task.spawn(function()
		local folder = waitForFinaleFolder(token)
		if not folder or token ~= generation then
			return
		end
		-- Establishing hard cut — no multi-second camera glide.
		cut("ShotWide", Vector3.new(0, 5.2, 16), 2.2, false)
	end)

	task.spawn(function()
		task.wait(2.2)
		for _, line in lines do
			if token ~= generation then
				return
			end
			message.Text = line
			message.TextTransparency = 1
			tween(message, 0.45, { TextTransparency = 0 })
			playSound("softChime", "Message chime")
			task.wait(2.4)
			tween(message, 0.35, { TextTransparency = 1 })
			task.wait(0.4)
		end
		if token ~= generation then
			return
		end
		if summary and type(summary.ratthewCallback) == "string" then
			message.Text = summary.ratthewCallback
			message.TextTransparency = 1
			tween(message, 0.65, { TextTransparency = 0 })
			playSound("softChime", "Ratthew chime")
			task.wait(2.5)
			tween(message, 0.5, { TextTransparency = 1 })
			task.wait(0.55)
		end
		message.Text = `Happy Birthday, {Config.starName}.`
		message.TextTransparency = 1
		tween(message, 0.8, { TextTransparency = 0 })
		performanceConfetti(summary)
		playSound("cheer", "Birthday cheer")
	end)
end

function FinalePresenter.start(_self: any, payload: Payload)
	local summary = if type(payload.summary) == "table" then payload.summary else nil
	begin(validLines(payload.messageLines), summary)
end

function FinalePresenter.beat(_self: any, beat: string, _payload: Payload?)
	if not active then
		return
	end
	if beat == "Establishing" then
		cut("ShotWide", Vector3.new(0, 5.2, 16), 2.2, false)
	elseif beat == "LightsDimmed" then
		cut("ShotWide", Vector3.new(3.5, 4.2, 13), 2, true)
		playSound("softChime", "Lights dim chime")
	elseif beat == "DogsResting" then
		cut("ShotDogs", Vector3.new(-2.5, 2.4, 7.5), 0.8, true)
	elseif beat == "Message" then
		cut("ShotWide", Vector3.new(-1.5, 4.8, 14), 2.2, false)
	elseif beat == "BroodingGuest" then
		cut("ShotGuest", Vector3.new(-5.5, 3.2, 7), 1.4, true)
		playSound("softChime", "Guest reveal chime")
	elseif beat == "GuestWave" then
		cut("ShotGuest", Vector3.new(-3.2, 2.6, 5.5), 1.5, true)
	elseif beat == "HappyBirthday" then
		cut("ShotBirthday", Vector3.new(0, 4.8, 13), 2.4, true)
		gentleConfetti()
		playSound("cheer", "Birthday cheer")
	end
end

function FinalePresenter.stop(_self: any)
	generation += 1
	active = false
	finaleFolder = nil
	CutsceneCamera.stop()
	if gui then
		gui:Destroy()
		gui = nil
		messageCard = nil
		shade = nil
		titleLabel = nil
		messageLabel = nil
	end
end

return FinalePresenter
