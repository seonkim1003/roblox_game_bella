--!strict

-- Server-authoritative filtered messages, tactile surprises, and dog entrances.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local VisualConfig = require(Shared.VisualConfig)
local DogBuilder = require(script.Parent.world.DogBuilder)
local DogPuppet = require(script.Parent.world.DogPuppet)
local VisualKit = require(script.Parent.world.VisualKit)

type Payload = { [string]: any }
type Broadcast = (event: string, payload: Payload?) -> ()
type DeliveryCheck = () -> boolean

local P = VisualConfig.palette
local DOG_LIFETIME = 12
local VALID_TRICKS = { TrotIn = true, Spin = true, Cuddle = true }
local VALID_SURPRISES = { Confetti = true, Cake = true, Balloons = true, AsmrBurst = true }
local COLORS = { P.blush, P.sky, P.butter, P.mint, Color3.fromRGB(188, 151, 216) }

local SurpriseService = {}
local broadcast: Broadcast? = nil
local activeDogs: Folder? = nil
local activeSurprises: { Folder } = {}

local function surprisePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	return VisualKit.part(parent, name, size, cf, color, material, { shape = shape })
end

local function createSurpriseFolder(kind: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = `BirthdaySurprise_{kind}`
	folder.Parent = Workspace
	table.insert(activeSurprises, folder)
	Debris:AddItem(folder, 12)
	task.delay(12, function()
		local index = table.find(activeSurprises, folder)
		if index then
			table.remove(activeSurprises, index)
		end
	end)
	return folder
end

local function confettiSurprise(at: CFrame)
	local folder = createSurpriseFolder("Confetti")
	local emitterPart = surprisePart(
		folder,
		"ConfettiEmitter",
		Vector3.one,
		at * CFrame.new(0, 8, 0),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic,
		nil
	)
	emitterPart.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BirthdayConfetti"
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS[1]),
		ColorSequenceKeypoint.new(0.25, COLORS[2]),
		ColorSequenceKeypoint.new(0.5, COLORS[3]),
		ColorSequenceKeypoint.new(0.75, COLORS[4]),
		ColorSequenceKeypoint.new(1, COLORS[5]),
	})
	emitter.Drag = 1.7
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Lifetime = NumberRange.new(2.6, 4.2)
	emitter.LightEmission = 0.15
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.24),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Speed = NumberRange.new(6, 11)
	emitter.SpreadAngle = Vector2.new(58, 58)
	emitter.Parent = emitterPart
	emitter:Emit(VisualConfig.budget.maxSurpriseParticles)
end

local function cakeSurprise(at: CFrame)
	local folder = createSurpriseFolder("Cake")
	local base = at * CFrame.new(0, -2.25, -5)
	VisualKit.cylinder(
		folder,
		"PorcelainCakeStand",
		0.25,
		6.2,
		base * CFrame.Angles(0, 0, math.rad(90)),
		P.cream,
		Enum.Material.Marble,
		nil
	)
	VisualKit.cylinder(
		folder,
		"CakeStandStem",
		0.85,
		0.8,
		base * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		P.cream,
		Enum.Material.Marble,
		nil
	)
	for layer = 1, 3 do
		local diameter = 5.25 - (layer - 1) * 0.75
		local y = 0.55 + (layer - 1) * 1.08
		VisualKit.cylinder(
			folder,
			`CakeLayer{layer}`,
			1.18,
			diameter,
			base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			if layer % 2 == 0 then P.blush else Color3.fromRGB(252, 222, 197),
			Enum.Material.SmoothPlastic,
			nil
		)
		for dollop = 1, 8 do
			local angle = (dollop / 8) * math.pi * 2
			local radius = diameter * 0.39
			VisualKit.ball(
				folder,
				`Layer{layer}Frosting{dollop}`,
				Vector3.new(0.42, 0.36, 0.42),
				base * CFrame.new(math.cos(angle) * radius, y + 0.62, math.sin(angle) * radius),
				P.cream,
				Enum.Material.SmoothPlastic
			)
		end
	end
	for candle = -2, 2 do
		local stem = surprisePart(
			folder,
			`Candle{candle + 3}`,
			Vector3.new(0.18, 0.95, 0.18),
			base * CFrame.new(candle * 0.55, 4.15, 0),
			COLORS[(candle + 5) % #COLORS + 1],
			Enum.Material.SmoothPlastic,
			nil
		)
		local flame = VisualKit.ball(
			folder,
			`Flame{candle + 3}`,
			Vector3.new(0.27, 0.42, 0.27),
			stem.CFrame * CFrame.new(0, 0.67, 0),
			P.flame,
			Enum.Material.Neon
		)
		if candle == 0 then
			VisualKit.pointLight(flame, P.flame, 1, 7)
		end
	end
	local topper = surprisePart(
		folder,
		"CakeTopper",
		Vector3.new(3.4, 0.9, 0.15),
		base * CFrame.new(0, 4.55, 0),
		P.butter,
		Enum.Material.Wood,
		nil
	)
	VisualKit.surfaceText(topper, "MAKE A WISH", P.plumDeep)
end

local function balloonSurprise(at: CFrame)
	local folder = createSurpriseFolder("Balloons")
	for index = 1, 9 do
		local angle = (index / 9) * math.pi * 2
		local radius = 4 + (index % 3) * 0.8
		local cf = CFrame.new(
			at.Position
				+ Vector3.new(math.cos(angle) * radius, 3.6 + (index % 4), math.sin(angle) * radius)
		)
		local balloon = VisualKit.ball(
			folder,
			`Balloon{index}`,
			Vector3.new(1.2, 1.55, 1.16),
			cf,
			COLORS[(index - 1) % #COLORS + 1],
			Enum.Material.SmoothPlastic
		)
		balloon.Reflectance = 0.04
		VisualKit.cylinder(
			folder,
			`BalloonKnot{index}`,
			0.22,
			0.14,
			cf * CFrame.new(0, -0.88, 0) * CFrame.Angles(0, 0, math.rad(90)),
			balloon.Color,
			Enum.Material.SmoothPlastic,
			nil
		)
		local stringPart = surprisePart(
			folder,
			`BalloonString{index}`,
			Vector3.new(0.025, 3.3, 0.025),
			cf * CFrame.new(0, -2.55, 0),
			P.linen,
			Enum.Material.SmoothPlastic,
			nil
		)
		stringPart.CastShadow = false
		TweenService:Create(
			balloon,
			TweenInfo.new(
				1.5 + (index % 3) * 0.18,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			),
			{ CFrame = cf * CFrame.new(0, 0.45, 0) }
		):Play()
	end
end

local function asmrBurstSurprise(at: CFrame)
	local folder = createSurpriseFolder("AsmrBurst")
	for index = 1, 5 do
		local angle = (index / 5) * math.pi * 2
		local orb = VisualKit.ball(
			folder,
			`PearlescentBubble{index}`,
			Vector3.new(0.75, 0.75, 0.75),
			at * CFrame.new(0, 1.5, -2),
			COLORS[index],
			Enum.Material.Glass
		)
		orb.Transparency = 0.18
		local target = at
			* CFrame.new(math.cos(angle) * 5.2, 2.4 + index * 0.32, math.sin(angle) * 5.2)
		TweenService:Create(
			orb,
			TweenInfo.new(1.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = target, Size = Vector3.new(2.2, 2.2, 2.2), Transparency = 0.82 }
		):Play()
		for ringIndex = 1, 2 do
			local ring = VisualKit.cylinder(
				folder,
				`Ripple{index}_{ringIndex}`,
				0.08,
				0.7,
				at * CFrame.new(0, 0.3, -2) * CFrame.Angles(0, 0, math.rad(90)),
				COLORS[index],
				Enum.Material.Neon,
				{ transparency = 0.25 }
			)
			TweenService:Create(
				ring,
				TweenInfo.new(
					0.8 + ringIndex * 0.25,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out
				),
				{ Size = Vector3.new(0.08, 7 + ringIndex * 2, 7 + ringIndex * 2), Transparency = 1 }
			):Play()
		end
	end
end

-- Linear root motion + Motor6D limb clips. Quad eased rigid slides looked like gliding blocks.
local function moveRootLinear(root: BasePart, target: CFrame, duration: number): Tween
	local tween = TweenService:Create(
		root,
		TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = target }
	)
	tween:Play()
	return tween
end

local function animateTrick(dog: Model, target: CFrame, trick: string, side: number)
	local root = dog.PrimaryPart
	if not root then
		return
	end
	if trick == "TrotIn" then
		DogPuppet.play(dog, "Walk")
		local arrival = moveRootLinear(root, target, 1.6)
		arrival.Completed:Once(function()
			if dog.Parent then
				DogPuppet.play(dog, "Idle")
			end
		end)
	elseif trick == "Spin" then
		DogPuppet.play(dog, "Walk")
		local arrival = moveRootLinear(root, target, 0.55)
		arrival.Completed:Once(function()
			if not dog.Parent then
				return
			end
			-- Root yaw is the spin; keep Idle limb pose so body Motor6D doesn't double-rotate.
			DogPuppet.play(dog, "Idle")
			task.spawn(function()
				for quarter = 1, 4 do
					if not root.Parent then
						return
					end
					local spin = moveRootLinear(
						root,
						target * CFrame.Angles(0, math.rad(90 * quarter), 0),
						0.18
					)
					spin.Completed:Wait()
				end
				if dog.Parent then
					DogPuppet.play(dog, "Idle")
				end
			end)
		end)
	else
		-- Cuddle: trot in close, then sit with limb pose.
		local snuggle = target * CFrame.new(-0.35 * side, -0.18, 0.35)
		DogPuppet.play(dog, "Walk")
		local arrival = moveRootLinear(root, snuggle, 1.05)
		arrival.Completed:Once(function()
			if dog.Parent then
				DogPuppet.play(dog, "Sit")
			end
		end)
	end
end

function SurpriseService.start(broadcastEvent: Broadcast)
	broadcast = broadcastEvent
end

function SurpriseService.isValidTrick(trick: string): boolean
	return VALID_TRICKS[trick] == true
end

function SurpriseService.isValidSurprise(kind: string): boolean
	return VALID_SURPRISES[kind] == true
end

function SurpriseService.triggerSurprise(star: Player?, kind: string): (boolean, string?)
	if not VALID_SURPRISES[kind] then
		return false, "Choose Confetti, Cake, Balloons, or ASMR Burst"
	end
	if not star then
		return false, "Bella is not connected"
	end
	local character = star.Character
	local humanoidRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not humanoidRoot or not humanoidRoot:IsA("BasePart") then
		return false, "Bella's character is not ready"
	end
	if kind == "Confetti" then
		confettiSurprise(humanoidRoot.CFrame)
	elseif kind == "Cake" then
		cakeSurprise(humanoidRoot.CFrame)
	elseif kind == "Balloons" then
		balloonSurprise(humanoidRoot.CFrame)
	else
		asmrBurstSurprise(humanoidRoot.CFrame)
	end
	if broadcast then
		broadcast("SurpriseTriggered", { kind = kind })
	end
	return true, nil
end

function SurpriseService.summonDogs(star: Player?, trick: string): (boolean, string?)
	if not VALID_TRICKS[trick] then
		return false, "Choose Trot In, Spin, or Cuddle"
	end
	if not star then
		return false, "Bella is not connected"
	end
	local character = star.Character
	local humanoidRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not humanoidRoot or not humanoidRoot:IsA("BasePart") then
		return false, "Bella's character is not ready"
	end
	if activeDogs then
		activeDogs:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "BirthdayDogs"
	folder.Parent = Workspace
	activeDogs = folder
	local names = {}
	for index, dogConfig in Config.dogs do
		local side = if index == 1 then -1 else 1
		local target = humanoidRoot.CFrame * CFrame.new(side * 1.7, -1.75, -4)
		local dog = DogBuilder.create(
			folder,
			dogConfig.name,
			dogConfig.color,
			target * CFrame.new(side * 2.5, 0, 8),
			{
				accessoryColor = COLORS[index],
				pose = "Standing",
				showName = true,
			}
		)
		table.insert(names, dogConfig.name)
		animateTrick(dog, target, trick, side)
	end
	Debris:AddItem(folder, DOG_LIFETIME)
	task.delay(DOG_LIFETIME, function()
		if activeDogs == folder then
			activeDogs = nil
		end
	end)
	if broadcast then
		broadcast("DogsSummoned", { trick = trick, dogs = names })
	end
	return true, nil
end

function SurpriseService.sendMessage(
	sender: Player,
	recipient: Player,
	message: string,
	canDeliver: DeliveryCheck
): (boolean, string?, boolean)
	if sender.Parent ~= Players or recipient.Parent ~= Players or not canDeliver() then
		return false, "Bella is not connected", false
	end
	local isStudioPreview = RunService:IsStudio() and sender.UserId <= 0
	local deliveredText = `[Studio preview] {message}`
	if not isStudioPreview then
		local filterSuccess, filterResult = pcall(function()
			return TextService:FilterStringAsync(message, sender.UserId)
		end)
		if not filterSuccess or not filterResult then
			warn("[Bash] Could not filter Director message")
			return false, "Roblox could not filter that message; please try again", false
		end
		local broadcastSuccess, filteredText = pcall(function()
			return filterResult:GetNonChatStringForBroadcastAsync()
		end)
		if not broadcastSuccess or type(filteredText) ~= "string" then
			warn("[Bash] Could not prepare filtered Director message")
			return false, "Roblox could not prepare that message; please try again", false
		end
		deliveredText = filteredText
	end
	if sender.Parent ~= Players or recipient.Parent ~= Players or not canDeliver() then
		return false, "The show changed before that message could be delivered", false
	end
	if broadcast then
		broadcast("MessageShown", { text = deliveredText, studioPreview = isStudioPreview })
	end
	return true, nil, isStudioPreview
end

return SurpriseService
