# roblox_game

AI-directed Roblox game built with strict Luau, Rojo, and automated validation.

This is a fresh project. `src/server/Main.server.luau` and `src/client/Main.client.luau`
are empty entry points ready for you to build on.

## First-time setup

Install tools from `rokit.toml`:

```powershell
rokit install
```

Install locked packages and validate the complete project:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate.ps1
```

The playable output is written to `artifacts/roblox_game.rbxl`.

Install the Rojo Studio plugin:

```powershell
rojo plugin install
```

Start syncing:

```powershell
rojo serve default.project.json
```

Then open Roblox Studio, use the Rojo plugin, and connect to the local server.

For AI feature prompts and playtest feedback, see `docs/AI_WORKFLOW.md`. All coding agents must follow `AGENTS.md`.

## Folders

- `src/client`: LocalScripts under `StarterPlayerScripts`
- `src/server`: Scripts under `ServerScriptService`
- `src/shared`: Modules under `ReplicatedStorage.Shared`
- `tests`: pure Luau tests run through Lune
- `art/source`: editable art and audio masters tracked with Git LFS
- `art/export`: reviewed files ready for Roblox import
