--!strict

local Dispatch = require("../src/server/DirectorEffectDispatch")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local appliedEffect: { [string]: any }? = nil
local supported = {
	applyDirectorEffect = function(_self: any, effect: { [string]: any })
		appliedEffect = effect
		return true
	end,
}
local effect = { cardId = "PerfectZone", duration = 4, strength = 1 }

local accepted, reason = Dispatch.apply("Minigame", supported, effect)
expect(accepted and reason == nil, "supported active minigame accepts effect")
expect(appliedEffect == effect, "dispatch preserves the authoritative effect payload")

accepted, reason = Dispatch.apply("Minigame", nil, effect)
expect(not accepted and reason ~= nil, "missing active minigame fails closed")

accepted, reason = Dispatch.apply("Minigame", {}, effect)
expect(not accepted and reason ~= nil, "missing hook fails closed")

accepted, reason = Dispatch.apply("Minigame", {
	applyDirectorEffect = function()
		error("hook failure")
	end,
}, effect)
expect(not accepted and reason ~= nil, "hook errors fail closed")

accepted, reason = Dispatch.apply("Minigame", {
	applyDirectorEffect = function()
		return false
	end,
}, effect)
expect(not accepted and reason ~= nil, "hook rejection fails closed")

accepted, reason = Dispatch.apply("ActResult", nil, effect)
expect(accepted and reason == nil, "non-gameplay cue needs no minigame hook")

print(`PASS DirectorEffectDispatch.spec ({assertions} assertions)`)
