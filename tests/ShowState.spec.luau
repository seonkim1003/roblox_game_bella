--!strict

local ShowState = require("../src/server/ShowState")

local assertions = 0

local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local function expectEqual(actual: any, expected: any, message: string)
	expect(actual == expected, `{message}: expected {tostring(expected)}, got {tostring(actual)}`)
end

local function expectRejected(result: any, original: any, reason: string)
	expect(result.error ~= nil, reason)
	expectEqual(result.changed, false, "rejected transition is unchanged")
	expectEqual(result.state.phase, original.phase, "rejected transition preserves phase")
	expectEqual(
		result.state.activeMinigame,
		original.activeMinigame,
		"rejected transition preserves active minigame"
	)
	expectEqual(
		result.state.difficulty,
		original.difficulty,
		"rejected transition preserves difficulty"
	)
end

local initial = ShowState.new(0.5)
expectEqual(initial.phase, "Lobby", "initial phase")
expectEqual(initial.difficulty, 0.5, "initial difficulty")
expectEqual(initial.activeMinigame, nil, "initial active minigame")

local invalidDefault = ShowState.new(math.huge)
expectEqual(invalidDefault.difficulty, 0.5, "non-finite default falls back safely")
local lowDefault = ShowState.new(-4)
expectEqual(lowDefault.difficulty, 0, "default difficulty clamps low")
local highDefault = ShowState.new(7)
expectEqual(highDefault.difficulty, 1, "default difficulty clamps high")

local launchFromLobby = ShowState.transition(initial, "LaunchMinigame", { id = "CheeseTower" })
expectRejected(launchFromLobby, initial, "launch from lobby is rejected")

local startHub = ShowState.transition(initial, "StartHub", nil)
expectEqual(startHub.error, nil, "StartHub succeeds from lobby")
expectEqual(startHub.state.phase, "Hub", "StartHub enters hub")
expectEqual(initial.phase, "Lobby", "transitions do not mutate their input")

local repeatHub = ShowState.transition(startHub.state, "StartHub", nil)
expectEqual(repeatHub.error, nil, "StartHub is idempotent in hub")
expectEqual(repeatHub.changed, false, "idempotent StartHub reports no state change")

local unknownGame = ShowState.transition(startHub.state, "LaunchMinigame", { id = "Nope" })
expectRejected(unknownGame, startHub.state, "unknown minigame is rejected")
local missingGame = ShowState.transition(startHub.state, "LaunchMinigame", nil)
expectRejected(missingGame, startHub.state, "missing minigame id is rejected")

local launchCheese = ShowState.transition(startHub.state, "LaunchMinigame", { id = "CheeseTower" })
expectEqual(launchCheese.error, nil, "Cheese Tower launches")
expectEqual(launchCheese.state.phase, "Minigame", "launch enters minigame phase")
expectEqual(launchCheese.state.activeMinigame, "CheeseTower", "launch records active game")

local relaunchSame =
	ShowState.transition(launchCheese.state, "LaunchMinigame", { id = "CheeseTower" })
expectRejected(relaunchSame, launchCheese.state, "duplicate launch is rejected")

local switchGame = ShowState.transition(launchCheese.state, "LaunchMinigame", { id = "DogDash" })
expectEqual(switchGame.error, nil, "direct minigame switch succeeds")
expectEqual(switchGame.state.phase, "Minigame", "switch remains in minigame phase")
expectEqual(switchGame.state.activeMinigame, "DogDash", "switch records the new game")

local staleCompletion =
	ShowState.transition(switchGame.state, "MinigameComplete", { id = "CheeseTower" })
expectRejected(staleCompletion, switchGame.state, "stale completion is rejected")

local naturalCompletion =
	ShowState.transition(switchGame.state, "MinigameComplete", { id = "DogDash" })
expectEqual(naturalCompletion.error, nil, "active minigame can complete")
expectEqual(naturalCompletion.state.phase, "Hub", "completion returns to hub")
expectEqual(naturalCompletion.state.activeMinigame, nil, "completion clears active game")

local duplicateCompletion =
	ShowState.transition(naturalCompletion.state, "MinigameComplete", { id = "DogDash" })
expectRejected(duplicateCompletion, naturalCompletion.state, "duplicate completion is rejected")

local noGameEnd = ShowState.transition(startHub.state, "EndMinigame", nil)
expectRejected(noGameEnd, startHub.state, "ending without an active game is rejected")
local directorEnd = ShowState.transition(launchCheese.state, "EndMinigame", nil)
expectEqual(directorEnd.error, nil, "Director can end an active game")
expectEqual(directorEnd.state.phase, "Hub", "Director end returns to hub")
expectEqual(directorEnd.state.activeMinigame, nil, "Director end clears active game")

local startHubDuringGame = ShowState.transition(launchCheese.state, "StartHub", nil)
expectRejected(startHubDuringGame, launchCheese.state, "StartHub cannot bypass EndMinigame")

local exactEasy = ShowState.transition(startHub.state, "SetDifficulty", { level = 0 })
expectEqual(exactEasy.state.difficulty, 0, "difficulty accepts exact minimum")
local exactHard = ShowState.transition(exactEasy.state, "SetDifficulty", { level = 1 })
expectEqual(exactHard.state.difficulty, 1, "difficulty accepts exact maximum")
local clampLow = ShowState.transition(exactHard.state, "SetDifficulty", { level = -10 })
expectEqual(clampLow.state.difficulty, 0, "difficulty clamps below range")
local clampHigh = ShowState.transition(clampLow.state, "SetDifficulty", { level = 10 })
expectEqual(clampHigh.state.difficulty, 1, "difficulty clamps above range")
local liveDifficulty = ShowState.transition(launchCheese.state, "SetDifficulty", { level = 0.72 })
expectEqual(liveDifficulty.error, nil, "difficulty changes during a minigame")
expectEqual(liveDifficulty.state.activeMinigame, "CheeseTower", "difficulty keeps active game")
expectEqual(liveDifficulty.state.difficulty, 0.72, "difficulty updates live")

local unchangedDifficulty =
	ShowState.transition(liveDifficulty.state, "SetDifficulty", { level = 0.72 })
expectEqual(unchangedDifficulty.error, nil, "same difficulty is valid")
expectEqual(unchangedDifficulty.changed, false, "same difficulty is idempotent")

local badLevels: { any } = { "hard", math.huge, -math.huge, math.sqrt(-1) }
for _, badLevel in badLevels do
	local badDifficulty = ShowState.transition(startHub.state, "SetDifficulty", {
		level = badLevel,
	})
	expectRejected(badDifficulty, startHub.state, "invalid difficulty is rejected")
end
local missingDifficulty = ShowState.transition(startHub.state, "SetDifficulty", nil)
expectRejected(missingDifficulty, startHub.state, "missing difficulty is rejected")

local finaleState = {
	phase = "Finale",
	difficulty = 0.5,
	activeMinigame = nil,
}
local finaleFromLobby = ShowState.transition(initial, "StartFinale", nil)
expectRejected(finaleFromLobby, initial, "finale cannot start from the lobby")
local finaleDuringGame = ShowState.transition(launchCheese.state, "StartFinale", nil)
expectRejected(finaleDuringGame, launchCheese.state, "finale cannot interrupt a minigame")
local startFinale = ShowState.transition(startHub.state, "StartFinale", nil)
expectEqual(startFinale.error, nil, "finale starts from the hub")
expectEqual(startFinale.changed, true, "finale transition reports a change")
expectEqual(startFinale.state.phase, "Finale", "finale transition enters finale")
expectEqual(startFinale.state.activeMinigame, nil, "finale transition has no active game")
local repeatedFinale = ShowState.transition(startFinale.state, "StartFinale", nil)
expectRejected(repeatedFinale, startFinale.state, "finale cannot be started twice")
local finaleDifficulty = ShowState.transition(finaleState :: any, "SetDifficulty", { level = 0.8 })
expectRejected(finaleDifficulty, finaleState, "difficulty is locked in finale")
local finaleLaunch = ShowState.transition(finaleState :: any, "LaunchMinigame", { id = "DogDash" })
expectRejected(finaleLaunch, finaleState, "minigame launch is locked in finale")
local finaleHub = ShowState.transition(finaleState :: any, "StartHub", nil)
expectRejected(finaleHub, finaleState, "StartHub is locked in finale")

expectEqual(ShowState.canUseLiveEffect(initial), false, "live effects are unavailable in lobby")
expectEqual(ShowState.canUseLiveEffect(startHub.state), true, "live effects are available in hub")
expectEqual(
	ShowState.canUseLiveEffect(launchCheese.state),
	true,
	"live effects are available during a minigame"
)
expectEqual(
	ShowState.canUseLiveEffect(finaleState :: any),
	false,
	"live effects are locked in finale"
)

local unknownAction = ShowState.transition(startHub.state, "TeleportEveryone", nil)
expectRejected(unknownAction, startHub.state, "unknown transition fails closed")

print(`PASS ShowState.spec ({assertions} assertions)`)
