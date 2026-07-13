-- Shared contract types for Bella's Birthday Bash.
-- FROZEN after Milestone 0: changing anything here requires both lanes to agree
-- (see docs/BIRTHDAY_BASH_PLAN.md section 7).

export type Role = "Director" | "Star"

export type MinigameId = "CheeseTower" | "DogDash" | "SatisfyStation"

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
	difficulty: () -> number,
	broadcast: (event: string, payload: { [string]: any }?) -> (),
	complete: (result: { [string]: any }?) -> (),
}

export type MinigameServer = {
	id: MinigameId,
	start: (self: MinigameServer, ctx: ShowContext) -> (),
	stop: (self: MinigameServer) -> (),
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
