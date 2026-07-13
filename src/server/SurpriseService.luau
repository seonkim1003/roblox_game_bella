--!strict

-- Server-authoritative M1 surprises: filtered Director messages and the
-- replicated Gigi/Rambo dog entrance.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

type Payload = { [string]: any }
type Broadcast = (event: string, payload: Payload?) -> ()
type DeliveryCheck = () -> boolean

local VALID_TRICKS: { [string]: boolean } = {
	TrotIn = true,
	Spin = true,
	Cuddle = true,
}

local DOG_LIFETIME = 12

local SurpriseService = {}

local broadcast: Broadcast? = nil
local activeDogs: Folder? = nil

local function makePart(
	model: Model,
	root: BasePart,
	name: string,
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Massless = true
	part.Anchored = true
	part.CFrame = root.CFrame * localCFrame
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Anchored = false

	return part
end

local function addNameplate(head: BasePart, dogName: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Nameplate"
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(130, 34)
	billboard.StudsOffset = Vector3.new(0, 1.35, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(35, 27, 47)
	label.BackgroundTransparency = 0.15
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = dogName
	label.TextColor3 = Color3.fromRGB(255, 244, 224)
	label.TextScaled = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
end

local function createDog(dogName: string, color: Color3, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = dogName

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.3, 0.3, 0.3)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Anchored = true
	root.CFrame = at
	root.Parent = model
	model.PrimaryPart = root

	makePart(model, root, "Body", Vector3.new(1.25, 1.05, 3.3), CFrame.new(0, 0, 0), color)
	local head = makePart(
		model,
		root,
		"Head",
		Vector3.new(1.35, 1.35, 1.25),
		CFrame.new(0, 0.38, -2.05),
		color
	)
	makePart(
		model,
		root,
		"Snout",
		Vector3.new(0.85, 0.55, 0.9),
		CFrame.new(0, 0.2, -2.95),
		color:Lerp(Color3.new(1, 1, 1), 0.08)
	)

	local earColor = color:Lerp(Color3.new(0, 0, 0), 0.22)
	makePart(
		model,
		root,
		"LeftEar",
		Vector3.new(0.28, 1.05, 0.65),
		CFrame.new(-0.72, 0.15, -2.05) * CFrame.Angles(0, 0, math.rad(12)),
		earColor
	)
	makePart(
		model,
		root,
		"RightEar",
		Vector3.new(0.28, 1.05, 0.65),
		CFrame.new(0.72, 0.15, -2.05) * CFrame.Angles(0, 0, math.rad(-12)),
		earColor
	)

	for index, offset in
		{
			Vector3.new(-0.45, -0.82, -1.05),
			Vector3.new(0.45, -0.82, -1.05),
			Vector3.new(-0.45, -0.82, 1.05),
			Vector3.new(0.45, -0.82, 1.05),
		}
	do
		makePart(
			model,
			root,
			`Leg{index}`,
			Vector3.new(0.34, 0.75, 0.34),
			CFrame.new(offset),
			color
		)
	end

	makePart(
		model,
		root,
		"Tail",
		Vector3.new(0.22, 0.22, 1.45),
		CFrame.new(0, 0.25, 2.15) * CFrame.Angles(math.rad(-28), 0, 0),
		color,
		Enum.PartType.Cylinder
	)

	local eyeColor = Color3.fromRGB(24, 20, 25)
	makePart(
		model,
		root,
		"LeftEye",
		Vector3.new(0.18, 0.18, 0.18),
		CFrame.new(-0.3, 0.62, -2.68),
		eyeColor,
		Enum.PartType.Ball
	)
	makePart(
		model,
		root,
		"RightEye",
		Vector3.new(0.18, 0.18, 0.18),
		CFrame.new(0.3, 0.62, -2.68),
		eyeColor,
		Enum.PartType.Ball
	)

	addNameplate(head, dogName)
	return model
end

local function tweenRoot(root: BasePart, target: CFrame, duration: number): Tween
	local tween = TweenService:Create(
		root,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = target }
	)
	tween:Play()
	return tween
end

local function animateTrick(root: BasePart, target: CFrame, trick: string, side: number)
	if trick == "TrotIn" then
		tweenRoot(root, target, 1.8)
	elseif trick == "Spin" then
		local arrival = tweenRoot(root, target, 0.65)
		arrival.Completed:Once(function()
			task.spawn(function()
				for quarter = 1, 4 do
					if not root.Parent then
						return
					end
					local turn = target * CFrame.Angles(0, math.rad(90 * quarter), 0)
					local spinTween = tweenRoot(root, turn, 0.22)
					spinTween.Completed:Wait()
				end
			end)
		end)
	else
		local cuddleTarget = target * CFrame.new(-0.35 * side, -0.18, 0.35)
		tweenRoot(root, cuddleTarget, 1.15)
	end
end

function SurpriseService.start(broadcastEvent: Broadcast)
	broadcast = broadcastEvent
end

function SurpriseService.isValidTrick(trick: string): boolean
	return VALID_TRICKS[trick] == true
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
		local target = humanoidRoot.CFrame * CFrame.new(side * 1.7, -1.85, -4)
		local startAt = target * CFrame.new(side * 2.5, 0, 8)
		local dog = createDog(dogConfig.name, dogConfig.color, startAt)
		dog.Parent = folder
		table.insert(names, dogConfig.name)
		local root = dog.PrimaryPart
		if root then
			animateTrick(root, target, trick, side)
		end
	end

	Debris:AddItem(folder, DOG_LIFETIME)
	task.delay(DOG_LIFETIME, function()
		if activeDogs == folder then
			activeDogs = nil
		end
	end)

	if broadcast then
		broadcast("DogsSummoned", {
			trick = trick,
			dogs = names,
		})
	end

	return true, nil
end

function SurpriseService.sendMessage(
	sender: Player,
	recipient: Player,
	text: string,
	canDeliver: DeliveryCheck
): (boolean, string?, boolean)
	if sender.Parent ~= Players or recipient.Parent ~= Players or not canDeliver() then
		return false, "Bella is not connected", false
	end

	-- Local multi-client tests use synthetic negative user IDs, which Roblox's
	-- filtering service cannot process. Keep the bypass both Studio-only and
	-- synthetic-ID-only so every production message still goes through Roblox.
	local isStudioPreview = RunService:IsStudio() and sender.UserId <= 0
	local deliveredText = `[Studio preview] {text}`
	if not isStudioPreview then
		local filterSuccess, filterResult = pcall(function()
			return TextService:FilterStringAsync(text, sender.UserId)
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
		broadcast("MessageShown", {
			text = deliveredText,
			studioPreview = isStudioPreview,
		})
	end
	return true, nil, isStudioPreview
end

return SurpriseService
