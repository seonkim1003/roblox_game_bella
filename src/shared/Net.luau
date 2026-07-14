-- Single source of truth for every RemoteEvent.
-- Server side creates the remotes; client side waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "BashRemotes"

local RoleAssigned = "Role_Assigned"
local RoleSelection = "Role_Selection"
local DirectorCommand = "Director_Command"
local ShowEvent = "Show_Event"
local MinigameScore = "Minigame_Score"

local REMOTE_NAMES = { RoleAssigned, RoleSelection, DirectorCommand, ShowEvent, MinigameScore }

local function ensureServerFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in REMOTE_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	return folder
end

local function get(name: string): RemoteEvent
	local folder: Instance
	if RunService:IsServer() then
		folder = ensureServerFolder()
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

local Net = {
	RoleAssigned = RoleAssigned,
	RoleSelection = RoleSelection,
	DirectorCommand = DirectorCommand,
	ShowEvent = ShowEvent,
	MinigameScore = MinigameScore,
	get = get,
}

return Net
