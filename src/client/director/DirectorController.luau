--!strict

-- Director client networking boundary. DirectorPanel emits intent; this
-- controller sends commands and renders only server events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local DirectorPanel = require(script.Parent.DirectorPanel)

type Payload = { [string]: any }

local DirectorController = {}

local started = false

local function payloadOf(message: any): Payload
	if type(message.payload) == "table" then
		return message.payload
	end
	return {}
end

function DirectorController.start()
	if started then
		return
	end
	started = true

	local commandRemote = Net.get(Net.DirectorCommand)
	local panel = DirectorPanel.new(function(action: string, payload: Payload?)
		commandRemote:FireServer({ action = action, payload = payload })
	end)

	Net.get(Net.ShowEvent).OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" or type(message.event) ~= "string" then
			return
		end

		local event = message.event
		local payload = payloadOf(message)
		if event == "ShowState" then
			panel.applyState(payload)
		elseif event == "PhaseChanged" then
			local phase = payload.phase
			if type(phase) == "string" then
				panel.setPhase(phase, nil)
			end
		elseif event == "MinigameStarted" then
			local id = payload.id
			if type(id) == "string" then
				panel.setPhase("Minigame", id)
			end
		elseif event == "MinigameComplete" then
			panel.setNotice("Bella completed the minigame. Back to the hub!", false)
		elseif event == "MinigameEnded" then
			panel.setNotice("Minigame ended. The hub is ready for your next cue.", false)
		elseif event == "MinigameFailed" then
			panel.setNotice(
				"That minigame could not start. The show returned safely to the hub.",
				true
			)
		elseif event == "DifficultyChanged" then
			local level = payload.level
			if type(level) == "number" then
				panel.setDifficulty(level)
			end
		elseif event == "ScoreUpdate" then
			local id = payload.id
			local score = payload.score
			local progress = if type(payload.data) == "table" then payload.data else nil
			if type(id) == "string" and type(score) == "number" then
				panel.setScore(id, score, progress)
			end
		elseif event == "StarConnectionChanged" then
			local connected = payload.connected
			local name = if type(payload.name) == "string" then payload.name else nil
			if type(connected) == "boolean" then
				panel.setStarConnection(connected, name)
			end
		elseif event == "CommandAccepted" then
			local action = payload.action
			local detail = if type(payload.detail) == "string" then payload.detail else nil
			if type(action) == "string" then
				panel.commandResult(action, true, detail)
			end
		elseif event == "CommandRejected" then
			local action = payload.action
			local reason = payload.reason
			if type(action) == "string" then
				panel.commandResult(action, false, if type(reason) == "string" then reason else nil)
			end
		elseif event == "DogsSummoned" then
			local trick = payload.trick
			panel.setNotice(
				if type(trick) == "string"
					then `Gigi and Rambo are on cue: {trick}.`
					else "Gigi and Rambo are on cue.",
				false
			)
		elseif event == "MessageShown" then
			panel.setNotice("Your filtered message is now on Bella's screen.", false)
		end
	end)

	print("[Bash] Director console ready -- the show is yours.")
end

return DirectorController
