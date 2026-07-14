--!strict

-- Accepts one server-validated Host (Director) and Bella (Star) selection, then
-- keeps both clients informed. Repeated delivery covers client startup timing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

type RolesChangedCallback = () -> ()

local ASSIGNMENT_RETRIES = { 0, 1, 3 }
local SELECTION_COOLDOWN_SECONDS = 0.75

local RoleService = {}

local roleByPlayer: { [Player]: Types.Role } = {}
local rolesChangedCallbacks: { RolesChangedCallback } = {}
local directorPlayer: Player? = nil
local starPlayer: Player? = nil
local lastSelectionAt: { [Player]: number } = {}
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

local function configuredRole(player: Player): Types.Role?
	local matchesDirector = Config.directorUserId ~= 0 and player.UserId == Config.directorUserId
	local matchesStar = Config.starUserId ~= 0 and player.UserId == Config.starUserId
	if matchesDirector then
		local role: Types.Role = "Director"
		return role
	elseif matchesStar then
		local role: Types.Role = "Star"
		return role
	end
	return nil
end

local function onPlayerAdded(player: Player)
	if roleByPlayer[player] then
		deliverRole(player, roleByPlayer[player])
	end
end

local function sendSelectionError(player: Player, message: string)
	Net.get(Net.RoleAssigned):FireClient(player, { error = message })
end

local function selectionAllowed(player: Player, selectedRole: Types.Role): boolean
	local requiredRole = studioOverride() or configuredRole(player)
	if requiredRole and selectedRole ~= requiredRole then
		sendSelectionError(
			player,
			if requiredRole == "Director" then "Please choose Host." else "Please choose Bella."
		)
		return false
	end

	if
		Config.directorUserId ~= 0
		and selectedRole == "Director"
		and player.UserId ~= Config.directorUserId
	then
		sendSelectionError(player, "The Host choice is reserved.")
		return false
	elseif
		Config.starUserId ~= 0
		and selectedRole == "Star"
		and player.UserId ~= Config.starUserId
	then
		sendSelectionError(player, "The Bella choice is reserved.")
		return false
	end

	return true
end

local function onRoleSelection(player: Player, data: any)
	local now = os.clock()
	local previousSelection = lastSelectionAt[player]
	if previousSelection and now - previousSelection < SELECTION_COOLDOWN_SECONDS then
		sendSelectionError(player, "Please wait a moment, then choose again.")
		return
	end
	lastSelectionAt[player] = now

	if roleByPlayer[player] then
		deliverRole(player, roleByPlayer[player])
		return
	end
	if type(data) ~= "table" or (data.role ~= "Director" and data.role ~= "Star") then
		return
	end

	local selectedRole: Types.Role = data.role
	if not selectionAllowed(player, selectedRole) then
		return
	end
	if selectedRole == "Director" and directorPlayer then
		sendSelectionError(player, "Host has already joined. Please choose Bella.")
		return
	elseif selectedRole == "Star" and starPlayer then
		sendSelectionError(player, "Bella has already joined. Please choose Host.")
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
	lastSelectionAt[player] = nil
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
	Net.get(Net.RoleSelection).OnServerEvent:Connect(onRoleSelection)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return RoleService
