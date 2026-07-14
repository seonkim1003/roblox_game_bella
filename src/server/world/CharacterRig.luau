--!strict

-- Builds R15 NPCs that play real Roblox AnimationTracks (not rigid CFrame glides).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimationIds = require(Shared.AnimationIds)
local VisualKit = require(script.Parent.VisualKit)

export type Appearance = {
	head: Color3?,
	torso: Color3?,
	arms: Color3?,
	legs: Color3?,
	masked: boolean?,
}

local CharacterRig = {}

local function ensureAnimator(humanoid: Humanoid): Animator
	local existing = humanoid:FindFirstChildOfClass("Animator")
	if existing then
		return existing
	end
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

function CharacterRig.stopTracks(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(0.15)
	end
end

function CharacterRig.play(
	model: Model,
	clip: string,
	looped: boolean?,
	fadeTime: number?
): AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animId = (AnimationIds :: { [string]: string })[clip]
	if type(animId) ~= "string" then
		warn(`[Bash] Unknown animation clip "{clip}"`)
		return nil
	end
	CharacterRig.stopTracks(model)
	local animator = ensureAnimator(humanoid)
	local animation = Instance.new("Animation")
	animation.Name = clip
	animation.AnimationId = animId
	animation.Parent = animator
	local ok, trackOrErr = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(`[Bash] Failed to load animation {clip}: {trackOrErr}`)
		return nil
	end
	local animTrack = trackOrErr :: AnimationTrack
	animTrack.Looped = looped == true
	animTrack.Priority = Enum.AnimationPriority.Action
	animTrack:Play(if fadeTime ~= nil then fadeTime else 0.12)
	return animTrack
end

function CharacterRig.createR15(
	parent: Instance,
	name: string,
	at: CFrame,
	appearance: Appearance?
): Model
	local desc = Instance.new("HumanoidDescription")
	local arms = if appearance and appearance.arms
		then appearance.arms
		else Color3.fromRGB(35, 37, 48)
	local legs = if appearance and appearance.legs
		then appearance.legs
		else Color3.fromRGB(24, 25, 34)
	desc.HeadColor = if appearance and appearance.head
		then appearance.head
		else Color3.fromRGB(42, 44, 56)
	desc.TorsoColor = if appearance and appearance.torso
		then appearance.torso
		else Color3.fromRGB(35, 37, 48)
	desc.LeftArmColor = arms
	desc.RightArmColor = arms
	desc.LeftLegColor = legs
	desc.RightLegColor = legs
	desc.BodyTypeScale = 0.15
	desc.ProportionScale = 0.2

	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = name
	model:PivotTo(at)
	model.Parent = parent

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
		humanoid.BreakJointsOnDeath = false
		ensureAnimator(humanoid)
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.CanCollide = false
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Massless = true
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end

	if appearance and appearance.masked then
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local mask = VisualKit.part(
				model,
				"BatMask",
				Vector3.new(1.35, 0.95, 1.15),
				head.CFrame * CFrame.new(0, 0.05, -0.05),
				Color3.fromRGB(28, 30, 38),
				Enum.Material.SmoothPlastic,
				{ shape = Enum.PartType.Ball, canCollide = false }
			)
			mask.Anchored = false
			mask.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = mask
			weld.Parent = mask
			for side = -1, 1, 2 do
				local ear = VisualKit.part(
					model,
					if side < 0 then "MaskEarL" else "MaskEarR",
					Vector3.new(0.32, 0.95, 0.4),
					head.CFrame
						* CFrame.new(side * 0.42, 0.7, 0)
						* CFrame.Angles(0, 0, math.rad(side * 12)),
					Color3.fromRGB(22, 23, 30),
					Enum.Material.SmoothPlastic,
					{ canCollide = false }
				)
				ear.Anchored = false
				ear.Massless = true
				local earWeld = Instance.new("WeldConstraint")
				earWeld.Part0 = head
				earWeld.Part1 = ear
				earWeld.Parent = ear
			end
			local cape = VisualKit.part(
				model,
				"Cape",
				Vector3.new(2.4, 3.4, 0.2),
				at * CFrame.new(0, 0.4, 0.55),
				Color3.fromRGB(18, 19, 26),
				Enum.Material.Fabric,
				{ canCollide = false }
			)
			local upperTorso = model:FindFirstChild("UpperTorso")
			local capeAnchor = if upperTorso and upperTorso:IsA("BasePart")
				then upperTorso
				else root
			if capeAnchor and capeAnchor:IsA("BasePart") then
				cape.Anchored = false
				cape.Massless = true
				cape.CFrame = capeAnchor.CFrame * CFrame.new(0, -0.6, 0.7)
				local capeWeld = Instance.new("WeldConstraint")
				capeWeld.Part0 = capeAnchor
				capeWeld.Part1 = cape
				capeWeld.Parent = cape
			end
		end
	end

	CharacterRig.play(model, "idle", true, 0)
	return model
end

-- Linear root motion while a walk AnimationTrack plays — no eased "block glide".
function CharacterRig.walkTo(model: Model, target: CFrame, duration: number, thenClip: string?)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	CharacterRig.play(model, "walk", true, 0.08)
	local tween = TweenService:Create(
		root,
		TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ CFrame = target }
	)
	tween:Play()
	tween.Completed:Once(function()
		if not model.Parent then
			return
		end
		CharacterRig.play(model, thenClip or "idle", true, 0.15)
	end)
end

return CharacterRig
