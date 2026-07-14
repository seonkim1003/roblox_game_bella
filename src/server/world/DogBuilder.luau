--!strict

local VisualKit = require(script.Parent.VisualKit)

local DogBuilder = {}

export type Options = {
	pose: "Standing" | "Curled"?,
	accessoryColor: Color3?,
	showName: boolean?,
}

local function attach(root: BasePart, part: BasePart)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function piece(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = VisualKit.part(model, name, size, root.CFrame * localCFrame, color, material, {
		shape = shape,
	})
	attach(root, part)
	return part
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

	local root = VisualKit.part(
		model,
		"Root",
		Vector3.new(0.25, 0.25, 0.25),
		at,
		coat,
		Enum.Material.SmoothPlastic
	)
	root.Transparency = 1
	root.CanQuery = false
	model.PrimaryPart = root

	local curled = options ~= nil and options.pose == "Curled"
	local accent = if options and options.accessoryColor
		then options.accessoryColor
		else Color3.fromRGB(220, 139, 158)
	local darkCoat = coat:Lerp(Color3.fromRGB(30, 24, 25), 0.28)
	local warmCoat = coat:Lerp(Color3.fromRGB(255, 225, 187), 0.12)
	local bodySize = if curled then Vector3.new(2.35, 1.2, 2.75) else Vector3.new(1.35, 1.15, 3.45)
	piece(
		model,
		root,
		"Body",
		bodySize,
		CFrame.new(),
		coat,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	local headOffset = if curled
		then CFrame.new(0.65, 0.45, -0.65) * CFrame.Angles(0, math.rad(-28), 0)
		else CFrame.new(0, 0.4, -2.05)
	local head = piece(
		model,
		root,
		"Head",
		Vector3.new(1.45, 1.35, 1.35),
		headOffset,
		coat,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	piece(
		model,
		root,
		"Muzzle",
		Vector3.new(0.92, 0.58, 0.95),
		headOffset * CFrame.new(0, -0.12, -0.78),
		warmCoat,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	piece(
		model,
		root,
		"Nose",
		Vector3.new(0.32, 0.25, 0.24),
		headOffset * CFrame.new(0, -0.02, -1.22),
		Color3.fromRGB(35, 27, 30),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)

	for side = -1, 1, 2 do
		local sideName = if side == -1 then "Left" else "Right"
		piece(
			model,
			root,
			`{sideName}Ear`,
			Vector3.new(0.42, 1.2, 0.75),
			headOffset
				* CFrame.new(side * 0.62, -0.12, 0.08)
				* CFrame.Angles(0, 0, math.rad(side * 11)),
			darkCoat,
			Enum.Material.Fabric,
			Enum.PartType.Ball
		)
		piece(
			model,
			root,
			`{sideName}Eye`,
			Vector3.new(0.2, 0.22, 0.16),
			headOffset * CFrame.new(side * 0.31, 0.24, -0.63),
			Color3.fromRGB(26, 21, 26),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		piece(
			model,
			root,
			`{sideName}EyeGlint`,
			Vector3.new(0.065, 0.065, 0.055),
			headOffset * CFrame.new(side * 0.28, 0.3, -0.71),
			Color3.fromRGB(255, 250, 235),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
	end

	piece(
		model,
		root,
		"Collar",
		Vector3.new(0.18, 1.35, 1.35),
		if curled
			then CFrame.new(0.38, 0.25, -0.68) * CFrame.Angles(0, math.rad(62), 0)
			else CFrame.new(0, 0.25, -1.45) * CFrame.Angles(0, 0, math.rad(90)),
		accent,
		Enum.Material.Fabric,
		Enum.PartType.Cylinder
	)
	piece(
		model,
		root,
		"Tag",
		Vector3.new(0.25, 0.25, 0.12),
		if curled then CFrame.new(0.65, -0.05, -1.05) else CFrame.new(0, -0.18, -1.62),
		Color3.fromRGB(241, 197, 91),
		Enum.Material.Metal,
		Enum.PartType.Ball
	)

	if curled then
		piece(
			model,
			root,
			"CurledTail",
			Vector3.new(0.2, 0.2, 1.65),
			CFrame.new(-0.55, 0.25, 0.65) * CFrame.Angles(0, math.rad(42), math.rad(16)),
			darkCoat,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	else
		for index, offset in
			{
				Vector3.new(-0.44, -0.74, -1.05),
				Vector3.new(0.44, -0.74, -1.05),
				Vector3.new(-0.44, -0.74, 1.05),
				Vector3.new(0.44, -0.74, 1.05),
			}
		do
			piece(
				model,
				root,
				`Leg{index}`,
				Vector3.new(0.42, 0.72, 0.42),
				CFrame.new(offset),
				coat,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Ball
			)
			piece(
				model,
				root,
				`Paw{index}`,
				Vector3.new(0.48, 0.25, 0.62),
				CFrame.new(offset + Vector3.new(0, -0.4, -0.08)),
				darkCoat,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Ball
			)
		end
		piece(
			model,
			root,
			"Tail",
			Vector3.new(0.2, 0.2, 1.65),
			CFrame.new(0, 0.3, 2.08) * CFrame.Angles(math.rad(-22), 0, 0),
			darkCoat,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end

	if options == nil or options.showName ~= false then
		addNameplate(head, dogName, accent)
	end
	return model
end

return DogBuilder
