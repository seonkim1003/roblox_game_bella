# roblox_game

Bella's Birthday Bash is an AI-directed Roblox game built with strict Luau, Rojo,
and automated validation. Milestone 1 is playable: a Director can run Cheese Tower,
watch Bella's live score, adjust difficulty, summon Gigi and Rambo, and send a
server-filtered message.

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

## Milestone 1 playtest

1. Start Rojo with `rojo serve default.project.json` and connect the Studio plugin.
2. In Studio's **Test** tab, choose **Local Server**, set **Players** to `2`, and start.
3. The first player is the Director and the second is Bella unless user IDs are set
   in `src/shared/Config.luau`.
4. On the Director client, select **Start Party Hub**, then launch **Cheese Tower**.
5. On Bella's client, tap, click, or press Space to drop cheese. Confirm the Director
   sees the score, can change difficulty, summon the dogs, send a message, and end
   the game.

Milestone 2 games, the dressed hub, surprises, and the finale are intentionally not
included yet.

For AI feature prompts and playtest feedback, see `docs/AI_WORKFLOW.md`. All coding agents must follow `AGENTS.md`.

## Folders

- `src/client`: LocalScripts under `StarterPlayerScripts`
- `src/server`: Scripts under `ServerScriptService`
- `src/shared`: Modules under `ReplicatedStorage.Shared`
- `tests`: pure Luau tests run through Lune
- `art/source`: editable art and audio masters tracked with Git LFS
- `art/export`: reviewed files ready for Roblox import
