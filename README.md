# roblox_game

Bella's Birthday Bash is an AI-directed Roblox game built with strict Luau, Rojo,
and automated validation. Milestone 2 is playable: a Director can run all three
minigames, watch Bella's live score, adjust difficulty, summon Gigi and Rambo,
send a server-filtered message, trigger surprises, and start the grand finale.

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

## Milestone 2 playtest

1. Start Rojo with `rojo serve default.project.json` and connect the Studio plugin.
2. In Studio's **Test** tab, choose **Local Server**, set **Players** to `2`, and start.
3. The first player is the Director and the second is Bella unless user IDs are set
   in `src/shared/Config.luau`.
4. On the Director client, select **Start Party Hub** and launch each game:
   **Ratthew's Cheese Tower**, **Gigi & Rambo Dash**, and **ASMR Satisfy Station**.
5. On Bella's client, verify touch or keyboard/controller input, live score updates,
   difficulty changes, clean game completion, and replaying a game after it ends.
6. During the hub and minigames, test all dog tricks, a filtered message, Confetti,
   Cake, Balloons, and ASMR Burst.
7. Return to the hub and select **Start Grand Finale**. Confirm gameplay controls
   lock, the cozy set appears, the message advances, and the brooding guest reveal
   completes without errors.

Personal details, user IDs, dog personalities, and the final birthday message remain
placeholders in `src/shared/Config.luau` until the Milestone 3 personalization pass.

For AI feature prompts and playtest feedback, see `docs/AI_WORKFLOW.md`. All coding agents must follow `AGENTS.md`.

## Folders

- `src/client`: LocalScripts under `StarterPlayerScripts`
- `src/server`: Scripts under `ServerScriptService`
- `src/shared`: Modules under `ReplicatedStorage.Shared`
- `tests`: pure Luau tests run through Lune
- `art/source`: editable art and audio masters tracked with Git LFS
- `art/export`: reviewed files ready for Roblox import
