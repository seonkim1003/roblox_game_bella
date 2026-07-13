-- Server bootstrap. FROZEN after Milestone 0.
-- RoleService assigns Director/Star; ShowDirectorService runs the show and
-- folder-loads minigames from src/server/minigames (no edit needed to add one).

local RoleService = require(script.Parent.RoleService)
local ShowDirectorService = require(script.Parent.ShowDirectorService)

RoleService.start()
ShowDirectorService.start()

print("[Bash] Server ready -- Bella's Birthday Bash is standing by.")
