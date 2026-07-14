--!strict

-- Star-side act intro / interlude cutscenes. Hard camera cuts to hub markers
-- so phase transitions read as film beats, not empty overlay waits.
-- DogDash uses the live Rambo vs Gigi fight arena.

local Workspace = game:GetService("Workspace")

local CutsceneCamera = require(script.Parent.CutsceneCamera)
local SoundKit = require(script.Parent.Parent.juice.SoundKit)

type Payload = { [string]: any }

local CutsceneDirector = {}

local started = false
local generation = 0
local WORLD_NAME = "BirthdayBashWorld"
local dogFightActive = false

local ACT_SHOTS: { [string]: { focusName: string, offset: Vector3, lookHeight: number } } = {
	CheeseTower = {
		focusName = "Cam_CheeseTower",
		offset = Vector3.new(10, 7, 14),
		lookHeight = 2,
	},
	DogDash = {
		focusName = "Cam_DogFight",
		offset = Vector3.new(0, 5.5, 12),
		lookHeight = 0.8,
	},
	SatisfyStation = {
		focusName = "Cam_SatisfyStation",
		offset = Vector3.new(8, 6.5, -12),
		lookHeight = 2,
	},
}

local FIGHT_SHOTS: { [string]: { offset: Vector3, lookHeight: number } } = {
	FaceOff = { offset = Vector3.new(0, 4.8, 11), lookHeight = 0.7 },
	Charge = { offset = Vector3.new(-6, 3.8, 8), lookHeight = 0.6 },
	Clash = { offset = Vector3.new(5, 3.2, 7), lookHeight = 0.9 },
	Tussle = { offset = Vector3.new(0, 6.5, 9), lookHeight = 0.4 },
	GigiStrike = { offset = Vector3.new(-4, 3.5, 7.5), lookHeight = 0.8 },
	GigiWins = { offset = Vector3.new(2, 3.2, 8), lookHeight = 1 },
	VictoryPose = { offset = Vector3.new(0, 4.5, 10), lookHeight = 0.9 },
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
	local focus = findFocus(focusName)
		or findFocus("Cam_DogFight")
		or findFocus("HubCenter")
		or findFocus("ShowStage")
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
		if dogFightActive then
			return
		end
		CutsceneCamera.stop()
	end)
end

local function frameDogFight(beatName: string?, fade: boolean?)
	local shot = if beatName then FIGHT_SHOTS[beatName] else nil
	local offset = if shot then shot.offset else Vector3.new(0, 5.5, 12)
	local lookHeight = if shot then shot.lookHeight else 0.8
	cutToNamed("Cam_DogFight", offset, lookHeight, fade == true)
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

	if event == "DogFightStarted" then
		generation += 1
		dogFightActive = true
		frameDogFight("FaceOff", true)
		SoundKit.play("cheer", nil)
		return
	end

	if event == "DogFightBeat" then
		local beat = data.beat
		if type(beat) == "string" then
			dogFightActive = true
			frameDogFight(beat, beat == "Clash" or beat == "GigiWins")
			if beat == "Clash" or beat == "GigiWins" then
				SoundKit.play("softChime", nil)
			end
		end
		return
	end

	if event == "DogFightEnded" then
		dogFightActive = false
		generation += 1
		CutsceneCamera.stop()
		return
	end

	if
		event == "ActIntroduction"
		or (event == "PremierePhaseChanged" and phase == "ActIntroduction")
	then
		generation += 1
		local token = generation
		local gameId = data.gameId or data.activeGameId
		if gameId == "DogDash" or data.dogFight == true or dogFightActive then
			dogFightActive = true
			frameDogFight("FaceOff", true)
			SoundKit.play("softChime", nil)
			endAfter(10.5, token)
			return
		end
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
		if data.dogFight == true or data.nextGameId == "DogDash" or dogFightActive then
			dogFightActive = true
			frameDogFight("FaceOff", true)
			SoundKit.play("softChime", nil)
			endAfter(10.5, token)
			return
		end
		cutToNamed("Cam_Interlude", Vector3.new(0, 9, 20), 1.5, true)
		SoundKit.play("softChime", nil)
		endAfter(5.2, token)
		return
	end

	if event == "HeadlinerReady" then
		generation += 1
		local token = generation
		dogFightActive = false
		cutToNamed("FinaleCenter", Vector3.new(0, 6, 16), 2, true)
		SoundKit.play("softChime", nil)
		endAfter(1.8, token)
		return
	end

	-- FinalePresenter owns the camera once the personalized set starts.
	if event == "FinaleStarted" then
		generation += 1
		dogFightActive = false
		return
	end

	-- Hand camera back once minigame / lounge play resumes.
	if
		event == "MinigameStarted"
		or (event == "PremierePhaseChanged" and (phase == "Minigame" or phase == "Lounge"))
	then
		generation += 1
		dogFightActive = false
		CutsceneCamera.stop()
	end
end

function CutsceneDirector.stop()
	generation += 1
	dogFightActive = false
	CutsceneCamera.stop()
end

return CutsceneDirector
