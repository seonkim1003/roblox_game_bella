--!strict

-- Server-authoritative finale set and timing. The client presenter only controls
-- Bella's camera and text; all shared world objects are created here.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

type Payload = { [string]: any }
type Broadcast = (event: string, payload: Payload?) -> ()

type LightingSnapshot = {
	ambient: Color3,
	brightness: number,
	clockTime: number,
	outdoorAmbient: Color3,
}

local FinaleService = {}

local broadcast: Broadcast? = nil
local finaleWorld: Folder? = nil
local lightingSnapshot: LightingSnapshot? = nil
local runToken = 0

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Anchored = true
	result.CanCollide = false
	result.CanQuery = false
	result.CanTouch = false
	result.CastShadow = true
	result.Color = color
	result.Material = material
	result.Shape = shape or Enum.PartType.Block
	result.Size = size
	result.CFrame = cf
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

local function broadcastBeat(token: number, delaySeconds: number, beat: string)
	task.delay(delaySeconds, function()
		if token ~= runToken or not finaleWorld or not finaleWorld.Parent then
			return
		end
		if broadcast then
			broadcast("FinaleBeat", { beat = beat })
		end
	end)
end

local function createDog(parent: Instance, name: string, color: Color3, cf: CFrame)
	local body = makePart(
		parent,
		name,
		Vector3.new(2.5, 1.15, 3.5),
		cf,
		color,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	makePart(
		parent,
		`{name}Head`,
		Vector3.new(1.45, 1.35, 1.45),
		body.CFrame * CFrame.new(0.2, 0.45, -1.55),
		color,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
end

local function createBroodingGuest(parent: Instance, center: CFrame): (BasePart, Model)
	local model = Instance.new("Model")
	model.Name = "BroodingGuest"
	model.Parent = parent
	local root = makePart(
		model,
		"BatRobRoot",
		Vector3.new(0.5, 0.5, 0.5),
		center * CFrame.new(8, 2.5, -3),
		Color3.new(0, 0, 0),
		Enum.Material.SmoothPlastic,
		nil
	)
	root.Transparency = 1
	model.PrimaryPart = root

	makePart(
		model,
		"BroodingGuestBody",
		Vector3.new(2.2, 4.2, 1.25),
		root.CFrame,
		Color3.fromRGB(22, 24, 31),
		Enum.Material.SmoothPlastic,
		nil
	)
	makePart(
		model,
		"BroodingGuestCape",
		Vector3.new(4.7, 5.2, 0.35),
		root.CFrame * CFrame.new(0, -0.25, 0.72),
		Color3.fromRGB(14, 15, 21),
		Enum.Material.Fabric,
		nil
	)
	local head = makePart(
		model,
		"BroodingGuestMask",
		Vector3.new(1.65, 1.8, 1.45),
		root.CFrame * CFrame.new(0, 2.9, 0),
		Color3.fromRGB(30, 32, 40),
		Enum.Material.SmoothPlastic,
		nil
	)
	makePart(
		model,
		"LeftEar",
		Vector3.new(0.35, 1.2, 0.45),
		head.CFrame * CFrame.new(-0.52, 1.15, 0),
		Color3.fromRGB(25, 27, 34),
		Enum.Material.SmoothPlastic,
		nil
	)
	makePart(
		model,
		"RightEar",
		Vector3.new(0.35, 1.2, 0.45),
		head.CFrame * CFrame.new(0.52, 1.15, 0),
		Color3.fromRGB(25, 27, 34),
		Enum.Material.SmoothPlastic,
		nil
	)
	for side = -1, 1, 2 do
		makePart(
			model,
			if side == -1 then "LeftEye" else "RightEye",
			Vector3.new(0.32, 0.14, 0.08),
			head.CFrame * CFrame.new(side * 0.38, 0.1, -0.75),
			Color3.fromRGB(192, 221, 255),
			Enum.Material.Neon,
			nil
		)
	end

	return root, model
end

local function applyFinaleLighting()
	if not lightingSnapshot then
		lightingSnapshot = {
			ambient = Lighting.Ambient,
			brightness = Lighting.Brightness,
			clockTime = Lighting.ClockTime,
			outdoorAmbient = Lighting.OutdoorAmbient,
		}
	end
	Lighting.Ambient = Color3.fromRGB(24, 28, 45)
	Lighting.Brightness = 1.15
	Lighting.ClockTime = 23.3
	Lighting.OutdoorAmbient = Color3.fromRGB(35, 42, 64)
end

local function clearFinale()
	runToken += 1
	if finaleWorld then
		finaleWorld:Destroy()
		finaleWorld = nil
	end
end

local function restoreLighting()
	local snapshot = lightingSnapshot
	if not snapshot then
		return
	end
	Lighting.Ambient = snapshot.ambient
	Lighting.Brightness = snapshot.brightness
	Lighting.ClockTime = snapshot.clockTime
	Lighting.OutdoorAmbient = snapshot.outdoorAmbient
	lightingSnapshot = nil
end

function FinaleService.start(broadcastEvent: Broadcast)
	broadcast = broadcastEvent
	clearFinale()
end

function FinaleService.begin(star: Player?): (boolean, string?)
	if not star or star.Parent ~= Players then
		return false, "Bella is not connected"
	end
	local character = star.Character
	local humanoidRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not humanoidRoot or not humanoidRoot:IsA("BasePart") then
		return false, "Bella's character is not ready"
	end

	clearFinale()
	runToken += 1
	local token = runToken
	applyFinaleLighting()

	local folder = Instance.new("Folder")
	folder.Name = "BirthdayFinale"
	folder.Parent = Workspace
	finaleWorld = folder

	local center = humanoidRoot.CFrame * CFrame.new(0, -2.5, -10)
	local floor = makePart(
		folder,
		"CozyFinaleRug",
		Vector3.new(22, 0.25, 14),
		center,
		Color3.fromRGB(47, 38, 65),
		Enum.Material.Fabric,
		nil
	)
	local window = makePart(
		folder,
		"Window",
		Vector3.new(11, 8, 0.5),
		center * CFrame.new(0, 4.5, 5.8),
		Color3.fromRGB(33, 46, 69),
		Enum.Material.Glass,
		nil
	)
	window.Transparency = 0.25

	for index = 1, 10 do
		local candle = makePart(
			folder,
			`FinaleCandle{index}`,
			Vector3.new(0.22, 0.75 + (index % 3) * 0.2, 0.22),
			center * CFrame.new(-9 + index * 1.7, 0.5, if index % 2 == 0 then 5 else -5),
			Color3.fromRGB(255, 235, 211),
			Enum.Material.SmoothPlastic,
			nil
		)
		local flame = makePart(
			folder,
			`FinaleFlame{index}`,
			Vector3.new(0.24, 0.38, 0.24),
			candle.CFrame * CFrame.new(0, candle.Size.Y * 0.65, 0),
			Color3.fromRGB(255, 191, 90),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		local light = Instance.new("PointLight")
		light.Brightness = 1.2
		light.Color = flame.Color
		light.Range = 7
		light.Parent = flame
	end

	createDog(folder, Config.dogs[1].name, Config.dogs[1].color, center * CFrame.new(-2, 0.8, 1))
	createDog(folder, Config.dogs[2].name, Config.dogs[2].color, center * CFrame.new(2, 0.8, 1))

	local guestRoot, guestModel = createBroodingGuest(folder, center)
	local guestParts: { BasePart } = {}
	for _, child in guestModel:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(guestParts, child)
		end
	end
	local guestTarget = center * CFrame.new(6, 2.5, 1)
	local worldDelta = guestTarget * guestRoot.CFrame:Inverse()
	for _, guestPart in guestParts do
		TweenService:Create(
			guestPart,
			TweenInfo.new(4.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 4.5),
			{ CFrame = worldDelta * guestPart.CFrame }
		):Play()
	end

	local focus = makePart(
		folder,
		"FinaleFocus",
		Vector3.new(1, 1, 1),
		floor.CFrame * CFrame.new(0, 2.5, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		nil
	)
	focus.Transparency = 1

	if broadcast then
		broadcast("FinaleStarted", {
			messageLines = Config.finaleMessage,
			starName = Config.starName,
		})
	end
	broadcastBeat(token, 0.8, "LightsDimmed")
	broadcastBeat(token, 3.5, "Message")
	broadcastBeat(token, 8.5, "BroodingGuest")
	broadcastBeat(token, 14, "HappyBirthday")
	return true, nil
end

function FinaleService.cancel()
	clearFinale()
	restoreLighting()
end

return FinaleService
