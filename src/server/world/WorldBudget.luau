--!strict

export type Limits = {
	maxHubLights: number,
	maxTransparentDecorations: number,
}

export type Report = {
	lights: number,
	transparentDecorations: number,
	particleEmitters: number,
	withinBudget: boolean,
}

local WorldBudget = {}

function WorldBudget.audit(root: Instance, limits: Limits): Report
	local lights = 0
	local transparent = 0
	local emitters = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Light") then
			lights += 1
		elseif descendant:IsA("ParticleEmitter") then
			emitters += 1
		elseif
			descendant:IsA("BasePart")
			and descendant.Transparency > 0
			and descendant:GetAttribute("CameraMarker") ~= true
		then
			transparent += 1
		end
	end
	return {
		lights = lights,
		transparentDecorations = transparent,
		particleEmitters = emitters,
		withinBudget = lights <= limits.maxHubLights
			and transparent <= limits.maxTransparentDecorations,
	}
end

return table.freeze(WorldBudget)
