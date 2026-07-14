--!strict

type Payload = { [string]: any }
type Send = (string, Payload?) -> ()

local CueCardHand = {}

local LABELS: { [string]: string } = {
	DogAssist = "Dog Assist",
	SlowMotion = "Slow Motion",
	PerfectZone = "Perfect Zone",
	TreatRain = "Treat Rain",
	RescueSpotlight = "Rescue Spotlight",
	DreamModeBoost = "Dream Mode Boost",
	DoubleOrNothingTopper = "Double-or-Nothing",
	ConfettiFinish = "Confetti Finish",
}

function CueCardHand.new(parent: Instance, send: Send): { set: ({ any }) -> () }
	local root = Instance.new("Frame")
	root.Name = "CueCardHand"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, 96)
	root.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = root
	local buttons: { TextButton } = {}
	for index = 1, 3 do
		local button = Instance.new("TextButton")
		button.Name = `Cue{index}`
		button.AutoButtonColor = false
		button.BackgroundColor3 = Color3.fromRGB(244, 157, 181)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBold
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		button.Text = "Cue loading…"
		button.TextColor3 = Color3.fromRGB(39, 31, 49)
		button.TextSize = 13
		button.TextWrapped = true
		button.Selectable = true
		button.Parent = root
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = button
		table.insert(buttons, button)
	end
	return {
		set = function(hand: { any })
			for index, button in buttons do
				local card = hand[index]
				local id = if type(card) == "table" and type(card.id) == "string"
					then card.id
					else nil
				local available = type(card) == "table" and card.available == true
				local cost = if type(card) == "table" and type(card.cost) == "number"
					then card.cost
					else 0
				button.Text = if id then `{LABELS[id] or id}\n{cost} energy` else "Cue loading…"
				button.Active = available
				button.Selectable = available
				button.BackgroundTransparency = if available then 0 else 0.5
				button:SetAttribute("CardId", id)
				if button:GetAttribute("Bound") ~= true then
					button:SetAttribute("Bound", true)
					button.Activated:Connect(function()
						local selected = button:GetAttribute("CardId")
						if type(selected) == "string" then
							send("UseCard", { cardId = selected })
						end
					end)
				end
			end
		end,
	}
end

return CueCardHand
