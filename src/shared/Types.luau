--!strict

-- Shared contract types for the Premiere runtime.
-- CONTRACT FREEZE B0: changes require both development lanes to stop and sync.

export type Role = "Director" | "Star"

export type MinigameId = "CheeseTower" | "DogDash" | "SatisfyStation"

export type SessionId = string
export type RoundId = string

export type AccessibilitySettings = {
	reducedMotion: boolean,
	mutedAudio: boolean,
	visualSoundCues: boolean,
	highContrast: boolean,
}

export type RoundConfig = {
	sessionId: SessionId,
	roundId: RoundId,
	gameId: MinigameId,
	seed: number,
	difficulty: number,
	modifiers: { string },
}

export type RoundInput = {
	roundId: RoundId,
	sequence: number,
	action: string,
	value: number?,
	objectId: number?,
	clientTime: number,
}

export type RoundAction =
	"Place"
	| "Nudge"
	| "Rescue"
	| "Bank"
	| "Topper"
	| "Jump"
	| "SwitchDog"
	| "Charge"
	| "Lunge"
	| "Route"
	| "Trace"
	| "Squish"
	| "Pop"
	| "Peel"
	| "Pipe"
	| "Complete"

export type TelemetryMetric =
	"Score"
	| "Combo"
	| "Accuracy"
	| "Progress"
	| "Instability"
	| "Flow"
	| "ProjectedGrade"
	| "Friendship"

export type TelemetrySample = {
	roundId: RoundId,
	metric: TelemetryMetric,
	value: number,
	tag: string?,
}

export type SignificantMomentKind =
	"Perfect"
	| "Rescue"
	| "Tandem"
	| "DreamMode"
	| "Combo"
	| "Finish"

export type SignificantGameplayMoment = {
	roundId: RoundId,
	sequence: number,
	kind: SignificantMomentKind,
	serverTime: number,
	value: number?,
	label: string?,
}

export type DirectorCardId =
	"DogAssist"
	| "SlowMotion"
	| "PerfectZone"
	| "TreatRain"
	| "RescueSpotlight"
	| "DreamModeBoost"
	| "DoubleOrNothingTopper"
	| "ConfettiFinish"

export type DirectorCard = {
	id: DirectorCardId,
	energyCost: number,
	available: boolean,
	reason: string?,
}

export type RoundResult = {
	roundId: RoundId,
	score: number,
	grade: string,
	metrics: { [string]: number },
}

export type RoundIngress =
	{ kind: "Input", payload: RoundInput }
	| { kind: "Telemetry", payload: TelemetrySample }
	| { kind: "Ready", payload: { roundId: RoundId } }

export type ShowPhase = "Lobby" | "Hub" | "Minigame" | "Finale"

export type SurpriseKind = "Confetti" | "Cake" | "Balloons" | "AsmrBurst"

export type DirectorAction =
	"StartHub"
	| "LaunchMinigame"
	| "EndMinigame"
	| "SetDifficulty"
	| "SummonDogs"
	| "SendMessage"
	| "Surprise"
	| "StartFinale"

export type DirectorCommand = {
	action: DirectorAction,
	payload: { [string]: any }?,
}

-- Given to a minigame's SERVER module by the ShowDirectorService.
export type ShowContext = {
	star: Player?,
	roundConfig: RoundConfig,
	difficulty: () -> number,
	broadcast: (event: string, payload: { [string]: any }?) -> (),
	publishTelemetry: (sample: TelemetrySample) -> (),
	recordMoment: (moment: SignificantGameplayMoment) -> (),
	complete: (result: RoundResult | { [string]: any }) -> (),
}

export type MinigameServer = {
	id: MinigameId,
	start: (self: MinigameServer, ctx: ShowContext) -> (),
	stop: (self: MinigameServer) -> (),
	handleInput: ((self: MinigameServer, player: Player, input: RoundInput) -> ())?,
}

-- Juice library owned by the Player Experience lane; consumed by both lanes.
export type FeedbackApi = {
	pop: (position: Vector3, options: { [string]: any }?) -> (),
	confetti: (options: { [string]: any }?) -> (),
	squish: (target: Instance, options: { [string]: any }?) -> (),
	cameraKick: (strength: number) -> (),
}

export type SoundApi = {
	play: (name: string, options: { [string]: any }?) -> (),
}

-- Given to a minigame's CLIENT module by the StarController.
export type ClientContext = {
	roundConfig: RoundConfig?,
	sendInput: ((input: RoundInput) -> ())?,
	publishTelemetry: ((sample: TelemetrySample) -> ())?,
	reportScore: (score: number, data: { [string]: any }?) -> (),
	onEvent: (callback: (event: string, payload: { [string]: any }?) -> ()) -> (),
	feedback: FeedbackApi,
	sound: SoundApi,
}

export type MinigameClient = {
	id: MinigameId,
	start: (self: MinigameClient, ctx: ClientContext) -> (),
	stop: (self: MinigameClient) -> (),
}

return {}
