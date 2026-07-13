--!strict

-- Builds the shared party hub without owning any minigame runtime objects.
-- Minigames are free to create and destroy their own client-side stages.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local WORLD_NAME = "BirthdayBashWorld"

local HubBuilder = {}

local world: Folder? = nil

type BalloonData = {
	position: Vector3,
	color: Color3,
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Anchored = true
	result.CanCollide = canCollide == true
	result.CanQuery = true
	result.CanTouch = false
	result.CastShadow = true
	result.Color = color
	result.Material = material
	result.Size = size
	result.CFrame = cf
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

local function addText(adornedPart: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "PartySign"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 45
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = adornedPart

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(55, 35, 68)
	label.TextStrokeTransparency = 0.25
	label.Parent = gui
end

local function addBalloon(parent: Instance, position: Vector3, color: Color3, index: number)
	local balloon = part(
		parent,
		`Balloon{index}`,
		Vector3.new(1.15, 1.45, 1.15),
		CFrame.new(position),
		color,
		Enum.Material.SmoothPlastic,
		false
	)
	balloon.Shape = Enum.PartType.Ball

	local stringPart = part(
		parent,
		`BalloonString{index}`,
		Vector3.new(0.04, 3.5, 0.04),
		CFrame.new(position - Vector3.new(0, 2.35, 0)),
		Color3.fromRGB(231, 224, 239),
		Enum.Material.SmoothPlastic,
		false
	)
	stringPart.CastShadow = false
end

local function configureLighting()
	Lighting.Ambient = Color3.fromRGB(86, 68, 106)
	Lighting.Brightness = 2.25
	Lighting.ClockTime = 18.2
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.OutdoorAmbient = Color3.fromRGB(108, 89, 129)

	local atmosphere = Lighting:FindFirstChild("BirthdayAtmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "BirthdayAtmosphere"
		atmosphere.Parent = Lighting
	end
	if atmosphere:IsA("Atmosphere") then
		atmosphere.Color = Color3.fromRGB(211, 190, 232)
		atmosphere.Decay = Color3.fromRGB(86, 65, 108)
		atmosphere.Density = 0.18
		atmosphere.Glare = 0.08
		atmosphere.Haze = 1.2
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

	local cozy = Color3.fromRGB(49, 37, 68)
	local pink = Color3.fromRGB(255, 143, 196)
	local blue = Color3.fromRGB(126, 200, 255)
	local gold = Color3.fromRGB(255, 213, 126)

	local rug = part(
		folder,
		"PartyRug",
		Vector3.new(34, 0.18, 24),
		CFrame.new(0, 0.1, -4),
		cozy,
		Enum.Material.Fabric,
		false
	)
	rug.Shape = Enum.PartType.Block

	local stage = part(
		folder,
		"ShowStage",
		Vector3.new(28, 1.2, 12),
		CFrame.new(0, 0.55, -18),
		Color3.fromRGB(68, 50, 86),
		Enum.Material.WoodPlanks,
		true
	)
	part(
		folder,
		"StageTrim",
		Vector3.new(28.4, 0.35, 12.4),
		stage.CFrame * CFrame.new(0, 0.67, 0),
		gold,
		Enum.Material.Neon,
		false
	)

	local sign = part(
		folder,
		"BirthdaySign",
		Vector3.new(18, 5, 0.5),
		CFrame.new(0, 8, -24) * CFrame.Angles(0, math.rad(180), 0),
		Color3.fromRGB(68, 50, 86),
		Enum.Material.SmoothPlastic,
		false
	)
	addText(sign, "BELLA'S BIRTHDAY BASH", Color3.fromRGB(255, 235, 246))

	local balloonData: { BalloonData } = {
		{ position = Vector3.new(-11, 6.2, -22.5), color = pink },
		{ position = Vector3.new(-8.5, 8.1, -22.7), color = blue },
		{ position = Vector3.new(9, 7.4, -22.6), color = gold },
		{ position = Vector3.new(12, 5.8, -22.3), color = pink },
		{ position = Vector3.new(-15, 5.5, 4), color = blue },
		{ position = Vector3.new(15, 6.4, 3), color = gold },
	}
	for index, data in balloonData do
		addBalloon(folder, data.position, data.color, index)
	end

	for index = 1, 12 do
		local x = -22 + (index - 1) * 4
		local bulb = part(
			folder,
			`StringLight{index}`,
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(x, 11 + math.sin(index * 0.7), -8),
			if index % 2 == 0 then pink else gold,
			Enum.Material.Neon,
			false
		)
		bulb.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Brightness = 0.8
		light.Color = bulb.Color
		light.Range = 9
		light.Parent = bulb
	end

	local anchors = Instance.new("Folder")
	anchors.Name = "Anchors"
	anchors.Parent = folder
	local anchorPositions: { [string]: Vector3 } = {
		HubCenter = Vector3.new(0, 0.5, 0),
		ShowStage = Vector3.new(0, 1.3, -18),
		FinaleCenter = Vector3.new(0, 1, -18),
	}
	for name, position in anchorPositions do
		local anchor = part(
			anchors,
			name,
			Vector3.new(1, 1, 1),
			CFrame.new(position),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			false
		)
		anchor.Transparency = 1
		anchor.CanQuery = false
	end
end

function HubBuilder.getWorld(): Folder?
	return world
end

return HubBuilder
