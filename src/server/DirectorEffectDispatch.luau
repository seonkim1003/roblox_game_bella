--!strict

type Payload = { [string]: any }

local DirectorEffectDispatch = {}

function DirectorEffectDispatch.apply(
	phase: string,
	minigame: any?,
	effect: Payload
): (boolean, string?)
	if phase ~= "Minigame" then
		return true, nil
	end
	if type(minigame) ~= "table" then
		return false, "The active act is not ready for cues"
	end
	local hook = minigame.applyDirectorEffect
	if type(hook) ~= "function" then
		return false, "This act does not support Director cues yet"
	end
	local success, accepted = pcall(function()
		return hook(minigame, effect)
	end)
	if not success then
		return false, "The act could not apply that cue"
	end
	if accepted ~= true then
		return false, "That cue is not available in the active act"
	end
	return true, nil
end

return table.freeze(DirectorEffectDispatch)
