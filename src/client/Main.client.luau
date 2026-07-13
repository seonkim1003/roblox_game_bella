-- Client bootstrap. FROZEN after Milestone 0.
-- Waits for its assigned role, then boots exactly one controller so the
-- Director never loads Star code and vice versa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local started = false

local function boot(role: Types.Role)
	if started then
		return
	end
	started = true

	if role == "Director" then
		local DirectorController = require(script.Parent.director.DirectorController)
		DirectorController.start()
	else
		local StarController = require(script.Parent.star.StarController)
		StarController.start()
	end
end

Net.get(Net.RoleAssigned).OnClientEvent:Connect(function(data: any)
	if type(data) == "table" and type(data.role) == "string" then
		boot(data.role :: Types.Role)
	end
end)
