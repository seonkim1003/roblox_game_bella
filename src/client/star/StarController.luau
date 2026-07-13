--!strict
-- Bella's client shell: HUD, input, juice wiring, and minigame folder-loader.
-- New minigames = new ModuleScripts under client/minigames (or folders with init).
-- Do NOT edit Main.client — the frozen bootstrap just requires this module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local Feedback = require(script.Parent.Parent.juice.Feedback)
local SoundKit = require(script.Parent.Parent.juice.SoundKit)
local InputRouter = require(script.Parent.InputRouter)
local StarHud = require(script.Parent.StarHud)

local StarController = {}

local minigames: { [string]: Types.MinigameClient } = {}
local activeClient: Types.MinigameClient? = nil
local activeRunId: number? = nil
local eventListeners: { (string, { [string]: any }?) -> () } = {}

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
	hud:setHint("Tap / click / Space to drop")
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
		end
		return
	end

	if event == "MinigameComplete" or event == "PhaseChanged" then
		local phase = payload and payload.phase
		if event == "MinigameComplete" or phase == "Hub" or phase == "Finale" then
			stopActive()
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
	elseif event == "DirectorSignal" then
		local action = payload and payload.action
		local inner = payload and payload.payload
		if action == "Surprise" and type(inner) == "table" and type(inner.kind) == "string" then
			hud:flashSurprise(inner.kind)
			Feedback.confetti(nil)
			SoundKit.play("confetti")
		end
	end

	-- Fan out to the active minigame's onEvent subscribers (CheeseTowerBegin, etc.)
	fanOutToActive(event, payload)
end

function StarController.start()
	print("[Bash] Star ready -- enjoy the show, Bella!")

	loadMinigames()
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
