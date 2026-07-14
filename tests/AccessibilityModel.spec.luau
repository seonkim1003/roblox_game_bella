--!strict

local AccessibilityModel = require("../src/client/finale/AccessibilityModel")

local assertions = 0
local function expect(condition: boolean, message: string)
	assertions += 1
	assert(condition, message)
end

local initial = AccessibilityModel.new()
expect(not initial.mutedAudio and not initial.reducedMotion, "accessibility defaults are gentle")
expect(AccessibilityModel.audioLabel(initial) == "AUDIO ON", "audio default is explicit")
expect(AccessibilityModel.motionLabel(initial) == "MOTION FULL", "motion default is explicit")

local muted = AccessibilityModel.withMutedAudio(initial, true)
expect(muted.mutedAudio and not initial.mutedAudio, "audio update is immutable")
expect(AccessibilityModel.audioLabel(muted) == "AUDIO MUTED", "muted label is explicit")

local reduced = AccessibilityModel.withReducedMotion(muted, true)
expect(reduced.mutedAudio and reduced.reducedMotion, "settings compose")
expect(AccessibilityModel.motionLabel(reduced) == "MOTION REDUCED", "reduced label is explicit")

print(`PASS AccessibilityModel.spec ({assertions} assertions)`)
