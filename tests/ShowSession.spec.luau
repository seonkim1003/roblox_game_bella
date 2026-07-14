--!strict

local ShowSession = require("../src/server/ShowSession")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local state = ShowSession.new("session-1", 0)
expect(state.phase == "Lobby", "session starts in lobby")
local invitation = ShowSession.openInvitation(state, 1)
expect(invitation.state.phase == "Invitation", "invitation opens")
expect(state.phase == "Lobby", "transitions preserve inputs")
expect(ShowSession.chooseMood(invitation.state, "Nope", 2).error ~= nil, "unknown mood rejected")
local lounge = ShowSession.chooseMood(invitation.state, "Cozy", 2)
expect(lounge.state.phase == "Lounge" and lounge.state.mood == "Cozy", "mood enters lounge")
local intro = ShowSession.introduceAct(lounge.state, "CheeseTower", 3)
expect(intro.state.phase == "ActIntroduction" and intro.state.actIndex == 1, "act introduced")
local play = ShowSession.skipOrdinary(intro.state, 3, 4)
expect(play.state.phase == "Minigame", "either player can skip ordinary introduction")
local stale = ShowSession.completeAct(play.state, {
	roundId = "r0",
	gameId = "DogDash",
	score = 1,
	grade = "D",
	metrics = {},
}, 5)
expect(stale.error ~= nil, "stale result rejected")
local result = ShowSession.completeAct(play.state, {
	roundId = "r1",
	gameId = "CheeseTower",
	score = 920,
	grade = "A",
	metrics = { Combo = 4 },
}, 5)
expect(result.state.phase == "ActResult" and #result.state.results == 1, "result recorded")
local interlude = ShowSession.skipOrdinary(result.state, 3, 6)
expect(interlude.state.phase == "Interlude", "result advances to interlude")
local intro2 = ShowSession.introduceAct(interlude.state, "DogDash", 7)
local play2 = ShowSession.beginAct(intro2.state, 8)
local result2 = ShowSession.completeAct(play2.state, {
	roundId = "r2",
	gameId = "DogDash",
	score = 850,
	grade = "B",
	metrics = {},
}, 9)
local interlude2 = ShowSession.advance(result2.state, 3, 10)
local intro3 = ShowSession.introduceAct(interlude2.state, "SatisfyStation", 11)
local play3 = ShowSession.beginAct(intro3.state, 12)
local result3 = ShowSession.completeAct(play3.state, {
	roundId = "r3",
	gameId = "SatisfyStation",
	score = 990,
	grade = "S",
	metrics = {},
}, 13)
local finale = ShowSession.advance(result3.state, 3, 14)
expect(finale.state.phase == "HeadlinerFinale", "three acts unlock finale")
local oneSkip = ShowSession.confirmFinaleSkip(finale.state, "Director", 15)
expect(oneSkip.state.phase == "HeadlinerFinale", "one finale confirmation is insufficient")
local bothSkip = ShowSession.confirmFinaleSkip(oneSkip.state, "Star", 16)
expect(bothSkip.state.phase == "KeepsakeResult", "both confirmations skip finale")
local encore = ShowSession.requestEncore(bothSkip.state)
expect(encore.state.encoreRequested, "Bella can request encore")
expect(ShowSession.requestEncore(encore.state).error ~= nil, "encore is deterministic and one-shot")
local replay = ShowSession.replay(encore.state, 17)
expect(replay.state.phase == "Lounge" and #replay.state.results == 0, "replay resets acts")

print(`PASS ShowSession.spec ({assertions} assertions)`)
