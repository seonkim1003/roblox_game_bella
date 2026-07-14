--!strict

-- Authoritative show orchestration and the single server networking boundary.
-- Agent A's minigames are discovered dynamically and used only through the
-- frozen MinigameServer interface.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local ContractValidation = require(Shared.ContractValidation)
local ShowConstants = require(Shared.ShowConstants)
local TelemetryMock = require(Shared.TelemetryMock)
local Types = require(Shared.Types)

local RoleService = require(script.Parent.RoleService)
local FinaleService = require(script.Parent.FinaleService)
local DirectorEffectDispatch = require(script.Parent.DirectorEffectDispatch)
local DirectorStrategy = require(script.Parent.DirectorStrategy)
local IngressHealth = require(script.Parent.IngressHealth)
local PerformanceSummary = require(script.Parent.PerformanceSummary)
local ShowState = require(script.Parent.ShowState)
local ShowSession = require(script.Parent.ShowSession)
local SurpriseService = require(script.Parent.SurpriseService)
local HubBuilder = require(script.Parent.world.HubBuilder)
local TokenBucket = require(script.Parent.TokenBucket)

type Payload = { [string]: any }

local MAX_MESSAGE_CHARACTERS = 160
local MAX_MESSAGE_BYTES = 600
local MAX_SCORE = 1_000_000_000
local MAX_PROGRESS_FIELDS = 12
local RECONNECT_GRACE_SECONDS = 20
local ACT_COUNT = #ShowConstants.MinigameOrder

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
	ChooseMood = 0.5,
	SkipCinematic = 0.5,
	AdvanceShow = 0.5,
	UseCard = 0.2,
	Predict = 0.5,
	SetDebugTelemetry = 0.25,
	DebugLaunch = 1,
	RequestEncore = 1,
	ReplayShow = 2,
}

local ShowDirectorService = {}

local state: ShowState.State = ShowState.new(ShowConstants.DefaultDifficulty)
local sessionId = HttpService:GenerateGUID(false)
local session: ShowSession.State = ShowSession.new(sessionId, workspace:GetServerTimeNow())
local strategy: DirectorStrategy.State =
	DirectorStrategy.new(Random.new():NextInteger(1, 2_147_483_647), workspace:GetServerTimeNow())
local minigames: { [string]: Types.MinigameServer } = {}
local activeMinigame: Types.MinigameServer? = nil
local activeRoundConfig: Types.RoundConfig? = nil
local activeRunToken = 0
local requestBuckets: { [Player]: { [string]: TokenBucket.Bucket } } = {}
local lastInputSequence: { [Player]: number } = {}
local abandonToken = 0
local lastSignificantMomentAt: number? = nil
local lastShowrunnerAt = 0
local started = false
local advancePremiere: (reason: string) -> (boolean, string?)
local debugSeedOverride: number? = nil
local ingressRejectionCounts: IngressHealth.Counts = IngressHealth.new()
local ingressRecoveryPending = false
local lastIngressNoticeAt = 0
local activePerformanceSummary: PerformanceSummary.Summary? = nil

local function sendEvent(player: Player, event: string, payload: Payload?)
	if player.Parent ~= Players then
		return
	end
	Net.get(Net.ShowEvent):FireClient(player, { event = event, payload = payload })
end

local function broadcast(event: string, payload: Payload?)
	Net.get(Net.ShowEvent):FireAllClients({ event = event, payload = payload })
end

local function sendIngressHealth(status: string, kind: string?, reason: string?)
	local director = RoleService.getDirector()
	if not director then
		return
	end
	sendEvent(director, "IngressHealth", {
		status = status,
		kind = kind,
		reason = reason,
		counts = ingressRejectionCounts,
		total = IngressHealth.total(ingressRejectionCounts),
		roundId = if activeRoundConfig then activeRoundConfig.roundId else nil,
	})
end

local function recordIngressRejection(kind: string, reason: string?)
	local category: string
	ingressRejectionCounts, category = IngressHealth.record(ingressRejectionCounts, reason)
	ingressRecoveryPending = true
	local now = workspace:GetServerTimeNow()
	if now - lastIngressNoticeAt < 0.25 then
		return
	end
	lastIngressNoticeAt = now
	sendIngressHealth("Rejected", kind, category)
end

local function recordIngressAccepted()
	if not ingressRecoveryPending then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now - lastIngressNoticeAt < 0.5 then
		return
	end
	ingressRecoveryPending = false
	lastIngressNoticeAt = now
	sendIngressHealth("Healthy", nil, nil)
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
		phase = session.phase,
		legacyPhase = state.phase,
		difficulty = state.difficulty,
		activeMinigame = state.activeMinigame,
		sessionId = sessionId,
		roundConfig = activeRoundConfig,
		starConnected = star ~= nil,
		starName = if star then star.DisplayName else nil,
		directorConnected = director ~= nil,
		availableMinigames = availableMinigames(),
		performanceSummary = activePerformanceSummary,
		runId = if activeMinigame then activeRunToken else nil,
		reason = reason,
		session = ShowSession.snapshot(session),
		director = {
			energy = strategy.energy,
			finaleEnergy = strategy.finaleEnergy,
			hand = DirectorStrategy.handView(strategy, session.phase, state.activeMinigame),
			prediction = strategy.prediction,
			predictionResolved = strategy.predictionResolved,
			predictionMatched = strategy.predictionMatched,
			cueGrade = DirectorStrategy.cueGrade(strategy),
			showrunnerFallback = director == nil,
			ingressHealth = {
				counts = ingressRejectionCounts,
				total = IngressHealth.total(ingressRejectionCounts),
				recoveryPending = ingressRecoveryPending,
			},
		},
	}
end

local function publishState(reason: string)
	strategy = DirectorStrategy.tick(strategy, workspace:GetServerTimeNow())
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

local function authoritativeResult(
	roundConfig: Types.RoundConfig,
	rawResult: Payload?
): ShowSession.Result
	local score = if rawResult and type(rawResult.score) == "number" then rawResult.score else 0
	if not isFinite(score) then
		score = 0
	end
	score = math.clamp(math.round(score), 0, MAX_SCORE)
	local grade = if rawResult and type(rawResult.grade) == "string" then rawResult.grade else nil
	if grade ~= "S" and grade ~= "A" and grade ~= "B" and grade ~= "C" and grade ~= "D" then
		grade = if score >= 900
			then "S"
			elseif score >= 750 then "A"
			elseif score >= 550 then "B"
			elseif score >= 300 then "C"
			else "D"
	end
	local metrics: { [string]: number } = {}
	local rawMetrics = if rawResult and type(rawResult.metrics) == "table"
		then rawResult.metrics
		else nil
	if rawMetrics then
		for key, value in rawMetrics do
			if
				type(key) == "string"
				and #key <= 32
				and type(value) == "number"
				and isFinite(value)
			then
				metrics[key] = value
			end
		end
	end
	return {
		roundId = roundConfig.roundId,
		gameId = roundConfig.gameId,
		score = score,
		grade = grade :: string,
		metrics = metrics,
	}
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
			lastSignificantMomentAt = moment.serverTime
			strategy = DirectorStrategy.resolvePrediction(strategy, moment.kind)
			broadcast("SignificantMoment", moment :: any)
			publishState("SignificantMoment")
		end,
		complete = function(result: Payload?)
			if activeMinigame ~= minigame or activeRunToken ~= runToken then
				return
			end

			local completedId = minigame.id
			local finalResult = authoritativeResult(roundConfig, result)
			stopActiveMinigame()
			local transition = ShowState.transition(state, "MinigameComplete", { id = completedId })
			if transition.error then
				warn(`[Bash] Completion transition rejected: {transition.error}`)
				return
			end
			state = transition.state
			local sessionTransition =
				ShowSession.completeAct(session, finalResult, workspace:GetServerTimeNow())
			if sessionTransition.error then
				warn(`[Bash] Session completion rejected: {sessionTransition.error}`)
			else
				session = sessionTransition.state
			end
			broadcast("MinigameComplete", {
				id = completedId,
				roundId = roundConfig.roundId,
				result = finalResult,
			})
			broadcast("PhaseChanged", { phase = session.phase })
			broadcast(
				"PremierePhaseChanged",
				{ phase = session.phase, revision = session.revision }
			)
			publishState("MinigameComplete")
			local resultRevision = session.revision
			task.delay(6, function()
				if session.phase == "ActResult" and session.revision == resultRevision then
					advancePremiere("ActResultComplete")
				end
			end)
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
	local previousSession = session
	local sessionTransition = ShowSession.beginAct(session, workspace:GetServerTimeNow())
	if sessionTransition.error or session.activeGameId ~= id then
		reject(player, "LaunchMinigame", sessionTransition.error or "That act is not introduced")
		return
	end
	session = sessionTransition.state

	local transition = ShowState.transition(state, "LaunchMinigame", { id = id })
	if transition.error then
		session = previousSession
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
		seed = debugSeedOverride or Random.new():NextInteger(1, 2_147_483_647),
		difficulty = state.difficulty,
		modifiers = {},
	}
	debugSeedOverride = nil
	activeRoundConfig = roundConfig
	strategy = DirectorStrategy.resetPrediction(strategy)
	ingressRejectionCounts = IngressHealth.new()
	ingressRecoveryPending = false
	lastIngressNoticeAt = 0
	table.clear(lastInputSequence)

	broadcast("PhaseChanged", { phase = session.phase })
	broadcast("PremierePhaseChanged", { phase = session.phase, revision = session.revision })
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

local function queueAct(player: Player, requestedId: string): (boolean, string?)
	local expectedId = ShowConstants.MinigameOrder[session.actIndex + 1]
	if expectedId == nil then
		return false, "All acts are complete"
	end
	if requestedId ~= expectedId then
		return false, `The next act is {expectedId}`
	end
	local transition = ShowSession.introduceAct(session, requestedId, workspace:GetServerTimeNow())
	if transition.error then
		return false, transition.error
	end
	session = transition.state
	broadcast("ActIntroduction", {
		gameId = requestedId,
		actIndex = session.actIndex,
		totalActs = ACT_COUNT,
	})
	publishState("ActIntroduction")
	local revision = session.revision
	task.delay(4, function()
		if session.phase == "ActIntroduction" and session.revision == revision then
			launchMinigame(player, requestedId)
		end
	end)
	return true, nil
end

local function buildPerformanceSummary(): PerformanceSummary.Summary
	return PerformanceSummary.build(session.results :: any, {
		starName = Config.starName,
		mood = session.mood,
		directorCueGrade = DirectorStrategy.cueGrade(strategy),
		finaleEnergy = strategy.finaleEnergy,
	})
end

local function completeHeadlinerFinale(reason: string): (boolean, string?)
	if session.phase ~= "HeadlinerFinale" then
		return false, "The finale is not active"
	end
	local transition = ShowSession.completeFinale(session, workspace:GetServerTimeNow())
	if transition.error then
		return false, transition.error
	end
	activePerformanceSummary = activePerformanceSummary or buildPerformanceSummary()
	session = transition.state
	FinaleService.cancel()
	broadcast("PremierePhaseChanged", { phase = session.phase, revision = session.revision })
	broadcast("KeepsakeResult", {
		session = ShowSession.snapshot(session),
		summary = activePerformanceSummary,
		reason = reason,
	})
	publishState(reason)
	return true, nil
end

local function startHeadlinerFinale(): (boolean, string?)
	if session.phase ~= "HeadlinerFinale" then
		return false, "Complete all three acts first"
	end
	local star = RoleService.getStar()
	if not star then
		return false, "Bella is not connected"
	end
	local transition = ShowState.transition(state, "StartFinale", nil)
	if transition.error then
		return false, transition.error
	end
	local previousState = state
	state = transition.state
	activePerformanceSummary = buildPerformanceSummary()
	local success, finaleStarted, reason = pcall(function()
		local didBegin, finaleReason = FinaleService.begin(
			star,
			activePerformanceSummary :: any,
			function()
				completeHeadlinerFinale("FinaleComplete")
			end
		)
		return didBegin, finaleReason
	end)
	if not success or not finaleStarted then
		state = previousState
		activePerformanceSummary = nil
		FinaleService.cancel()
		return false,
			if success and type(reason) == "string" then reason else "The finale could not start"
	end
	broadcast("PhaseChanged", { phase = session.phase })
	publishState("StartFinale")
	return true, nil
end

advancePremiere = function(reason: string): (boolean, string?)
	local transition = ShowSession.advance(session, ACT_COUNT, workspace:GetServerTimeNow())
	if transition.error then
		return false, transition.error
	end
	session = transition.state
	broadcast("PremierePhaseChanged", { phase = session.phase, revision = session.revision })
	publishState(reason)
	if session.phase == "Interlude" then
		local expectedId = ShowConstants.MinigameOrder[session.actIndex + 1]
		broadcast("InterludeStarted", { nextGameId = expectedId, duration = 6 })
		local revision = session.revision
		task.delay(6, function()
			if session.phase ~= "Interlude" or session.revision ~= revision or not expectedId then
				return
			end
			local owner = RoleService.getDirector() or RoleService.getStar()
			if owner then
				queueAct(owner, expectedId)
			end
		end)
	elseif session.phase == "HeadlinerFinale" then
		broadcast("HeadlinerReady", { finaleEnergy = strategy.finaleEnergy })
		local revision = session.revision
		task.delay(2, function()
			if session.phase == "HeadlinerFinale" and session.revision == revision then
				startHeadlinerFinale()
			end
		end)
	end
	return true, nil
end

local function handleCommand(player: Player, command: any)
	if not consumeRateLimit(player, "DirectorIngress") then
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
	local role = RoleService.roleOf(player)
	if action == "ChooseMood" then
		if role ~= "Star" then
			reject(player, action, "Only Bella chooses the Premiere mood")
			return
		end
		local mood = if payload then payload.mood else nil
		if type(mood) ~= "string" then
			reject(player, action, "Choose Cozy, Playful, or Dreamy")
			return
		end
		local transition = ShowSession.chooseMood(session, mood, workspace:GetServerTimeNow())
		if transition.error then
			reject(player, action, transition.error)
			return
		end
		local hubTransition = ShowState.transition(state, "StartHub", nil)
		if hubTransition.error then
			reject(player, action, hubTransition.error)
			return
		end
		state = hubTransition.state
		session = transition.state
		broadcast("MoodChosen", { mood = session.mood })
		publishState("MoodChosen")
		accept(player, action, mood)
		return
	elseif action == "SkipCinematic" then
		if role ~= "Director" and role ~= "Star" then
			return
		end
		if session.phase == "HeadlinerFinale" then
			local transition =
				ShowSession.confirmFinaleSkip(session, role, workspace:GetServerTimeNow())
			if transition.error then
				reject(player, action, transition.error)
				return
			end
			local reachedKeepsake = transition.state.phase == "KeepsakeResult"
			session = transition.state
			broadcast("FinaleSkipConfirmed", {
				role = role,
				complete = reachedKeepsake,
			})
			if reachedKeepsake then
				FinaleService.cancel()
				activePerformanceSummary = activePerformanceSummary or buildPerformanceSummary()
				broadcast("KeepsakeResult", {
					session = ShowSession.snapshot(session),
					summary = activePerformanceSummary,
					reason = "FinaleSkipped",
				})
			end
			publishState("FinaleSkipConfirmed")
			accept(player, action)
			return
		elseif session.phase == "ActIntroduction" then
			local id = session.activeGameId
			if not id then
				reject(player, action, "No act is ready")
				return
			end
			launchMinigame(player, id)
			return
		elseif session.phase == "ActResult" then
			local success, reason = advancePremiere("ResultSkipped")
			if not success then
				reject(player, action, reason or "Cannot skip")
			else
				accept(player, action)
			end
			return
		elseif session.phase == "Interlude" then
			local id = ShowConstants.MinigameOrder[session.actIndex + 1]
			if not id then
				reject(player, action, "No act remains")
				return
			end
			local success, reason = queueAct(player, id)
			if not success then
				reject(player, action, reason or "Cannot skip")
			else
				accept(player, action)
			end
			return
		end
		reject(player, action, "This moment is not skippable")
		return
	elseif action == "RequestEncore" then
		if role ~= "Star" then
			reject(player, action, "Only Bella can request an encore")
			return
		end
		local transition = ShowSession.requestEncore(session)
		if transition.error then
			reject(player, action, transition.error)
			return
		end
		session = transition.state
		strategy = DirectorStrategy.requestEncore(strategy)
		broadcast("EncoreRequested", {
			summary = activePerformanceSummary,
			replayIndex = 1,
		})
		publishState("EncoreRequested")
		accept(player, action)
		return
	elseif action == "ReplayShow" then
		if role ~= "Director" and role ~= "Star" then
			return
		end
		local transition = ShowSession.replay(session, workspace:GetServerTimeNow())
		if transition.error then
			reject(player, action, transition.error)
			return
		end
		FinaleService.cancel()
		activePerformanceSummary = nil
		state = ShowState.transition(ShowState.new(state.difficulty), "StartHub", nil).state
		session = transition.state
		strategy = DirectorStrategy.new(
			Random.new():NextInteger(1, 2_147_483_647),
			workspace:GetServerTimeNow()
		)
		broadcast("ReplayStarted", { mood = session.mood })
		publishState("ReplayStarted")
		accept(player, action)
		return
	end

	if role ~= "Director" then
		return
	end
	if action == "SetDebugTelemetry" then
		if not RunService:IsStudio() then
			reject(player, action, "Studio-only control")
			return
		end
		local enabled = if payload then payload.enabled else nil
		if type(enabled) ~= "boolean" then
			reject(player, action, "Choose whether fake telemetry is enabled")
			return
		end
		game:SetAttribute("BashFakeTelemetry", enabled)
		sendEvent(player, "DebugTelemetryChanged", { enabled = enabled })
		accept(player, action, if enabled then "enabled" else "disabled")
		return
	elseif action == "DebugLaunch" then
		if not RunService:IsStudio() then
			reject(player, action, "Studio-only control")
			return
		end
		local gameId = if payload then payload.gameId else nil
		local seed = if payload then payload.seed else nil
		if type(gameId) ~= "string" or not isKnownMinigameId(gameId) then
			reject(player, action, "Choose a valid Studio act")
			return
		end
		if type(seed) ~= "number" or not isFinite(seed) or seed % 1 ~= 0 then
			reject(player, action, "Seed must be a whole number")
			return
		end
		local fakeTelemetry = if payload then payload.fakeTelemetry else nil
		if type(fakeTelemetry) == "boolean" then
			game:SetAttribute("BashFakeTelemetry", fakeTelemetry)
		end
		local launched, reason = ShowDirectorService.debugLaunch(gameId, seed)
		if not launched then
			reject(player, action, reason or "The debug round could not launch")
			return
		end
		sendEvent(player, "DebugTelemetryChanged", {
			enabled = game:GetAttribute("BashFakeTelemetry") == true,
		})
		accept(player, action, `{gameId} / seed {math.floor(seed)}`)
		return
	elseif action == "UseCard" then
		local cardId = if payload then payload.cardId else nil
		if type(cardId) ~= "string" then
			reject(player, action, "Choose a cue card")
			return
		end
		local play = DirectorStrategy.play(
			strategy,
			cardId :: any,
			session.phase,
			state.activeMinigame,
			workspace:GetServerTimeNow(),
			lastSignificantMomentAt
		)
		if not play.accepted then
			reject(player, action, play.reason or "That cue is unavailable")
			return
		end
		local effect = play.effect
		if type(effect) ~= "table" then
			reject(player, action, "That cue has no gameplay effect")
			return
		end
		local applied, applyReason =
			DirectorEffectDispatch.apply(session.phase, activeMinigame, effect)
		if not applied then
			reject(player, action, applyReason or "That cue could not be applied")
			return
		end
		strategy = play.state
		if session.phase == "Minigame" then
			sendEvent(player, "DirectorCardPlayed", effect)
		else
			broadcast("DirectorCardPlayed", effect)
		end
		publishState("DirectorCardPlayed")
		accept(player, action, cardId)
		return
	elseif action == "Predict" then
		local prediction = if payload then payload.moment else nil
		if type(prediction) ~= "string" or not DirectorStrategy.isPrediction(prediction) then
			reject(player, action, "Choose a prediction")
			return
		end
		if session.phase ~= "Minigame" then
			reject(player, action, "Predictions open during an active act")
			return
		end
		if strategy.prediction ~= nil then
			reject(player, action, "Your prediction is already locked for this act")
			return
		end
		strategy = DirectorStrategy.predict(strategy, prediction)
		publishState("DirectorPrediction")
		accept(player, action, prediction)
		return
	elseif action == "AdvanceShow" then
		local id = ShowConstants.MinigameOrder[session.actIndex + 1]
		if not id then
			reject(player, action, "All acts are complete")
			return
		end
		local success, reason = queueAct(player, id)
		if not success then
			reject(player, action, reason or "The next act is not ready")
		else
			accept(player, action, id)
		end
		return
	elseif action == "StartHub" then
		if session.phase == "Lobby" then
			local invitation = ShowSession.openInvitation(session, workspace:GetServerTimeNow())
			if invitation.error then
				reject(player, action, invitation.error)
				return
			end
			session = invitation.state
			broadcast("PlayableInvitation", {
				moods = { "Cozy", "Playful", "Dreamy" },
			})
			publishState("InvitationOpened")
			accept(player, action)
			return
		end
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
		local success, reason = queueAct(player, id)
		if not success then
			reject(player, action, reason or "That act is not ready")
		else
			accept(player, action, id)
		end
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
		local success, reason = startHeadlinerFinale()
		if not success then
			reject(player, action, reason or "The finale could not start")
		else
			accept(player, action)
		end
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
		recordIngressRejection(envelope.kind, "no active round")
		return
	end
	local bounded, boundedReason = ContractValidation.isBoundedPayload(envelope)
	if not bounded then
		recordIngressRejection(envelope.kind, boundedReason)
		return
	end

	if envelope.kind == "Input" then
		if not consumeRateLimit(player, "RoundInput") then
			recordIngressRejection("Input", "rate limit")
			return
		end
		local input = envelope.payload
		local previousSequence = lastInputSequence[player] or 0
		local valid, reason = ContractValidation.validateRoundInput(
			input,
			roundConfig.roundId,
			previousSequence,
			workspace:GetServerTimeNow(),
			roundConfig.gameId
		)
		if not valid then
			recordIngressRejection("Input", reason)
			return
		end
		lastInputSequence[player] = input.sequence
		recordIngressAccepted()
		local handler = activeMinigame.handleInput
		if handler then
			handler(activeMinigame, player, input :: Types.RoundInput)
		end
	elseif envelope.kind == "Telemetry" then
		if not consumeRateLimit(player, "Telemetry") then
			recordIngressRejection("Telemetry", "rate limit")
			return
		end
		local sample = envelope.payload
		local valid, reason = ContractValidation.validateTelemetry(sample, roundConfig.roundId)
		if not valid then
			recordIngressRejection("Telemetry", reason)
			return
		end
		recordIngressAccepted()
		local director = RoleService.getDirector()
		if director then
			sendEvent(director, "TelemetrySample", sample)
		end
	elseif envelope.kind == "Ready" then
		if not consumeRateLimit(player, "RoundReady") then
			recordIngressRejection("Ready", "rate limit")
			return
		end
		local payload = envelope.payload
		if type(payload) == "table" and payload.roundId == roundConfig.roundId then
			recordIngressAccepted()
			sendEvent(player, "RoundSnapshot", {
				roundConfig = roundConfig,
				lastAcceptedSequence = lastInputSequence[player] or 0,
			})
		else
			recordIngressRejection("Ready", "stale round")
		end
	else
		recordIngressRejection(envelope.kind, "unknown ingress kind")
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
		if
			session.phase == "Lobby"
			and RoleService.getStar() ~= nil
			and RoleService.getDirector() ~= nil
		then
			local invitation = ShowSession.openInvitation(session, workspace:GetServerTimeNow())
			if not invitation.error then
				session = invitation.state
				broadcast("PlayableInvitation", {
					moods = { "Cozy", "Playful", "Dreamy" },
				})
			end
		end
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

	task.spawn(function()
		while started do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			strategy = DirectorStrategy.tick(strategy, now)
			if
				session.phase == "Minigame"
				and RoleService.getDirector() == nil
				and now - lastShowrunnerAt >= 5
			then
				local cue = DirectorStrategy.chooseShowrunnerCue(
					strategy,
					session.phase,
					state.activeMinigame
				)
				if cue then
					local play = DirectorStrategy.play(
						strategy,
						cue :: any,
						session.phase,
						state.activeMinigame,
						now,
						lastSignificantMomentAt
					)
					if play.accepted then
						local effect = play.effect
						if type(effect) == "table" then
							local applied =
								DirectorEffectDispatch.apply(session.phase, activeMinigame, effect)
							if applied then
								strategy = play.state
								lastShowrunnerAt = now
								publishState("ShowrunnerCue")
							end
						end
					end
				end
			end
		end
	end)

	task.spawn(function()
		local tickIndex = 0
		while started do
			task.wait(0.2)
			if not RunService:IsStudio() or game:GetAttribute("BashFakeTelemetry") ~= true then
				continue
			end
			local roundConfig = activeRoundConfig
			local director = RoleService.getDirector()
			if not roundConfig or not director then
				continue
			end
			tickIndex += 1
			for _, sample in
				TelemetryMock.sampleAt(
					roundConfig.roundId,
					roundConfig.gameId,
					roundConfig.seed,
					tickIndex
				)
			do
				sendEvent(director, "TelemetrySample", sample)
			end
		end
	end)

	-- Best-effort snapshots for the frozen M0 one-way role/event contract. The
	-- next contract revision should replace this with an explicit client-ready handshake.
	for _, delaySeconds in { 0.5, 1.5, 3 } do
		task.delay(delaySeconds, function()
			publishState("StartupSnapshot")
		end)
	end
end

function ShowDirectorService.debugLaunch(gameId: string, seed: number?): (boolean, string?)
	if not RunService:IsStudio() then
		return false, "debug launch is Studio-only"
	end
	if not isKnownMinigameId(gameId) then
		return false, "unknown minigame"
	end
	local owner = RoleService.getDirector() or RoleService.getStar()
	if not owner or not RoleService.getStar() then
		return false, "assign Bella before launching a debug round"
	end
	if session.phase == "Lobby" then
		session = ShowSession.openInvitation(session, workspace:GetServerTimeNow()).state
	end
	if session.phase == "Invitation" then
		session = ShowSession.chooseMood(session, "Cozy", workspace:GetServerTimeNow()).state
		state = ShowState.transition(state, "StartHub", nil).state
	end
	if session.phase ~= "Lounge" and session.phase ~= "Interlude" then
		return false, "finish or replay the active show first"
	end
	local transition = ShowSession.introduceAct(session, gameId, workspace:GetServerTimeNow())
	if transition.error then
		return false, transition.error
	end
	session = transition.state
	debugSeedOverride = if type(seed) == "number"
		then math.clamp(math.floor(seed), 1, 2_147_483_647)
		else 1
	task.defer(function()
		launchMinigame(owner, gameId)
	end)
	return true, nil
end

return ShowDirectorService
