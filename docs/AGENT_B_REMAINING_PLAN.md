# Agent B Remaining Plan

Checkpoint date: 2026-07-13
Checkpoint branch: `main`

## Completed at this checkpoint

- B0 contract freeze (`13dc7ab`): typed round/session contracts, server-generated IDs and seeds, bounded payload validation, sequence/timestamp/action checks, token-bucket limiting, reconnect grace, deterministic mock telemetry, and contract tests.
- B1 foundation: pure authoritative Premiere state machine and tests covering Lobby, Invitation, Lounge, Act Introduction, Minigame, Act Result, Interlude, Headliner Finale, and Keepsake Result.
- B1 runtime wiring: mood selection, completion-driven acts, ordinary cinematic skips, dual-confirm finale skips, state snapshots, reconnect handling, transition timers, replay, and encore requests.
- B2 foundation and runtime wiring: deterministic three-card hands, regenerating cue energy, contextual card availability, prediction rewards, shared finale energy, cue timing grades, and deterministic solo Showrunner fallback.
- B3 module split: `DirectorShell`, `ShowTimeline`, `LiveTrendGraph`, `ProgressWidget`, `ProjectedGrade`, `RecentMoments`, `CueCardHand`, and `DirectorNotice`.
- B3 graph foundation: pooled 300-segment rolling graph representing 60 seconds at five samples per second; incoming samples animate over 150 ms without rebuilding the graph.
- Partial B4 visual work: palette and lighting tokens, reusable world primitives, moonlit lounge, improved dog models, surprise treatments, and a dressed finale set.

## Required integration before more shared-contract work

1. Rebase Agent A's `agent-a/gameplay` branch onto B0 commit `13dc7ab`.
2. Resolve only integration points; preserve Agent A ownership of `src/client/minigames/**`, `src/client/star/**`, `src/client/juice/**`, and `src/server/minigames/**`.
3. Wire Agent A's A1 normalized actions and telemetry through the frozen B0 ingress envelope.
4. Do not alter frozen shared payload shapes without stopping both lanes and agreeing on the change.

## B1 remaining work

- Add two-player Studio integration tests for the full invitation-to-act-result path.
- Verify automatic transition timing under player reconnect and late role assignment.
- Confirm the personalized finale completes into Keepsake Result without relying on a skip.
- Add visible muted-audio and reduced-motion controls to the Premiere overlay.

## B2 remaining work

- Add prediction controls to the Director shell.
- Connect each accepted card effect to Agent A's server-owned gameplay hooks after the Agent A rebase.
- Add Bella's Encore button to the final keepsake presentation and define its deterministic replay behavior.
- Balance energy costs, regeneration, cue windows, and solo Showrunner cadence using two-device playtests.
- Verify every card is strictly helpful and cannot alter rewards directly.

## B3 remaining work

- Add Director card markers and significant-moment marker legends to the graph.
- Add a projected-grade target band rather than only the current projected grade.
- Add active-dog and remaining-object labels when Agent A exposes those telemetry tags.
- Add connection validation detail for rejected sequence, stale round, and timestamp drift states.
- Verify graph pooling and layout performance at phone, tablet, desktop, and controller-safe resolutions.
- Add a Studio-only dashboard toggle that enables `BashFakeTelemetry` and launches a chosen seeded round through `ShowDirectorService.debugLaunch`.

## B4 remaining work

- Build authored Cheese Atelier, Garden Dash, Dream Studio, transition corridor, and photo-ready result sets under `src/server/world/**`.
- Add named camera composition markers for every set and transition.
- Add reviewed source/export manifests under `art/source/**` and `art/export/**`; do not insert placeholder asset IDs.
- Finish responsive visual tokens for spacing, corner radii, typography, button states, motion timings, and safe areas.
- Audit lighting, transparent parts, particles, and dynamic lights against the declared budgets.
- Run target-mobile performance profiling in Roblox Studio.

## B5 remaining work

- Create a server-owned performance summary from authoritative `RoundResult` records and Director strategy state.
- Select featured trophy, best moment, personalized title, dog pose, lighting accent, Ratthew callback, and confetti treatment from real performance data.
- Extend `FinaleService.begin` and `FinalePresenter` to consume that summary.
- Build the complete keepsake card with all act grades, Director cue grade, best act, dog pose, Replay, and Encore actions.
- Require both players for personalized finale skipping, but allow either player to skip ordinary cinematics.
- Add finale/result pure tests and reconnect snapshots.

## Final acceptance and ship verification

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate.ps1
```

Then verify:

- Two-player local server and two physical devices.
- Touch, keyboard/mouse, and controller without a virtual cursor.
- Reduced motion and muted audio with visual alternatives.
- Invalid roles, stale round IDs, replayed sequences, timestamp drift, oversized payloads, and rate-limit bursts.
- Star reconnect during each minigame and Director disconnect with Showrunner takeover.
- Full Premiere from invitation through keepsake with no unexplained idle gap over ten seconds.
- No placeholders and no changes to generated/package directories.
