-- Shows the join choice, then boots exactly one controller after the server
-- confirms the role so the Director never loads Star code and vice versa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local RoleChoiceScreen = require(script.Parent:WaitForChild("RoleChoiceScreen"))

local started = false

-- Render before waiting for server-created remotes so slow Studio replication
-- cannot leave a joining player looking at an unexplained empty lobby.
RoleChoiceScreen.show()

local function boot(role: Types.Role)
	if started then
		return
	end
	started = true
	RoleChoiceScreen.hide()

	if role == "Director" then
		local directorFolder = script.Parent:WaitForChild("director")
		local DirectorController = require(directorFolder:WaitForChild("DirectorController"))
		DirectorController.start()
	else
		local starFolder = script.Parent:WaitForChild("star")
		local StarController = require(starFolder:WaitForChild("StarController"))
		StarController.start()
	end
end

Net.get(Net.RoleAssigned).OnClientEvent:Connect(function(data: any)
	if type(data) == "table" and type(data.role) == "string" then
		boot(data.role :: Types.Role)
	elseif type(data) == "table" and type(data.error) == "string" then
		RoleChoiceScreen.showError(data.error)
	end
end)
