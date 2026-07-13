--!strict
-- Ratthew's Cheese Tower -- CLIENT half.
--
-- Client-simulated tower (pendulum + drop) for juice; live score reports through
-- ClientContext so the Director can watch. Loaded by StarController because it
-- exports `id`. Scoring math lives in the child module so Lune can unit-test it.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Config = require(Shared.Config)

local Scoring = require(script.Scoring)

-- StarController is the shared shell; we borrow its single InputRouter.
local StarController = require(script.Parent.Parent.star.StarController)

local id: Types.MinigameId = "CheeseTower"

local CHEESE_COLOR = Color3.fromRGB(255, 206, 84)
local CHEESE_HOLE = Color3.fromRGB(240, 180, 60)
local STAGE_ORIGIN = Vector3.new(0, 4, -40)

type Wheel = {
	part: BasePart,
	center: number,
	width: number,
	y: number,
}

local running = false
local ctx: Types.ClientContext? = nil
local disconnectDrop: (() -> ())? = nil
local heartbeat: RBXScriptConnection? = nil
local stageFolder: Folder? = nil
local stack: { Wheel } = {}
local swinging: BasePart? = nil
local swingT = 0
local swingCenter = 0
local currentWidth = Scoring.BaseWidth
local config = Scoring.configFor(0.5)
local score = 0
local combo = 0
local height = 0
local dropping = false
local savedCameraType: Enum.CameraType? = nil

local function cheeseColor(): Color3
	return CHEESE_COLOR:Lerp(CHEESE_HOLE, math.random() * 0.25)
end

local function destroyStage()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	if stageFolder then
		stageFolder:Destroy()
		stageFolder = nil
	end
	table.clear(stack)
	swinging = nil
end

local function restoreCamera()
	local camera = Workspace.CurrentCamera
	if camera and savedCameraType then
		camera.CameraType = savedCameraType
	end
	savedCameraType = nil
end

local function updateCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local focusY = STAGE_ORIGIN.Y + height + 4
	local target = CFrame.new(
		STAGE_ORIGIN + Vector3.new(0, focusY * 0.35 + 10, 28),
		STAGE_ORIGIN + Vector3.new(0, focusY, 0)
	)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService
		:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = target,
		})
		:Play()
end

local function makeWheelPart(width: number, y: number, x: number): BasePart
	local part = Instance.new("Part")
	part.Name = "CheeseWheel"
	part.Shape = Enum.PartType.Cylinder
	-- Cylinder's long axis is +X; rotate so the disc faces the camera (along Z).
	part.Size = Vector3.new(1.4, width, width)
	part.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(x, y, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = cheeseColor()
	part.Parent = stageFolder
	return part
end

local function spawnSwing()
	if swinging then
		swinging:Destroy()
		swinging = nil
	end
	local top = stack[#stack]
	local y = if top then top.y + 1.5 else STAGE_ORIGIN.Y + 1.5
	swingCenter = if top then top.center else 0
	swingT = 0
	local part = makeWheelPart(currentWidth, y, swingCenter)
	part.Name = "SwingingCheese"
	part.Transparency = 0.05
	swinging = part
end

local function applyDifficulty(level: number)
	config = Scoring.configFor(level)
	-- Fresh wheels size to the dial; already-placed stack keeps its trimmed widths.
	if #stack == 0 then
		currentWidth = config.wheelWidth
	end
end

local function beginRound(difficulty: number)
	destroyStage()
	dropping = false
	score = 0
	combo = 0
	height = 0
	currentWidth = Scoring.configFor(difficulty).wheelWidth
	applyDifficulty(difficulty)

	local folder = Instance.new("Folder")
	folder.Name = "CheeseTowerStage"
	folder.Parent = Workspace
	stageFolder = folder

	local base = makeWheelPart(Scoring.BaseWidth, STAGE_ORIGIN.Y, 0)
	base.Name = "BasePlate"
	base.Color = Config.palette.accent
	table.insert(stack, {
		part = base,
		center = 0,
		width = Scoring.BaseWidth,
		y = STAGE_ORIGIN.Y,
	})

	local camera = Workspace.CurrentCamera
	if camera and not savedCameraType then
		savedCameraType = camera.CameraType
	end
	updateCamera()
	spawnSwing()

	if ctx then
		ctx.reportScore(0, { detail = "stack 0", height = 0 })
	end

	heartbeat = RunService.RenderStepped:Connect(function(dt: number)
		if not swinging or dropping then
			return
		end
		swingT += dt * config.pendulumSpeed
		local x = swingCenter + math.sin(swingT) * config.pendulumRange
		local y = swinging.Position.Y
		swinging.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(x, y - STAGE_ORIGIN.Y, 0))
			* CFrame.Angles(0, 0, math.rad(90))
	end)
end

local function topple(failed: BasePart)
	if not ctx then
		return
	end
	ctx.sound.play("crumble")
	ctx.feedback.cameraKick(1.2)
	TweenService
		:Create(failed, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = failed.CFrame * CFrame.new(4, -6, 0) * CFrame.Angles(0, 0, math.rad(70)),
			Transparency = 1,
		})
		:Play()
	for _, wheel in stack do
		local nudge = if math.random() > 0.5 then 1 else -1
		TweenService:Create(wheel.part, TweenInfo.new(0.5), {
			CFrame = wheel.part.CFrame * CFrame.Angles(0, 0, math.rad(12 * nudge)),
		}):Play()
	end
	task.delay(0.8, function()
		-- End of run: keep the stage until the Director ends the minigame, but stop input.
		local input = StarController.getInput()
		input:setEnabled(false)
		local hud = StarController.getHud()
		hud:setHint("Tower toppled — waiting for Director")
		if ctx then
			ctx.reportScore(score, { detail = "toppled", height = height, toppled = true })
		end
	end)
end

local function placeWheel()
	if not ctx or not swinging or dropping or #stack == 0 then
		return
	end
	dropping = true

	local top = stack[#stack]
	local dropCenter = swinging.Position.X - STAGE_ORIGIN.X
	local dropWidth = currentWidth
	local result = Scoring.resolveDrop(top.center, top.width, dropCenter, dropWidth, combo)

	local landY = top.y + 1.5
	local tween = TweenService:Create(
		swinging,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(dropCenter, landY, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
		}
	)
	tween:Play()
	tween.Completed:Wait()

	if not running or not swinging then
		return
	end

	if not result.placed then
		topple(swinging)
		swinging = nil
		dropping = false
		return
	end

	-- Snap to trimmed width/center.
	swinging.Size = Vector3.new(1.4, result.newWidth, result.newWidth)
	swinging.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(result.newCenter, landY, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	swinging.Name = "StackedCheese"

	ctx.feedback.squish(swinging, { strength = 0.7 + result.wobble })
	ctx.feedback.pop(
		swinging.Position,
		{ color = CHEESE_COLOR, count = if result.perfect then 22 else 12 }
	)
	ctx.feedback.cameraKick(0.25 + result.wobble)
	if result.perfect then
		ctx.sound.play("plop", { speed = 1.15 })
		ctx.sound.play("cheer", { volume = 0.18 })
		combo += 1
	else
		ctx.sound.play("squelch")
		if result.wobble > 0.35 then
			ctx.sound.play("wobble")
		end
		combo = 0
	end

	if result.wobble > 0 then
		local wobbleAmt = result.wobble * 8
		TweenService:Create(
			swinging,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
			{
				CFrame = swinging.CFrame * CFrame.Angles(0, 0, math.rad(wobbleAmt)),
			}
		):Play()
	end

	table.insert(stack, {
		part = swinging,
		center = result.newCenter,
		width = result.newWidth,
		y = landY,
	})
	swinging = nil
	currentWidth = result.newWidth
	score += result.points
	height = #stack - 1

	ctx.reportScore(score, {
		detail = if result.perfect then `perfect x{combo}` else `stack {height}`,
		height = height,
		perfect = result.perfect,
		combo = combo,
	})
	updateCamera()
	spawnSwing()
	dropping = false
end

local function stopTower()
	running = false
	if disconnectDrop then
		disconnectDrop()
		disconnectDrop = nil
	end
	destroyStage()
	restoreCamera()
	ctx = nil
	local hud = StarController.getHud()
	hud:setHint("")
end

local CheeseTowerClient: Types.MinigameClient = {
	id = id,

	start = function(_self, clientCtx)
		ctx = clientCtx
		running = true
		dropping = false

		clientCtx.onEvent(function(event: string, payload: { [string]: any }?)
			if not running then
				return
			end
			if event == "CheeseTowerBegin" then
				local difficulty = if payload and type(payload.difficulty) == "number"
					then payload.difficulty
					else 0.5
				beginRound(difficulty)
			elseif event == "CheeseTowerDifficulty" then
				if payload and type(payload.difficulty) == "number" then
					applyDifficulty(payload.difficulty)
				end
			elseif event == "CheeseTowerEnd" then
				stopTower()
			end
		end)

		local input = StarController.getInput()
		input:setEnabled(true)
		if disconnectDrop then
			disconnectDrop()
		end
		disconnectDrop = input:on("Drop", function()
			if running and not dropping then
				-- placeWheel yields on the land tween; keep the input thread free.
				task.spawn(placeWheel)
			end
		end)

		local hud = StarController.getHud()
		hud:setHint("Tap / click / Space to drop the cheese")
	end,

	stop = function(_self)
		stopTower()
	end,
}

return CheeseTowerClient
