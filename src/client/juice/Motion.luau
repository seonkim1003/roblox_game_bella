--!strict
-- Motion helper: gentle, reduced-motion-aware tweening for client UI + ambient
-- world life. Reads the shared AccessibilitySettings so the accessibility control
-- has real teeth (snaps tweens to their goal when reduced motion is on).

local TweenService = game:GetService("TweenService")

local Motion = {}

local accessibilityModule: any = nil
local accessibilityResolved = false

local function accessibility()
	if accessibilityResolved then
		return accessibilityModule
	end
	accessibilityResolved = true
	local finale = script.Parent.Parent:FindFirstChild("finale")
	local settings = finale and finale:FindFirstChild("AccessibilitySettings")
	if settings and settings:IsA("ModuleScript") then
		local ok, result = pcall(function()
			return (require :: any)(settings)
		end)
		if ok then
			accessibilityModule = result
		end
	end
	return accessibilityModule
end

function Motion.reduced(): boolean
	local settings = accessibility()
	if settings and type(settings.get) == "function" then
		local state = settings.get()
		return type(state) == "table" and state.reducedMotion == true
	end
	return false
end

-- Tween `instance` toward `goal`. Returns the playing Tween, or nil when motion
-- is reduced (in which case the goal is applied immediately).
function Motion.tween(instance: Instance, info: TweenInfo, goal: { [string]: any }): Tween?
	if Motion.reduced() then
		for property, value in goal do
			(instance :: any)[property] = value
		end
		return nil
	end

	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- Convenience: a standard cozy ease (Quad Out) of `time` seconds.
function Motion.ease(time: number): TweenInfo
	return TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

-- A gentle overshoot (Back Out) for playful pops — matches the Squish feel.
function Motion.pop(time: number): TweenInfo
	return TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

return Motion
