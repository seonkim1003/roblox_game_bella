--!strict

export type EventKind = "Beat" | "Animation" | "Complete"
export type Status = "Playing" | "Complete" | "Cancelled"

export type Event = {
	at: number,
	kind: EventKind,
	name: string?,
	line: string?,
}

export type State = {
	cursor: number,
	elapsed: number,
	status: Status,
}

local DURATION = 10

local EVENTS: { Event } = {
	{ at = 0.05, kind = "Beat", name = "FaceOff", line = "Rambo vs Gigi!" },
	{ at = 0.9, kind = "Animation", name = "Charge" },
	{ at = 1.1, kind = "Beat", name = "Charge", line = "They charge!" },
	{ at = 2.05, kind = "Animation", name = "Clash" },
	{ at = 2.35, kind = "Beat", name = "Clash", line = "Paws flying!" },
	{ at = 2.7, kind = "Animation", name = "TussleA" },
	{ at = 3.05, kind = "Animation", name = "TussleB" },
	{ at = 3.4, kind = "Animation", name = "TussleC" },
	{ at = 4, kind = "Beat", name = "Tussle", line = "Tumble time!" },
	{ at = 5.15, kind = "Animation", name = "GigiStrike" },
	{
		at = 5.8,
		kind = "Beat",
		name = "GigiStrike",
		line = "Gigi lands the finishing pounce!",
	},
	{ at = 6.3, kind = "Animation", name = "GigiWins" },
	{ at = 7.2, kind = "Beat", name = "GigiWins", line = "Gigi wins!" },
	{ at = 7.75, kind = "Animation", name = "VictoryPose" },
	{
		at = 8.6,
		kind = "Beat",
		name = "VictoryPose",
		line = "Moonlight Dash is next.",
	},
	{ at = 9.2, kind = "Animation", name = "Settle" },
	{ at = DURATION, kind = "Complete" },
}

local DogFightTimeline = {}

local function copyEvent(event: Event): Event
	return {
		at = event.at,
		kind = event.kind,
		name = event.name,
		line = event.line,
	}
end

function DogFightTimeline.new(): State
	return {
		cursor = 1,
		elapsed = 0,
		status = "Playing",
	}
end

function DogFightTimeline.duration(): number
	return DURATION
end

function DogFightTimeline.isActive(state: State): boolean
	return state.status == "Playing"
end

function DogFightTimeline.remaining(state: State, elapsed: number?): number
	if state.status ~= "Playing" then
		return 0
	end
	local current = if elapsed ~= nil then math.max(state.elapsed, elapsed) else state.elapsed
	return math.max(0, DURATION - current)
end

function DogFightTimeline.advance(state: State, elapsed: number): { Event }
	if state.status ~= "Playing" then
		return {}
	end

	state.elapsed = math.clamp(math.max(state.elapsed, elapsed), 0, DURATION)
	local emitted: { Event } = {}

	while state.cursor <= #EVENTS do
		local event = EVENTS[state.cursor]
		if event.at > state.elapsed then
			break
		end

		state.cursor += 1
		table.insert(emitted, copyEvent(event))
		if event.kind == "Complete" then
			state.status = "Complete"
			break
		end
	end

	return emitted
end

function DogFightTimeline.cancel(state: State): boolean
	if state.status ~= "Playing" then
		return false
	end
	state.status = "Cancelled"
	return true
end

return DogFightTimeline
