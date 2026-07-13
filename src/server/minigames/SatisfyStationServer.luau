--!strict
-- ASMR Satisfy Station -- SERVER half.
-- Client owns tray juice & scoring; server announces start/difficulty/end and
-- completes after a soft segment window. Loaded by ShowDirectorService via `id`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

local id: Types.MinigameId = "SatisfyStation"

local SEGMENT_SECONDS = 55

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

local SatisfyStationServer: Types.MinigameServer = {
	id = id,

	start = function(_self, ctx)
		activeCtx = ctx
		stopWatch()
		cancelComplete()

		local lastDifficulty = ctx.difficulty()
		ctx.broadcast("SatisfyStationBegin", { difficulty = lastDifficulty })

		difficultyWatch = RunService.Heartbeat:Connect(function()
			local d = ctx.difficulty()
			if math.abs(d - lastDifficulty) > 1e-3 then
				lastDifficulty = d
				ctx.broadcast("SatisfyStationDifficulty", { difficulty = d })
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
			activeCtx.broadcast("SatisfyStationEnd", nil)
			activeCtx = nil
		end
	end,
}

return SatisfyStationServer
