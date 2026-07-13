--!strict
-- Ratthew's Cheese Tower -- SERVER half.
--
-- This is a trusted 2-player show, so the tower is simulated on Bella's client
-- for maximum juice; the server's job is only to run the show segment: announce
-- the start, relay the live difficulty dial to the client, and announce the end.
-- Bella's live score reaches the Director through ctx.reportScore -> Minigame_Score,
-- which ShowDirectorService already forwards; this module does not touch scoring.
--
-- Loaded automatically by ShowDirectorService because it exports `id`. Do NOT
-- wire it into any bootstrap.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)

-- Assign the id to a typed local first so luau-lsp keeps the singleton-union
-- literal instead of widening it to `string` (see MEMORY: luau-lsp gotcha).
local id: Types.MinigameId = "CheeseTower"

local difficultyWatch: RBXScriptConnection? = nil
local activeCtx: Types.ShowContext? = nil

local function stopWatch()
	if difficultyWatch then
		difficultyWatch:Disconnect()
		difficultyWatch = nil
	end
end

local CheeseTowerServer: Types.MinigameServer = {
	id = id,

	start = function(_self, ctx)
		activeCtx = ctx
		stopWatch()

		local lastDifficulty = ctx.difficulty()
		-- Tell the client to spin up the tower and what difficulty to build at.
		ctx.broadcast("CheeseTowerBegin", { difficulty = lastDifficulty })

		-- ShowContext has no difficulty-changed callback, but difficulty() is live,
		-- so watch it and re-broadcast only when it actually moves. This keeps the
		-- Director's live slider driving Bella's pendulum without spamming events.
		difficultyWatch = RunService.Heartbeat:Connect(function()
			local d = ctx.difficulty()
			if math.abs(d - lastDifficulty) > 1e-3 then
				lastDifficulty = d
				ctx.broadcast("CheeseTowerDifficulty", { difficulty = d })
			end
		end)
	end,

	stop = function(_self)
		stopWatch()
		if activeCtx then
			activeCtx.broadcast("CheeseTowerEnd", nil)
			activeCtx = nil
		end
	end,
}

return CheeseTowerServer
