-- The show brain: receives Director commands, drives phases, and owns the
-- minigame lifecycle via the frozen MinigameServer interface.
-- Owned by the Director & Show lane (Agent B). Minigames come from Agent A.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)
local ShowConstants = require(Shared.ShowConstants)

local RoleService = require(script.Parent.RoleService)

local ShowDirectorService = {}

local currentPhase: Types.ShowPhase = "Lobby"
local difficulty: number = ShowConstants.DefaultDifficulty
local minigames: { [string]: Types.MinigameServer } = {}
local activeMinigame: Types.MinigameServer? = nil

local function broadcast(event: string, payload: { [string]: any }?)
	Net.get(Net.ShowEvent):FireAllClients({ event = event, payload = payload })
end

local function loadMinigames()
	local folder = script.Parent:FindFirstChild("minigames")
	if not folder then
		return
	end
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") then
			-- Cast require to bypass static path resolution for folder-loaded modules.
			local minigame = (require :: any)(module) :: Types.MinigameServer
			minigames[minigame.id] = minigame
		end
	end
end

local function buildContext(): Types.ShowContext
	return {
		star = RoleService.getStar(),
		difficulty = function()
			return difficulty
		end,
		broadcast = broadcast,
		complete = function(result: { [string]: any }?)
			if activeMinigame then
				activeMinigame:stop()
				activeMinigame = nil
			end
			currentPhase = "Hub"
			broadcast("MinigameComplete", { result = result })
		end,
	}
end

local function launchMinigame(id: string)
	local minigame = minigames[id]
	if not minigame then
		broadcast("MinigameMissing", { id = id })
		return
	end
	if activeMinigame then
		activeMinigame:stop()
	end
	activeMinigame = minigame
	currentPhase = "Minigame"
	broadcast("MinigameStarted", { id = id })
	minigame:start(buildContext())
end

local function handleCommand(player: Player, command: Types.DirectorCommand)
	if RoleService.roleOf(player) ~= "Director" then
		return
	end

	local action = command.action
	local payload = command.payload

	if action == "StartHub" then
		currentPhase = "Hub"
		broadcast("PhaseChanged", { phase = currentPhase })
	elseif action == "LaunchMinigame" then
		local id = payload and payload.id
		if type(id) == "string" then
			launchMinigame(id)
		end
	elseif action == "EndMinigame" then
		if activeMinigame then
			activeMinigame:stop()
			activeMinigame = nil
		end
		currentPhase = "Hub"
		broadcast("PhaseChanged", { phase = currentPhase })
	elseif action == "SetDifficulty" then
		local level = payload and payload.level
		if type(level) == "number" then
			difficulty = math.clamp(level, ShowConstants.MinDifficulty, ShowConstants.MaxDifficulty)
			broadcast("DifficultyChanged", { level = difficulty })
		end
	else
		-- SummonDogs / SendMessage / Surprise / StartFinale are implemented by the
		-- Director & Show lane; relaying keeps the pipeline observable in M0.
		broadcast("DirectorSignal", { action = action, payload = payload })
	end
end

function ShowDirectorService.start()
	loadMinigames()

	Net.get(Net.DirectorCommand).OnServerEvent:Connect(function(player: Player, command: any)
		if type(command) == "table" and type(command.action) == "string" then
			handleCommand(player, command)
		end
	end)

	Net.get(Net.MinigameScore).OnServerEvent:Connect(function(player: Player, data: any)
		local director = RoleService.getDirector()
		if director then
			Net.get(Net.ShowEvent):FireClient(director, {
				event = "ScoreUpdate",
				payload = { from = player.Name, data = data },
			})
		end
	end)
end

return ShowDirectorService
