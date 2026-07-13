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

local Squish = require(script.Parent.Squish)

local cameraKickToken = 0

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
		local amount = if options and type(options.amount) == "number" then options.amount else 40

		local colors = {
			Config.palette.primary,
			Config.palette.accent,
			Color3.fromRGB(255, 220, 120),
			Color3.fromRGB(170, 255, 190),
		}

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

			local drift =
				Vector3.new(math.random(-10, 10), math.random(-14, -6), math.random(-10, 10))
			TweenService:Create(
				flake,
				TweenInfo.new(
					1.6 + math.random() * 0.6,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				),
				{
					CFrame = CFrame.new(start + drift)
						* CFrame.Angles(math.random(), math.random(), math.random()),
					Transparency = 1,
				}
			):Play()
			Debris:AddItem(flake, 2.4)
		end
	end,

	squish = function(target: Instance, options: { [string]: any }?)
		Squish.punch(target, options)
	end,

	cameraKick = function(strength: number)
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
