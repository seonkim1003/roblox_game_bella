--!strict
-- Touch + keyboard/mouse abstraction for Bella's controls.
-- Minigames subscribe to named actions; they never touch UserInputService directly.

local UserInputService = game:GetService("UserInputService")

export type ActionName = "Drop" | "Left" | "Right" | "Primary" | "Slice"

export type InputRouterApi = {
	start: (self: InputRouterApi) -> (),
	stop: (self: InputRouterApi) -> (),
	on: (self: InputRouterApi, action: ActionName, callback: () -> ()) -> () -> (),
	setEnabled: (self: InputRouterApi, enabled: boolean) -> (),
	-- Latest pointer position in screen pixels (mouse or primary touch), if any.
	getPointer: (self: InputRouterApi) -> Vector2?,
}

local InputRouter = {}
InputRouter.__index = InputRouter

local DEBOUNCE = 0.08

local function fire(self: any, action: ActionName)
	local now = os.clock()
	local last = self._lastFire[action]
	if last and now - last < DEBOUNCE then
		return
	end
	self._lastFire[action] = now

	local list = self._listeners[action]
	if not list then
		return
	end
	for _, callback in list do
		-- Synchronous dispatch so a Drop handler can set its own re-entrancy
		-- guard before a second mirrored touch/mouse event is processed.
		callback()
	end
end

function InputRouter.new(): InputRouterApi
	local self = setmetatable({
		_enabled = false,
		_started = false,
		_listeners = {} :: { [ActionName]: { () -> () } },
		_lastFire = {} :: { [ActionName]: number },
		_connections = {} :: { RBXScriptConnection },
		_pointer = nil :: Vector2?,
		_dragOrigin = nil :: Vector2?,
		_dragPointerType = nil :: Enum.UserInputType?,
	}, InputRouter)
	return (self :: any) :: InputRouterApi
end

function InputRouter.start(self: any)
	if self._started then
		return
	end
	self._started = true
	self._enabled = true

	local SLICE_THRESHOLD = 52

	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed or not self._enabled then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self._pointer = Vector2.new(input.Position.X, input.Position.Y)
				self._dragOrigin = self._pointer
				self._dragPointerType = input.UserInputType
				local drop: ActionName = "Drop"
				local primary: ActionName = "Primary"
				fire(self, drop)
				fire(self, primary)
				return
			end

			if input.UserInputType == Enum.UserInputType.Touch then
				self._pointer = Vector2.new(input.Position.X, input.Position.Y)
				self._dragOrigin = self._pointer
				self._dragPointerType = input.UserInputType
				-- TouchBegan fires per finger; treat as Drop/Primary.
				local drop: ActionName = "Drop"
				local primary: ActionName = "Primary"
				fire(self, drop)
				fire(self, primary)
				return
			end

			-- Inline key → action (no function return) so the ActionName singleton
			-- union survives luau-lsp; see RoleService for the same gotcha.
			local keyCode = input.KeyCode
			if keyCode == Enum.KeyCode.Space or keyCode == Enum.KeyCode.ButtonA then
				local drop: ActionName = "Drop"
				local primary: ActionName = "Primary"
				fire(self, drop)
				fire(self, primary)
			elseif
				keyCode == Enum.KeyCode.Left
				or keyCode == Enum.KeyCode.A
				or keyCode == Enum.KeyCode.DPadLeft
			then
				local left: ActionName = "Left"
				fire(self, left)
			elseif
				keyCode == Enum.KeyCode.Right
				or keyCode == Enum.KeyCode.D
				or keyCode == Enum.KeyCode.DPadRight
			then
				local right: ActionName = "Right"
				fire(self, right)
			elseif keyCode == Enum.KeyCode.ButtonX or keyCode == Enum.KeyCode.ButtonB then
				-- Controller "slice" affordance for Satisfy Station.
				local slice: ActionName = "Slice"
				fire(self, slice)
			end
		end)
	)

	table.insert(
		self._connections,
		UserInputService.InputChanged:Connect(function(input: InputObject, _gp: boolean)
			if not self._enabled then
				return
			end
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				self._pointer = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
	)

	table.insert(
		self._connections,
		UserInputService.InputEnded:Connect(function(input: InputObject, _gp: boolean)
			if not self._enabled then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local origin = self._dragOrigin
			local pointerType = self._dragPointerType
			self._dragOrigin = nil
			self._dragPointerType = nil
			if not origin or pointerType ~= input.UserInputType then
				return
			end
			local ended = Vector2.new(input.Position.X, input.Position.Y)
			self._pointer = ended
			local delta = ended - origin
			if delta.Magnitude >= SLICE_THRESHOLD then
				local slice: ActionName = "Slice"
				fire(self, slice)
			end
		end)
	)

	-- Horizontal swipe for Left/Right without hijacking Drop taps.
	local swipeStart: Vector3? = nil
	table.insert(
		self._connections,
		UserInputService.TouchStarted:Connect(function(touch: InputObject, _gp: boolean)
			if not self._enabled then
				return
			end
			swipeStart = touch.Position
		end)
	)
	table.insert(
		self._connections,
		UserInputService.TouchEnded:Connect(function(touch: InputObject, _gp: boolean)
			if not self._enabled or not swipeStart then
				swipeStart = nil
				return
			end
			local delta = touch.Position - swipeStart
			swipeStart = nil
			if math.abs(delta.X) < 40 or math.abs(delta.X) < math.abs(delta.Y) then
				return
			end
			if delta.X > 0 then
				local right: ActionName = "Right"
				fire(self, right)
			else
				local left: ActionName = "Left"
				fire(self, left)
			end
		end)
	)
end

function InputRouter.stop(self: any)
	for _, conn in self._connections do
		conn:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._listeners)
	table.clear(self._lastFire)
	self._pointer = nil
	self._dragOrigin = nil
	self._dragPointerType = nil
	self._started = false
	self._enabled = false
end

function InputRouter.getPointer(self: any): Vector2?
	return self._pointer
end

function InputRouter.on(self: any, action: ActionName, callback: () -> ()): () -> ()
	local list = self._listeners[action]
	if not list then
		list = {}
		self._listeners[action] = list
	end
	table.insert(list, callback)

	return function()
		local current = self._listeners[action]
		if not current then
			return
		end
		local index = table.find(current, callback)
		if index then
			table.remove(current, index)
		end
	end
end

function InputRouter.setEnabled(self: any, enabled: boolean)
	self._enabled = enabled
end

return InputRouter
