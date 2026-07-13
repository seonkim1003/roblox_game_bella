--!strict
-- Gigi & Rambo Dash -- SERVER half.
-- Client simulates the run for juice; this module announces start/difficulty/end
-- and auto-completes the segment after a soft timed window so Director progress
-- can roll forward. Loaded by ShowDirectorService via exported `id`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local id: Types.MinigameId = "DogDash"

-- Soft show segment length; Director may still EndMinigame earlier.
local SEGMENT_SECONDS = 50

local difficultyWatch: RBXScriptConnection? = nil
local completeThread: thread? = nil
local activeCtx: Types.ShowContext? = nil
local segmentToken = 0

local function stopWatch()
	if difficultyWatch then
		difficultyWatch:Disconnect()
		difficultyWatch = nil
	end
end

local function cancelComplete()
	segmentToken += 1
	if completeThread then
		task.cancel(completeThread)
		completeThread = nil
	end
end

local DogDashServer: Types.MinigameServer = {
	id = id,

	start = function(_self, ctx)
		activeCtx = ctx
		stopWatch()
		cancelComplete()

		local lastDifficulty = ctx.difficulty()
		ctx.broadcast("DogDashBegin", { difficulty = lastDifficulty })

		difficultyWatch = RunService.Heartbeat:Connect(function()
			local d = ctx.difficulty()
			if math.abs(d - lastDifficulty) > 1e-3 then
				lastDifficulty = d
				ctx.broadcast("DogDashDifficulty", { difficulty = d })
			end
		end)

		local token = segmentToken
		completeThread = task.delay(SEGMENT_SECONDS, function()
			completeThread = nil
			if token ~= segmentToken or activeCtx ~= ctx then
				return
			end
			ctx.complete({ id = id, reason = "segmentComplete" })
		end)
	end,

	stop = function(_self)
		stopWatch()
		cancelComplete()
		if activeCtx then
			activeCtx.broadcast("DogDashEnd", nil)
			activeCtx = nil
		end
	end,
}

return DogDashServer
