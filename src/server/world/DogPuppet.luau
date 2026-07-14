--!strict

-- Motor6D-driven dog performance clips. Limb animation replaces rigid body glides.

local RunService = game:GetService("RunService")

export type Clip = "Idle" | "Walk" | "Spin" | "Sit" | "Curled"

type Motors = {
	body: Motor6D,
	head: Motor6D,
	tail: Motor6D,
	legFL: Motor6D?,
	legFR: Motor6D?,
	legBL: Motor6D?,
	legBR: Motor6D?,
}

type Controller = {
	model: Model,
	motors: Motors,
	clip: Clip,
	connection: RBXScriptConnection?,
	elapsed: number,
	bases: { [Motor6D]: CFrame },
}

local DogPuppet = {}
local controllers: { [Model]: Controller } = {}

local function captureBases(motors: Motors): { [Motor6D]: CFrame }
	local bases: { [Motor6D]: CFrame } = {}
	bases[motors.body] = motors.body.C0
	bases[motors.head] = motors.head.C0
	bases[motors.tail] = motors.tail.C0
	if motors.legFL then
		bases[motors.legFL] = motors.legFL.C0
	end
	if motors.legFR then
		bases[motors.legFR] = motors.legFR.C0
	end
	if motors.legBL then
		bases[motors.legBL] = motors.legBL.C0
	end
	if motors.legBR then
		bases[motors.legBR] = motors.legBR.C0
	end
	return bases
end

local function readMotors(model: Model): Motors?
	local body = model:FindFirstChild("BodyMotor")
	local head = model:FindFirstChild("HeadMotor")
	local tail = model:FindFirstChild("TailMotor")
	if
		not (
			body
			and body:IsA("Motor6D")
			and head
			and head:IsA("Motor6D")
			and tail
			and tail:IsA("Motor6D")
		)
	then
		return nil
	end
	local fl = model:FindFirstChild("LegFLMotor")
	local fr = model:FindFirstChild("LegFRMotor")
	local bl = model:FindFirstChild("LegBLMotor")
	local br = model:FindFirstChild("LegBRMotor")
	return {
		body = body,
		head = head,
		tail = tail,
		legFL = if fl and fl:IsA("Motor6D") then fl else nil,
		legFR = if fr and fr:IsA("Motor6D") then fr else nil,
		legBL = if bl and bl:IsA("Motor6D") then bl else nil,
		legBR = if br and br:IsA("Motor6D") then br else nil,
	}
end

local function setOffset(ctrl: Controller, motor: Motor6D?, offset: CFrame)
	if not motor then
		return
	end
	local base = ctrl.bases[motor]
	if base then
		motor.C0 = base * offset
	end
end

local function tickClip(ctrl: Controller, dt: number)
	ctrl.elapsed += dt
	local t = ctrl.elapsed
	if ctrl.clip == "Walk" then
		local swing = math.sin(t * 14)
		local opposite = math.sin(t * 14 + math.pi)
		setOffset(ctrl, ctrl.motors.legFL, CFrame.Angles(swing * 0.75, 0, 0))
		setOffset(ctrl, ctrl.motors.legBR, CFrame.Angles(swing * 0.75, 0, 0))
		setOffset(ctrl, ctrl.motors.legFR, CFrame.Angles(opposite * 0.75, 0, 0))
		setOffset(ctrl, ctrl.motors.legBL, CFrame.Angles(opposite * 0.75, 0, 0))
		setOffset(ctrl, ctrl.motors.head, CFrame.Angles(math.sin(t * 7) * 0.08, 0, 0))
		setOffset(ctrl, ctrl.motors.tail, CFrame.Angles(0, math.sin(t * 16) * 0.45, 0))
		setOffset(ctrl, ctrl.motors.body, CFrame.Angles(0, 0, math.sin(t * 14) * 0.04))
	elseif ctrl.clip == "Idle" then
		setOffset(
			ctrl,
			ctrl.motors.head,
			CFrame.Angles(math.sin(t * 2.2) * 0.06, math.sin(t * 1.4) * 0.08, 0)
		)
		setOffset(ctrl, ctrl.motors.tail, CFrame.Angles(0, math.sin(t * 5) * 0.35, 0))
		setOffset(ctrl, ctrl.motors.body, CFrame.Angles(0, 0, math.sin(t * 1.8) * 0.02))
		setOffset(ctrl, ctrl.motors.legFL, CFrame.identity)
		setOffset(ctrl, ctrl.motors.legFR, CFrame.identity)
		setOffset(ctrl, ctrl.motors.legBL, CFrame.identity)
		setOffset(ctrl, ctrl.motors.legBR, CFrame.identity)
	elseif ctrl.clip == "Spin" then
		local spin = t * 10
		setOffset(ctrl, ctrl.motors.body, CFrame.Angles(0, spin, 0))
		setOffset(ctrl, ctrl.motors.tail, CFrame.Angles(0, math.sin(t * 20) * 0.6, 0))
		setOffset(ctrl, ctrl.motors.head, CFrame.Angles(0.1, 0, 0))
	elseif ctrl.clip == "Sit" then
		setOffset(
			ctrl,
			ctrl.motors.body,
			CFrame.Angles(math.rad(-18), 0, 0) * CFrame.new(0, -0.25, 0.15)
		)
		setOffset(ctrl, ctrl.motors.legBL, CFrame.Angles(math.rad(70), 0, 0))
		setOffset(ctrl, ctrl.motors.legBR, CFrame.Angles(math.rad(70), 0, 0))
		setOffset(ctrl, ctrl.motors.legFL, CFrame.Angles(math.rad(12), 0, 0))
		setOffset(ctrl, ctrl.motors.legFR, CFrame.Angles(math.rad(12), 0, 0))
		setOffset(ctrl, ctrl.motors.head, CFrame.Angles(math.rad(12), 0, 0))
		setOffset(ctrl, ctrl.motors.tail, CFrame.Angles(math.rad(25), math.sin(t * 6) * 0.25, 0))
	elseif ctrl.clip == "Curled" then
		setOffset(
			ctrl,
			ctrl.motors.body,
			CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, -0.1, 0)
		)
		setOffset(ctrl, ctrl.motors.head, CFrame.Angles(math.rad(8), math.rad(-20), 0))
		setOffset(ctrl, ctrl.motors.tail, CFrame.Angles(0, math.rad(40), math.rad(10)))
		setOffset(ctrl, ctrl.motors.legFL, CFrame.Angles(math.rad(40), 0, math.rad(-10)))
		setOffset(ctrl, ctrl.motors.legFR, CFrame.Angles(math.rad(45), 0, math.rad(10)))
		setOffset(ctrl, ctrl.motors.legBL, CFrame.Angles(math.rad(55), 0, 0))
		setOffset(ctrl, ctrl.motors.legBR, CFrame.Angles(math.rad(55), 0, 0))
	end
end

function DogPuppet.bind(model: Model): Controller?
	local existing = controllers[model]
	if existing then
		return existing
	end
	local motors = readMotors(model)
	if not motors then
		return nil
	end
	local ctrl: Controller = {
		model = model,
		motors = motors,
		clip = "Idle",
		connection = nil,
		elapsed = 0,
		bases = captureBases(motors),
	}
	ctrl.connection = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
			DogPuppet.release(model)
			return
		end
		tickClip(ctrl, dt)
	end)
	controllers[model] = ctrl
	model.Destroying:Connect(function()
		DogPuppet.release(model)
	end)
	return ctrl
end

function DogPuppet.play(model: Model, clip: Clip)
	local ctrl = DogPuppet.bind(model)
	if not ctrl then
		return
	end
	ctrl.clip = clip
	ctrl.elapsed = 0
end

function DogPuppet.release(model: Model)
	local ctrl = controllers[model]
	if not ctrl then
		return
	end
	if ctrl.connection then
		ctrl.connection:Disconnect()
		ctrl.connection = nil
	end
	controllers[model] = nil
end

return DogPuppet
