--!strict

-- Star-only finale presentation. StarController loads and starts this module;
-- it listens to the existing show event boundary without adding a new remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Feedback = require(script.Parent.Parent.juice.Feedback)
local SoundKit = require(script.Parent.Parent.juice.SoundKit)

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
local previousCameraType: Enum.CameraType? = nil
local previousCameraSubject: Instance? = nil
local previousCameraCFrame: CFrame? = nil

local function tween(object: Instance, duration: number, properties: { [string]: any })
	local value = TweenService:Create(
		object,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		properties
	)
	value:Play()
	return value
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
	backdrop.BackgroundColor3 = Color3.fromRGB(11, 14, 24)
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

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamMedium
	title.Position = UDim2.fromScale(0.5, 0.1)
	title.Size = UDim2.new(0.85, 0, 0, 44)
	title.Text = "ONE LAST SURPRISE"
	title.TextColor3 = Color3.fromRGB(211, 196, 229)
	title.TextScaled = true
	title.TextTransparency = 1
	title.Parent = backdrop
	titleLabel = title

	local message = Instance.new("TextLabel")
	message.AnchorPoint = Vector2.new(0.5, 1)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamBold
	message.Position = UDim2.fromScale(0.5, 0.89)
	message.Size = UDim2.fromScale(0.86, 0.22)
	message.Text = ""
	message.TextColor3 = Color3.fromRGB(255, 235, 246)
	message.TextScaled = true
	message.TextTransparency = 1
	message.TextWrapped = true
	message.Parent = backdrop
	messageLabel = message
end

local function focusCamera(token: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	previousCameraType = camera.CameraType
	previousCameraSubject = camera.CameraSubject
	previousCameraCFrame = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable

	task.spawn(function()
		local finaleFolder = Workspace:WaitForChild("BirthdayFinale", 5)
		if token ~= generation or not finaleFolder then
			return
		end
		local focus = finaleFolder:FindFirstChild("FinaleFocus")
		if not focus or not focus:IsA("BasePart") then
			return
		end
		local target = CFrame.lookAt(
			focus.Position + Vector3.new(0, 4.5, 15),
			focus.Position + Vector3.new(0, 2, 0)
		)
		tween(camera, 2.8, { CFrame = target })
	end)
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

local function begin(lines: { string })
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
	if not screen or not backdrop or not title or not message then
		return
	end

	screen.Enabled = true
	backdrop.BackgroundTransparency = 1
	title.TextTransparency = 1
	message.TextTransparency = 1
	tween(backdrop, 2.2, { BackgroundTransparency = 0.42 })
	tween(title, 1.5, { TextTransparency = 0.15 })
	SoundKit.play("softChime", nil)
	focusCamera(token)

	task.spawn(function()
		task.wait(2.4)
		for _, line in lines do
			if token ~= generation then
				return
			end
			message.Text = line
			message.TextTransparency = 1
			tween(message, 0.65, { TextTransparency = 0 })
			SoundKit.play("softChime", nil)
			task.wait(2.5)
			tween(message, 0.5, { TextTransparency = 1 })
			task.wait(0.55)
		end
		if token ~= generation then
			return
		end
		message.Text = `Happy Birthday, {Config.starName}.`
		message.TextTransparency = 1
		tween(message, 1.1, { TextTransparency = 0 })
		Feedback.confetti({ gentle = true })
		SoundKit.play("cheer", nil)
	end)
end

function FinalePresenter.start(_self: any, payload: Payload)
	begin(validLines(payload.messageLines))
end

function FinalePresenter.beat(_self: any, beat: string, _payload: Payload?)
	if not active then
		return
	end
	if beat == "BroodingGuest" then
		SoundKit.play("softChime", nil)
	elseif beat == "HappyBirthday" then
		Feedback.confetti({ gentle = true })
		SoundKit.play("cheer", nil)
	end
end

function FinalePresenter.stop(_self: any)
	generation += 1
	active = false
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = previousCameraType or Enum.CameraType.Custom
		if previousCameraSubject then
			camera.CameraSubject = previousCameraSubject
		end
		if previousCameraCFrame then
			camera.CFrame = previousCameraCFrame
		end
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end

return FinalePresenter
