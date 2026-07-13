-- Bella's client shell. M0 placeholder: logs show events.
-- The Player Experience lane (Agent A) replaces this with input, camera, HUD,
-- and minigame routing via the frozen MinigameClient interface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local StarController = {}

function StarController.start()
	print("[Bash] Star ready -- enjoy the show, Bella!")

	Net.get(Net.ShowEvent).OnClientEvent:Connect(function(message: any)
		if type(message) == "table" and type(message.event) == "string" then
			print(`[Bash][Star] show event: {message.event}`)
		end
	end)
end

return StarController
