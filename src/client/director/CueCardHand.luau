--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VisualConfig = require(Shared.VisualConfig)

local P = VisualConfig.palette
local FONTS = VisualConfig.fonts
local RADIUS = VisualConfig.radius

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

local HOVER_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

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
		button.BackgroundColor3 = P.blush
		button.BorderSizePixel = 0
		button.Font = FONTS.heading
		button.Size = UDim2.new(1 / 3, -6, 1, 0)
		button.Text = "Cue loading…"
		button.TextColor3 = P.ink
		button.TextSize = 13
		button.TextWrapped = true
		button.Selectable = true
		button.Parent = root
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, RADIUS.card)
		corner.Parent = button

		local scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = button

		local stroke = Instance.new("UIStroke")
		stroke.Color = P.rose
		stroke.Thickness = 2
		stroke.Transparency = 1
		stroke.Parent = button

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
				button.BackgroundColor3 = P.blush
				button.BackgroundTransparency = if available then 0 else 0.5
				button:SetAttribute("CardId", id)
				button:SetAttribute("Available", available)
				if button:GetAttribute("Bound") ~= true then
					button:SetAttribute("Bound", true)
					local btnScale = button:FindFirstChildOfClass("UIScale")
					local btnStroke = button:FindFirstChildOfClass("UIStroke")

					local function hover(on: boolean)
						if button:GetAttribute("Available") ~= true then
							return
						end
						button.BackgroundColor3 = if on then P.rose else P.blush
						if btnStroke then
							TweenService:Create(
								btnStroke,
								HOVER_INFO,
								{ Transparency = if on then 0.35 else 1 }
							):Play()
						end
					end

					button.MouseEnter:Connect(function()
						hover(true)
					end)
					button.MouseLeave:Connect(function()
						hover(false)
					end)
					button.SelectionGained:Connect(function()
						hover(true)
					end)
					button.SelectionLost:Connect(function()
						hover(false)
					end)
					button.MouseButton1Down:Connect(function()
						if btnScale then
							btnScale.Scale = 0.94
						end
					end)
					button.MouseButton1Up:Connect(function()
						if btnScale then
							TweenService
								:Create(
									btnScale,
									TweenInfo.new(
										0.2,
										Enum.EasingStyle.Back,
										Enum.EasingDirection.Out
									),
									{ Scale = 1 }
								)
								:Play()
						end
					end)
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
