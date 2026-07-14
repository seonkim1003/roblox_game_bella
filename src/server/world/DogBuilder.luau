--!strict

-- Motor6D-rigged dogs so DogPuppet can play walk/idle/sit/spin clips.

local VisualKit = require(script.Parent.VisualKit)
local DogPuppet = require(script.Parent.DogPuppet)

local DogBuilder = {}

export type Options = {
	pose: "Standing" | "Curled"?,
	accessoryColor: Color3?,
	showName: boolean?,
}

local function motor(
	model: Model,
	name: string,
	part0: BasePart,
	part1: BasePart,
	c0: CFrame,
	c1: CFrame?
): Motor6D
	part1.Anchored = false
	part1.Massless = true
	part1.CanCollide = false
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = c0
	joint.C1 = c1 or CFrame.identity
	joint.Parent = model
	return joint
end

local function makePart(
	model: Model,
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	return VisualKit.part(model, name, size, at, color, material, {
		shape = shape,
		canCollide = false,
	})
end

local function addNameplate(head: BasePart, name: string, accent: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nameplate"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 45
	billboard.Size = UDim2.fromOffset(116, 30)
	billboard.StudsOffset = Vector3.new(0, 1.35, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(43, 32, 48)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = name
	label.TextColor3 = Color3.fromRGB(255, 244, 225)
	label.TextScaled = true
	label.Parent = billboard
	VisualKit.corner(label, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = label
end

function DogBuilder.create(
	parent: Instance,
	dogName: string,
	coat: Color3,
	at: CFrame,
	options: Options?
): Model
	local model = Instance.new("Model")
	model.Name = dogName
	model.Parent = parent

	local root = makePart(
		model,
		"Root",
		Vector3.new(0.25, 0.25, 0.25),
		at,
		coat,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Block
	)
	root.Transparency = 1
	root.CanQuery = false
	root.Anchored = true
	model.PrimaryPart = root

	local curled = options ~= nil and options.pose == "Curled"
	local accent = if options and options.accessoryColor
		then options.accessoryColor
		else Color3.fromRGB(220, 139, 158)
	local darkCoat = coat:Lerp(Color3.fromRGB(30, 24, 25), 0.28)
	local warmCoat = coat:Lerp(Color3.fromRGB(255, 225, 187), 0.12)

	local body = makePart(
		model,
		"Body",
		Vector3.new(1.35, 1.15, 3.45),
		at,
		coat,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	motor(model, "BodyMotor", root, body, CFrame.identity)

	local head = makePart(
		model,
		"Head",
		Vector3.new(1.45, 1.35, 1.35),
		at * CFrame.new(0, 0.4, -2.05),
		coat,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	motor(model, "HeadMotor", body, head, CFrame.new(0, 0.4, -2.05))

	local muzzle = makePart(
		model,
		"Muzzle",
		Vector3.new(0.92, 0.58, 0.95),
		at * CFrame.new(0, 0.28, -2.83),
		warmCoat,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	motor(model, "MuzzleMotor", head, muzzle, CFrame.new(0, -0.12, -0.78))

	local nose = makePart(
		model,
		"Nose",
		Vector3.new(0.32, 0.25, 0.24),
		at * CFrame.new(0, 0.38, -3.27),
		Color3.fromRGB(35, 27, 30),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	motor(model, "NoseMotor", head, nose, CFrame.new(0, -0.02, -1.22))

	for side = -1, 1, 2 do
		local sideName = if side == -1 then "Left" else "Right"
		local ear = makePart(
			model,
			`{sideName}Ear`,
			Vector3.new(0.42, 1.2, 0.75),
			at * CFrame.new(side * 0.62, 0.28, -1.97),
			darkCoat,
			Enum.Material.Fabric,
			Enum.PartType.Ball
		)
		motor(
			model,
			`{sideName}EarMotor`,
			head,
			ear,
			CFrame.new(side * 0.62, -0.12, 0.08) * CFrame.Angles(0, 0, math.rad(side * 11))
		)
		local eye = makePart(
			model,
			`{sideName}Eye`,
			Vector3.new(0.2, 0.22, 0.16),
			at * CFrame.new(side * 0.31, 0.64, -2.68),
			Color3.fromRGB(26, 21, 26),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		motor(model, `{sideName}EyeMotor`, head, eye, CFrame.new(side * 0.31, 0.24, -0.63))
		local glint = makePart(
			model,
			`{sideName}EyeGlint`,
			Vector3.new(0.065, 0.065, 0.055),
			at * CFrame.new(side * 0.28, 0.7, -2.76),
			Color3.fromRGB(255, 250, 235),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		motor(model, `{sideName}GlintMotor`, head, glint, CFrame.new(side * 0.28, 0.3, -0.71))
	end

	local collar = makePart(
		model,
		"Collar",
		Vector3.new(0.18, 1.35, 1.35),
		at * CFrame.new(0, 0.25, -1.45) * CFrame.Angles(0, 0, math.rad(90)),
		accent,
		Enum.Material.Fabric,
		Enum.PartType.Cylinder
	)
	motor(
		model,
		"CollarMotor",
		body,
		collar,
		CFrame.new(0, 0.25, -1.45) * CFrame.Angles(0, 0, math.rad(90))
	)

	local tag = makePart(
		model,
		"Tag",
		Vector3.new(0.25, 0.25, 0.12),
		at * CFrame.new(0, -0.18, -1.62),
		Color3.fromRGB(241, 197, 91),
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	motor(model, "TagMotor", body, tag, CFrame.new(0, -0.18, -1.62))

	local legOffsets = {
		{ name = "FL", offset = Vector3.new(-0.44, -0.74, -1.05) },
		{ name = "FR", offset = Vector3.new(0.44, -0.74, -1.05) },
		{ name = "BL", offset = Vector3.new(-0.44, -0.74, 1.05) },
		{ name = "BR", offset = Vector3.new(0.44, -0.74, 1.05) },
	}
	for _, leg in legOffsets do
		local limb = makePart(
			model,
			`Leg{leg.name}`,
			Vector3.new(0.42, 0.72, 0.42),
			at * CFrame.new(leg.offset),
			coat,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		motor(model, `Leg{leg.name}Motor`, body, limb, CFrame.new(leg.offset))
		local paw = makePart(
			model,
			`Paw{leg.name}`,
			Vector3.new(0.48, 0.25, 0.62),
			at * CFrame.new(leg.offset + Vector3.new(0, -0.4, -0.08)),
			darkCoat,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		motor(model, `Paw{leg.name}Motor`, limb, paw, CFrame.new(0, -0.4, -0.08))
	end

	local tail = makePart(
		model,
		"Tail",
		Vector3.new(0.2, 0.2, 1.65),
		at * CFrame.new(0, 0.3, 2.08) * CFrame.Angles(math.rad(-22), 0, 0),
		darkCoat,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	motor(
		model,
		"TailMotor",
		body,
		tail,
		CFrame.new(0, 0.3, 2.08) * CFrame.Angles(math.rad(-22), 0, 0)
	)

	if options == nil or options.showName ~= false then
		addNameplate(head, dogName, accent)
	end

	DogPuppet.play(model, if curled then "Curled" else "Idle")
	return model
end

return DogBuilder
