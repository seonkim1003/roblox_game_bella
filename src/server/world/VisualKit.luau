--!strict

local VisualKit = {}

export type PartOptions = {
	shape: Enum.PartType?,
	transparency: number?,
	canCollide: boolean?,
	castShadow: boolean?,
}

function VisualKit.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	options: PartOptions?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Anchored = true
	result.CanCollide = options ~= nil and options.canCollide == true
	result.CanQuery = result.CanCollide
	result.CanTouch = false
	result.CastShadow = options == nil or options.castShadow ~= false
	result.Color = color
	result.Material = material
	result.Shape = if options and options.shape then options.shape else Enum.PartType.Block
	result.Size = size
	result.CFrame = cf
	result.Transparency = if options and options.transparency then options.transparency else 0
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

function VisualKit.ball(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	return VisualKit.part(parent, name, size, cf, color, material, { shape = Enum.PartType.Ball })
end

function VisualKit.cylinder(
	parent: Instance,
	name: string,
	length: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	options: PartOptions?
): Part
	local result = VisualKit.part(
		parent,
		name,
		Vector3.new(length, diameter, diameter),
		cf,
		color,
		material,
		options
	)
	result.Shape = Enum.PartType.Cylinder
	return result
end

function VisualKit.corner(gui: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = gui
end

function VisualKit.surfaceText(
	part: BasePart,
	text: string,
	textColor: Color3,
	face: Enum.NormalId?
)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DecorativeSign"
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0.15
	gui.PixelsPerStud = 48
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = textColor
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(55, 38, 58)
	label.TextStrokeTransparency = 0.72
	label.Parent = gui
end

function VisualKit.pointLight(
	parent: Instance,
	color: Color3,
	brightness: number,
	range: number
): PointLight
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Color = color
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	return light
end

return VisualKit
