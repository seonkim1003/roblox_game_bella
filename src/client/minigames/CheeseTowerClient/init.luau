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
local SWING_HEIGHT = 6

type Wheel = {
	part: BasePart,
	center: number,
	width: number,
	y: number,
}

local running = false
local ctx: Types.ClientContext? = nil
local disconnectDrop: (() -> ())? = nil
local disconnectLeft: (() -> ())? = nil
local disconnectRight: (() -> ())? = nil
local disconnectSecondary: (() -> ())? = nil
local disconnectTertiary: (() -> ())? = nil
local disconnectSwitch: (() -> ())? = nil
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
local lastTelemetryAt = 0
local pendulumScale = 1
local perfectBoost = 0
local cardToken = 0
local nudgeOffset = 0
local pendingRescue = false
local pendingTopper = false

local function publishTelemetry(detailTag: string?)
	if not ctx then
		return
	end
	local now = os.clock()
	if now - lastTelemetryAt < 0.2 then
		return
	end
	lastTelemetryAt = now
	local progress = math.clamp(height / 12, 0, 1)
	local accuracy = if height > 0 then math.clamp(combo / math.max(height, 1), 0, 1) else 0.8
	StarController.publishRoundTelemetry("Score", score, detailTag)
	StarController.publishRoundTelemetry("Progress", progress, detailTag)
	StarController.publishRoundTelemetry("Combo", combo, detailTag)
	StarController.publishRoundTelemetry("Accuracy", accuracy, detailTag)
	StarController.publishRoundTelemetry("Instability", math.clamp(1 - accuracy, 0, 1), detailTag)
	StarController.publishRoundTelemetry("ProjectedGrade", accuracy * 100, detailTag)
end

local cheeseSeed = 1
local swingBaseColor = CHEESE_COLOR

local function cheeseColor(): Color3
	cheeseSeed = (cheeseSeed * 1_103_515_245 + 12_345) % 2_147_483_648
	local t = (cheeseSeed / 2_147_483_648) * 0.25
	return CHEESE_COLOR:Lerp(CHEESE_HOLE, t)
end

local function paintSwingArmed()
	if not swinging then
		return
	end
	if pendingRescue then
		swinging.Color = Color3.fromRGB(140, 220, 255)
		swinging.Transparency = 0.12
	elseif pendingTopper then
		swinging.Color = Color3.fromRGB(255, 170, 90)
		swinging.Transparency = 0.08
	else
		swinging.Color = swingBaseColor
		swinging.Transparency = 0.05
	end
end

local function refreshSoftChrome()
	if not running then
		return
	end
	paintSwingArmed()
	StarController.setSoftActions({
		{ id = "Drop", label = "Drop" },
		{
			id = "Secondary",
			label = if pendingRescue then "Rescue ●" else "Rescue",
			armed = pendingRescue,
		},
		{ id = "Tertiary", label = "Bank" },
		{
			id = "Switch",
			label = if pendingTopper then "Topper ●" else "Topper",
			armed = pendingTopper,
		},
	})
end

local function applyCard(cardId: string, duration: number, strength: number)
	cardToken += 1
	local token = cardToken
	if cardId == "SlowMotion" then
		pendulumScale = math.max(0.45, 1 - 0.35 * strength)
	elseif cardId == "PerfectZone" then
		perfectBoost = 0.12 * strength
	elseif cardId == "RescueSpotlight" then
		pendingRescue = true
		refreshSoftChrome()
		if ctx then
			ctx.feedback.confetti({ amount = 18 })
			ctx.sound.play("rescue")
			StarController.getHud():setHint("Rescue armed — drop now")
		end
	elseif cardId == "DoubleOrNothingTopper" then
		pendingTopper = true
		perfectBoost = math.max(perfectBoost, 0.08 * strength)
		refreshSoftChrome()
		if ctx then
			ctx.sound.play("topper")
			StarController.getHud():setHint("Topper armed — drop for bonus")
		end
	elseif cardId == "DogAssist" or cardId == "ConfettiFinish" then
		if ctx then
			ctx.feedback.confetti({ amount = 24 })
		end
	end
	task.delay(duration, function()
		if token ~= cardToken then
			return
		end
		pendulumScale = 1
		perfectBoost = 0
	end)
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
	local y = if top then top.y + SWING_HEIGHT else STAGE_ORIGIN.Y + SWING_HEIGHT
	swingCenter = if top then top.center else 0
	swingT = 0
	local part = makeWheelPart(currentWidth, y, swingCenter)
	part.Name = "SwingingCheese"
	part.Transparency = 0.05
	swingBaseColor = part.Color
	swinging = part
	paintSwingArmed()
end

local function applyDifficulty(level: number)
	config = Scoring.configFor(level)
	-- Fresh wheels size to the dial; already-placed stack keeps its trimmed widths.
	if #stack == 0 then
		currentWidth = config.wheelWidth
	end
end

local function beginRound(difficulty: number, seed: number?)
	destroyStage()
	dropping = false
	score = 0
	combo = 0
	height = 0
	currentWidth = Scoring.configFor(difficulty).wheelWidth
	nudgeOffset = 0
	pendingRescue = false
	pendingTopper = false
	cheeseSeed = if seed ~= nil then math.floor(seed) else 1
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
		publishTelemetry("remaining:12")
	end

	heartbeat = RunService.RenderStepped:Connect(function(dt: number)
		if not swinging or dropping then
			return
		end
		swingT += dt * config.pendulumSpeed * pendulumScale
		local x = swingCenter + math.sin(swingT) * config.pendulumRange + nudgeOffset
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
			StarController.sendRoundAction("Complete", score)
			publishTelemetry("toppled")
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
	local useRescue = pendingRescue
	local useTopper = pendingTopper
	pendingRescue = false
	pendingTopper = false
	refreshSoftChrome()
	nudgeOffset = 0

	local result = if useRescue
		then Scoring.rescueDrop(top.center, top.width, dropCenter, dropWidth, combo)
		else Scoring.resolveDrop(top.center, top.width, dropCenter, dropWidth, combo)
	-- PerfectZone cue widens the perfect band by accepting near-perfect as perfect juice.
	if
		not result.perfect
		and result.placed
		and perfectBoost > 0
		and result.overhang / dropWidth <= perfectBoost
	then
		result = Scoring.resolveDrop(top.center, top.width, top.center, dropWidth, combo)
	end

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

	local accuracy = if result.placed
		then math.clamp(1 - (result.overhang / math.max(dropWidth, 0.001)), 0, 1)
		else 0
	if useRescue then
		StarController.sendRoundAction("Rescue", accuracy)
	elseif useTopper then
		StarController.sendRoundAction("Topper", accuracy)
	else
		StarController.sendRoundAction("Place", accuracy)
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
	swinging.Name = if useTopper then "TopperCheese" else "StackedCheese"

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

	local points = result.points
	if useTopper then
		points = math.floor(points * Scoring.topperMultiplier(true) + 0.5)
		if ctx then
			ctx.feedback.confetti({ amount = 20 })
		end
	end

	table.insert(stack, {
		part = swinging,
		center = result.newCenter,
		width = result.newWidth,
		y = landY,
	})
	swinging = nil
	currentWidth = result.newWidth
	score += points
	height = #stack - 1

	ctx.reportScore(score, {
		detail = if useTopper
			then "topper!"
			elseif useRescue then "rescued"
			elseif result.perfect then `perfect x{combo}`
			else `stack {height}`,
		height = height,
		perfect = result.perfect,
		combo = combo,
	})
	publishTelemetry(`remaining:{math.max(0, 12 - height)}`)
	updateCamera()
	spawnSwing()
	dropping = false
end

local function nudge(direction: number)
	if not running or not swinging or dropping or #stack == 0 then
		return
	end
	local top = stack[#stack]
	local currentX = swinging.Position.X - STAGE_ORIGIN.X
	local nudged, alignment = Scoring.nudgeToward(currentX, top.center, 1.1 * direction)
	nudgeOffset += nudged - currentX
	StarController.sendRoundAction("Nudge", alignment)
	if ctx then
		ctx.sound.play("nudge")
	end
end

local function bankTower()
	if not running or not ctx or dropping then
		return
	end
	local bonus = Scoring.bankPoints(height, score)
	score += bonus
	StarController.sendRoundAction("Bank", height)
	ctx.reportScore(score, { detail = `banked +{bonus}`, height = height, banked = true })
	publishTelemetry("banked")
	StarController.sendRoundAction("Complete", score)
	local input = StarController.getInput()
	input:setEnabled(false)
	local hud = StarController.getHud()
	hud:setHint("Tower banked — waiting for Director")
	ctx.sound.play("bank")
	ctx.feedback.confetti({ amount = 28 })
end

local function clearInputHooks()
	if disconnectDrop then
		disconnectDrop()
		disconnectDrop = nil
	end
	if disconnectLeft then
		disconnectLeft()
		disconnectLeft = nil
	end
	if disconnectRight then
		disconnectRight()
		disconnectRight = nil
	end
	if disconnectSecondary then
		disconnectSecondary()
		disconnectSecondary = nil
	end
	if disconnectTertiary then
		disconnectTertiary()
		disconnectTertiary = nil
	end
	if disconnectSwitch then
		disconnectSwitch()
		disconnectSwitch = nil
	end
end

local function stopTower()
	running = false
	clearInputHooks()
	destroyStage()
	restoreCamera()
	ctx = nil
	pendulumScale = 1
	perfectBoost = 0
	nudgeOffset = 0
	pendingRescue = false
	pendingTopper = false
	StarController.clearSoftActions()
	local hud = StarController.getHud()
	hud:setHint("")
end

local CheeseTowerClient: Types.MinigameClient = {
	id = id,

	start = function(_self, clientCtx)
		ctx = clientCtx
		running = true
		dropping = false
		pendulumScale = 1
		perfectBoost = 0
		nudgeOffset = 0
		pendingRescue = false
		pendingTopper = false
		lastTelemetryAt = 0

		clientCtx.onEvent(function(event: string, payload: { [string]: any }?)
			if not running then
				return
			end
			if event == "CheeseTowerBegin" then
				local difficulty = if payload and type(payload.difficulty) == "number"
					then payload.difficulty
					else 0.5
				local seed = if payload and type(payload.seed) == "number"
					then payload.seed
					else nil
				beginRound(difficulty, seed)
			elseif event == "CheeseTowerDifficulty" then
				if payload and type(payload.difficulty) == "number" then
					applyDifficulty(payload.difficulty)
				end
			elseif event == "CheeseTowerEnd" then
				stopTower()
			elseif event == "CheeseTowerCard" or event == "DirectorCardPlayed" then
				local cardId = payload and payload.cardId
				if type(cardId) == "string" then
					local duration = if payload and type(payload.duration) == "number"
						then payload.duration
						else 4
					local strength = if payload and type(payload.strength) == "number"
						then payload.strength
						else 1
					applyCard(cardId, duration, strength)
				end
			end
		end)

		local input = StarController.getInput()
		input:setEnabled(true)
		clearInputHooks()
		disconnectDrop = input:on("Drop", function()
			if running and not dropping then
				task.spawn(placeWheel)
			end
		end)
		disconnectLeft = input:on("Left", function()
			nudge(-1)
		end)
		disconnectRight = input:on("Right", function()
			nudge(1)
		end)
		disconnectSecondary = input:on("Secondary", function()
			if running and not dropping then
				pendingRescue = true
				refreshSoftChrome()
				if ctx then
					ctx.sound.play("rescue")
					StarController.getHud():setHint("Rescue armed — drop now")
				end
			end
		end)
		disconnectTertiary = input:on("Tertiary", function()
			bankTower()
		end)
		disconnectSwitch = input:on("Switch", function()
			if running and not dropping then
				pendingTopper = true
				refreshSoftChrome()
				if ctx then
					ctx.sound.play("topper")
					StarController.getHud():setHint("Topper armed — drop for bonus")
				end
			end
		end)

		local hud = StarController.getHud()
		hud:setHint("Drop · ←→ nudge · soft buttons for rescue / bank / topper")
		refreshSoftChrome()
	end,

	stop = function(_self)
		StarController.clearSoftActions()
		stopTower()
	end,
}

return CheeseTowerClient
