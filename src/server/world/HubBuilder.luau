--!strict

-- Builds a warm, layered party lounge while keeping stable gameplay anchors.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisualConfig = require(Shared.VisualConfig)
local VisualKit = require(script.Parent.VisualKit)
local PremiereSets = require(script.Parent.PremiereSets)
local WorldBudget = require(script.Parent.WorldBudget)

local P = VisualConfig.palette
local WORLD_NAME = "BirthdayBashWorld"

-- Endless, very gentle glow "breathing" for a neon part + its optional light.
-- Only light intensity/glow varies (no geometry moves, nothing detaches), which
-- keeps the lounge feeling alive without the parallax that reduced motion targets.
local function breatheGlow(part: BasePart, light: PointLight?, period: number, lift: number)
	local info = TweenInfo.new(period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(part, info, { Transparency = math.clamp(lift, 0, 1) }):Play()
	if light then
		TweenService:Create(light, info, { Brightness = light.Brightness * 1.5 }):Play()
	end
end

local HubBuilder = {}
local world: Folder? = nil

type BalloonData = {
	position: Vector3,
	color: Color3,
}

local function getOrCreate(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local result = Instance.new(className)
	result.Name = name
	result.Parent = Lighting
	return result
end

local function configureLighting()
	Lighting.Ambient = Color3.fromRGB(104, 79, 103)
	Lighting.Brightness = VisualConfig.lighting.hubBrightness
	Lighting.ClockTime = VisualConfig.lighting.hubClockTime
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.42
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 103, 125)
	Lighting.ShadowSoftness = 0.45

	local atmosphere = getOrCreate("Atmosphere", "BirthdayAtmosphere") :: Atmosphere
	atmosphere.Color = Color3.fromRGB(226, 203, 215)
	atmosphere.Decay = Color3.fromRGB(103, 74, 103)
	atmosphere.Density = 0.14
	atmosphere.Glare = 0.05
	atmosphere.Haze = 0.8

	local color = getOrCreate("ColorCorrectionEffect", "BirthdayColor") :: ColorCorrectionEffect
	color.Brightness = 0.015
	color.Contrast = 0.06
	color.Saturation = 0.08
	color.TintColor = Color3.fromRGB(255, 237, 229)

	local bloom = getOrCreate("BloomEffect", "BirthdayBloom") :: BloomEffect
	bloom.Intensity = 0.18
	bloom.Size = 22
	bloom.Threshold = 1.35

	local sunRays = getOrCreate("SunRaysEffect", "BirthdaySunRays") :: SunRaysEffect
	sunRays.Intensity = 0.025
	sunRays.Spread = 0.65
end

local function addBalloon(parent: Instance, position: Vector3, color: Color3, index: number)
	local balloon = VisualKit.ball(
		parent,
		`Balloon{index}`,
		Vector3.new(1.25, 1.55, 1.18),
		CFrame.new(position),
		color,
		Enum.Material.SmoothPlastic
	)
	balloon.Reflectance = 0.04
	VisualKit.cylinder(
		parent,
		`BalloonKnot{index}`,
		0.25,
		0.16,
		balloon.CFrame * CFrame.new(0, -0.88, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.Material.SmoothPlastic,
		nil
	)
	local stringPart = VisualKit.part(
		parent,
		`BalloonString{index}`,
		Vector3.new(0.035, 3.7, 0.035),
		balloon.CFrame * CFrame.new(0, -2.75, 0),
		P.linen,
		Enum.Material.SmoothPlastic,
		{ castShadow = false }
	)
	stringPart.Transparency = 0.15
end

local function addSofa(parent: Instance, cf: CFrame, color: Color3)
	VisualKit.part(
		parent,
		"SofaBase",
		Vector3.new(7.5, 1.1, 2.8),
		cf * CFrame.new(0, 0.65, 0),
		color,
		Enum.Material.Fabric,
		{ canCollide = true }
	)
	VisualKit.part(
		parent,
		"SofaBack",
		Vector3.new(7.5, 2.3, 0.7),
		cf * CFrame.new(0, 1.65, 1.05),
		color:Lerp(P.cream, 0.05),
		Enum.Material.Fabric,
		nil
	)
	for side = -1, 1, 2 do
		VisualKit.part(
			parent,
			"SofaArm",
			Vector3.new(0.7, 1.65, 2.85),
			cf * CFrame.new(side * 3.5, 1.05, 0),
			color:Lerp(P.ink, 0.08),
			Enum.Material.Fabric,
			nil
		)
	end
	for index = -1, 1 do
		VisualKit.part(
			parent,
			`SofaCushion{index + 2}`,
			Vector3.new(2.15, 0.48, 2.15),
			cf * CFrame.new(index * 2.18, 1.25, -0.2),
			P.cream:Lerp(color, 0.12),
			Enum.Material.Fabric,
			nil
		)
	end
	VisualKit.ball(
		parent,
		"SofaPillowPink",
		Vector3.new(1.35, 1.35, 0.55),
		cf * CFrame.new(-2.4, 2.05, 0.35) * CFrame.Angles(0, 0, math.rad(12)),
		P.blush,
		Enum.Material.Fabric
	)
	VisualKit.ball(
		parent,
		"SofaPillowGold",
		Vector3.new(1.2, 1.2, 0.5),
		cf * CFrame.new(2.4, 2.0, 0.4) * CFrame.Angles(0, 0, math.rad(-10)),
		P.butter,
		Enum.Material.Fabric
	)
end

local function addSideTable(parent: Instance, cf: CFrame, index: number)
	VisualKit.cylinder(
		parent,
		`TableTop{index}`,
		0.32,
		2.5,
		cf * CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		P.walnut,
		Enum.Material.Wood,
		nil
	)
	VisualKit.cylinder(
		parent,
		`TableStem{index}`,
		1.35,
		0.38,
		cf * CFrame.new(0, 0.78, 0) * CFrame.Angles(0, 0, math.rad(90)),
		P.wood,
		Enum.Material.Wood,
		nil
	)
	VisualKit.cylinder(
		parent,
		`TableFoot{index}`,
		0.2,
		1.75,
		cf * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		P.walnut,
		Enum.Material.Wood,
		nil
	)
	local lamp = VisualKit.ball(
		parent,
		`TableLamp{index}`,
		Vector3.new(0.75, 0.75, 0.75),
		cf * CFrame.new(0, 2.25, 0),
		P.flame,
		Enum.Material.Neon
	)
	local lampLight = VisualKit.pointLight(lamp, P.flame, 0.7, 8)
	breatheGlow(lamp, lampLight, 3.6, 0.12)
end

local function addPlanter(parent: Instance, cf: CFrame, index: number)
	VisualKit.cylinder(
		parent,
		`Planter{index}`,
		1.25,
		1.6,
		cf * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, 0, math.rad(90)),
		P.terracotta,
		Enum.Material.Slate,
		nil
	)
	for leaf = 1, 5 do
		local angle = math.rad((leaf - 1) * 72)
		VisualKit.ball(
			parent,
			`Planter{index}Leaf{leaf}`,
			Vector3.new(0.65, 2.25, 0.45),
			cf
				* CFrame.new(math.cos(angle) * 0.35, 2, math.sin(angle) * 0.35)
				* CFrame.Angles(math.rad(math.sin(angle) * 18), 0, math.rad(math.cos(angle) * 20)),
			P.mint:Lerp(P.ink, 0.18),
			Enum.Material.SmoothPlastic
		)
	end
end

local function addStage(parent: Instance)
	VisualKit.part(
		parent,
		"ShowStage",
		Vector3.new(30, 1.2, 12),
		CFrame.new(0, 0.55, -18),
		P.wood,
		Enum.Material.WoodPlanks,
		{ canCollide = true }
	)
	VisualKit.part(
		parent,
		"StageFront",
		Vector3.new(30.2, 1.35, 0.55),
		CFrame.new(0, 0.62, -11.8),
		P.walnut,
		Enum.Material.Wood,
		nil
	)
	VisualKit.part(
		parent,
		"StageRunner",
		Vector3.new(18, 0.12, 8),
		CFrame.new(0, 1.18, -17.8),
		P.rose,
		Enum.Material.Fabric,
		nil
	)
	for side = -1, 1, 2 do
		VisualKit.part(
			parent,
			if side == -1 then "LeftCurtain" else "RightCurtain",
			Vector3.new(4.4, 10, 0.65),
			CFrame.new(side * 12.8, 6, -23.5) * CFrame.Angles(0, 0, math.rad(side * 3)),
			P.plum,
			Enum.Material.Fabric,
			nil
		)
		VisualKit.cylinder(
			parent,
			"CurtainTie",
			0.3,
			1.1,
			CFrame.new(side * 12.2, 4.6, -23.1) * CFrame.Angles(0, 0, math.rad(90)),
			P.butter,
			Enum.Material.Fabric,
			nil
		)
	end
	local signBacking = VisualKit.part(
		parent,
		"BirthdaySignBacking",
		Vector3.new(19.5, 5.2, 0.65),
		CFrame.new(0, 8.2, -24) * CFrame.Angles(0, math.rad(180), 0),
		P.plumDeep,
		Enum.Material.Wood,
		nil
	)
	local signFace = VisualKit.part(
		parent,
		"BirthdaySign",
		Vector3.new(18.6, 4.35, 0.3),
		signBacking.CFrame * CFrame.new(0, 0, -0.48),
		P.cream,
		Enum.Material.SmoothPlastic,
		nil
	)
	VisualKit.surfaceText(signFace, "BELLA'S\nBIRTHDAY BASH", P.rose)
	for x = -8, 8, 2 do
		local marquee = VisualKit.ball(
			parent,
			`Marquee{x}`,
			Vector3.new(0.28, 0.28, 0.28),
			CFrame.new(x, 5.55, -23.58),
			P.flame,
			Enum.Material.Neon
		)
		if x == -8 or x == 0 or x == 8 then
			VisualKit.pointLight(marquee, P.flame, 0.35, 5)
		end
	end
end

local function addAnchors(parent: Instance)
	local anchors = Instance.new("Folder")
	anchors.Name = "Anchors"
	anchors.Parent = parent
	local positions: { [string]: Vector3 } = {
		HubCenter = Vector3.new(0, 0.5, 0),
		ShowStage = Vector3.new(0, 1.3, -18),
		FinaleCenter = Vector3.new(0, 1, -18),
	}
	for name, position in positions do
		local anchor = VisualKit.part(
			anchors,
			name,
			Vector3.new(1, 1, 1),
			CFrame.new(position),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			{ transparency = 1 }
		)
		anchor.CanQuery = false
	end
end

function HubBuilder.start()
	if world and world.Parent then
		return
	end
	local oldWorld = Workspace:FindFirstChild(WORLD_NAME)
	if oldWorld then
		oldWorld:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = WORLD_NAME
	folder.Parent = Workspace
	world = folder
	configureLighting()

	VisualKit.part(
		folder,
		"LoungeFloor",
		Vector3.new(54, 1, 54),
		CFrame.new(0, -0.55, -5),
		P.linen,
		Enum.Material.WoodPlanks,
		{ canCollide = true }
	)
	VisualKit.part(
		folder,
		"BackWall",
		Vector3.new(54, 15, 1),
		CFrame.new(0, 7, -25),
		P.plum:Lerp(P.cream, 0.12),
		Enum.Material.Plaster,
		{ canCollide = true }
	)
	VisualKit.part(
		folder,
		"PartyRug",
		Vector3.new(34, 0.18, 23),
		CFrame.new(0, 0.08, -3),
		P.plumDeep,
		Enum.Material.Fabric,
		nil
	)
	VisualKit.part(
		folder,
		"RugInset",
		Vector3.new(31.5, 0.06, 20.5),
		CFrame.new(0, 0.19, -3),
		P.plum,
		Enum.Material.Fabric,
		nil
	)
	for edge = -1, 1, 2 do
		VisualKit.part(
			folder,
			"RugStripe",
			Vector3.new(0.26, 0.07, 19.5),
			CFrame.new(edge * 14.8, 0.24, -3),
			P.butter,
			Enum.Material.Fabric,
			nil
		)
	end

	addStage(folder)
	addSofa(
		folder,
		CFrame.new(-17, 0, 3) * CFrame.Angles(0, math.rad(28), 0),
		P.sky:Lerp(P.plum, 0.25)
	)
	addSofa(
		folder,
		CFrame.new(17, 0, 3) * CFrame.Angles(0, math.rad(-28), 0),
		P.blush:Lerp(P.plum, 0.28)
	)
	addSideTable(folder, CFrame.new(-11.3, 0, 5.6), 1)
	addSideTable(folder, CFrame.new(11.3, 0, 5.6), 2)
	addPlanter(folder, CFrame.new(-23, 0, -20.5), 1)
	addPlanter(folder, CFrame.new(23, 0, -20.5), 2)

	local balloons: { BalloonData } = {
		{ position = Vector3.new(-11, 6.2, -22.5), color = P.blush },
		{ position = Vector3.new(-8.7, 7.7, -22.6), color = P.sky },
		{ position = Vector3.new(9, 7.2, -22.6), color = P.butter },
		{ position = Vector3.new(11.7, 5.9, -22.4), color = P.blush },
		{ position = Vector3.new(-21, 6.3, 6), color = P.sky },
		{ position = Vector3.new(21, 6.5, 6), color = P.butter },
	}
	for index, data in balloons do
		addBalloon(folder, data.position, data.color, index)
	end

	VisualKit.part(
		folder,
		"LightCable",
		Vector3.new(49, 0.045, 0.045),
		CFrame.new(0, 11.5, -7) * CFrame.Angles(0, 0, math.rad(-2)),
		P.ink,
		Enum.Material.SmoothPlastic,
		{ castShadow = false }
	)
	for index = 1, 12 do
		local x = -22 + (index - 1) * 4
		local y = 10.7 + math.sin(index * 0.7) * 0.55
		VisualKit.part(
			folder,
			`LightDrop{index}`,
			Vector3.new(0.035, 0.8, 0.035),
			CFrame.new(x, y + 0.4, -7),
			P.ink,
			Enum.Material.SmoothPlastic,
			{ castShadow = false }
		)
		local bulb = VisualKit.ball(
			folder,
			`StringLight{index}`,
			Vector3.new(0.38, 0.48, 0.38),
			CFrame.new(x, y, -7),
			if index % 3 == 0 then P.blush elseif index % 2 == 0 then P.sky else P.flame,
			Enum.Material.Neon
		)
		local bulbLight = if index % 3 == 1
			then VisualKit.pointLight(bulb, bulb.Color, 0.45, 7)
			else nil
		-- Staggered periods give the string a natural, uneven twinkle.
		breatheGlow(bulb, bulbLight, 2.1 + (index % 4) * 0.35, 0.16)
	end
	addAnchors(folder)
	PremiereSets.build(folder)
	local report = WorldBudget.audit(folder, VisualConfig.budget)
	folder:SetAttribute("BudgetLights", report.lights)
	folder:SetAttribute("BudgetTransparentDecorations", report.transparentDecorations)
	folder:SetAttribute("BudgetParticleEmitters", report.particleEmitters)
	folder:SetAttribute("WithinVisualBudget", report.withinBudget)
	if not report.withinBudget then
		warn(
			`[Bash] Authored world exceeds visual budget: {report.lights} lights, {report.transparentDecorations} transparent decorations`
		)
	end
end

function HubBuilder.getWorld(): Folder?
	return world
end

return HubBuilder
