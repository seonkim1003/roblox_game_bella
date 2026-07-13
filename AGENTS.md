# AI Development Rules

This is a Roblox-only game. Roblox Studio is the engine, Rojo is the filesystem bridge, and Luau is the language.

## Source of truth

- Edit Rojo-managed scripts on disk, never in Roblox Studio.
- Do not edit `Packages`, `ServerPackages`, `artifacts`, `build.rbxl`, or `sourcemap.json`.
- Put client code in `src/client`, authoritative code in `src/server`, and shared types or pure utilities in `src/shared`.
- Keep asset source files in `art/source` and reviewed exports in `art/export`.

## Engineering rules

- New Luau modules use `--!strict` unless a documented engine limitation prevents it.
- The server owns currency, inventory, progression, damage, rewards, purchases, and saved data.
- Validate and rate-limit every client-triggered server action.
- Keep remotes behind a small networking boundary. Do not scatter remote handling through gameplay code.
- Prefer small modules with explicit dependencies. Do not add a framework without a demonstrated need.
- Use the pinned Wally packages before inventing replacement Promise, Signal, cleanup, or profile-storage systems.
- Preserve touch, keyboard/mouse, and controller behavior for player-facing features.

## Required verification

Run this before handing work back:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate.ps1
```

The change is not complete until formatting, linting, type analysis, tests, and the Rojo build all pass.
