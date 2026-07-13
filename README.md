# roblox_game

Rojo project for Roblox Studio.

## First-time setup

Install tools from `rokit.toml`:

```powershell
rokit install
```

Install the Rojo Studio plugin:

```powershell
rojo plugin install
```

Start syncing:

```powershell
rojo serve default.project.json
```

Then open Roblox Studio, use the Rojo plugin, and connect to the local server.

## Folders

- `src/client`: LocalScripts under `StarterPlayerScripts`
- `src/server`: Scripts under `ServerScriptService`
- `src/shared`: Modules under `ReplicatedStorage.Shared`
- `src/ReplicatedStorage`: other replicated instances
- `src/workspace`: Workspace instances
