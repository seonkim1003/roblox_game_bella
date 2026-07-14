--!strict

-- Server-authoritative cozy finale set and timing. The client owns camera/text only.
-- Characters use real R15 AnimationTracks / Motor6D dog puppets — no rigid glides.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local VisualConfig = require(Shared.VisualConfig)
local CharacterRig = require(script.Parent.world.CharacterRig)
local DogBuilder = require(script.Parent.world.DogBuilder)
local DogPuppet = require(script.Parent.world.DogPuppet)
local VisualKit = require(script.Parent.world.VisualKit)

type Payload = { [string]: any }
type Broadcast = (event: string, payload: Payload?) -> ()
type Complete = () -> ()
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

local function broadcastBeat(token: number, delaySeconds: number, beat: string, extra: Payload?)
	task.delay(delaySeconds, function()
		if token ~= runToken or not finaleWorld or not finaleWorld.Parent then
			return
		end
		if broadcast then
			local payload: Payload = { beat = beat }
			if extra then
				for key, value in extra do
					payload[key] = value
				end
			end
			broadcast("FinaleBeat", payload)
		end
	end)
end

local function addShotMarker(parent: Instance, name: string, cf: CFrame)
	local marker = VisualKit.part(
		parent,
		name,
		Vector3.one,
		cf,
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		{ transparency = 1 }
	)
	marker.CanQuery = false
	return marker
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

local function summaryAccent(summary: Payload?): Color3
	local accent = if summary then summary.lightingAccent else nil
	if accent == "Sky" then
		return P.sky
	elseif accent == "Blush" then
		return P.blush
	elseif accent == "Mint" then
		return P.mint
	end
	return P.butter
end

function FinaleService.start(broadcastEvent: Broadcast)
	broadcast = broadcastEvent
	clearFinale()
end

function FinaleService.begin(
	star: Player?,
	summary: Payload?,
	onComplete: Complete?
): (boolean, string?)
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
	local accent = summaryAccent(summary)
	local accentOrb = VisualKit.ball(
		folder,
		"PerformanceAccent",
		Vector3.new(0.5, 0.5, 0.5),
		center * CFrame.new(0, 5.8, -4.8),
		accent,
		Enum.Material.Neon
	)
	VisualKit.pointLight(accentOrb, accent, 0.8, 10)
	local dogPose = if summary and summary.dogPose == "VictoryTandem" then "Standing" else "Curled"
	local dogClip = if dogPose == "Standing" then "Idle" else "Curled"

	local gigi = DogBuilder.create(
		folder,
		Config.dogs[1].name,
		Config.dogs[1].color,
		center * CFrame.new(-1.2, 0.75, 0.3),
		{ pose = dogPose :: any, accessoryColor = P.blush, showName = false }
	)
	local rambo = DogBuilder.create(
		folder,
		Config.dogs[2].name,
		Config.dogs[2].color,
		center * CFrame.new(1.4, 0.75, 0.4) * CFrame.Angles(0, math.rad(20), 0),
		{ pose = dogPose :: any, accessoryColor = P.sky, showName = false }
	)
	DogPuppet.play(gigi, dogClip :: any)
	DogPuppet.play(rambo, dogClip :: any)

	local guestStart = center * CFrame.new(9.5, 3, -4.5) * CFrame.Angles(0, math.rad(-35), 0)
	local guestEnd = center * CFrame.new(5.8, 3, 0.8) * CFrame.Angles(0, math.rad(-55), 0)
	local guest = CharacterRig.createR15(folder, "OriginalMaskedGuest", guestStart, {
		masked = true,
		head = Color3.fromRGB(42, 44, 56),
		torso = Color3.fromRGB(32, 34, 44),
		arms = Color3.fromRGB(28, 30, 40),
		legs = Color3.fromRGB(22, 23, 32),
	})

	local focus = addShotMarker(folder, "FinaleFocus", center * CFrame.new(0, 2.5, 0))
	addShotMarker(folder, "ShotWide", center * CFrame.new(0, 2.5, 0))
	addShotMarker(folder, "ShotDogs", center * CFrame.new(0.1, 1.2, 0.3))
	addShotMarker(folder, "ShotGuest", guestEnd * CFrame.new(0, 1.2, 0))
	addShotMarker(folder, "ShotBirthday", center * CFrame.new(0, 2.8, -1))
	focus.CanQuery = false

	-- Delayed entrance timed to BroodingGuest beat: walk cycle + linear root motion.
	task.delay(4.4, function()
		if token ~= runToken or not guest.Parent then
			return
		end
		CharacterRig.walkTo(guest, guestEnd, 3.2, "idle")
	end)
	task.delay(8.6, function()
		if token ~= runToken or not guest.Parent then
			return
		end
		CharacterRig.play(guest, "wave", false, 0.1)
		task.delay(2.2, function()
			if token ~= runToken or not guest.Parent then
				return
			end
			CharacterRig.play(guest, "idle", true, 0.2)
		end)
	end)
	task.delay(13.5, function()
		if token ~= runToken or not guest.Parent then
			return
		end
		CharacterRig.play(guest, "cheer", false, 0.1)
		DogPuppet.play(gigi, "Idle")
		DogPuppet.play(rambo, "Idle")
	end)

	if broadcast then
		broadcast(
			"FinaleStarted",
			{ messageLines = Config.finaleMessage, starName = Config.starName, summary = summary }
		)
	end
	broadcastBeat(token, 0.05, "Establishing")
	broadcastBeat(token, 0.8, "LightsDimmed")
	broadcastBeat(token, 2.4, "DogsResting")
	broadcastBeat(token, 3.5, "Message")
	broadcastBeat(token, 8.5, "BroodingGuest")
	broadcastBeat(token, 12, "GuestWave")
	broadcastBeat(token, 14, "HappyBirthday")
	task.delay(17.5, function()
		if token ~= runToken or not finaleWorld or not finaleWorld.Parent then
			return
		end
		if broadcast then
			broadcast("FinaleBeat", { beat = "KeepsakeReady", summary = summary })
		end
		if onComplete then
			onComplete()
		end
	end)
	return true, nil
end

function FinaleService.cancel()
	clearFinale()
	restoreLighting()
end

return FinaleService
