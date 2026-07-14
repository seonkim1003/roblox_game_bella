--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualConfig = require(ReplicatedStorage:WaitForChild("Shared").VisualConfig)
local AccessibilityModel = require(script.Parent.AccessibilityModel)
local AccessibilitySettings = require(script.Parent.AccessibilitySettings)

local AccessibilityControls = {}
local P = VisualConfig.palette
local started = false
local cueToken = 0

local function corner(parent: Instance, radius: number)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius)
	value.Parent = parent
end

function AccessibilityControls.start()
	if started then
		return
	end
	started = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local old = playerGui:FindFirstChild("PremiereAccessibility")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PremiereAccessibility"
	gui.DisplayOrder = 110
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(1, 0)
	root.BackgroundColor3 = P.night
	root.BackgroundTransparency = 0.08
	root.BorderSizePixel = 0
	root.Position = UDim2.new(1, -12, 0, 12)
	root.Size = UDim2.fromOffset(276, 70)
	root.Parent = gui
	corner(root, 14)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(8, 8)
	row.Size = UDim2.new(1, -16, 0, 36)
	row.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local function control(name: string): TextButton
		local result = Instance.new("TextButton")
		result.Name = name
		result.AutoButtonColor = true
		result.BackgroundColor3 = P.plum
		result.BorderSizePixel = 0
		result.Font = Enum.Font.GothamBold
		result.Selectable = true
		result.Size = UDim2.new(0.5, -4, 1, 0)
		result.TextColor3 = P.cream
		result.TextSize = 11
		result.Parent = row
		corner(result, 10)
		return result
	end

	local audio = control("AudioToggle")
	local motion = control("MotionToggle")
	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.Position = UDim2.fromOffset(8, 47)
	status.Size = UDim2.new(1, -16, 0, 16)
	status.Text = "ACCESSIBILITY CONTROLS"
	status.TextColor3 = P.linen
	status.TextSize = 9
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.Parent = root

	local function render(state: AccessibilityModel.State)
		audio.Text = AccessibilityModel.audioLabel(state)
		audio.BackgroundColor3 = if state.mutedAudio then P.butter else P.plum
		audio.TextColor3 = if state.mutedAudio then P.ink else P.cream
		motion.Text = AccessibilityModel.motionLabel(state)
		motion.BackgroundColor3 = if state.reducedMotion then P.mint else P.plum
		motion.TextColor3 = if state.reducedMotion then P.ink else P.cream
		if state.mutedAudio then
			status.Text = "VISUAL SOUND CUES ON"
		else
			status.Text = "ACCESSIBILITY CONTROLS"
		end
	end

	audio.Activated:Connect(function()
		local state = AccessibilitySettings.get()
		AccessibilitySettings.setMutedAudio(not state.mutedAudio)
	end)
	motion.Activated:Connect(function()
		local state = AccessibilitySettings.get()
		AccessibilitySettings.setReducedMotion(not state.reducedMotion)
	end)
	AccessibilitySettings.onChanged(render)
	AccessibilitySettings.onSoundCue(function(label: string)
		cueToken += 1
		local token = cueToken
		status.Text = string.upper(label)
		status.TextColor3 = P.butter
		task.delay(1.5, function()
			if cueToken == token then
				status.TextColor3 = P.linen
				render(AccessibilitySettings.get())
			end
		end)
	end)
	render(AccessibilitySettings.get())
end

return AccessibilityControls
