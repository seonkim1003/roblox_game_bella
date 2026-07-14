--!strict
-- Juice library: particles, confetti, squish, camera kicks.
-- Consumed by Star minigames and (via the frozen FeedbackApi) by Agent B's finale.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Config = require(Shared.Config)
local VisualConfig = require(Shared.VisualConfig)

local Squish = require(script.Parent.Squish)

local cameraKickToken = 0
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

local function attachEmitter(part: BasePart, color: Color3, rate: number, lifetime: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(lifetime * 0.5, lifetime)
	emitter.Speed = NumberRange.new(2, 6)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = attachment
	return emitter
end

local Feedback: Types.FeedbackApi = {
	pop = function(position: Vector3, options: { [string]: any }?)
		local color = Config.palette.accent
		if options and typeof(options.color) == "Color3" then
			color = options.color
		end
		local count = if options and type(options.count) == "number" then options.count else 14
		if reducedMotion() then
			count = math.min(count, 6)
		end

		local anchor = Instance.new("Part")
		anchor.Name = "BashPop"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = position
		anchor.Parent = Workspace

		local emitter = attachEmitter(anchor, color, 0, 0.45)
		emitter:Emit(count)
		Debris:AddItem(anchor, 1.2)
	end,

	confetti = function(options: { [string]: any }?)
		local origin = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.Position
			or Vector3.new(0, 12, 0)
		if options and typeof(options.position) == "Vector3" then
			origin = options.position
		end
		-- gentle = the finale's softer fall: fewer flakes, slower and calmer drift.
		local gentle = options ~= nil and options.gentle == true
		local defaultAmount = if gentle then 24 else 40
		local amount = if options and type(options.amount) == "number"
			then options.amount
			else defaultAmount
		if reducedMotion() then
			amount = math.min(amount, 10)
		end

		-- Pull from the shared palette so confetti matches the UI and 3D set.
		local palette = VisualConfig.palette
		local colors = {
			palette.blush,
			palette.sky,
			palette.butter,
			palette.mint,
		}

		local driftScale = if gentle then 0.55 else 1
		local fallTime = if gentle then 2.4 else 1.6

		for i = 1, amount do
			local flake = Instance.new("Part")
			flake.Name = "BashConfetti"
			flake.Anchored = true
			flake.CanCollide = false
			flake.Material = Enum.Material.SmoothPlastic
			flake.Color = colors[((i - 1) % #colors) + 1]
			flake.Size = Vector3.new(0.25, 0.08, 0.35)
			local start = origin
				+ Vector3.new(math.random(-6, 6), math.random(2, 6), math.random(-6, 6))
			flake.CFrame = CFrame.new(start)
			flake.Parent = Workspace

			local drift = Vector3.new(
				math.random(-10, 10) * driftScale,
				math.random(-14, -6),
				math.random(-10, 10) * driftScale
			)
			local spin = if gentle then 0.4 else 1
			local duration = if reducedMotion() then 0.7 else fallTime + math.random() * 0.6
			TweenService:Create(
				flake,
				TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					CFrame = CFrame.new(start + drift) * CFrame.Angles(
						math.random() * spin,
						math.random() * spin,
						math.random() * spin
					),
					Transparency = 1,
				}
			):Play()
			Debris:AddItem(flake, if reducedMotion() then 1.1 else fallTime + 0.9)
		end
	end,

	squish = function(target: Instance, options: { [string]: any }?)
		if reducedMotion() then
			return
		end
		Squish.punch(target, options)
	end,

	cameraKick = function(strength: number)
		if reducedMotion() then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		cameraKickToken += 1
		local token = cameraKickToken
		local player = Players.LocalPlayer
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		local amp = math.clamp(strength, 0, 2) * 0.35
		local elapsed = 0
		local conn: RBXScriptConnection?
		conn = RunService.RenderStepped:Connect(function(dt)
			if token ~= cameraKickToken then
				if conn then
					conn:Disconnect()
				end
				return
			end
			elapsed += dt
			if elapsed > 0.18 then
				if conn then
					conn:Disconnect()
				end
				if humanoid then
					humanoid.CameraOffset = Vector3.zero
				end
				return
			end
			local shake = Vector3.new(
				(math.noise(elapsed * 40, 1) - 0.5) * amp,
				(math.noise(elapsed * 40, 2) - 0.5) * amp,
				0
			)
			if humanoid then
				humanoid.CameraOffset = shake
			else
				-- Scriptable cameras (Cheese Tower) get a tiny nudge via tween.
				local goal = camera.CFrame * CFrame.new(shake.X, shake.Y, 0)
				TweenService:Create(camera, TweenInfo.new(0.05), { CFrame = goal }):Play()
			end
		end)
	end,
}

return Feedback
