--!strict

-- Star-side act intro / interlude cutscenes. Hard camera cuts to hub markers
-- so phase transitions read as film beats, not empty overlay waits.

local Workspace = game:GetService("Workspace")

local CutsceneCamera = require(script.Parent.CutsceneCamera)
local SoundKit = require(script.Parent.Parent.juice.SoundKit)

type Payload = { [string]: any }

local CutsceneDirector = {}

local started = false
local generation = 0
local WORLD_NAME = "BirthdayHub"

local ACT_SHOTS: { [string]: { focusName: string, offset: Vector3, lookHeight: number } } = {
	CheeseTower = {
		focusName = "Cam_CheeseTower",
		offset = Vector3.new(10, 7, 14),
		lookHeight = 2,
	},
	DogDash = {
		focusName = "Cam_DogDash",
		offset = Vector3.new(-12, 6, 10),
		lookHeight = 1.5,
	},
	SatisfyStation = {
		focusName = "Cam_SatisfyStation",
		offset = Vector3.new(8, 6.5, -12),
		lookHeight = 2,
	},
}

local function hubFolder(): Folder?
	local world = Workspace:FindFirstChild(WORLD_NAME)
	if world and world:IsA("Folder") then
		return world
	end
	return nil
end

local function findFocus(name: string): BasePart?
	local world = hubFolder()
	if not world then
		return nil
	end
	local anchors = world:FindFirstChild("Anchors")
	if anchors then
		local found = anchors:FindFirstChild(name)
		if found and found:IsA("BasePart") then
			return found
		end
	end
	local deep = world:FindFirstChild(name, true)
	if deep and deep:IsA("BasePart") then
		return deep
	end
	return nil
end

local function cutToNamed(focusName: string, offset: Vector3, lookHeight: number, fade: boolean?)
	local focus = findFocus(focusName) or findFocus("ShowStage") or findFocus("HubCenter")
	if not focus then
		return
	end
	CutsceneCamera.begin()
	CutsceneCamera.cutTo(nil, {
		focus = focus,
		offset = offset,
		lookHeight = lookHeight,
		fade = fade == true,
	})
end

local function endAfter(seconds: number, token: number)
	task.delay(seconds, function()
		if token ~= generation then
			return
		end
		CutsceneCamera.stop()
	end)
end

function CutsceneDirector.start()
	if started then
		return
	end
	started = true
end

function CutsceneDirector.handle(event: string, payload: Payload?)
	if not started then
		return
	end
	local data: Payload = payload or ({} :: Payload)
	local phase = data.phase

	if
		event == "ActIntroduction"
		or (event == "PremierePhaseChanged" and phase == "ActIntroduction")
	then
		generation += 1
		local token = generation
		local gameId = data.gameId or data.activeGameId
		local shot = if type(gameId) == "string" then ACT_SHOTS[gameId] else nil
		if shot then
			cutToNamed(shot.focusName, shot.offset, shot.lookHeight, true)
		else
			cutToNamed("ShowStage", Vector3.new(0, 8, 18), 2, true)
		end
		SoundKit.play("softChime", nil)
		endAfter(3.6, token)
		return
	end

	if
		event == "InterludeStarted" or (event == "PremierePhaseChanged" and phase == "Interlude")
	then
		generation += 1
		local token = generation
		cutToNamed("Cam_Interlude", Vector3.new(0, 9, 20), 1.5, true)
		SoundKit.play("softChime", nil)
		endAfter(5.2, token)
		return
	end

	if event == "HeadlinerReady" then
		generation += 1
		local token = generation
		cutToNamed("FinaleCenter", Vector3.new(0, 6, 16), 2, true)
		SoundKit.play("softChime", nil)
		endAfter(1.8, token)
		return
	end

	-- Hand camera back once minigame / lounge play resumes.
	if
		event == "MinigameStarted"
		or (event == "PremierePhaseChanged" and (phase == "Minigame" or phase == "Lounge"))
	then
		generation += 1
		CutsceneCamera.stop()
	end
end

function CutsceneDirector.stop()
	generation += 1
	CutsceneCamera.stop()
end

return CutsceneDirector
