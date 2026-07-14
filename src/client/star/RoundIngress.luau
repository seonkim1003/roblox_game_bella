--!strict
-- Star-side RoundIngress helper for the frozen B0 Minigame_Score envelope.
-- Owns sequence numbering and timestamps so minigames only pick actions/values.

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Types = require(Shared.Types)

export type Session = {
	roundConfig: Types.RoundConfig,
	sendInput: (action: Types.RoundAction, value: number?) -> (),
	publishTelemetry: (metric: Types.TelemetryMetric, value: number, tag: string?) -> (),
	ready: () -> (),
	getSequence: () -> number,
	syncSequence: (lastAccepted: number) -> (),
}

local RoundIngress = {}

local function fire(kind: string, payload: { [string]: any })
	Net.get(Net.MinigameScore):FireServer({
		kind = kind,
		payload = payload,
	})
end

function RoundIngress.create(roundConfig: Types.RoundConfig): Session
	local sequence = 0

	local session: Session = {
		roundConfig = roundConfig,
		sendInput = function(action: Types.RoundAction, value: number?)
			sequence += 1
			fire("Input", {
				roundId = roundConfig.roundId,
				sequence = sequence,
				action = action,
				value = value,
				clientTime = Workspace:GetServerTimeNow(),
			})
		end,
		publishTelemetry = function(metric: Types.TelemetryMetric, value: number, tag: string?)
			fire("Telemetry", {
				roundId = roundConfig.roundId,
				metric = metric,
				value = value,
				tag = tag,
			})
		end,
		ready = function()
			fire("Ready", {
				roundId = roundConfig.roundId,
			})
		end,
		getSequence = function()
			return sequence
		end,
		syncSequence = function(lastAccepted: number)
			if type(lastAccepted) == "number" and lastAccepted >= sequence then
				sequence = math.floor(lastAccepted)
			end
		end,
	}

	return session
end

return RoundIngress
