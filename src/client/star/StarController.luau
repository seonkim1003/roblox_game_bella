--!strict
-- Bella's client shell: HUD, input, juice wiring, minigame folder-loader,
-- surprise presentation hooks, and a generic finale-presenter bridge.
-- New minigames = new ModuleScripts under client/minigames (or folders with init).
-- FinalePresenter itself is owned by Agent B; this module only loads & bridges it.
-- Do NOT edit Main.client — the frozen bootstrap just requires this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local Feedback = require(script.Parent.Parent.juice.Feedback)
local SoundKit = require(script.Parent.Parent.juice.SoundKit)
local InputRouter = require(script.Parent.InputRouter)
local StarHud = require(script.Parent.StarHud)

export type FinalePresenterApi = {
	start: (self: FinalePresenterApi, payload: { [string]: any }) -> (),
	beat: (self: FinalePresenterApi, beat: string, payload: { [string]: any }?) -> (),
	stop: (self: FinalePresenterApi) -> (),
}

local StarController = {}

local minigames: { [string]: Types.MinigameClient } = {}
local activeClient: Types.MinigameClient? = nil
local activeRunId: number? = nil
local eventListeners: { (string, { [string]: any }?) -> () } = {}
local finalePresenter: FinalePresenterApi? = nil
local finaleActive = false

local input = InputRouter.new()
local hud = StarHud.new()

local function clearEventListeners()
	table.clear(eventListeners)
end

local function buildContext(minigameId: string, runId: number?): Types.ClientContext
	clearEventListeners()
	return {
		reportScore = function(score: number, data: { [string]: any }?)
			hud:setScore(score, if data and type(data.detail) == "string" then data.detail else nil)
			Net.get(Net.MinigameScore):FireServer({
				id = minigameId,
				runId = runId,
				score = score,
				data = data,
			})
		end,
		onEvent = function(callback: (event: string, payload: { [string]: any }?) -> ())
			table.insert(eventListeners, callback)
		end,
		feedback = Feedback,
		sound = SoundKit,
	}
end

local function loadMinigames()
	local folder = script.Parent.Parent:FindFirstChild("minigames")
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		-- Folder-with-init becomes a ModuleScript; nested helpers (e.g. Scoring)
		-- stay as children of that module and are never loaded here.
		if child:IsA("ModuleScript") then
			local ok, result = pcall(function()
				return (require :: any)(child)
			end)
			if ok and type(result) == "table" and type(result.id) == "string" then
				minigames[result.id] = result :: Types.MinigameClient
			else
				warn(`[Bash][Star] skipped minigame module {child.Name}`)
			end
		end
	end
end

-- Agent B owns client/finale/FinalePresenter. We load it if present and forward
-- FinaleStarted / FinaleBeat without implementing the scene ourselves.
local function loadFinalePresenter()
	local folder = script.Parent.Parent:FindFirstChild("finale")
	if not folder then
		return
	end
	local moduleScript = folder:FindFirstChild("FinalePresenter")
	if not (moduleScript and moduleScript:IsA("ModuleScript")) then
		return
	end
	local ok, result = pcall(function()
		return (require :: any)(moduleScript)
	end)
	if ok and type(result) == "table" and type(result.start) == "function" then
		finalePresenter = result :: FinalePresenterApi
	else
		warn("[Bash][Star] FinalePresenter present but failed to load")
	end
end

local function stopFinalePresenter()
	if finalePresenter and finaleActive then
		pcall(function()
			finalePresenter:stop()
		end)
	end
	finaleActive = false
end

local function presentSurprise(kind: string)
	hud:flashSurprise(kind)
	if kind == "Confetti" then
		Feedback.confetti({ amount = 48 })
		SoundKit.play("confetti")
	elseif kind == "Cake" then
		Feedback.pop(Vector3.new(0, 8, 0), {
			color = Color3.fromRGB(255, 190, 220),
			count = 28,
		})
		Feedback.confetti({ amount = 24 })
		SoundKit.play("softChime")
		SoundKit.play("pop", { speed = 0.9 })
		hud:showMessage("Cake!")
	elseif kind == "Balloons" then
		Feedback.confetti({ amount = 32 })
		Feedback.pop(Vector3.new(0, 10, -4), {
			color = Color3.fromRGB(126, 200, 255),
			count = 20,
		})
		SoundKit.play("cheer", { volume = 0.2 })
		SoundKit.play("pop", { speed = 1.35 })
		hud:showMessage("Balloons!")
	elseif kind == "AsmrBurst" then
		Feedback.pop(Vector3.new(0, 6, 0), {
			color = Color3.fromRGB(200, 255, 230),
			count = 30,
		})
		SoundKit.play("squelch")
		SoundKit.play("plop", { speed = 1.2 })
		SoundKit.play("pop", { volume = 0.22 })
		hud:showMessage("ASMR burst")
	else
		Feedback.confetti(nil)
		SoundKit.play("confetti")
	end
end

local function stopActive()
	if activeClient then
		activeClient:stop()
		activeClient = nil
	end
	activeRunId = nil
	clearEventListeners()
	input:setEnabled(false)
	hud:setHint("")
	hud:setGameplayVisible(false)
end

local function startFinalePresenter(payload: { [string]: any }?)
	stopActive()
	if finaleActive then
		return
	end
	finaleActive = true
	hud:setGameplayVisible(false)
	if finalePresenter then
		local messageLines = if payload and type(payload.messageLines) == "table"
			then payload.messageLines
			else {}
		pcall(function()
			finalePresenter:start({
				messageLines = messageLines,
				payload = payload,
			})
		end)
	else
		hud:showMessage("Finale…")
		SoundKit.play("softChime")
	end
end

local function startMinigame(id: string, runId: number?): boolean
	if activeClient and activeClient.id == id and activeRunId == runId then
		return false
	end
	local client = minigames[id]
	if not client then
		warn(`[Bash][Star] no client for minigame {id}`)
		return false
	end
	stopActive()
	activeClient = client
	activeRunId = runId
	input:setEnabled(true)
	hud:setGameplayVisible(true)
	hud:setScore(0, nil)
	if id == "DogDash" then
		hud:setHint("Swipe / ← → — catch treats, dodge puddles")
	elseif id == "SatisfyStation" then
		hud:setHint("Tap to pop/squish · drag to slice")
	else
		hud:setHint("Tap / click / Space to drop")
	end
	client:start(buildContext(id, activeRunId))
	return true
end

local function fanOutToActive(event: string, payload: { [string]: any }?)
	for _, callback in eventListeners do
		task.spawn(callback, event, payload)
	end
end

local function handleShowEvent(event: string, payload: { [string]: any }?)
	if event == "MinigameStarted" then
		local id = payload and payload.id
		local runId = payload and payload.runId
		if type(id) == "string" then
			startMinigame(id, if type(runId) == "number" then runId else nil)
		end
		return
	end
	if event == "ShowState" then
		local phase = payload and payload.phase
		local id = payload and payload.activeMinigame
		local runId = payload and payload.runId
		if phase == "Minigame" and type(id) == "string" and type(runId) == "number" then
			-- Recover when the Star's role boot happened after the original start
			-- events. The server snapshot is authoritative for the active run.
			if startMinigame(id, runId) then
				local difficulty = payload and payload.difficulty
				fanOutToActive(id .. "Begin", {
					difficulty = if type(difficulty) == "number" then difficulty else 0.5,
					resumedFromSnapshot = true,
				})
			end
		elseif type(phase) == "string" and phase ~= "Minigame" then
			stopActive()
			if phase == "Finale" then
				startFinalePresenter(payload)
			else
				stopFinalePresenter()
			end
		end
		return
	end

	if event == "MinigameComplete" or event == "PhaseChanged" then
		local phase = payload and payload.phase
		if event == "MinigameComplete" or phase == "Hub" or phase == "Finale" then
			stopActive()
		end
		-- FinaleStarted owns presentation; leaving Finale tears the presenter down.
		if type(phase) == "string" and phase ~= "Finale" then
			stopFinalePresenter()
		end
	end

	if event == "MessageShown" then
		local text = payload and payload.text
		if type(text) == "string" then
			hud:showMessage(text)
			SoundKit.play("softChime")
		end
	elseif event == "DogsSummoned" then
		hud:showMessage("Gigi & Rambo appear!")
		SoundKit.play("cheer")
	elseif event == "SurpriseTriggered" then
		local kind = payload and payload.kind
		if type(kind) == "string" then
			presentSurprise(kind)
		end
	elseif event == "DirectorSignal" then
		-- M1 compatibility path while Agent B finishes SurpriseTriggered broadcasts.
		local action = payload and payload.action
		local inner = payload and payload.payload
		if action == "Surprise" and type(inner) == "table" and type(inner.kind) == "string" then
			presentSurprise(inner.kind)
		end
	elseif event == "FinaleStarted" then
		startFinalePresenter(payload)
	elseif event == "FinaleBeat" then
		local beat = payload and payload.beat
		if type(beat) == "string" and finalePresenter and finaleActive then
			pcall(function()
				finalePresenter:beat(beat, payload)
			end)
		end
	end

	-- Fan out to the active minigame's onEvent subscribers (CheeseTowerBegin, etc.)
	fanOutToActive(event, payload)
end

function StarController.start()
	print("[Bash] Star ready -- enjoy the show, Bella!")

	loadMinigames()
	loadFinalePresenter()
	hud:mount()
	hud:setGameplayVisible(false)
	input:start()
	input:setEnabled(false)

	-- Expose input to minigames without freezing Types: they require InputRouter via
	-- StarController.getInput() so they share one router instance.
	Net.get(Net.ShowEvent).OnClientEvent:Connect(function(message: any)
		if type(message) == "table" and type(message.event) == "string" then
			handleShowEvent(message.event, message.payload)
		end
	end)
end

function StarController.getInput()
	return input
end

function StarController.getHud()
	return hud
end

return StarController
