--!strict

-- Pure validation helpers shared for local feedback and authoritative server checks.
-- Client use never replaces the server validation pass.

local ContractValidation = {}

ContractValidation.MAX_PAYLOAD_DEPTH = 4
ContractValidation.MAX_PAYLOAD_FIELDS = 48
ContractValidation.MAX_PAYLOAD_BYTES = 2_048
ContractValidation.MAX_STRING_BYTES = 160
ContractValidation.MAX_ACTION_BYTES = 48
ContractValidation.MAX_TAG_BYTES = 64
ContractValidation.MAX_TIMESTAMP_DRIFT_SECONDS = 15
ContractValidation.MAX_SEQUENCE_GAP = 1_024

export type ActionSchema = {
	requireValue: boolean?,
	valueMin: number?,
	valueMax: number?,
	minIntervalSeconds: number?,
	allowObjectId: boolean?,
}

local VALID_METRICS: { [string]: boolean } = {
	Score = true,
	Combo = true,
	Accuracy = true,
	Progress = true,
	Instability = true,
	Flow = true,
	ProjectedGrade = true,
	Friendship = true,
}

local ACTION_SCHEMAS: { [string]: { [string]: ActionSchema } } = {
	CheeseTower = {
		Place = { requireValue = true, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.08 },
		Nudge = { requireValue = false, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.05 },
		Rescue = { requireValue = false, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.2 },
		Bank = { requireValue = false, valueMin = 0, valueMax = 64, minIntervalSeconds = 0.5 },
		Topper = { requireValue = true, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.2 },
		Complete = { requireValue = false, valueMin = 0, valueMax = 1e6, minIntervalSeconds = 0.5 },
	},
	DogDash = {
		Jump = { requireValue = true, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.12 },
		SwitchDog = { requireValue = false, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.25 },
		Charge = { requireValue = true, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.2 },
		Lunge = { requireValue = true, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.15 },
		Route = { requireValue = true, valueMin = 0, valueMax = 1, minIntervalSeconds = 0.05 },
		Complete = { requireValue = false, valueMin = 0, valueMax = 1e6, minIntervalSeconds = 0.5 },
	},
	SatisfyStation = {
		Trace = {
			requireValue = true,
			valueMin = 0,
			valueMax = 1,
			minIntervalSeconds = 0.12,
			allowObjectId = true,
		},
		Squish = {
			requireValue = true,
			valueMin = 0,
			valueMax = 1,
			minIntervalSeconds = 0.12,
			allowObjectId = true,
		},
		Pop = {
			requireValue = true,
			valueMin = 0,
			valueMax = 1,
			minIntervalSeconds = 0.12,
			allowObjectId = true,
		},
		Peel = {
			requireValue = true,
			valueMin = 0,
			valueMax = 1,
			minIntervalSeconds = 0.12,
			allowObjectId = true,
		},
		Pipe = {
			requireValue = true,
			valueMin = 0,
			valueMax = 1,
			minIntervalSeconds = 0.12,
			allowObjectId = true,
		},
		Complete = { requireValue = false, valueMin = 0, valueMax = 1e6, minIntervalSeconds = 0.5 },
	},
}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function inspectBounded(
	value: any,
	depth: number,
	seen: { [any]: boolean },
	fieldCount: { number },
	byteCount: { number }
): (boolean, string?)
	local valueType = type(value)
	if valueType == "nil" or valueType == "boolean" then
		return true, nil
	elseif valueType == "number" then
		byteCount[1] += 8
		return if isFinite(value) then true else false,
			if isFinite(value) then nil else "non-finite number"
	elseif valueType == "string" then
		byteCount[1] += #value
		if byteCount[1] > ContractValidation.MAX_PAYLOAD_BYTES then
			return false, "payload is too large"
		end
		return if #value <= ContractValidation.MAX_STRING_BYTES then true else false,
			if #value <= ContractValidation.MAX_STRING_BYTES then nil else "string too large"
	elseif valueType ~= "table" then
		return false, "unsupported value type"
	end

	if depth >= ContractValidation.MAX_PAYLOAD_DEPTH then
		return false, "payload is too deeply nested"
	end
	if seen[value] then
		return false, "payload contains a cycle"
	end
	seen[value] = true

	for key, child in value do
		fieldCount[1] += 1
		if fieldCount[1] > ContractValidation.MAX_PAYLOAD_FIELDS then
			seen[value] = nil
			return false, "payload has too many fields"
		end
		if type(key) ~= "string" and type(key) ~= "number" then
			seen[value] = nil
			return false, "payload has an unsupported key"
		end
		byteCount[1] += if type(key) == "string" then #key else 8
		if byteCount[1] > ContractValidation.MAX_PAYLOAD_BYTES then
			seen[value] = nil
			return false, "payload is too large"
		end
		local valid, reason = inspectBounded(child, depth + 1, seen, fieldCount, byteCount)
		if not valid then
			seen[value] = nil
			return false, reason
		end
	end

	seen[value] = nil
	return true, nil
end

function ContractValidation.isBoundedPayload(value: any): (boolean, string?)
	return inspectBounded(value, 0, {}, { 0 }, { 0 })
end

function ContractValidation.actionSchema(gameId: string, action: string): ActionSchema?
	local gameActions = ACTION_SCHEMAS[gameId]
	if not gameActions then
		return nil
	end
	return gameActions[action]
end

function ContractValidation.validateActionValue(
	gameId: string,
	action: string,
	value: any
): (boolean, string?)
	local schema = ContractValidation.actionSchema(gameId, action)
	if not schema then
		return false, "action is unavailable for this game"
	end
	if value == nil then
		if schema.requireValue then
			return false, "value is required"
		end
		return true, nil
	end
	if type(value) ~= "number" or not isFinite(value) then
		return false, "invalid value"
	end
	local min = if schema.valueMin ~= nil then schema.valueMin else -math.huge
	local max = if schema.valueMax ~= nil then schema.valueMax else math.huge
	if value < min or value > max then
		return false, "value out of range"
	end
	return true, nil
end

function ContractValidation.validateActionInterval(
	gameId: string,
	action: string,
	now: number,
	lastActionAt: number?
): (boolean, string?)
	local schema = ContractValidation.actionSchema(gameId, action)
	if not schema or schema.minIntervalSeconds == nil then
		return true, nil
	end
	if lastActionAt == nil then
		return true, nil
	end
	if now - lastActionAt < schema.minIntervalSeconds then
		return false, "action frequency limit"
	end
	return true, nil
end

function ContractValidation.validateObjectId(
	gameId: string,
	action: string,
	objectId: any
): (boolean, string?)
	local schema = ContractValidation.actionSchema(gameId, action)
	if objectId == nil then
		return true, nil
	end
	if not schema or schema.allowObjectId ~= true then
		return false, "object id not allowed"
	end
	if
		type(objectId) ~= "number"
		or not isFinite(objectId)
		or objectId % 1 ~= 0
		or objectId < 1
		or objectId > 64
	then
		return false, "invalid object id"
	end
	return true, nil
end

function ContractValidation.validateRoundInput(
	input: any,
	expectedRoundId: string,
	lastSequence: number,
	serverTime: number,
	gameId: string?
): (boolean, string?)
	local bounded, boundedReason = ContractValidation.isBoundedPayload(input)
	if not bounded then
		return false, boundedReason
	end
	if type(input) ~= "table" then
		return false, "input must be a table"
	end
	if type(input.roundId) ~= "string" or input.roundId ~= expectedRoundId then
		return false, "stale round"
	end
	if
		type(input.sequence) ~= "number"
		or input.sequence % 1 ~= 0
		or input.sequence <= lastSequence
		or input.sequence > lastSequence + ContractValidation.MAX_SEQUENCE_GAP
	then
		return false, "sequence must increase"
	end
	if
		type(input.action) ~= "string"
		or input.action == ""
		or #input.action > ContractValidation.MAX_ACTION_BYTES
	then
		return false, "invalid action"
	end
	if gameId ~= nil then
		local schema = ContractValidation.actionSchema(gameId, input.action)
		if not schema then
			return false, "action is unavailable for this game"
		end
		local valueOk, valueReason =
			ContractValidation.validateActionValue(gameId, input.action, input.value)
		if not valueOk then
			return false, valueReason
		end
		local objectOk, objectReason =
			ContractValidation.validateObjectId(gameId, input.action, input.objectId)
		if not objectOk then
			return false, objectReason
		end
	elseif input.value ~= nil and (type(input.value) ~= "number" or not isFinite(input.value)) then
		return false, "invalid value"
	end
	if type(input.clientTime) ~= "number" or not isFinite(input.clientTime) then
		return false, "invalid timestamp"
	end
	if math.abs(serverTime - input.clientTime) > ContractValidation.MAX_TIMESTAMP_DRIFT_SECONDS then
		return false, "timestamp drift"
	end
	return true, nil
end

function ContractValidation.validateTelemetry(
	sample: any,
	expectedRoundId: string
): (boolean, string?)
	local bounded, boundedReason = ContractValidation.isBoundedPayload(sample)
	if not bounded then
		return false, boundedReason
	end
	if type(sample) ~= "table" then
		return false, "telemetry must be a table"
	end
	if type(sample.roundId) ~= "string" or sample.roundId ~= expectedRoundId then
		return false, "stale round"
	end
	if type(sample.metric) ~= "string" or not VALID_METRICS[sample.metric] then
		return false, "unknown metric"
	end
	if type(sample.value) ~= "number" or not isFinite(sample.value) then
		return false, "invalid telemetry value"
	end
	if
		sample.tag ~= nil
		and (type(sample.tag) ~= "string" or #sample.tag > ContractValidation.MAX_TAG_BYTES)
	then
		return false, "invalid telemetry tag"
	end
	return true, nil
end

return ContractValidation
