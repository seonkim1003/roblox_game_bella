--!strict
-- Touch + keyboard/mouse abstraction for Bella's controls.
-- Minigames subscribe to named actions; they never touch UserInputService directly.

local UserInputService = game:GetService("UserInputService")

export type ActionName = "Drop" | "Left" | "Right" | "Primary"

export type InputRouterApi = {
	start: (self: InputRouterApi) -> (),
	stop: (self: InputRouterApi) -> (),
	on: (self: InputRouterApi, action: ActionName, callback: () -> ()) -> () -> (),
	setEnabled: (self: InputRouterApi, enabled: boolean) -> (),
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
	}, InputRouter)
	return (self :: any) :: InputRouterApi
end

function InputRouter.start(self: any)
	if self._started then
		return
	end
	self._started = true
	self._enabled = true

	table.insert(
		self._connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed or not self._enabled then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local drop: ActionName = "Drop"
				local primary: ActionName = "Primary"
				fire(self, drop)
				fire(self, primary)
				return
			end

			if input.UserInputType == Enum.UserInputType.Touch then
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
	self._started = false
	self._enabled = false
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
