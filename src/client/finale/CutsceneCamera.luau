--!strict

-- Client hard-cut camera for real cutscenes (snaps between shots, no long glides).

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type Shot = {
	focusName: string?,
	focus: BasePart?,
	offset: Vector3?,
	lookHeight: number?,
	hold: number?,
	fade: boolean?,
}

local CutsceneCamera = {}

local previousCameraType: Enum.CameraType? = nil
local previousCameraSubject: Instance? = nil
local previousCameraCFrame: CFrame? = nil
local active = false
local generation = 0
local fadeGui: ScreenGui? = nil
local fadeFrame: Frame? = nil

local function ensureFade(): Frame
	if fadeFrame and fadeFrame.Parent then
		return fadeFrame
	end
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "CutsceneFade"
	gui.DisplayOrder = 120
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	fadeGui = gui
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	fadeFrame = frame
	return frame
end

local function hardCut(target: CFrame)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = target
end

local function resolveFocus(folder: Instance?, shot: Shot): BasePart?
	if shot.focus and shot.focus.Parent then
		return shot.focus
	end
	if folder and type(shot.focusName) == "string" then
		local found = folder:FindFirstChild(shot.focusName, true)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	return nil
end

local function composition(focus: BasePart, offset: Vector3, lookHeight: number): CFrame
	local lookAt = focus.Position + Vector3.new(0, lookHeight, 0)
	return CFrame.lookAt(focus.Position + offset, lookAt)
end

function CutsceneCamera.begin()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	if not active then
		previousCameraType = camera.CameraType
		previousCameraSubject = camera.CameraSubject
		previousCameraCFrame = camera.CFrame
	end
	active = true
	generation += 1
	camera.CameraType = Enum.CameraType.Scriptable
end

function CutsceneCamera.cutTo(folder: Instance?, shot: Shot)
	if not active then
		CutsceneCamera.begin()
	end
	local focus = resolveFocus(folder, shot)
	if not focus then
		return
	end
	local offset = shot.offset or Vector3.new(0, 4.5, 14)
	local lookHeight = if shot.lookHeight ~= nil then shot.lookHeight else 2
	local target = composition(focus, offset, lookHeight)

	if shot.fade then
		local token = generation
		local frame = ensureFade()
		local out = TweenService:Create(
			frame,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0 }
		)
		out:Play()
		out.Completed:Once(function()
			if token ~= generation then
				return
			end
			hardCut(target)
			TweenService:Create(
				frame,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }
			):Play()
		end)
	else
		hardCut(target)
	end
end

function CutsceneCamera.playSequence(
	folder: Instance?,
	shots: { Shot },
	tokenCheck: (() -> boolean)?
)
	CutsceneCamera.begin()
	task.spawn(function()
		local token = generation
		for _, shot in shots do
			if token ~= generation then
				return
			end
			if tokenCheck and not tokenCheck() then
				return
			end
			CutsceneCamera.cutTo(folder, shot)
			task.wait(shot.hold or 1.6)
		end
	end)
end

function CutsceneCamera.stop()
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
	if fadeGui then
		fadeGui:Destroy()
		fadeGui = nil
		fadeFrame = nil
	end
	previousCameraType = nil
	previousCameraSubject = nil
	previousCameraCFrame = nil
end

function CutsceneCamera.isActive(): boolean
	return active
end

return CutsceneCamera
