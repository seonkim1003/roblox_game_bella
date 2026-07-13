--!strict

-- Assigns exactly one Director and one Star, then keeps both clients informed.
-- The repeated assignment delivery is a compatibility safeguard for the frozen
-- one-way M0 role contract, which has no client-ready handshake.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

type RolesChangedCallback = () -> ()

local ASSIGNMENT_RETRIES = { 0, 1, 3 }

local RoleService = {}

local roleByPlayer: { [Player]: Types.Role } = {}
local rolesChangedCallbacks: { RolesChangedCallback } = {}
local directorPlayer: Player? = nil
local starPlayer: Player? = nil
local started = false

local function notifyRolesChanged()
	for _, callback in rolesChangedCallbacks do
		task.spawn(callback)
	end
end

local function sendRole(player: Player, role: Types.Role)
	if player.Parent == Players then
		Net.get(Net.RoleAssigned):FireClient(player, { role = role })
	end
end

local function deliverRole(player: Player, role: Types.Role)
	for _, delaySeconds in ASSIGNMENT_RETRIES do
		task.delay(delaySeconds, function()
			if roleByPlayer[player] == role then
				sendRole(player, role)
			end
		end)
	end
end

local function studioOverride(): Types.Role?
	if not RunService:IsStudio() then
		return nil
	end

	local configured = game:GetAttribute("BashRoleOverride")
	if configured == "Director" then
		local role: Types.Role = "Director"
		return role
	elseif configured == "Star" then
		local role: Types.Role = "Star"
		return role
	end
	return nil
end

local function chooseRole(player: Player): Types.Role?
	local override = studioOverride()
	if override == "Director" and directorPlayer == nil then
		return override
	elseif override == "Star" and starPlayer == nil then
		return override
	end

	local matchesDirector = Config.directorUserId ~= 0 and player.UserId == Config.directorUserId
	local matchesStar = Config.starUserId ~= 0 and player.UserId == Config.starUserId

	if
		not directorPlayer and (matchesDirector or (Config.directorUserId == 0 and not matchesStar))
	then
		local role: Types.Role = "Director"
		return role
	elseif not starPlayer and (matchesStar or (Config.starUserId == 0 and not matchesDirector)) then
		local role: Types.Role = "Star"
		return role
	end

	return nil
end

local function onPlayerAdded(player: Player)
	if roleByPlayer[player] then
		deliverRole(player, roleByPlayer[player])
		return
	end

	local selectedRole = chooseRole(player)
	if selectedRole ~= "Director" and selectedRole ~= "Star" then
		player:Kick("This private birthday show already has its Director and Star.")
		return
	end

	local role: Types.Role = "Star"
	if selectedRole == "Director" then
		role = "Director"
	end
	roleByPlayer[player] = role
	player:SetAttribute("BashRole", role)
	if role == "Director" then
		directorPlayer = player
	else
		starPlayer = player
	end

	deliverRole(player, role)
	notifyRolesChanged()
end

local function onPlayerRemoving(player: Player)
	roleByPlayer[player] = nil
	if directorPlayer == player then
		directorPlayer = nil
	end
	if starPlayer == player then
		starPlayer = nil
	end
	notifyRolesChanged()
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

function RoleService.onRolesChanged(callback: RolesChangedCallback)
	table.insert(rolesChangedCallbacks, callback)
end

function RoleService.start()
	if started then
		return
	end
	started = true

	if Config.directorUserId ~= 0 and Config.directorUserId == Config.starUserId then
		warn("[Bash] Config directorUserId and starUserId must be different")
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return RoleService
