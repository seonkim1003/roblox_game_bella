--!strict
-- ASMR Satisfy Station -- CLIENT half.
-- Tray of jellies/soaps/kinetic-sand: Slice (drag), Squish/Pop (tap).
-- Pure combo/score math lives in Logic.luau for Lune tests.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Config = require(Shared.Config)

local Logic = require(script.Logic)
local StarController = require(script.Parent.Parent.star.StarController)

local id: Types.MinigameId = "SatisfyStation"

local STAGE_ORIGIN = Vector3.new(-24, 5, -40)
local COLORS = {
	Slice = Color3.fromRGB(255, 170, 210),
	Squish = Color3.fromRGB(170, 220, 255),
	Pop = Color3.fromRGB(255, 230, 140),
}

local running = false
local ctx: Types.ClientContext? = nil
local disconnectPrimary: (() -> ())? = nil
local disconnectSlice: (() -> ())? = nil
local stageFolder: Folder? = nil
local itemParts: { [number]: BasePart } = {}
local itemLabels: { [number]: string } = {}
local state: Logic.State? = nil
local config = Logic.configFor(0.5)
local savedCameraType: Enum.CameraType? = nil
local suppressPrimaryUntil = 0

local function destroyStage()
	if stageFolder then
		stageFolder:Destroy()
		stageFolder = nil
	end
	table.clear(itemParts)
	table.clear(itemLabels)
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
	camera.CFrame =
		CFrame.new(STAGE_ORIGIN + Vector3.new(0, 12, 16), STAGE_ORIGIN + Vector3.new(0, 1, 0))
end

local function reportLive(detail: string?)
	if not ctx or not state then
		return
	end
	ctx.reportScore(state.score, {
		detail = detail or (if state.combo > 1 then `combo x{state.combo}` else "tray"),
		combo = state.combo,
		remaining = Logic.remaining(state),
		finished = state.finished,
		progress = if #state.items > 0 then state.resolvedCount / #state.items else 1,
	})
end

local function layoutForIndex(index: number, total: number): Vector3
	local cols = math.min(5, math.max(3, math.ceil(math.sqrt(total))))
	local row = math.floor((index - 1) / cols)
	local col = (index - 1) % cols
	local rows = math.ceil(total / cols)
	local x = (col - (cols - 1) * 0.5) * 2.6
	local z = (row - (rows - 1) * 0.5) * 2.6
	return STAGE_ORIGIN + Vector3.new(x, 1.2, z)
end

local function makeItemPart(item: Logic.Item, index: number, total: number): BasePart
	local part = Instance.new("Part")
	part.Name = item.kind .. item.id
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = COLORS[item.kind]
	if item.kind == "Pop" then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(1.6, 1.6, 1.6)
	elseif item.kind == "Squish" then
		part.Size = Vector3.new(1.8, 1.2, 1.8)
	else
		part.Size = Vector3.new(2.1, 0.9, 1.4)
	end
	part.CFrame = CFrame.new(layoutForIndex(index, total))
	part.Parent = stageFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(70, 22)
	billboard.StudsOffset = Vector3.new(0, 1.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.35
	label.Text = item.kind
	label.Parent = billboard

	itemParts[item.id] = part
	itemLabels[item.id] = item.kind
	return part
end

local function beginRound(difficulty: number)
	destroyStage()
	config = Logic.configFor(difficulty)
	state = Logic.newState(difficulty)
	suppressPrimaryUntil = 0

	local folder = Instance.new("Folder")
	folder.Name = "SatisfyStationStage"
	folder.Parent = Workspace
	stageFolder = folder

	local tray = Instance.new("Part")
	tray.Name = "Tray"
	tray.Anchored = true
	tray.CanCollide = false
	tray.Size = Vector3.new(14, 0.4, 10)
	tray.Color = Config.palette.cozy
	tray.Material = Enum.Material.SmoothPlastic
	tray.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(0, 0.7, 0))
	tray.Parent = folder

	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Anchored = true
	rim.CanCollide = false
	rim.Size = Vector3.new(14.4, 0.25, 10.4)
	rim.Color = Config.palette.primary
	rim.Transparency = 0.35
	rim.CFrame = CFrame.new(STAGE_ORIGIN + Vector3.new(0, 0.95, 0))
	rim.Parent = folder

	local round = state
	if not round then
		return
	end
	local total = #round.items
	for index, item in round.items do
		makeItemPart(item, index, total)
	end

	local camera = Workspace.CurrentCamera
	if camera and not savedCameraType then
		savedCameraType = camera.CameraType
	end
	updateCamera()
	reportLive("fresh tray")
end

local function applyDifficulty(level: number)
	config = Logic.configFor(level)
end

local function resolveVisual(itemId: number, result: Logic.ActionResult, action: Logic.ActionKind)
	if not ctx then
		return
	end
	local part = itemParts[itemId]
	local pos = if part then part.Position else STAGE_ORIGIN
	if result.accepted then
		if action == "Slice" then
			ctx.sound.play("squelch", { speed = 1.15 })
			ctx.feedback.pop(pos, { color = COLORS.Slice, count = 18 })
		elseif action == "Squish" then
			if part then
				ctx.feedback.squish(part, { strength = 0.9 })
			end
			ctx.sound.play("squelch")
			ctx.feedback.pop(pos, { color = COLORS.Squish, count = 12 })
		else
			ctx.sound.play("pop", { speed = 1.25 })
			ctx.feedback.pop(pos, { color = COLORS.Pop, count = 22 })
			ctx.feedback.cameraKick(0.2)
		end
		if result.perfect then
			ctx.sound.play("softChime", { volume = 0.22 })
		end
		if part then
			TweenService:Create(part, TweenInfo.new(0.22), {
				Transparency = 1,
				Size = part.Size * 0.4,
			}):Play()
			task.delay(0.25, function()
				if part.Parent then
					part:Destroy()
				end
			end)
			itemParts[itemId] = nil
			itemLabels[itemId] = nil
		end
	else
		ctx.sound.play("wobble", { volume = 0.18 })
		if part then
			TweenService:Create(
				part,
				TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true),
				{ CFrame = part.CFrame * CFrame.Angles(0, 0, math.rad(8)) }
			):Play()
		end
	end

	local detail = if result.accepted
		then (if result.perfect then `perfect {action}` else action)
		else "miss"
	reportLive(detail)

	if result.finished then
		local hud = StarController.getHud()
		hud:setHint("Tray cleared — waiting for Director")
		ctx.sound.play("cheer")
	end
end

local function pickNearestItem(prefer: Logic.ActionKind?): number?
	if not state then
		return nil
	end
	local pointer = StarController.getInput():getPointer()
	local camera = Workspace.CurrentCamera
	local player = Players.LocalPlayer
	local bestId: number? = nil
	local bestDist = math.huge

	for _, item in state.items do
		if item.resolved then
			continue
		end
		if prefer and item.kind ~= prefer then
			continue
		end
		local part = itemParts[item.id]
		if not part then
			continue
		end
		local dist = 0
		if pointer and camera then
			local screen, onScreen = camera:WorldToViewportPoint(part.Position)
			if onScreen then
				dist = (Vector2.new(screen.X, screen.Y) - pointer).Magnitude
			else
				dist = 5000 + (part.Position - STAGE_ORIGIN).Magnitude
			end
		else
			local char = player and player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				dist = (part.Position - root.Position).Magnitude
			else
				dist = (part.Position - STAGE_ORIGIN).Magnitude
			end
		end
		if dist < bestDist then
			bestDist = dist
			bestId = item.id
		end
	end

	-- Fall back to any unresolved item of the preferred kind, then any item.
	if not bestId and prefer then
		for _, item in state.items do
			if not item.resolved and item.kind == prefer then
				return item.id
			end
		end
	end
	if not bestId then
		for _, item in state.items do
			if not item.resolved then
				return item.id
			end
		end
	end
	return bestId
end

local function perform(action: Logic.ActionKind)
	if not running or not state or not ctx or state.finished then
		return
	end
	local now = os.clock()
	local itemId = pickNearestItem(action)
	if not itemId then
		return
	end
	local result = Logic.applyAction(state, itemId, action, now, config)
	resolveVisual(itemId, result, action)
end

local function stopStation()
	running = false
	if disconnectPrimary then
		disconnectPrimary()
		disconnectPrimary = nil
	end
	if disconnectSlice then
		disconnectSlice()
		disconnectSlice = nil
	end
	destroyStage()
	restoreCamera()
	ctx = nil
	local hud = StarController.getHud()
	hud:setHint("")
end

local SatisfyStationClient: Types.MinigameClient = {
	id = id,

	start = function(_self, clientCtx)
		ctx = clientCtx
		running = true

		clientCtx.onEvent(function(event: string, payload: { [string]: any }?)
			if not running then
				return
			end
			if event == "SatisfyStationBegin" then
				local difficulty = if payload and type(payload.difficulty) == "number"
					then payload.difficulty
					else 0.5
				beginRound(difficulty)
			elseif event == "SatisfyStationDifficulty" then
				if payload and type(payload.difficulty) == "number" then
					applyDifficulty(payload.difficulty)
				end
			elseif event == "SatisfyStationEnd" then
				stopStation()
			end
		end)

		local input = StarController.getInput()
		input:setEnabled(true)
		if disconnectPrimary then
			disconnectPrimary()
		end
		if disconnectSlice then
			disconnectSlice()
		end

		disconnectPrimary = input:on("Primary", function()
			if os.clock() < suppressPrimaryUntil then
				return
			end
			-- Tap/controller A: prefer Pop, then Squish (Slice wants a drag).
			local itemId = pickNearestItem("Pop") or pickNearestItem("Squish")
			if not itemId or not state then
				return
			end
			local item = Logic.findItem(state, itemId)
			if not item then
				return
			end
			perform(item.kind)
		end)

		disconnectSlice = input:on("Slice", function()
			-- Drag / controller X|B just finished — don't also treat as a tap.
			suppressPrimaryUntil = os.clock() + 0.12
			perform("Slice")
		end)

		local hud = StarController.getHud()
		hud:setHint("Tap to pop/squish · drag to slice · keep a gentle combo")
	end,

	stop = function(_self)
		stopStation()
	end,
}

return SatisfyStationClient
