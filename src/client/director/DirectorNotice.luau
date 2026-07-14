--!strict

local DirectorNotice = {}

function DirectorNotice.new(parent: Instance): { set: (string, boolean?) -> () }
	local label = Instance.new("TextLabel")
	label.Name = "DirectorNotice"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Size = UDim2.new(1, 0, 0, 34)
	label.Text = "Show link ready"
	label.TextColor3 = Color3.fromRGB(226, 207, 190)
	label.TextSize = 13
	label.TextWrapped = true
	label.Parent = parent
	return {
		set = function(text: string, isError: boolean?)
			label.Text = text
			label.TextColor3 = if isError
				then Color3.fromRGB(244, 157, 181)
				else Color3.fromRGB(226, 207, 190)
		end,
	}
end

return DirectorNotice
