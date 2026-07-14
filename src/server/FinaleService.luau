--!strict

-- Server-authoritative cozy finale set and timing. The client owns camera/text only.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local VisualConfig = require(Shared.VisualConfig)
local DogBuilder = require(script.Parent.world.DogBuilder)
local VisualKit = require(script.Parent.world.VisualKit)

type Payload = { [string]: any }
type Broadcast = (event: string, payload: Payload?) -> ()
type LightingSnapshot = {
	ambient: Color3,
	brightness: number,
	clockTime: number,
	outdoorAmbient: Color3,
	diffuse: number,
	specular: number,
}

local P = VisualConfig.palette
local FinaleService = {}
local broadcast: Broadcast? = nil
local finaleWorld: Folder? = nil
local lightingSnapshot: LightingSnapshot? = nil
local runToken = 0

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

local function weldedPiece(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = VisualKit.part(
		model,
		name,
		size,
		root.CFrame * localCFrame,
		color,
		material,
		{ shape = shape }
	)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function createMaskedGuest(parent: Instance, center: CFrame): (BasePart, Model)
	local model = Instance.new("Model")
	model.Name = "OriginalMaskedGuest"
	model.Parent = parent
	local root = VisualKit.part(
		model,
		"GuestRoot",
		Vector3.new(0.4, 0.4, 0.4),
		center * CFrame.new(8.2, 2.65, -2.5),
		P.night,
		Enum.Material.SmoothPlastic,
		{ transparency = 1 }
	)
	model.PrimaryPart = root
	weldedPiece(
		model,
		root,
		"Coat",
		Vector3.new(2.3, 4.3, 1.3),
		CFrame.new(),
		Color3.fromRGB(35, 37, 48),
		Enum.Material.Fabric,
		Enum.PartType.Block
	)
	weldedPiece(
		model,
		root,
		"Cape",
		Vector3.new(4.5, 5.15, 0.28),
		CFrame.new(0, -0.25, 0.72),
		Color3.fromRGB(20, 21, 29),
		Enum.Material.Fabric,
		Enum.PartType.Block
	)
	weldedPiece(
		model,
		root,
		"ShoulderLeft",
		Vector3.new(1.3, 0.7, 1.45),
		CFrame.new(-1.25, 1.45, 0),
		Color3.fromRGB(29, 31, 41),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	weldedPiece(
		model,
		root,
		"ShoulderRight",
		Vector3.new(1.3, 0.7, 1.45),
		CFrame.new(1.25, 1.45, 0),
		Color3.fromRGB(29, 31, 41),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	local head = CFrame.new(0, 2.9, 0)
	weldedPiece(
		model,
		root,
		"Mask",
		Vector3.new(1.7, 1.85, 1.5),
		head,
		Color3.fromRGB(42, 44, 56),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	for side = -1, 1, 2 do
		weldedPiece(
			model,
			root,
			if side == -1 then "LeftMaskPoint" else "RightMaskPoint",
			Vector3.new(0.38, 1.15, 0.48),
			head * CFrame.new(side * 0.5, 1.1, 0) * CFrame.Angles(0, 0, math.rad(side * 7)),
			Color3.fromRGB(34, 36, 46),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Block
		)
		weldedPiece(
			model,
			root,
			if side == -1 then "LeftEye" else "RightEye",
			Vector3.new(0.34, 0.13, 0.08),
			head * CFrame.new(side * 0.37, 0.12, -0.73),
			Color3.fromRGB(188, 217, 230),
			Enum.Material.Neon,
			Enum.PartType.Block
		)
	end
	weldedPiece(
		model,
		root,
		"Brooch",
		Vector3.new(0.42, 0.42, 0.16),
		CFrame.new(0, 1.25, -0.7),
		P.butter,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	return root, model
end

local function applyFinaleLighting()
	if not lightingSnapshot then
		lightingSnapshot = {
			ambient = Lighting.Ambient,
			brightness = Lighting.Brightness,
			clockTime = Lighting.ClockTime,
			outdoorAmbient = Lighting.OutdoorAmbient,
			diffuse = Lighting.EnvironmentDiffuseScale,
			specular = Lighting.EnvironmentSpecularScale,
		}
	end
	Lighting.Ambient = Color3.fromRGB(31, 34, 52)
	Lighting.Brightness = VisualConfig.lighting.finaleBrightness
	Lighting.ClockTime = VisualConfig.lighting.finaleClockTime
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.OutdoorAmbient = Color3.fromRGB(43, 49, 68)
	local color = Lighting:FindFirstChild("BirthdayColor")
	if color and color:IsA("ColorCorrectionEffect") then
		color.TintColor = Color3.fromRGB(218, 224, 244)
		color.Contrast = 0.12
		color.Saturation = -0.06
	end
	local bloom = Lighting:FindFirstChild("BirthdayBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.3
		bloom.Threshold = 1.1
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
	Lighting.EnvironmentDiffuseScale = snapshot.diffuse
	Lighting.EnvironmentSpecularScale = snapshot.specular
	local color = Lighting:FindFirstChild("BirthdayColor")
	if color and color:IsA("ColorCorrectionEffect") then
		color.TintColor = Color3.fromRGB(255, 237, 229)
		color.Contrast = 0.06
		color.Saturation = 0.08
	end
	local bloom = Lighting:FindFirstChild("BirthdayBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Intensity = 0.18
		bloom.Threshold = 1.35
	end
	lightingSnapshot = nil
end

local function clearFinale()
	runToken += 1
	if finaleWorld then
		finaleWorld:Destroy()
		finaleWorld = nil
	end
end

local function addWindow(parent: Instance, center: CFrame)
	local windowCf = center * CFrame.new(0, 5, 6)
	local glass = VisualKit.part(
		parent,
		"RainWindow",
		Vector3.new(12, 8.5, 0.35),
		windowCf,
		P.rain,
		Enum.Material.Glass,
		{ transparency = 0.3 }
	)
	glass.Reflectance = 0.06
	for x = -1, 1 do
		VisualKit.part(
			parent,
			`WindowMullion{x + 2}`,
			Vector3.new(0.28, 8.8, 0.5),
			windowCf * CFrame.new(x * 4, 0, -0.1),
			P.walnut,
			Enum.Material.Wood,
			nil
		)
	end
	VisualKit.part(
		parent,
		"WindowCrossbar",
		Vector3.new(12.3, 0.3, 0.5),
		windowCf * CFrame.new(0, 0.4, -0.1),
		P.walnut,
		Enum.Material.Wood,
		nil
	)
	VisualKit.part(
		parent,
		"WindowSill",
		Vector3.new(13, 0.55, 1.2),
		windowCf * CFrame.new(0, -4.5, -0.25),
		P.wood,
		Enum.Material.Wood,
		nil
	)
	for streak = 1, 14 do
		local x = -5.5 + ((streak * 2.37) % 11)
		local y = -3.2 + ((streak * 1.83) % 6.5)
		local rain = VisualKit.part(
			parent,
			`RainStreak{streak}`,
			Vector3.new(0.035, 0.75 + (streak % 3) * 0.35, 0.04),
			windowCf * CFrame.new(x, y, -0.22) * CFrame.Angles(0, 0, math.rad(-8)),
			Color3.fromRGB(194, 221, 235),
			Enum.Material.Neon,
			{ transparency = 0.42, castShadow = false }
		)
		TweenService:Create(
			rain,
			TweenInfo.new(
				1.5 + (streak % 4) * 0.2,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.In,
				-1
			),
			{ CFrame = rain.CFrame * CFrame.new(0, -2.2, 0), Transparency = 0.8 }
		):Play()
	end
end

local function addSetDressing(parent: Instance, center: CFrame)
	VisualKit.part(
		parent,
		"FinaleFloor",
		Vector3.new(26, 0.55, 18),
		center * CFrame.new(0, -0.38, 0),
		P.walnut,
		Enum.Material.WoodPlanks,
		{ canCollide = false }
	)
	VisualKit.part(
		parent,
		"FinaleRug",
		Vector3.new(20, 0.18, 13),
		center,
		P.plumDeep,
		Enum.Material.Fabric,
		nil
	)
	VisualKit.part(
		parent,
		"RugBorder",
		Vector3.new(18.6, 0.06, 11.6),
		center * CFrame.new(0, 0.12, 0),
		P.plum,
		Enum.Material.Fabric,
		nil
	)
	VisualKit.part(
		parent,
		"FinaleBackWall",
		Vector3.new(26, 12, 0.6),
		center * CFrame.new(0, 5.5, 6.35),
		P.night,
		Enum.Material.Plaster,
		nil
	)
	addWindow(parent, center)

	VisualKit.part(
		parent,
		"LowSofaBase",
		Vector3.new(9, 1.15, 3),
		center * CFrame.new(-5.5, 0.7, 2.8),
		P.sky:Lerp(P.plum, 0.35),
		Enum.Material.Fabric,
		nil
	)
	VisualKit.part(
		parent,
		"LowSofaBack",
		Vector3.new(9, 2.5, 0.7),
		center * CFrame.new(-5.5, 1.75, 4),
		P.sky:Lerp(P.plum, 0.42),
		Enum.Material.Fabric,
		nil
	)
	for index = -1, 1 do
		VisualKit.part(
			parent,
			`FinaleCushion{index + 2}`,
			Vector3.new(2.45, 0.42, 2.25),
			center * CFrame.new(-5.5 + index * 2.65, 1.28, 2.65),
			P.cream:Lerp(if index == 0 then P.blush else P.sky, 0.17),
			Enum.Material.Fabric,
			nil
		)
	end
	VisualKit.part(
		parent,
		"KnittedThrow",
		Vector3.new(3.2, 0.12, 3.5),
		center * CFrame.new(-7.8, 1.55, 2.6) * CFrame.Angles(0, 0, math.rad(5)),
		P.blush,
		Enum.Material.Fabric,
		nil
	)

	for index = 1, 8 do
		local x = -10.5 + index * 2.35
		local z = if index % 2 == 0 then 5.15 else -5.4
		local candle = VisualKit.cylinder(
			parent,
			`FinaleCandle{index}`,
			0.7 + (index % 3) * 0.18,
			0.22,
			center * CFrame.new(x, 0.52, z) * CFrame.Angles(0, 0, math.rad(90)),
			P.cream,
			Enum.Material.SmoothPlastic,
			nil
		)
		local flame = VisualKit.ball(
			parent,
			`FinaleFlame{index}`,
			Vector3.new(0.23, 0.36, 0.23),
			candle.CFrame * CFrame.new(0, candle.Size.X * 0.72, 0),
			P.flame,
			Enum.Material.Neon
		)
		if index % 2 == 0 then
			VisualKit.pointLight(flame, P.flame, 0.65, 6)
		end
	end
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
	addSetDressing(folder, center)
	DogBuilder.create(
		folder,
		Config.dogs[1].name,
		Config.dogs[1].color,
		center * CFrame.new(-1.2, 0.75, 0.3),
		{ pose = "Curled", accessoryColor = P.blush, showName = false }
	)
	DogBuilder.create(
		folder,
		Config.dogs[2].name,
		Config.dogs[2].color,
		center * CFrame.new(1.4, 0.75, 0.4) * CFrame.Angles(0, math.rad(20), 0),
		{ pose = "Curled", accessoryColor = P.sky, showName = false }
	)

	local guestRoot = createMaskedGuest(folder, center)
	TweenService:Create(
		guestRoot,
		TweenInfo.new(4.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 4.5),
		{ CFrame = center * CFrame.new(6.5, 2.65, 1) }
	):Play()

	local focus = VisualKit.part(
		folder,
		"FinaleFocus",
		Vector3.one,
		center * CFrame.new(0, 2.5, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		{ transparency = 1 }
	)
	focus.CanQuery = false
	if broadcast then
		broadcast(
			"FinaleStarted",
			{ messageLines = Config.finaleMessage, starName = Config.starName }
		)
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
