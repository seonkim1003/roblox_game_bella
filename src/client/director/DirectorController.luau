--!strict

-- Director client networking boundary. DirectorShell emits intent; this
-- controller sends commands and renders only server events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local DirectorShell = require(script.Parent.DirectorShell)

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
	local panel = DirectorShell.new(function(action: string, payload: Payload?)
		commandRemote:FireServer({ action = action, payload = payload })
	end)

	Net.get(Net.ShowEvent).OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" or type(message.event) ~= "string" then
			return
		end

		local event = message.event
		local payload = payloadOf(message)
		if event == "ShowState" then
			panel:applyState(payload)
		elseif event == "TelemetrySample" then
			panel:pushTelemetry(payload)
		elseif event == "SignificantMoment" then
			panel:pushMoment(payload)
		elseif event == "DirectorCardPlayed" then
			panel:cardPlayed(payload)
		elseif event == "IngressHealth" then
			panel:setConnectionHealth(payload)
		elseif event == "DebugTelemetryChanged" then
			panel:setDebugTelemetry(payload.enabled == true)
		elseif event == "MinigameComplete" then
			panel:setNotice("Act complete. The result is authoritative.", false)
		elseif event == "MinigameEnded" then
			panel:setNotice("The active round ended safely.", false)
		elseif event == "MinigameFailed" then
			panel:setNotice(
				"That minigame could not start. The show returned safely to the hub.",
				true
			)
		elseif event == "CommandAccepted" then
			local action = payload.action
			local detail = if type(payload.detail) == "string" then payload.detail else nil
			if type(action) == "string" then
				panel:setNotice(`{action} accepted{if detail then ` · {detail}` else ""}`, false)
			end
		elseif event == "CommandRejected" then
			local action = payload.action
			local reason = payload.reason
			if type(action) == "string" then
				panel:setNotice(if type(reason) == "string" then reason else "Cue rejected", true)
			end
		elseif event == "DogsSummoned" then
			local trick = payload.trick
			panel:setNotice(
				if type(trick) == "string"
					then `Gigi and Rambo are on cue: {trick}.`
					else "Gigi and Rambo are on cue.",
				false
			)
		elseif event == "MessageShown" then
			panel:setNotice(
				if payload.studioPreview == true
					then "Your Studio preview is now on Bella's screen."
					else "Your filtered message is now on Bella's screen.",
				false
			)
		elseif event == "SurpriseTriggered" then
			local kind = payload.kind
			panel:setNotice(
				if type(kind) == "string"
					then `{kind} is live on Bella's screen.`
					else "Surprise fired.",
				false
			)
		elseif event == "FinaleStarted" then
			panel:setNotice("Finale started. Let the moment breathe.", false)
		elseif event == "FinaleBeat" then
			local beat = payload.beat
			if beat == "BroodingGuest" then
				panel:setNotice("The brooding guest is stepping out of the shadows.", false)
			elseif beat == "HappyBirthday" then
				panel:setNotice("Happy Birthday, Bella. The keepsake is next.", false)
			end
		end
	end)

	print("[Bash] Director console ready -- the show is yours.")
end

return DirectorController
