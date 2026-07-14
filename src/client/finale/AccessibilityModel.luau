--!strict

export type State = {
	mutedAudio: boolean,
	reducedMotion: boolean,
}

local AccessibilityModel = {}

function AccessibilityModel.new(): State
	return { mutedAudio = false, reducedMotion = false }
end

function AccessibilityModel.withMutedAudio(state: State, muted: boolean): State
	return { mutedAudio = muted, reducedMotion = state.reducedMotion }
end

function AccessibilityModel.withReducedMotion(state: State, reduced: boolean): State
	return { mutedAudio = state.mutedAudio, reducedMotion = reduced }
end

function AccessibilityModel.audioLabel(state: State): string
	return if state.mutedAudio then "AUDIO MUTED" else "AUDIO ON"
end

function AccessibilityModel.motionLabel(state: State): string
	return if state.reducedMotion then "MOTION REDUCED" else "MOTION FULL"
end

return table.freeze(AccessibilityModel)
