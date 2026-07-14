--!strict

-- Server-authored Rambo vs Gigi play-fight at the hub. Gigi always comes out
-- on top. Client owns camera/caption only via DogFightBeat broadcasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local VisualConfig = require(Shared.VisualConfig)

local DogFightTimeline = require(script.Parent.DogFightTimeline)
local DogBuilder = require(script.Parent.world.DogBuilder)
local DogPuppet = require(script.Parent.world.DogPuppet)

type TimelineEvent = DogFightTimeline.Event
type TimelineState = DogFightTimeline.State
type Payload = { [string]: any }
type Broadcast = (event: string, payload: Payload?) -> ()

type ActiveFight = {
	folder: Folder,
	gigi: Model,
	rambo: Model,
	center: Vector3,
	startedAt: number,
	timeline: TimelineState,
}

local P = VisualConfig.palette
local WORLD_NAME = "BirthdayBashWorld"
local FOLDER_NAME = "DogFightArena"

local DogFightService = {}

local broadcast: Broadcast? = nil
local active: ActiveFight? = nil

local function hubFocus(): CFrame
	local world = Workspace:FindFirstChild(WORLD_NAME)
	if world and world:IsA("Folder") then
		local anchors = world:FindFirstChild("Anchors")
		if anchors then
			local mark = anchors:FindFirstChild("Cam_DogFight")
				or anchors:FindFirstChild("HubCenter")
			if mark and mark:IsA("BasePart") then
				return mark.CFrame
			end
		end
	end
	return CFrame.new(0, 0.75, 0)
end

local function moveRoot(root: BasePart?, target: CFrame, duration: number)
	if not root then
		return
	end
	local tween = TweenService:Create(
		root,
		TweenInfo.new(math.max(duration, 0.05), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = target }
	)
	tween:Play()
end

local function faceToward(from: Vector3, toward: Vector3): CFrame
	local flat = Vector3.new(toward.X - from.X, 0, toward.Z - from.Z)
	if flat.Magnitude < 0.05 then
		return CFrame.new(from)
	end
	-- Dog heads face -LookVector; lookAt points -Z toward the opponent.
	return CFrame.lookAt(from, from + flat.Unit)
end

local function emit(event: string, payload: Payload?)
	local callback = broadcast
	if callback then
		callback(event, payload)
	end
end

local function finishFight(fight: ActiveFight, reason: string): boolean
	if active ~= fight then
		return false
	end

	active = nil
	if reason ~= "Complete" then
		DogFightTimeline.cancel(fight.timeline)
	end
	if fight.folder.Parent then
		fight.folder:Destroy()
	end

	local payload: Payload = { reason = reason }
	if reason == "Complete" then
		payload.winner = "Gigi"
	end
	emit("DogFightEnded", payload)
	return true
end

local function playAnimation(fight: ActiveFight, name: string)
	local gigi = fight.gigi
	local rambo = fight.rambo
	local gigiRoot = gigi.PrimaryPart
	local ramboRoot = rambo.PrimaryPart
	local mid = fight.center

	if name == "Charge" then
		DogPuppet.play(gigi, "Walk")
		DogPuppet.play(rambo, "Walk")
		moveRoot(
			gigiRoot,
			faceToward(mid + Vector3.new(-1.05, 0, 0), mid + Vector3.new(1, 0, 0)),
			1.15
		)
		moveRoot(
			ramboRoot,
			faceToward(mid + Vector3.new(1.05, 0, 0), mid + Vector3.new(-1, 0, 0)),
			1.15
		)
	elseif name == "Clash" then
		DogPuppet.play(gigi, "Pounce")
		DogPuppet.play(rambo, "Pounce")
		moveRoot(gigiRoot, faceToward(mid + Vector3.new(-0.35, 0.55, 0.1), mid), 0.35)
		moveRoot(ramboRoot, faceToward(mid + Vector3.new(0.35, 0.55, -0.1), mid), 0.35)
	elseif string.sub(name, 1, 7) == "Tussle" then
		DogPuppet.play(gigi, "Tumble")
		DogPuppet.play(rambo, "Tumble")
		local spin = if name == "TussleA" then 1 elseif name == "TussleB" then 2 else 3
		local angle = math.rad(120 * spin)
		local gx = math.cos(angle) * 0.7
		local gz = math.sin(angle) * 0.55
		moveRoot(
			gigiRoot,
			CFrame.new(mid + Vector3.new(gx, 0.4 + spin * 0.08, gz))
				* CFrame.Angles(math.rad(spin * 40), angle, math.rad(spin * 25)),
			0.28
		)
		moveRoot(
			ramboRoot,
			CFrame.new(mid + Vector3.new(-gx, 0.35 + spin * 0.06, -gz))
				* CFrame.Angles(math.rad(-spin * 35), angle + math.pi, math.rad(-spin * 20)),
			0.28
		)
	elseif name == "GigiStrike" then
		DogPuppet.play(gigi, "Pounce")
		DogPuppet.play(rambo, "Walk")
		moveRoot(
			gigiRoot,
			faceToward(mid + Vector3.new(0.2, 0.7, 0), mid + Vector3.new(1.6, 0, 0)),
			0.4
		)
		moveRoot(
			ramboRoot,
			faceToward(mid + Vector3.new(2.4, 0.15, 0.3), mid)
				* CFrame.Angles(math.rad(70), 0, math.rad(25)),
			0.55
		)
	elseif name == "GigiWins" then
		DogPuppet.play(gigi, "Victory")
		DogPuppet.play(rambo, "Sit")
		moveRoot(
			gigiRoot,
			faceToward(mid + Vector3.new(-0.2, 0, 0), mid + Vector3.new(0, 0, -4)),
			0.45
		)
		moveRoot(ramboRoot, faceToward(mid + Vector3.new(2.6, 0, 0.45), mid), 0.35)
	elseif name == "VictoryPose" then
		DogPuppet.play(gigi, "Spin")
		DogPuppet.play(rambo, "Sit")
	elseif name == "Settle" then
		DogPuppet.play(gigi, "Idle")
		DogPuppet.play(rambo, "Sit")
	end
end

local function handleTimelineEvent(fight: ActiveFight, event: TimelineEvent): boolean
	if event.kind == "Animation" then
		if event.name then
			playAnimation(fight, event.name)
		end
	elseif event.kind == "Beat" then
		emit("DogFightBeat", {
			beat = event.name,
			line = event.line,
			winner = "Gigi",
			duration = DogFightTimeline.duration(),
		})
	elseif event.kind == "Complete" then
		finishFight(fight, "Complete")
		return false
	end
	return true
end

local function runFight(fight: ActiveFight)
	while active == fight and DogFightTimeline.isActive(fight.timeline) do
		if not fight.folder.Parent then
			finishFight(fight, "Cancelled")
			return
		end

		local elapsed = os.clock() - fight.startedAt
		local events = DogFightTimeline.advance(fight.timeline, elapsed)
		for _, event in events do
			if active ~= fight or not handleTimelineEvent(fight, event) then
				return
			end
		end
		task.wait()
	end
end

function DogFightService.start(broadcastEvent: Broadcast)
	broadcast = broadcastEvent
end

function DogFightService.isPlaying(): boolean
	local fight = active
	return fight ~= nil and fight.folder.Parent ~= nil and DogFightTimeline.isActive(fight.timeline)
end

function DogFightService.remaining(): number
	local fight = active
	if not fight or not fight.folder.Parent then
		return 0
	end
	return DogFightTimeline.remaining(fight.timeline, os.clock() - fight.startedAt)
end

function DogFightService.duration(): number
	return DogFightTimeline.duration()
end

function DogFightService.cancel()
	local fight = active
	if fight then
		finishFight(fight, "Cancelled")
	end
end

function DogFightService.play(): boolean
	local current = active
	if current and current.folder.Parent and DogFightTimeline.isActive(current.timeline) then
		return true
	elseif current then
		finishFight(current, "Cancelled")
	end

	local center = hubFocus() * CFrame.new(0, 0.25, 0)
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	local gigiConfig = Config.dogs[1]
	local ramboConfig = Config.dogs[2]
	local gigiSpawn = center.Position + Vector3.new(-3.2, 0, 0.2)
	local ramboSpawn = center.Position + Vector3.new(3.2, 0, -0.2)

	local gigi = DogBuilder.create(
		folder,
		gigiConfig.name,
		gigiConfig.color,
		faceToward(gigiSpawn, ramboSpawn),
		{ pose = "Standing", accessoryColor = P.blush, showName = true }
	)
	local rambo = DogBuilder.create(
		folder,
		ramboConfig.name,
		ramboConfig.color,
		faceToward(ramboSpawn, gigiSpawn),
		{ pose = "Standing", accessoryColor = P.sky, showName = true }
	)
	DogPuppet.play(gigi, "Idle")
	DogPuppet.play(rambo, "Idle")

	local fight: ActiveFight = {
		folder = folder,
		gigi = gigi,
		rambo = rambo,
		center = center.Position,
		startedAt = os.clock(),
		timeline = DogFightTimeline.new(),
	}
	active = fight

	emit("DogFightStarted", {
		duration = DogFightTimeline.duration(),
		dogs = { gigiConfig.name, ramboConfig.name },
		winner = "Gigi",
	})
	task.spawn(runFight, fight)
	return true
end

return DogFightService
