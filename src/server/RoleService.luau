-- Assigns the Director and Star roles and tells each client which it is.
-- Owned by the Director & Show lane (Agent B).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local RoleService = {}

local roleByPlayer: { [Player]: Types.Role } = {}
local directorPlayer: Player? = nil
local starPlayer: Player? = nil

local function onPlayerAdded(player: Player)
	-- Assign the role to a typed local via direct literal assignment (no
	-- function boundary, no cast) so the singleton union type is preserved.
	local role: Types.Role = "Star"
	local matchesDirector = Config.directorUserId ~= 0 and player.UserId == Config.directorUserId
	local matchesStar = Config.starUserId ~= 0 and player.UserId == Config.starUserId
	-- Explicit director id, or (in local testing, with no id configured) the
	-- first joiner when there is no director yet.
	if matchesDirector or (directorPlayer == nil and not matchesStar) then
		role = "Director"
	end

	roleByPlayer[player] = role
	if role == "Director" then
		directorPlayer = player
	else
		starPlayer = player
	end
	Net.get(Net.RoleAssigned):FireClient(player, { role = role })
end

local function onPlayerRemoving(player: Player)
	roleByPlayer[player] = nil
	if directorPlayer == player then
		directorPlayer = nil
	end
	if starPlayer == player then
		starPlayer = nil
	end
end

function RoleService.roleOf(player: Player): Types.Role?
	return roleByPlayer[player]
end

function RoleService.getDirector(): Player?
	return directorPlayer
end

function RoleService.getStar(): Player?
	return starPlayer
end

function RoleService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return RoleService
