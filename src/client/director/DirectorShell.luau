--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisualConfig = require(Shared.VisualConfig)

local CueCardHand = require(script.Parent.CueCardHand)
local DirectorDashboardModel = require(script.Parent.DirectorDashboardModel)
local DirectorNotice = require(script.Parent.DirectorNotice)
local LiveTrendGraph = require(script.Parent.LiveTrendGraph)
local PredictionControls = require(script.Parent.PredictionControls)
local ProgressWidget = require(script.Parent.ProgressWidget)
local ProjectedGrade = require(script.Parent.ProjectedGrade)
local RecentMoments = require(script.Parent.RecentMoments)
local ResponsiveTokens = require(script.Parent.ResponsiveTokens)
local ShowTimeline = require(script.Parent.ShowTimeline)
local StudioDashboard = require(script.Parent.StudioDashboard)

type Payload = { [string]: any }
type Send = (string, Payload?) -> ()

export type Shell = {
	applyState: (self: Shell, Payload) -> (),
	pushTelemetry: (self: Shell, Payload) -> (),
	pushMoment: (self: Shell, Payload) -> (),
	cardPlayed: (self: Shell, Payload) -> (),
	setConnectionHealth: (self: Shell, Payload) -> (),
	setDebugTelemetry: (self: Shell, boolean) -> (),
	setNotice: (self: Shell, string, boolean?) -> (),
	destroy: (self: Shell) -> (),
}

local DirectorShell = {}
local P = VisualConfig.palette

local function label(parent: Instance, text: string, height: number, size: number): TextLabel
	local result = Instance.new("TextLabel")
	result.BackgroundTransparency = 1
	result.Font = Enum.Font.GothamMedium
	result.Size = UDim2.new(1, 0, 0, height)
	result.Text = text
	result.TextColor3 = P.cream
	result.TextSize = size
	result.TextWrapped = true
	result.TextXAlignment = Enum.TextXAlignment.Left
	result.Parent = parent
	return result
end

function DirectorShell.new(send: Send): Shell
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local old = playerGui:FindFirstChild("PremiereDirectorShell")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PremiereDirectorShell"
	gui.DisplayOrder = 55
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.BackgroundColor3 = P.plumDeep
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = gui

	local content = Instance.new("ScrollingFrame")
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.CanvasSize = UDim2.new()
	content.ScrollBarThickness = 5
	content.Parent = backdrop
	local layout = Instance.new("UIListLayout")
	layout.Parent = content

	local heading = label(content, "PREMIERE SHOWRUNNER", 34, 22)
	heading.Font = Enum.Font.GothamBlack
	local connection = label(content, "● Connecting to authoritative show state", 26, 12)
	connection.TextColor3 = P.butter
	local studio = StudioDashboard.new(content, send)
	local timeline = ShowTimeline.new(content)
	local graph = LiveTrendGraph.new(content)
	local progress = ProgressWidget.new(content)
	local projected = ProjectedGrade.new(content)
	local gameDetail = label(content, "Waiting for act telemetry", 42, 13)
	local nextCue = label(content, "NEXT BEST CUE  ·  Waiting for context", 34, 13)
	nextCue.Font = Enum.Font.GothamBold
	nextCue.TextColor3 = P.mint
	local predictions = PredictionControls.new(content, send)
	local cards = CueCardHand.new(content, send)
	local moments = RecentMoments.new(content)
	local notice = DirectorNotice.new(content)
	local viewportConnection: RBXScriptConnection? = nil
	local function applyResponsiveLayout()
		local size = backdrop.AbsoluteSize
		local x, y, width, height = ResponsiveTokens.contentBounds(size.X, size.Y)
		local tokens = ResponsiveTokens.forWidth(size.X)
		content.Position = UDim2.fromOffset(x, y)
		content.Size = UDim2.fromOffset(width, height)
		layout.Padding = UDim.new(0, tokens.sectionGap)
		heading.TextSize = tokens.headingSize
	end
	applyResponsiveLayout()
	viewportConnection =
		backdrop:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout)

	local currentGame: string? = nil
	local metrics: { [string]: number } = {}
	local activeDog: string? = nil
	local remainingObjects: number? = nil
	local marker: string? = nil
	local shell = {} :: any

	local function renderConnectionHealth(payload: Payload)
		local health = DirectorDashboardModel.connectionHealth(payload)
		connection.Text = health.text
		connection.TextColor3 = if health.severity == "Healthy"
			then P.mint
			elseif health.severity == "Error" then P.blush
			else P.butter
	end

	local function refreshGameDetail()
		if currentGame == "CheeseTower" then
			gameDetail.Text =
				`ALIGNMENT {math.round((metrics.Accuracy or 0) * 100)}%  ·  INSTABILITY {math.round(
					(metrics.Instability or 0) * 100
				)}%  ·  PERFECT STREAK {math.round(metrics.Combo or 0)}`
		elseif currentGame == "DogDash" then
			gameDetail.Text =
				`ROUTE {math.round((metrics.Progress or 0) * 100)}%  ·  TREATS {math.round(
					(metrics.Accuracy or 0) * 100
				)}%  ·  FRIENDSHIP {math.round((metrics.Friendship or 0) * 100)}%  ·  ACTIVE DOG {string.upper(
					activeDog or "WAITING"
				)}`
		elseif currentGame == "SatisfyStation" then
			gameDetail.Text =
				`ORDER {math.round((metrics.Progress or 0) * 100)}%  ·  GESTURES {math.round(
					(metrics.Accuracy or 0) * 100
				)}%  ·  FLOW {math.round((metrics.Flow or 0) * 100)}%  ·  {if remainingObjects
						~= nil
					then remainingObjects
					else "--"} OBJECTS LEFT`
		else
			gameDetail.Text = "Waiting for act telemetry"
		end
	end

	function shell:applyState(payload: Payload)
		local phase = if type(payload.phase) == "string" then payload.phase else "Lobby"
		local session = if type(payload.session) == "table" then payload.session else {}
		local actIndex = if type(session.actIndex) == "number" then session.actIndex else 0
		timeline.set(phase, actIndex)
		local nextGame = if type(payload.activeMinigame) == "string"
			then payload.activeMinigame
			else nil
		if nextGame ~= currentGame then
			table.clear(metrics)
			activeDog = nil
			remainingObjects = nil
		end
		currentGame = nextGame
		local connected = payload.starConnected == true
		connection.Text = if connected
			then "● Bella connected · round validation healthy"
			else "● Bella reconnecting · authoritative round paused"
		connection.TextColor3 = if connected then P.mint else P.butter
		local director = if type(payload.director) == "table" then payload.director else {}
		local ingressHealth = if type(director.ingressHealth) == "table"
			then director.ingressHealth
			else nil
		if ingressHealth and ingressHealth.recoveryPending == true then
			renderConnectionHealth(ingressHealth)
		end
		local prediction = if type(director.prediction) == "string"
			then director.prediction
			else nil
		local predictionResolved = director.predictionResolved == true
		local predictionMatched = if type(director.predictionMatched) == "boolean"
			then director.predictionMatched
			else nil
		predictions.set(phase, prediction, predictionResolved, predictionMatched)
		local hand = if type(director.hand) == "table" then director.hand else {}
		cards.set(hand)
		local energy = if type(director.energy) == "number" then director.energy else 0
		local finaleEnergy = if type(director.finaleEnergy) == "number"
			then director.finaleEnergy
			else 0
		local recommendation = "Let the act breathe"
		for _, card in hand do
			if type(card) == "table" and card.available == true and type(card.id) == "string" then
				recommendation = card.id
				break
			end
		end
		nextCue.Text =
			`NEXT BEST CUE  ·  {recommendation}  ·  ENERGY {math.floor(energy)}/10  ·  FINALE {math.floor(
				finaleEnergy
			)}%`
		refreshGameDetail()
	end

	function shell:pushTelemetry(sample: Payload)
		local metric = sample.metric
		local value = sample.value
		if type(metric) ~= "string" or type(value) ~= "number" then
			return
		end
		metrics[metric] = value
		local context = DirectorDashboardModel.telemetryContext(sample.tag)
		if context.activeDog then
			activeDog = context.activeDog
		end
		if context.remainingObjects ~= nil then
			remainingObjects = context.remainingObjects
		end
		if metric == "Progress" then
			progress.set(value)
		end
		if metric == "ProjectedGrade" then
			projected.set(value)
		end
		local momentum = if metric == "Score" or metric == "ProjectedGrade"
			then math.clamp(value / 100, 0, 1)
			elseif metric == "Instability" then 1 - math.clamp(value, 0, 1)
			else math.clamp(value, 0, 1)
		graph:push(momentum, marker)
		marker = nil
		refreshGameDetail()
	end

	function shell:pushMoment(payload: Payload)
		local kind = if type(payload.kind) == "string" then payload.kind else "Moment"
		local detail = if type(payload.label) == "string" then payload.label else nil
		marker = kind
		moments.push(kind, detail)
	end

	function shell:cardPlayed(payload: Payload)
		local cardId = if type(payload.cardId) == "string" then payload.cardId else "Cue"
		marker = cardId
		moments.push("Director cue", cardId)
	end

	function shell:setConnectionHealth(payload: Payload)
		renderConnectionHealth(payload)
	end

	function shell:setDebugTelemetry(enabled: boolean)
		if studio then
			studio.setTelemetry(enabled)
		end
	end

	function shell:setNotice(text: string, isError: boolean?)
		notice.set(text, isError)
	end
	function shell:destroy()
		if viewportConnection then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		gui:Destroy()
	end
	return shell :: Shell
end

return DirectorShell
