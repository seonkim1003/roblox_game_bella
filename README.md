# roblox_game

Bella's Birthday Bash is a private two-player Roblox Premiere built with strict
Luau, Rojo, and automated validation. A Director runs the show while Bella plays
three fixed-order acts, watches the Rambo-versus-Gigi cinematic, and reaches a
personalized finale and keepsake.

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

## Release-candidate playtest

1. Start Rojo with `rojo serve default.project.json` and connect the Studio plugin.
2. In Studio's **Test** tab, choose **Local Server**, set **Players** to `2`, and start.
3. On the role-selection screen, choose **Host** for the Director controls and
   **Bella** for the Star experience. Each role can be claimed once. Studio also
   supports `BashRoleOverride` for focused local testing.
4. The Director opens the invitation and Bella chooses a mood. Follow the authored
   order: **Ratthew's Cheese Tower** (`CheeseTower`), the Rambo-versus-Gigi cinematic
   followed by **Gigi & Rambo Dash** (`DogDash`), then **ASMR Satisfy Station**
   (`SatisfyStation`). Acts cannot be freely launched out of order.
5. On Bella's client, verify touch, keyboard/mouse, and controller input; validated
   live telemetry; clean act completion; and the transition into each next act.
   Individual acts do not have a free replay control. The keepsake offers a full-show
   replay after the complete fixed-order run.
6. During the hub and acts, test all dog tricks, a filtered message, Confetti, Cake,
   Balloons, and ASMR Burst.
7. Complete the headliner finale. Confirm gameplay controls lock, the cozy set
   appears, both-player skip confirmation works, the message advances, the brooding
   guest reveal completes, and the camera returns on completion or cancellation.

The name, dog details, palette, guardrails, and finale message are already populated
in `src/shared/Config.luau`; they are not generic placeholders. Role IDs are optional:
leaving them at zero lets the two players choose Host or Bella when they join. A
non-zero ID may be used later only if a role should be reserved for one account.

## Authoritative scoring contract

- Clients send input intent, never scores, grades, progress, object identity, or
  completion authority.
- Each minigame server owns its timer, legal action sequence, bounded state, score,
  progress, and completion conditions. Invalid, duplicate, out-of-order, impossible,
  or over-frequency actions are rejected.
- A result and grade require valid attempts. An immediate `Complete` or zero-action
  run cannot receive a passing grade.
- Official results and dashboard projections use the same shared grade policy.
  Dashboard telemetry is advisory and cannot mutate rewards or official results.

For AI feature prompts and playtest feedback, see `docs/AI_WORKFLOW.md`. All coding agents must follow `AGENTS.md`.

## Folders

- `src/client`: LocalScripts under `StarterPlayerScripts`
- `src/server`: Scripts under `ServerScriptService`
- `src/shared`: Modules under `ReplicatedStorage.Shared`
- `tests`: pure Luau tests run through Lune
- `art/source`: editable art and audio masters tracked with Git LFS
- `art/export`: reviewed files ready for Roblox import
