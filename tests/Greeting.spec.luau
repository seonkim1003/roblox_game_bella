local Greeting = require("../src/shared/Greeting")

local actual = Greeting.message("test")
local expected = "Hello from test! Rojo is syncing."

assert(actual == expected, `expected {expected}, got {actual}`)

print("PASS Greeting.spec")
