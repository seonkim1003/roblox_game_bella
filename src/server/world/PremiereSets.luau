--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualConfig = require(ReplicatedStorage:WaitForChild("Shared").VisualConfig)
local VisualKit = require(script.Parent.VisualKit)

local PremiereSets = {}
local P = VisualConfig.palette

local function folder(parent: Instance, name: string): Folder
	local result = Instance.new("Folder")
	result.Name = name
	result.Parent = parent
	return result
end

local function sign(parent: Instance, name: string, text: string, cf: CFrame, color: Color3)
	local backing = VisualKit.part(
		parent,
		name,
		Vector3.new(10, 3, 0.4),
		cf,
		P.plumDeep,
		Enum.Material.Wood,
		nil
	)
	VisualKit.surfaceText(backing, text, color)
end

local function cameras(parent: Instance, entries: { { string | CFrame } })
	local markers = folder(parent, "CameraMarkers")
	for _, entry in entries do
		VisualKit.cameraMarker(markers, entry[1] :: string, entry[2] :: CFrame)
	end
end

local function buildCheeseAtelier(parent: Instance)
	local set = folder(parent, "CheeseAtelier")
	local center = CFrame.new(-72, 0, -4)
	VisualKit.part(
		set,
		"AtelierFloor",
		Vector3.new(30, 0.7, 24),
		center,
		P.cream,
		Enum.Material.WoodPlanks,
		{
			canCollide = true,
		}
	)
	VisualKit.part(
		set,
		"AtelierWall",
		Vector3.new(30, 12, 0.6),
		center * CFrame.new(0, 5.5, 11.5),
		P.terracotta:Lerp(P.cream, 0.5),
		Enum.Material.Plaster,
		nil
	)
	sign(
		set,
		"AtelierSign",
		"CHEESE ATELIER",
		center * CFrame.new(0, 7.5, 11.1) * CFrame.Angles(0, math.rad(180), 0),
		P.butter
	)
	for index = -1, 1 do
		VisualKit.part(
			set,
			`Worktable{index + 2}`,
			Vector3.new(7, 1, 3.2),
			center * CFrame.new(index * 8.5, 1.2, 2),
			P.walnut,
			Enum.Material.Wood,
			nil
		)
		VisualKit.cylinder(
			set,
			`CheeseWheel{index + 2}`,
			1.4,
			3.2,
			center * CFrame.new(index * 8.5, 2.55, 2) * CFrame.Angles(0, 0, math.rad(90)),
			P.butter,
			Enum.Material.SmoothPlastic,
			nil
		)
	end
	for shelf = 1, 3 do
		VisualKit.part(
			set,
			`CheeseShelf{shelf}`,
			Vector3.new(22, 0.35, 1.4),
			center * CFrame.new(0, 2 + shelf * 1.6, 10.3),
			P.wood,
			Enum.Material.Wood,
			nil
		)
	end
	cameras(set, {
		{
			"Camera_Wide",
			center * CFrame.new(0, 8, -18) * CFrame.Angles(math.rad(-12), math.rad(180), 0),
		},
		{
			"Camera_Hero",
			center * CFrame.new(-7, 5, -8) * CFrame.Angles(math.rad(-8), math.rad(150), 0),
		},
		{
			"Camera_Result",
			center * CFrame.new(0, 4.5, -10) * CFrame.Angles(math.rad(-5), math.rad(180), 0),
		},
	})
end

local function buildGardenDash(parent: Instance)
	local set = folder(parent, "GardenDash")
	local center = CFrame.new(0, 0, 70)
	VisualKit.part(
		set,
		"GardenFloor",
		Vector3.new(34, 0.7, 38),
		center,
		P.mint:Lerp(P.cream, 0.28),
		Enum.Material.Grass,
		{ canCollide = true }
	)
	for lane = -1, 1 do
		VisualKit.part(
			set,
			`GardenLane{lane + 2}`,
			Vector3.new(4.8, 0.08, 34),
			center * CFrame.new(lane * 6, 0.4, 0),
			P.cream,
			Enum.Material.Sand,
			nil
		)
	end
	for side = -1, 1, 2 do
		for index = 1, 6 do
			VisualKit.ball(
				set,
				`Hedge{side}_{index}`,
				Vector3.new(3.2, 2.4, 3.2),
				center * CFrame.new(side * 15, 1.3, -15 + index * 5),
				P.mint:Lerp(P.ink, 0.12),
				Enum.Material.Grass
			)
		end
	end
	for side = -1, 1, 2 do
		VisualKit.cylinder(
			set,
			`TrellisPost{side}`,
			7,
			0.55,
			center * CFrame.new(side * 8, 3.5, -14) * CFrame.Angles(0, 0, math.rad(90)),
			P.wood,
			Enum.Material.Wood,
			nil
		)
	end
	VisualKit.part(
		set,
		"TrellisTop",
		Vector3.new(17, 0.6, 0.8),
		center * CFrame.new(0, 7, -14),
		P.wood,
		Enum.Material.Wood,
		nil
	)
	sign(
		set,
		"GardenSign",
		"GIGI + RAMBO\nGARDEN DASH",
		center * CFrame.new(0, 9, 17.8) * CFrame.Angles(0, math.rad(180), 0),
		P.blush
	)
	cameras(set, {
		{
			"Camera_Start",
			center * CFrame.new(0, 6, -22) * CFrame.Angles(math.rad(-10), math.rad(180), 0),
		},
		{
			"Camera_Tracking",
			center * CFrame.new(12, 4, 0) * CFrame.Angles(math.rad(-5), math.rad(90), 0),
		},
		{ "Camera_Result", center * CFrame.new(0, 5, 22) },
	})
end

local function buildDreamStudio(parent: Instance)
	local set = folder(parent, "DreamStudio")
	local center = CFrame.new(72, 0, -4)
	VisualKit.part(
		set,
		"DreamFloor",
		Vector3.new(30, 0.7, 24),
		center,
		P.plumDeep,
		Enum.Material.SmoothPlastic,
		{ canCollide = true }
	)
	VisualKit.part(
		set,
		"DreamBackdrop",
		Vector3.new(30, 12, 0.6),
		center * CFrame.new(0, 5.5, 11.5),
		P.plum,
		Enum.Material.Fabric,
		nil
	)
	for index = -2, 2 do
		local color = if index % 2 == 0 then P.blush else P.sky
		VisualKit.ball(
			set,
			`DreamOrb{index + 3}`,
			Vector3.new(2.4, 2.4, 2.4),
			center * CFrame.new(index * 4.8, 2.2 + math.abs(index) * 0.5, 7.5),
			color,
			Enum.Material.Neon
		)
	end
	VisualKit.part(
		set,
		"SatisfyTable",
		Vector3.new(20, 1.1, 8),
		center * CFrame.new(0, 1.1, 0),
		P.cream,
		Enum.Material.SmoothPlastic,
		nil
	)
	for index = -2, 2 do
		VisualKit.ball(
			set,
			`JellySample{index + 3}`,
			Vector3.new(2.6, 1.4, 2.6),
			center * CFrame.new(index * 3.5, 2.5, 0),
			if index % 2 == 0 then P.mint else P.blush,
			Enum.Material.Glass
		)
	end
	sign(
		set,
		"DreamSign",
		"ASMR DREAM STUDIO",
		center * CFrame.new(0, 8, 11.1) * CFrame.Angles(0, math.rad(180), 0),
		P.sky
	)
	cameras(set, {
		{
			"Camera_Wide",
			center * CFrame.new(0, 8, -18) * CFrame.Angles(math.rad(-14), math.rad(180), 0),
		},
		{
			"Camera_Table",
			center * CFrame.new(0, 8, -5) * CFrame.Angles(math.rad(-48), math.rad(180), 0),
		},
		{
			"Camera_Result",
			center * CFrame.new(9, 5, -9) * CFrame.Angles(math.rad(-8), math.rad(140), 0),
		},
	})
end

local function buildCorridor(parent: Instance)
	local set = folder(parent, "TransitionCorridor")
	local center = CFrame.new(0, 0, 34)
	VisualKit.part(
		set,
		"CorridorFloor",
		Vector3.new(16, 0.7, 30),
		center,
		P.walnut,
		Enum.Material.WoodPlanks,
		{ canCollide = true }
	)
	VisualKit.part(
		set,
		"CorridorRunner",
		Vector3.new(7, 0.08, 29),
		center * CFrame.new(0, 0.4, 0),
		P.rose,
		Enum.Material.Fabric,
		nil
	)
	for side = -1, 1, 2 do
		VisualKit.part(
			set,
			`CorridorWall{side}`,
			Vector3.new(0.6, 10, 30),
			center * CFrame.new(side * 8, 4.7, 0),
			P.plumDeep,
			Enum.Material.Plaster,
			nil
		)
		for frame = -2, 2 do
			VisualKit.part(
				set,
				`MemoryFrame{side}_{frame}`,
				Vector3.new(0.2, 3, 3.6),
				center * CFrame.new(side * 7.65, 4.8, frame * 5.2),
				if frame % 2 == 0 then P.butter else P.sky,
				Enum.Material.Wood,
				nil
			)
		end
	end
	cameras(set, {
		{
			"Camera_Entry",
			center * CFrame.new(0, 5, -18) * CFrame.Angles(math.rad(-5), math.rad(180), 0),
		},
		{ "Camera_Midpoint", center * CFrame.new(-5, 4, 0) * CFrame.Angles(0, math.rad(-100), 0) },
		{ "Camera_Exit", center * CFrame.new(0, 5, 18) },
	})
end

local function buildResultSet(parent: Instance)
	local set = folder(parent, "KeepsakeResultSet")
	local center = CFrame.new(0, 0, -52)
	VisualKit.part(
		set,
		"ResultFloor",
		Vector3.new(28, 0.7, 18),
		center,
		P.cream,
		Enum.Material.WoodPlanks,
		{ canCollide = true }
	)
	VisualKit.part(
		set,
		"PhotoBackdrop",
		Vector3.new(24, 11, 0.7),
		center * CFrame.new(0, 5, 8.5),
		P.blush:Lerp(P.cream, 0.45),
		Enum.Material.Fabric,
		nil
	)
	VisualKit.cylinder(
		set,
		"TrophyPodium",
		1.4,
		5,
		center * CFrame.new(0, 0.8, 1) * CFrame.Angles(0, 0, math.rad(90)),
		P.walnut,
		Enum.Material.Wood,
		nil
	)
	VisualKit.ball(
		set,
		"TrophyForm",
		Vector3.new(3, 3, 3),
		center * CFrame.new(0, 3, 1),
		P.butter,
		Enum.Material.Metal
	)
	for side = -1, 1, 2 do
		VisualKit.part(
			set,
			`PhotoWing{side}`,
			Vector3.new(4.5, 8, 0.5),
			center * CFrame.new(side * 10, 4, 8),
			if side == -1 then P.sky else P.mint,
			Enum.Material.Fabric,
			nil
		)
	end
	sign(
		set,
		"ResultSign",
		"A NIGHT TO KEEP",
		center * CFrame.new(0, 7.5, 8.05) * CFrame.Angles(0, math.rad(180), 0),
		P.rose
	)
	cameras(set, {
		{
			"Camera_Keepsake",
			center * CFrame.new(0, 5, -14) * CFrame.Angles(math.rad(-6), math.rad(180), 0),
		},
		{
			"Camera_Trophy",
			center * CFrame.new(6, 4, -7) * CFrame.Angles(math.rad(-8), math.rad(140), 0),
		},
		{
			"Camera_Photo",
			center * CFrame.new(0, 4.5, -11) * CFrame.Angles(math.rad(-4), math.rad(180), 0),
		},
	})
end

function PremiereSets.build(parent: Instance): Folder
	local old = parent:FindFirstChild("PremiereSets")
	if old then
		old:Destroy()
	end
	local root = folder(parent, "PremiereSets")
	buildCheeseAtelier(root)
	buildGardenDash(root)
	buildDreamStudio(root)
	buildCorridor(root)
	buildResultSet(root)
	return root
end

return PremiereSets
