--!strict
-- Gigi & Rambo Dash -- CLIENT half.
-- Auto-running dachshunds; Left/Right lane swaps catch treats and dodge puddles.
-- Pure spawn/score math lives in Logic.luau for Lune tests.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Config = require(Shared.Config)

local Logic = require(script.Logic)
local StarController = require(script.Parent.Parent.star.StarController)
local Motion = require(script.Parent.Parent.juice.Motion)

local id: Types.MinigameId = "DogDash"

local STAGE_ORIGIN = Vector3.new(24, 4, -40)
local LANE_WIDTH = 4.2
local GROUND_SIZE = Vector3.new(Logic.LaneCount * LANE_WIDTH + 4, 1, 55)

local running = false
local ctx: Types.ClientContext? = nil
local disconnectLeft: (() -> ())? = nil
local disconnectRight: (() -> ())? = nil
local disconnectSecondary: (() -> ())? = nil
local disconnectTertiary: (() -> ())? = nil
local disconnectSwitch: (() -> ())? = nil
local disconnectDrop: (() -> ())? = nil
local heartbeat: RBXScriptConnection? = nil
local stageFolder: Folder? = nil
local dogModels: { Model } = {}
local entityParts: { [number]: BasePart } = {}
local state: Logic.State? = nil
local config = Logic.configFor(0.5)
local savedCameraType: Enum.CameraType? = nil
local stretchToken = 0
local lastTelemetryAt = 0
local speedScale = 1
local treatBoost = 0
local activeDogName = "Gigi"
local cardToken = 0

local placeDogs: () -> ()
local stretchDogs: () -> ()

local function publishTelemetry()
	if not ctx or not state then
		return
	end
	local now = os.clock()
	if now - lastTelemetryAt < 0.2 then
		return
	end
	lastTelemetryAt = now
	local progress = math.clamp(state.distance / Logic.RunDistance, 0, 1)
	local accuracy = math.clamp(0.55 + state.combo * 0.05, 0, 1)
	local dogTag = `dog:{activeDogName}`
	StarController.publishRoundTelemetry("Score", state.score, dogTag)
	StarController.publishRoundTelemetry("Progress", progress, dogTag)
	StarController.publishRoundTelemetry("Combo", state.combo, dogTag)
	StarController.publishRoundTelemetry(
		"Friendship",
		math.clamp(progress + state.combo * 0.02, 0, 1),
		dogTag
	)
	StarController.publishRoundTelemetry("Accuracy", accuracy, dogTag)
	StarController.publishRoundTelemetry("ProjectedGrade", accuracy * 100, dogTag)
end

local function activeDogIndexValue(): number
	return if activeDogName == "Rambo" then 2 else 1
end

local function applyCard(cardId: string, duration: number, strength: number)
	cardToken += 1
	local token = cardToken
	if cardId == "SlowMotion" then
		speedScale = math.max(0.5, 1 - 0.3 * strength)
	elseif cardId == "TreatRain" then
		treatBoost = 0.35 * strength
	elseif cardId == "DogAssist" then
		if state then
			Logic.shiftLane(state, if state.lane < Logic.DefaultLane then 1 else -1)
			placeDogs()
			stretchDogs()
		end
		StarController.sendRoundAction("SwitchDog", activeDogIndexValue())
	elseif cardId == "ConfettiFinish" and ctx then
		ctx.feedback.confetti({ amount = 28 })
	end
	task.delay(duration, function()
		if token ~= cardToken then
			return
		end
		speedScale = 1
		treatBoost = 0
	end)
end

local function laneX(lane: number): number
	local mid = (Logic.LaneCount - 1) * 0.5
	return (lane - mid) * LANE_WIDTH
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
	table.clear(dogModels)
	table.clear(entityParts)
	state = nil
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
	camera.CameraType = Enum.CameraType.Scriptable
	local look = STAGE_ORIGIN + Vector3.new(0, 2, 8)
	local target = CFrame.new(STAGE_ORIGIN + Vector3.new(0, 14, 28), look)
	-- Gentle push-in instead of a hard cut, matching Cheese Tower's feel.
	Motion.tween(
		camera,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = target }
	)
end

local function makeDog(name: string, color: Color3, offsetX: number): Model
	local model = Instance.new("Model")
	model.Name = name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.2, 0.7, 2.8)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(offsetX, 1.1, 0))
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(0.9, 0.9, 0.9)
	head.Color = color
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(offsetX, 1.35, -1.5))
	head.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(90, 24)
	billboard.StudsOffset = Vector3.new(0, 1.1, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = name
	label.Parent = billboard

	model.PrimaryPart = body
	model.Parent = stageFolder
	return model
end

local function jumpHop(now: number): number
	if not state or not Logic.isJumping(state, now) then
		return 0
	end
	local remaining = math.max(0, state.jumpUntil - now)
	local t = 1 - math.clamp(remaining / Logic.JumpDuration, 0, 1)
	return math.sin(t * math.pi) * 1.45
end

local function placeDogsImpl()
	if not state then
		return
	end
	local now = os.clock()
	local hop = jumpHop(now)
	local hopping = hop > 0.04
	local x = laneX(state.lane)
	for index, dog in dogModels do
		local body = dog:FindFirstChild("Body")
		local head = dog:FindFirstChild("Head")
		local side = if index == 1 then -0.7 else 0.7
		local target = STAGE_ORIGIN + Vector3.new(x + side, 1.1 + hop, 0)
		local headTarget = target + Vector3.new(0, 0.25, -1.5)
		if body and body:IsA("BasePart") then
			if hopping then
				body.CFrame = CFrame.new(target)
			else
				TweenService:Create(
					body,
					TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						CFrame = CFrame.new(target),
					}
				):Play()
			end
		end
		if head and head:IsA("BasePart") then
			if hopping then
				head.CFrame = CFrame.new(headTarget)
			else
				TweenService:Create(
					head,
					TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{
						CFrame = CFrame.new(headTarget),
					}
				):Play()
			end
		end
	end
end
placeDogs = placeDogsImpl

local function stretchDogsImpl()
	stretchToken += 1
	local token = stretchToken
	for _, dog in dogModels do
		local body = dog:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			local original = body.Size
			body.Size = Vector3.new(original.X, original.Y, original.Z * 1.28)
			task.delay(0.12, function()
				if token == stretchToken and body.Parent then
					TweenService:Create(body, TweenInfo.new(0.18), { Size = original }):Play()
				end
			end)
		end
	end
end
stretchDogs = stretchDogsImpl

local function spawnVisual(entity: Logic.Entity)
	local part = Instance.new("Part")
	part.Name = entity.kind .. entity.id
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	if entity.kind == "Treat" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(1.1, 1.1, 1.1)
		part.Color = Color3.fromRGB(255, 170, 90)
	else
		part.Size = Vector3.new(2.4, 0.25, 2.2)
		part.Color = Color3.fromRGB(70, 110, 170)
		part.Transparency = 0.25
	end
	part.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(laneX(entity.lane), 1.2, entity.z))
	part.Parent = stageFolder
	entityParts[entity.id] = part
end

local function syncEntityParts()
	if not state then
		return
	end
	local alive: { [number]: boolean } = {}
	for _, entity in state.entities do
		alive[entity.id] = true
		local part = entityParts[entity.id]
		if part then
			part.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(laneX(entity.lane), 1.2, entity.z))
		end
	end
	for entityId, part in entityParts do
		if not alive[entityId] then
			part:Destroy()
			entityParts[entityId] = nil
		end
	end
end

local function reportLive()
	if not ctx or not state then
		return
	end
	local progress = math.clamp(state.distance / Logic.RunDistance, 0, 1)
	ctx.reportScore(state.score, {
		detail = if state.combo > 1 then `combo x{state.combo}` else `dash`,
		combo = state.combo,
		distance = state.distance,
		progress = progress,
		finished = state.finished,
		activeDog = activeDogName,
	})
	publishTelemetry()
end

local function beginRound(difficulty: number, seed: number?)
	destroyStage()
	config = Logic.configFor(difficulty)
	state = Logic.newState(difficulty, seed)

	local folder = Instance.new("Folder")
	folder.Name = "DogDashStage"
	folder.Parent = Workspace
	stageFolder = folder

	local ground = Instance.new("Part")
	ground.Name = "Track"
	ground.Anchored = true
	ground.CanCollide = false
	ground.Size = GROUND_SIZE
	ground.Color = Color3.fromRGB(120, 190, 110)
	ground.Material = Enum.Material.Grass
	ground.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(0, 0.4, 18))
	ground.Parent = folder

	for lane = 0, Logic.LaneCount - 1 do
		local stripe = Instance.new("Part")
		stripe.Name = "Lane" .. lane
		stripe.Anchored = true
		stripe.CanCollide = false
		stripe.Size = Vector3.new(0.15, 0.12, GROUND_SIZE.Z)
		stripe.Color = Color3.fromRGB(255, 255, 255)
		stripe.Transparency = 0.45
		stripe.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(laneX(lane), 0.95, 18))
		stripe.Parent = folder
	end

	local gigi = Config.dogs[1]
	local rambo = Config.dogs[2]
	activeDogName = gigi.name
	table.insert(dogModels, makeDog(gigi.name, gigi.color, -0.7))
	table.insert(dogModels, makeDog(rambo.name, rambo.color, 0.7))
	placeDogs()

	local camera = Workspace.CurrentCamera
	if camera and not savedCameraType then
		savedCameraType = camera.CameraType
	end
	updateCamera()
	reportLive()

	heartbeat = RunService.RenderStepped:Connect(function(dt: number)
		if not running or not state or not ctx then
			return
		end
		local scaledDt = dt * speedScale
		-- TreatRain gently biases spawn luck by advancing the spawn clock.
		if treatBoost > 0 then
			state.spawnTimer -= scaledDt * treatBoost
		end
		local now = os.clock()
		local events = Logic.tick(state, scaledDt, config, now)
		for _, event in events do
			if event.kind == "Spawn" then
				spawnVisual(event.entity)
			elseif event.kind == "Catch" then
				stretchDogs()
				StarController.sendRoundAction("Lunge", 0.9)
				local part = entityParts[event.entityId]
				local pos = if part
					then part.Position
					else STAGE_ORIGIN + Vector3.new(laneX(state.lane), 1.2, 0)
				ctx.feedback.pop(pos, { color = Color3.fromRGB(255, 190, 120), count = 16 })
				ctx.sound.play("pop", { speed = 1.1 + math.min(event.combo, 6) * 0.04 })
				ctx.sound.play("cheer", { volume = 0.12 })
				if part then
					part:Destroy()
					entityParts[event.entityId] = nil
				end
			elseif event.kind == "Hit" then
				StarController.sendRoundAction("Jump", 0.15)
				ctx.feedback.cameraKick(0.85)
				ctx.sound.play("wobble")
				local part = entityParts[event.entityId]
				if part then
					part:Destroy()
					entityParts[event.entityId] = nil
				end
				ctx.reportScore(state.score, {
					detail = "combo broken",
					combo = 0,
					comboBroken = true,
					distance = state.distance,
					progress = math.clamp(state.distance / Logic.RunDistance, 0, 1),
					finished = state.finished,
					activeDog = activeDogName,
				})
			elseif event.kind == "Finish" then
				local hud = StarController.getHud()
				hud:setHint("Dash complete — waiting for Director")
				ctx.sound.play("cheer")
				StarController.sendRoundAction("Complete", state.score)
				reportLive()
			end
		end
		syncEntityParts()
		if Logic.isJumping(state, now) then
			placeDogs()
		end
		local progress = math.clamp(state.distance / Logic.RunDistance, 0, 1)
		if
			#events > 0
			or (state.distance // 4) ~= ((state.distance - state.speed * scaledDt) // 4)
		then
			reportLive()
		elseif (state.distance // 20) ~= ((state.distance - state.speed * scaledDt) // 20) then
			StarController.sendRoundAction("Route", progress)
		end
	end)
end

local function applyDifficulty(level: number)
	config = Logic.configFor(level)
	if state and not state.finished then
		state.speed = config.baseSpeed + state.distance * config.speedRamp
	end
end

local function stopDash()
	running = false
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
	if disconnectDrop then
		disconnectDrop()
		disconnectDrop = nil
	end
	destroyStage()
	restoreCamera()
	ctx = nil
	speedScale = 1
	treatBoost = 0
	StarController.clearSoftActions()
	local hud = StarController.getHud()
	hud:setHint("")
end

local DogDashClient: Types.MinigameClient = {
	id = id,

	start = function(_self, clientCtx)
		ctx = clientCtx
		running = true
		speedScale = 1
		treatBoost = 0
		lastTelemetryAt = 0
		activeDogName = Config.dogs[1].name

		clientCtx.onEvent(function(event: string, payload: { [string]: any }?)
			if not running then
				return
			end
			if event == "DogDashBegin" then
				local difficulty = if payload and type(payload.difficulty) == "number"
					then payload.difficulty
					else 0.5
				local seed = if payload and type(payload.seed) == "number"
					then payload.seed
					else nil
				beginRound(difficulty, seed)
			elseif event == "DogDashDifficulty" then
				if payload and type(payload.difficulty) == "number" then
					applyDifficulty(payload.difficulty)
				end
			elseif event == "DogDashEnd" then
				stopDash()
			elseif event == "DogDashCard" or event == "DirectorCardPlayed" then
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
		if disconnectLeft then
			disconnectLeft()
		end
		if disconnectRight then
			disconnectRight()
		end
		if disconnectSecondary then
			disconnectSecondary()
		end
		if disconnectTertiary then
			disconnectTertiary()
		end
		if disconnectSwitch then
			disconnectSwitch()
		end
		if disconnectDrop then
			disconnectDrop()
		end
		disconnectLeft = input:on("Left", function()
			if running and state and not state.finished then
				Logic.shiftLane(state, -1)
				placeDogs()
				stretchDogs()
				StarController.sendRoundAction(
					"Route",
					math.clamp(state.distance / Logic.RunDistance, 0, 1)
				)
			end
		end)
		disconnectRight = input:on("Right", function()
			if running and state and not state.finished then
				Logic.shiftLane(state, 1)
				placeDogs()
				stretchDogs()
				StarController.sendRoundAction(
					"Route",
					math.clamp(state.distance / Logic.RunDistance, 0, 1)
				)
			end
		end)
		disconnectDrop = input:on("Drop", function()
			-- Space / tap also jumps to clear puddles.
			if running and state and not state.finished then
				local now = os.clock()
				if Logic.jump(state, now) then
					StarController.sendRoundAction("Jump", 1)
					placeDogs()
					if ctx then
						ctx.sound.play("jump")
						local paws = STAGE_ORIGIN + Vector3.new(laneX(state.lane), 1.1, 0)
						ctx.feedback.pop(paws, { color = Color3.fromRGB(210, 240, 255), count = 8 })
					end
				end
			end
		end)
		disconnectSecondary = input:on("Secondary", function()
			if running and state and not state.finished then
				local now = os.clock()
				if Logic.jump(state, now) then
					StarController.sendRoundAction("Jump", 1)
					placeDogs()
					if ctx then
						ctx.sound.play("jump")
						local paws = STAGE_ORIGIN + Vector3.new(laneX(state.lane), 1.1, 0)
						ctx.feedback.pop(paws, { color = Color3.fromRGB(210, 240, 255), count = 8 })
					end
				end
			end
		end)
		disconnectTertiary = input:on("Tertiary", function()
			if running and state and not state.finished then
				local now = os.clock()
				if Logic.charge(state, now) then
					StarController.sendRoundAction("Charge", 1)
					if ctx then
						ctx.sound.play("charge")
						ctx.feedback.cameraKick(0.2)
					end
				end
			end
		end)
		disconnectSwitch = input:on("Switch", function()
			if running and state and not state.finished then
				local lead = Logic.switchDog(state)
				activeDogName = if lead == 1 then Config.dogs[1].name else Config.dogs[2].name
				StarController.sendRoundAction("SwitchDog", lead)
				placeDogs()
				stretchDogs()
				publishTelemetry()
				if ctx then
					ctx.sound.play("switchDog")
					StarController.getHud():setHint(`Lead: {activeDogName}`)
				end
			end
		end)

		local hud = StarController.getHud()
		hud:setHint("←→ route · jump on tap · soft buttons for charge / switch")
		StarController.setSoftActions({
			{ id = "Drop", label = "Jump" },
			{ id = "Tertiary", label = "Charge" },
			{ id = "Switch", label = "Switch" },
		})
	end,

	stop = function(_self)
		StarController.clearSoftActions()
		stopDash()
	end,
}

return DogDashClient
