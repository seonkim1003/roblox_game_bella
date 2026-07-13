local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Greeting = require(Shared.Greeting)

print(Greeting.message("server"))
