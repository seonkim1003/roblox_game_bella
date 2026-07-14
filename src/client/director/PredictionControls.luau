--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualConfig = require(ReplicatedStorage:WaitForChild("Shared").VisualConfig)

type Payload = { [string]: any }
type Send = (string, Payload?) -> ()

export type Controls = {
	set: (phase: string, prediction: string?, resolved: boolean, matched: boolean?) -> (),
}

local PredictionControls = {}
local P = VisualConfig.palette
local PREDICTIONS = { "Perfect", "Rescue", "Finish" }

function PredictionControls.new(parent: Instance, send: Send): Controls
	local root = Instance.new("Frame")
	root.Name = "PredictionControls"
	root.BackgroundColor3 = P.night
	root.BorderSizePixel = 0
	root.Size = UDim2.new(1, 0, 0, 102)
	root.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = root

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.Position = UDim2.fromOffset(12, 7)
	heading.Size = UDim2.new(0.48, -12, 0, 20)
	heading.Text = "CALL THE NEXT MOMENT"
	heading.TextColor3 = P.linen
	heading.TextSize = 11
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Parent = root

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.Position = UDim2.new(0.48, 0, 0, 7)
	status.Size = UDim2.new(0.52, -12, 0, 20)
	status.Text = "WAITING FOR AN ACT"
	status.TextColor3 = P.linen
	status.TextSize = 10
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Parent = root

	local buttonRow = Instance.new("Frame")
	buttonRow.BackgroundTransparency = 1
	buttonRow.Position = UDim2.fromOffset(12, 34)
	buttonRow.Size = UDim2.new(1, -24, 0, 54)
	buttonRow.Parent = root
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.Parent = buttonRow

	local buttons: { [string]: TextButton } = {}
	local strokes: { [string]: UIStroke } = {}
	local phase = "Lobby"
	local selected: string? = nil
	local predictionResolved = false
	local predictionMatched: boolean? = nil

	local function render()
		local open = phase == "Minigame" and selected == nil
		if selected == nil then
			status.Text = if phase == "Minigame"
				then "CHOOSE ONCE PER ACT"
				else "WAITING FOR AN ACT"
			status.TextColor3 = if phase == "Minigame" then P.mint else P.linen
		elseif not predictionResolved then
			status.Text = `LOCKED: {string.upper(selected)}`
			status.TextColor3 = P.butter
		elseif predictionMatched == true then
			status.Text = "CALLED IT: +15 FINALE"
			status.TextColor3 = P.mint
		else
			status.Text = "NOT THIS TIME: NEW CALL NEXT ACT"
			status.TextColor3 = P.linen
		end

		for name, button in buttons do
			local isSelected = selected == name
			button.Active = open
			button.Selectable = open
			button.BackgroundColor3 = if isSelected then P.butter else P.plum
			button.BackgroundTransparency = if open or isSelected then 0 else 0.42
			button.TextColor3 = if isSelected then P.ink else P.cream
			strokes[name].Enabled = isSelected
		end
	end

	for _, prediction in PREDICTIONS do
		local button = Instance.new("TextButton")
		button.Name = `Predict{prediction}`
		button.AutoButtonColor = false
		button.BackgroundColor3 = P.plum
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		button.Text = string.upper(prediction)
		button.TextColor3 = P.cream
		button.TextSize = 12
		button.Parent = buttonRow
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 12)
		buttonCorner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = P.cream
		stroke.Enabled = false
		stroke.Thickness = 2
		stroke.Parent = button
		buttons[prediction] = button
		strokes[prediction] = stroke
		button.SelectionGained:Connect(function()
			if button.Selectable then
				stroke.Enabled = true
			end
		end)
		button.SelectionLost:Connect(function()
			stroke.Enabled = selected == prediction
		end)
		button.MouseEnter:Connect(function()
			if button.Active and selected ~= prediction then
				button.BackgroundColor3 = P.rose
			end
		end)
		button.MouseLeave:Connect(render)
		button.Activated:Connect(function()
			if phase == "Minigame" and selected == nil then
				send("Predict", { moment = prediction })
			end
		end)
	end

	render()
	return {
		set = function(
			newPhase: string,
			newPrediction: string?,
			resolved: boolean,
			matched: boolean?
		)
			phase = newPhase
			selected = newPrediction
			predictionResolved = resolved
			predictionMatched = matched
			render()
		end,
	}
end

return PredictionControls
