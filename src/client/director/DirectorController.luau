-- Your control-panel client. M0 placeholder: logs show events and fires one
-- StartHub so the full round-trip is observable.
-- The Director & Show lane (Agent B) replaces this with the real DirectorPanel UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local DirectorController = {}

function DirectorController.start()
	print("[Bash] Director ready -- you are running the show.")

	Net.get(Net.ShowEvent).OnClientEvent:Connect(function(message: any)
		if type(message) == "table" and type(message.event) == "string" then
			print(`[Bash][Director] {message.event}`)
		end
	end)

	-- M0 smoke test: kick the hub so both clients confirm the round-trip.
	task.delay(1, function()
		Net.get(Net.DirectorCommand):FireServer({ action = "StartHub" })
	end)
end

return DirectorController
