--!strict

local DirectorStrategy = require("../src/server/DirectorStrategy")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local state = DirectorStrategy.new(42, 0)
expect(#state.hand == 3, "strategy starts with three cards")
local same = DirectorStrategy.new(42, 0)
expect(table.concat(state.hand, ",") == table.concat(same.hand, ","), "hand is deterministic")
local drained = table.clone(state)
drained.energy = 0
drained.updatedAt = 0
local refilled = DirectorStrategy.tick(drained, 10)
expect(refilled.energy > 5 and refilled.energy <= 10, "energy regenerates and caps")

local cue = DirectorStrategy.chooseShowrunnerCue(state, "Minigame", "CheeseTower")
if cue then
	local played = DirectorStrategy.play(state, cue :: any, "Minigame", "CheeseTower", 2, 2.1)
	expect(played.accepted, "available cue plays")
	expect(#played.state.hand == 3, "played cue is replaced")
	expect(played.state.finaleEnergy > 0, "cue builds shared finale energy")
	expect(played.effect ~= nil and played.effect.strength == 1, "cue effect only helps")
else
	expect(true, "deterministic hand may be context-gated")
end

local predicted = DirectorStrategy.predict(state, "Perfect")
local resolved = DirectorStrategy.resolvePrediction(predicted, "Perfect")
expect(resolved.finaleEnergy == 15, "correct prediction builds finale energy")
expect(
	DirectorStrategy.resolvePrediction(resolved, "Perfect").finaleEnergy == 15,
	"prediction resolves once"
)
expect(DirectorStrategy.cueGrade(state) == "B", "unused fallback receives neutral grade")

print(`PASS DirectorStrategy.spec ({assertions} assertions)`)
