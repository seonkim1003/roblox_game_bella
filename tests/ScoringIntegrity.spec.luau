--!strict
-- Security regressions for authoritative scoring: zero-action grades, cheese
-- farming, DogDash progress jumps, SatisfyStation tray clears, and contracts.

local CheeseTowerRules = require("../src/server/minigames/lib/CheeseTowerRules")
local ContractValidation = require("../src/shared/ContractValidation")
local DogDashRules = require("../src/server/minigames/lib/DogDashRules")
local GameplayHooks = require("../src/server/minigames/lib/GameplayHooks")
local GradePolicy = require("../src/shared/GradePolicy")
local SatisfyStationRules = require("../src/server/minigames/lib/SatisfyStationRules")

local assertions = 0

local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local function input(action: string, sequence: number, value: number?): { [string]: any }
	return {
		roundId = "round-1",
		sequence = sequence,
		action = action,
		value = value,
		clientTime = 100,
	}
end

-- 1. Immediate Complete / zero-action A grade
do
	local tracker = GameplayHooks.newTracker()
	expect(GameplayHooks.gradeFor(tracker) == "D", "zero-action grade is D not A")
	expect(GradePolicy.gradeFromAccuracy(nil, 0, 0) == "D", "policy refuses unset accuracy")
	expect(GradePolicy.gradeFromAccuracy(0.99, 0, 5) == "D", "policy requires valid attempts")

	local cheese = CheeseTowerRules.newState()
	expect(not CheeseTowerRules.canComplete(cheese), "cheese rejects premature Complete")
	local dash = DogDashRules.newState()
	expect(not DogDashRules.canComplete(dash), "dash rejects premature Complete")
	local station = SatisfyStationRules.newState(0.5, 42)
	expect(not SatisfyStationRules.canComplete(station), "station rejects premature Complete")
end

-- 2. Unlimited Place / Bank / Topper
do
	local state = CheeseTowerRules.newState()
	for _ = 1, CheeseTowerRules.MAX_PLACES do
		expect(CheeseTowerRules.applyPlace(state, 1, 1, false), "place within cap accepted")
	end
	expect(not CheeseTowerRules.applyPlace(state, 1, 1, false), "place beyond cap rejected")
	expect(not CheeseTowerRules.applyTopper(state, 1, false), "topper blocked at place cap")

	local tower = CheeseTowerRules.newState()
	expect(CheeseTowerRules.applyPlace(tower, 1, 1, false), "seed place for bank")
	expect(CheeseTowerRules.applyBank(tower), "first bank accepted")
	expect(not CheeseTowerRules.applyBank(tower), "second bank rejected")
	expect(not CheeseTowerRules.applyPlace(tower, 1, 1, false), "place after bank rejected")
	expect(CheeseTowerRules.canComplete(tower), "bank enables Complete")
	expect(tower.score <= CheeseTowerRules.MAX_SCORE, "cheese score stays within max")

	local topped = CheeseTowerRules.newState()
	expect(CheeseTowerRules.applyTopper(topped, 1, false), "single topper accepted")
	expect(not CheeseTowerRules.applyTopper(topped, 1, false), "repeat topper rejected")
end

-- 3. Repeated SatisfyStation actions cannot clear tray
do
	local state = SatisfyStationRules.newState(0, 7)
	local firstKind = state.items[1].kind
	local acceptedCount = 0
	for _ = 1, state.traySize + 5 do
		local ok = SatisfyStationRules.applyAction(state, firstKind, 0.9, nil)
		if ok then
			acceptedCount += 1
		end
	end
	local available = 0
	for _, item in state.items do
		if item.kind == firstKind then
			available += 1
		end
	end
	expect(acceptedCount <= available, "kind spam cannot exceed owned object count")
	expect(state.resolved <= state.traySize, "resolved never exceeds tray size")

	local byId = SatisfyStationRules.newState(0.2, 9)
	local target = byId.items[1]
	local ok1 = SatisfyStationRules.applyAction(byId, target.kind, 0.9, target.id)
	expect(ok1, "object id resolve accepted once")
	local ok2 = SatisfyStationRules.applyAction(byId, target.kind, 0.9, target.id)
	expect(not ok2, "duplicate object id rejected")
	if target.kind ~= "Trace" then
		expect(
			not SatisfyStationRules.applyAction(byId, "Trace", 0.9, target.id),
			"wrong kind for object id rejected"
		)
	end
end

-- 4. Impossible DogDash progress jumps
do
	local state = DogDashRules.newState()
	local before = state.progress
	DogDashRules.applyRoute(state, 1)
	expect(state.progress == before, "Route cannot jump progress to 1")
	expect(not DogDashRules.canComplete(state), "complete still gated after Route cheat")
	for _ = 1, 20 do
		DogDashRules.applySkill(state, 1)
	end
	expect(state.progress <= 1, "progress clamps to 1")
	expect(state.score <= DogDashRules.MAX_SCORE, "dash score capped")
	expect(DogDashRules.canComplete(state), "earned progress unlocks Complete")
end

-- 5. Duplicate / out-of-order inputs + value ranges + frequency
do
	expect(
		ContractValidation.validateRoundInput(
			input("Place", 1, 0.5),
			"round-1",
			0,
			100,
			"CheeseTower"
		),
		"monotonic sequence accepted"
	)
	expect(
		not ContractValidation.validateRoundInput(
			input("Place", 1, 0.5),
			"round-1",
			1,
			100,
			"CheeseTower"
		),
		"duplicate sequence rejected"
	)
	expect(
		not ContractValidation.validateRoundInput(
			input("Place", 4, 0.5),
			"round-1",
			5,
			100,
			"CheeseTower"
		),
		"out-of-order sequence rejected"
	)
	expect(
		not select(
			1,
			ContractValidation.validateRoundInput(
				input("Place", 1, 2),
				"round-1",
				0,
				100,
				"CheeseTower"
			)
		),
		"Place value above 1 rejected"
	)
	expect(
		not select(
			1,
			ContractValidation.validateRoundInput(
				input("Place", 1, nil),
				"round-1",
				0,
				100,
				"CheeseTower"
			)
		),
		"Place without value rejected"
	)
	expect(
		not select(
			1,
			ContractValidation.validateRoundInput(
				input("Jump", 1, 0.8),
				"round-1",
				0,
				100,
				"CheeseTower"
			)
		),
		"cross-game action rejected"
	)
	expect(
		not select(
			1,
			ContractValidation.validateActionInterval("CheeseTower", "Complete", 100.1, 100)
		),
		"Complete frequency limit enforced"
	)
	expect(
		select(1, ContractValidation.validateActionInterval("CheeseTower", "Complete", 101, 100)),
		"Complete after interval accepted"
	)
	local withObject = input("Pop", 1, 0.8)
	withObject.objectId = 99
	expect(
		not select(
			1,
			ContractValidation.validateRoundInput(withObject, "round-1", 0, 100, "SatisfyStation")
		),
		"impossible object id rejected"
	)
end

-- 6. Score-based fallback thresholds removed from official policy
do
	expect(GradePolicy.gradeFromAccuracy(nil, 0, 0) == "D", "missing metrics grade D")
	expect(GradePolicy.gradeFromAccuracy(0.85, 3, 0) == "A", "accuracy band A")
	expect(
		GradePolicy.gradeFromProjected(750) == "S",
		"projected clamps; raw score 750 is not an A gate"
	)
	expect(GradePolicy.gradeFromProjected(47) == "D", "dashboard D band shared")
	expect(GradePolicy.gradeFromProjected(80) == "A", "dashboard A band shared")
end

print(`PASS ScoringIntegrity.spec ({assertions} assertions)`)
