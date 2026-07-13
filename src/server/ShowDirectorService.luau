--!strict

-- Authoritative show orchestration and the single server networking boundary.
-- Agent A's minigames are discovered dynamically and used only through the
-- frozen MinigameServer interface.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local ContractValidation = require(Shared.ContractValidation)
local ShowConstants = require(Shared.ShowConstants)
local Types = require(Shared.Types)

local RoleService = require(script.Parent.RoleService)
local FinaleService = require(script.Parent.FinaleService)
local ShowState = require(script.Parent.ShowState)
local SurpriseService = require(script.Parent.SurpriseService)
local HubBuilder = require(script.Parent.world.HubBuilder)
local TokenBucket = require(script.Parent.TokenBucket)

type Payload = { [string]: any }

local MAX_MESSAGE_CHARACTERS = 160
local MAX_MESSAGE_BYTES = 600
local MAX_SCORE = 1_000_000_000
local MAX_PROGRESS_FIELDS = 12
local RECONNECT_GRACE_SECONDS = 20

local ACTION_INTERVALS: { [string]: number } = {
	DirectorIngress = 0.01,
	StartHub = 0.5,
	LaunchMinigame = 0.5,
	EndMinigame = 0.5,
	SetDifficulty = 0.05,
	SummonDogs = 1.5,
	SendMessage = 1.5,
	Surprise = 0.5,
	StartFinale = 2,
	MinigameScore = 0.04,
	RoundInput = 0.02,
	Telemetry = 0.2,
	RoundReady = 0.5,
}

local ShowDirectorService = {}

local state: ShowState.State = ShowState.new(ShowConstants.DefaultDifficulty)
local sessionId = HttpService:GenerateGUID(false)
local minigames: { [string]: Types.MinigameServer } = {}
local activeMinigame: Types.MinigameServer? = nil
local activeRoundConfig: Types.RoundConfig? = nil
local activeRunToken = 0
local requestBuckets: { [Player]: { [string]: TokenBucket.Bucket } } = {}
local lastInputSequence: { [Player]: number } = {}
local abandonToken = 0
local started = false

local function sendEvent(player: Player, event: string, payload: Payload?)
	if player.Parent ~= Players then
		return
	end
	Net.get(Net.ShowEvent):FireClient(player, { event = event, payload = payload })
end

local function broadcast(event: string, payload: Payload?)
	Net.get(Net.ShowEvent):FireAllClients({ event = event, payload = payload })
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isKnownMinigameId(id: string): boolean
	for _, knownId in ShowConstants.MinigameOrder do
		if id == knownId then
			return true
		end
	end
	return false
end

local function availableMinigames(): { string }
	local available = {}
	for _, id in ShowConstants.MinigameOrder do
		if minigames[id] then
			table.insert(available, id)
		end
	end
	return available
end

local function statePayload(reason: string): Payload
	local star = RoleService.getStar()
	local director = RoleService.getDirector()
	return {
		phase = state.phase,
		difficulty = state.difficulty,
		activeMinigame = state.activeMinigame,
		sessionId = sessionId,
		roundConfig = activeRoundConfig,
		starConnected = star ~= nil,
		starName = if star then star.DisplayName else nil,
		directorConnected = director ~= nil,
		availableMinigames = availableMinigames(),
		runId = if activeMinigame then activeRunToken else nil,
		reason = reason,
	}
end

local function publishState(reason: string)
	broadcast("ShowState", statePayload(reason))

	local director = RoleService.getDirector()
	local star = RoleService.getStar()
	if director then
		sendEvent(director, "StarConnectionChanged", {
			connected = star ~= nil,
			name = if star then star.DisplayName else nil,
		})
	end
end

local function reject(player: Player, action: string, reason: string)
	sendEvent(player, "CommandRejected", {
		action = action,
		reason = reason,
	})
end

local function accept(player: Player, action: string, detail: string?)
	sendEvent(player, "CommandAccepted", {
		action = action,
		detail = detail,
	})
end

local function consumeRateLimit(player: Player, key: string): boolean
	local now = os.clock()
	local interval = ACTION_INTERVALS[key] or 0.5
	local playerBuckets = requestBuckets[player]
	if not playerBuckets then
		playerBuckets = {}
		requestBuckets[player] = playerBuckets
	end

	local accepted, bucket = TokenBucket.consume(playerBuckets[key], now, 2, 1 / interval)
	playerBuckets[key] = bucket
	return accepted
end

local function stopActiveMinigame()
	local minigame = activeMinigame
	activeRunToken += 1
	activeMinigame = nil
	activeRoundConfig = nil
	table.clear(lastInputSequence)
	if not minigame then
		return
	end

	local success, stopError = pcall(function()
		minigame:stop()
	end)
	if not success then
		warn(`[Bash] Failed to stop {minigame.id}: {stopError}`)
	end
end

local function buildContext(
	minigame: Types.MinigameServer,
	runToken: number,
	roundConfig: Types.RoundConfig
): Types.ShowContext
	return {
		star = RoleService.getStar(),
		roundConfig = roundConfig,
		difficulty = function()
			return state.difficulty
		end,
		broadcast = broadcast,
		publishTelemetry = function(sample: Types.TelemetrySample)
			if activeRunToken ~= runToken or sample.roundId ~= roundConfig.roundId then
				return
			end
			local director = RoleService.getDirector()
			if director then
				sendEvent(director, "TelemetrySample", sample :: any)
			end
		end,
		recordMoment = function(moment: Types.SignificantGameplayMoment)
			if activeRunToken ~= runToken or moment.roundId ~= roundConfig.roundId then
				return
			end
			broadcast("SignificantMoment", moment :: any)
		end,
		complete = function(result: Payload?)
			if activeMinigame ~= minigame or activeRunToken ~= runToken then
				return
			end

			local completedId = minigame.id
			stopActiveMinigame()
			local transition = ShowState.transition(state, "MinigameComplete", { id = completedId })
			if transition.error then
				warn(`[Bash] Completion transition rejected: {transition.error}`)
				return
			end
			state = transition.state
			broadcast("MinigameComplete", {
				id = completedId,
				roundId = roundConfig.roundId,
				result = result,
			})
			broadcast("PhaseChanged", { phase = state.phase })
			publishState("MinigameComplete")
		end,
	}
end

local function loadMinigames()
	local folder = script.Parent:FindFirstChild("minigames")
	if not folder then
		return
	end

	for _, module in folder:GetChildren() do
		if not module:IsA("ModuleScript") then
			continue
		end

		local success, loaded = pcall(function()
			return (require :: any)(module)
		end)
		if not success then
			warn(`[Bash] Could not load minigame module {module.Name}: {loaded}`)
			continue
		end
		if type(loaded) ~= "table" then
			warn(`[Bash] Minigame module {module.Name} did not return a table`)
			continue
		end

		local id = loaded.id
		if type(id) ~= "string" or not isKnownMinigameId(id) then
			warn(`[Bash] Minigame module {module.Name} has an invalid id`)
			continue
		end
		if type(loaded.start) ~= "function" or type(loaded.stop) ~= "function" then
			warn(`[Bash] Minigame module {module.Name} does not implement start/stop`)
			continue
		end
		if minigames[id] then
			warn(`[Bash] Duplicate minigame id {id}; ignoring {module.Name}`)
			continue
		end

		minigames[id] = loaded :: Types.MinigameServer
	end
end

local function launchMinigame(player: Player, id: string)
	local minigame = minigames[id]
	if not minigame then
		reject(player, "LaunchMinigame", "That game is not installed yet")
		return
	end
	if not RoleService.getStar() then
		reject(player, "LaunchMinigame", "Bella is not connected")
		return
	end

	local transition = ShowState.transition(state, "LaunchMinigame", { id = id })
	if transition.error then
		reject(player, "LaunchMinigame", transition.error)
		return
	end

	stopActiveMinigame()
	state = transition.state
	activeMinigame = minigame
	activeRunToken += 1
	local runToken = activeRunToken
	local roundConfig: Types.RoundConfig = {
		sessionId = sessionId,
		roundId = HttpService:GenerateGUID(false),
		gameId = id :: Types.MinigameId,
		seed = Random.new():NextInteger(1, 2_147_483_647),
		difficulty = state.difficulty,
		modifiers = {},
	}
	activeRoundConfig = roundConfig
	table.clear(lastInputSequence)

	broadcast("PhaseChanged", { phase = state.phase })
	broadcast("MinigameStarted", {
		id = id,
		difficulty = state.difficulty,
		runId = runToken,
		roundConfig = roundConfig,
	})
	publishState("MinigameStarted")

	local success, startError = pcall(function()
		minigame:start(buildContext(minigame, runToken, roundConfig))
	end)
	if not success then
		warn(`[Bash] Failed to start {id}: {startError}`)
		stopActiveMinigame()
		local rollback = ShowState.transition(state, "EndMinigame", nil)
		state = rollback.state
		broadcast("MinigameFailed", { id = id })
		broadcast("PhaseChanged", { phase = state.phase })
		publishState("MinigameFailed")
		reject(player, "LaunchMinigame", "That game could not start")
		return
	end

	accept(player, "LaunchMinigame", id)
end

local function trimMessage(text: string): string
	return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

local function validateMessage(rawText: any): (string?, string?)
	if type(rawText) ~= "string" then
		return nil, "Enter a message first"
	end

	local text = trimMessage(rawText)
	if text == "" then
		return nil, "Enter a message first"
	end
	if #text > MAX_MESSAGE_BYTES then
		return nil, `Keep the message under {MAX_MESSAGE_CHARACTERS} characters`
	end

	local characterCount = utf8.len(text)
	if characterCount == nil or characterCount > MAX_MESSAGE_CHARACTERS then
		return nil, `Keep the message under {MAX_MESSAGE_CHARACTERS} characters`
	end
	return text, nil
end

local function handleCommand(player: Player, command: any)
	if not consumeRateLimit(player, "DirectorIngress") then
		return
	end
	if RoleService.roleOf(player) ~= "Director" then
		return
	end
	local bounded = ContractValidation.isBoundedPayload(command)
	if not bounded then
		reject(player, "Unknown", "Malformed command")
		return
	end
	if type(command) ~= "table" or type(command.action) ~= "string" then
		reject(player, "Unknown", "Malformed command")
		return
	end

	local action = command.action
	if not ACTION_INTERVALS[action] then
		reject(player, action, "Unknown command")
		return
	end
	if not consumeRateLimit(player, action) then
		reject(player, action, "Please give that control a moment")
		return
	end

	local payload = if type(command.payload) == "table" then command.payload else nil
	if action == "StartHub" then
		local transition = ShowState.transition(state, action, payload)
		if transition.error then
			reject(player, action, transition.error)
			return
		end
		state = transition.state
		broadcast("PhaseChanged", { phase = state.phase })
		publishState("StartHub")
		accept(player, action)
	elseif action == "LaunchMinigame" then
		local id = if payload then payload.id else nil
		if type(id) ~= "string" then
			reject(player, action, "Choose a game to launch")
			return
		end
		launchMinigame(player, id)
	elseif action == "EndMinigame" then
		local transition = ShowState.transition(state, action, payload)
		if transition.error then
			reject(player, action, transition.error)
			return
		end
		local endedId = state.activeMinigame
		stopActiveMinigame()
		state = transition.state
		broadcast("MinigameEnded", { id = endedId })
		broadcast("PhaseChanged", { phase = state.phase })
		publishState("EndMinigame")
		accept(player, action)
	elseif action == "SetDifficulty" then
		local transition = ShowState.transition(state, action, payload)
		if transition.error then
			reject(player, action, transition.error)
			return
		end
		state = transition.state
		broadcast("DifficultyChanged", { level = state.difficulty })
		publishState("SetDifficulty")
		accept(player, action)
	elseif action == "SummonDogs" then
		if not ShowState.canUseLiveEffect(state) then
			reject(player, action, "Start the hub before summoning the dogs")
			return
		end
		local trick = if payload then payload.trick else nil
		if type(trick) ~= "string" or not SurpriseService.isValidTrick(trick) then
			reject(player, action, "Choose a dog trick")
			return
		end
		local success, reason = SurpriseService.summonDogs(RoleService.getStar(), trick)
		if not success then
			reject(player, action, reason or "The dogs could not enter")
			return
		end
		accept(player, action, trick)
	elseif action == "SendMessage" then
		if not ShowState.canUseLiveEffect(state) then
			reject(player, action, "Start the hub before sending a message")
			return
		end
		local star = RoleService.getStar()
		if not star then
			reject(player, action, "Bella is not connected")
			return
		end
		local text, validationError = validateMessage(if payload then payload.text else nil)
		if not text then
			reject(player, action, validationError or "That message is not valid")
			return
		end
		local success, reason, isStudioPreview = SurpriseService.sendMessage(
			player,
			star,
			text,
			function()
				return RoleService.roleOf(player) == "Director"
					and RoleService.getStar() == star
					and ShowState.canUseLiveEffect(state)
			end
		)
		if not success then
			reject(player, action, reason or "That message could not be sent")
			return
		end
		accept(player, action, if isStudioPreview then "StudioPreview" else nil)
	elseif action == "Surprise" then
		if not ShowState.canUseLiveEffect(state) then
			reject(player, action, "Start the hub before triggering a surprise")
			return
		end
		local kind = if payload then payload.kind else nil
		if type(kind) ~= "string" or not SurpriseService.isValidSurprise(kind) then
			reject(player, action, "Choose Confetti, Cake, Balloons, or ASMR Burst")
			return
		end
		local success, reason = SurpriseService.triggerSurprise(RoleService.getStar(), kind)
		if not success then
			reject(player, action, reason or "That surprise could not start")
			return
		end
		accept(player, action, kind)
	elseif action == "StartFinale" then
		local star = RoleService.getStar()
		if not star then
			reject(player, action, "Bella is not connected")
			return
		end
		local transition = ShowState.transition(state, action, payload)
		if transition.error then
			reject(player, action, transition.error)
			return
		end

		local previousState = state
		state = transition.state
		local success, finaleStarted, reason = pcall(function()
			local didBegin, finaleReason = FinaleService.begin(star)
			return didBegin, finaleReason
		end)
		if not success or not finaleStarted then
			state = previousState
			FinaleService.cancel()
			warn(
				`[Bash] Failed to start finale: {tostring(if success then reason else finaleStarted)}`
			)
			publishState("FinaleFailed")
			reject(
				player,
				action,
				if success and type(reason) == "string"
					then reason
					else "The finale could not start"
			)
			return
		end

		broadcast("PhaseChanged", { phase = state.phase })
		publishState("StartFinale")
		accept(player, action)
	end
end

local function sanitizeProgress(raw: any): Payload?
	if type(raw) ~= "table" then
		return nil
	end

	local clean: Payload = {}
	local count = 0
	for key, value in raw do
		if count >= MAX_PROGRESS_FIELDS then
			break
		end
		if type(key) ~= "string" or #key > 32 then
			continue
		end

		local valueType = type(value)
		if valueType == "number" then
			if isFinite(value) then
				clean[key] = value
				count += 1
			end
		elseif valueType == "boolean" or (valueType == "string" and #value <= 100) then
			clean[key] = value
			count += 1
		end
	end
	return clean
end

local function handleScore(player: Player, report: any)
	local withinRateLimit = consumeRateLimit(player, "MinigameScore")
	if RoleService.roleOf(player) ~= "Star" or not withinRateLimit then
		return
	end
	if state.phase ~= "Minigame" or state.activeMinigame == nil or activeMinigame == nil then
		return
	end
	if type(report) ~= "table" then
		return
	end

	local id = report.id
	local score = report.score
	local runId = report.runId
	if type(id) ~= "string" or id ~= state.activeMinigame then
		return
	end
	-- Bind every score to the exact active run. This prevents a delayed packet
	-- from an earlier Cheese Tower round being shown as part of a relaunch.
	if type(runId) ~= "number" or runId ~= activeRunToken then
		return
	end
	if type(score) ~= "number" or not isFinite(score) or score < 0 or score > MAX_SCORE then
		return
	end

	local director = RoleService.getDirector()
	if director then
		sendEvent(director, "ScoreUpdate", {
			id = id,
			score = score,
			data = sanitizeProgress(report.data),
			from = player.DisplayName,
		})
	end
end

local function handleRoundIngress(player: Player, envelope: any)
	if type(envelope) ~= "table" or type(envelope.kind) ~= "string" then
		-- Compatibility only: legacy score reports are presentation telemetry and
		-- can never complete a round or grant an authoritative result.
		handleScore(player, envelope)
		return
	end
	if RoleService.roleOf(player) ~= "Star" then
		return
	end

	local roundConfig = activeRoundConfig
	if state.phase ~= "Minigame" or not activeMinigame or not roundConfig then
		return
	end
	local bounded = ContractValidation.isBoundedPayload(envelope)
	if not bounded then
		return
	end

	if envelope.kind == "Input" then
		if not consumeRateLimit(player, "RoundInput") then
			return
		end
		local input = envelope.payload
		local previousSequence = lastInputSequence[player] or 0
		local valid = ContractValidation.validateRoundInput(
			input,
			roundConfig.roundId,
			previousSequence,
			workspace:GetServerTimeNow(),
			roundConfig.gameId
		)
		if not valid then
			return
		end
		lastInputSequence[player] = input.sequence
		local handler = activeMinigame.handleInput
		if handler then
			handler(activeMinigame, player, input :: Types.RoundInput)
		end
	elseif envelope.kind == "Telemetry" then
		if not consumeRateLimit(player, "Telemetry") then
			return
		end
		local sample = envelope.payload
		local valid = ContractValidation.validateTelemetry(sample, roundConfig.roundId)
		if not valid then
			return
		end
		local director = RoleService.getDirector()
		if director then
			sendEvent(director, "TelemetrySample", sample)
		end
	elseif envelope.kind == "Ready" then
		if not consumeRateLimit(player, "RoundReady") then
			return
		end
		local payload = envelope.payload
		if type(payload) == "table" and payload.roundId == roundConfig.roundId then
			sendEvent(player, "RoundSnapshot", {
				roundConfig = roundConfig,
				lastAcceptedSequence = lastInputSequence[player] or 0,
			})
		end
	end
end

function ShowDirectorService.start()
	if started then
		return
	end
	started = true

	loadMinigames()
	HubBuilder.start()
	SurpriseService.start(broadcast)
	FinaleService.start(broadcast)
	RoleService.onRolesChanged(function()
		if state.phase == "Minigame" and not RoleService.getStar() then
			abandonToken += 1
			local pendingToken = abandonToken
			local pendingRunToken = activeRunToken
			broadcast("RoundConnectionChanged", {
				status = "Reconnecting",
				graceSeconds = RECONNECT_GRACE_SECONDS,
			})
			task.delay(RECONNECT_GRACE_SECONDS, function()
				if
					pendingToken ~= abandonToken
					or pendingRunToken ~= activeRunToken
					or RoleService.getStar() ~= nil
				then
					return
				end
				local interruptedId = state.activeMinigame
				local interruptedRoundId = if activeRoundConfig
					then activeRoundConfig.roundId
					else nil
				stopActiveMinigame()
				local transition = ShowState.transition(state, "EndMinigame", nil)
				if not transition.error then
					state = transition.state
					broadcast("MinigameEnded", {
						id = interruptedId,
						roundId = interruptedRoundId,
						reason = "RoundAbandoned",
					})
					broadcast("PhaseChanged", { phase = state.phase })
					publishState("RoundAbandoned")
				end
			end)
		elseif state.phase == "Minigame" and RoleService.getStar() then
			abandonToken += 1
			broadcast("RoundConnectionChanged", { status = "Connected" })
		end
		publishState("RolesChanged")
		-- Role_Assigned is retried at 0/1/3 seconds by the frozen M0 role
		-- channel. Follow each delivery with a state snapshot so a late or
		-- reconnecting Director cannot miss the authoritative console state.
		for _, delaySeconds in { 0.25, 1.25, 3.25 } do
			task.delay(delaySeconds, function()
				publishState("RoleSnapshot")
			end)
		end
	end)

	Net.get(Net.DirectorCommand).OnServerEvent:Connect(handleCommand)
	Net.get(Net.MinigameScore).OnServerEvent:Connect(handleRoundIngress)
	Players.PlayerRemoving:Connect(function(player: Player)
		requestBuckets[player] = nil
		lastInputSequence[player] = nil
	end)

	-- Best-effort snapshots for the frozen M0 one-way role/event contract. The
	-- next contract revision should replace this with an explicit client-ready handshake.
	for _, delaySeconds in { 0.5, 1.5, 3 } do
		task.delay(delaySeconds, function()
			publishState("StartupSnapshot")
		end)
	end
end

return ShowDirectorService
