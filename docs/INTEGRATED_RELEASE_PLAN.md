# Integrated Premiere Release Plan

Checkpoint: 2026-07-13

Integration branch: `main`

This is the canonical plan for the combined Agent A and Agent B implementation. The lane documents record ownership and completed work; this document owns shared status, cross-lane dependencies, and release gates.

## Product outcome

Ship a private, polished two-player birthday Premiere:

- Bella plays three tactile, controller/touch-safe acts as the Star.
- The Director runs helpful cues, predictions, pacing, and surprises without directly changing rewards.
- Authoritative server state carries the show from invitation through a personalized finale and keepsake.
- Reconnects, muted audio, and reduced motion retain usable alternatives.

## Integrated architecture

| Area | Owner | Current contract |
| --- | --- | --- |
| Star input, HUD, minigame clients, feedback, sound | Agent A | Sends normalized ready/input/telemetry envelopes through `RoundIngress` |
| Minigame server trackers and scoring | Agent A | Validates actions and emits authoritative telemetry/results |
| Show state, roles, Director strategy, finale, worlds | Agent B | Owns phase progression, card dispatch, summaries, reconnect snapshots, and keepsake |
| Shared payloads and bootstrap | Stop-and-sync | `src/shared/**`, `Main.server.luau`, and `Main.client.luau` change only with both lanes reconciled |

The A-to-B gameplay seam is integrated: accepted Director cards dispatch into the active server-owned minigame hook before energy is spent. Telemetry flows back through bounded server-authored samples; no cue grants score or rewards directly.

## Completed implementation

1. Authoritative ingress, validation, replay protection, rate limiting, and reconnect grace.
2. Three complete acts with deterministic seeds, touch/keyboard/controller input, scoring, feedback, and accessibility hooks.
3. Full Premiere state machine from invitation to keepsake, including ordinary skips, dual-confirm finale skip, natural finale completion, replay, and one-shot encore.
4. Director dashboard with predictions, helpful cue cards, live telemetry, projected grades, graph markers, diagnostics, and Studio Round Lab.
5. Personalized server-owned performance summary consumed by the finale and keepsake presentation.
6. Authored Premiere sets, named camera markers, responsive UI tokens, reviewed art manifests, and runtime world-budget auditing.
7. Automated pure and integration coverage plus a successful strict Luau, Selene, StyLua, Lune, and Rojo build pipeline.

## Remaining release gates

These are shared acceptance tasks, not unfinished Agent A or Agent B implementation:

1. Run a two-player local-server rehearsal from invitation through keepsake.
2. Test touch, keyboard/mouse, and controller without a virtual cursor at phone, tablet, and desktop sizes.
3. Reconnect the Star during each act and verify the documented behavior: sequence state resynchronizes, but client-side visual simulation restarts while the authoritative server tracker continues. Decide whether that is acceptable for this private experience before expanding the frozen snapshot contract.
4. Disconnect the Director and verify deterministic Showrunner takeover.
5. Verify reduced motion, muted audio, visual sound cues, and finale controls during a complete run.
6. Profile target-mobile performance and inspect the world-budget attributes in Studio.
7. Replace optional safe-default personalization with the final birthday date, Roblox user IDs, personal message, and dog details if the user supplies them.
8. Publish privately and complete a two-device rehearsal.

## Error and regression policy

- `scripts/validate.ps1` must pass immediately before publishing.
- No generated/package directories may be edited manually.
- Do not expand `RoundSnapshot` or another shared payload in one lane. Record the fields needed, stop both lanes, update validation/types/server/client together, and add reconnect tests.
- A card effect is accepted only if the active server gameplay hook accepts it; energy is spent afterward.
- Do not mark live Studio/device gates complete based only on Lune tests.

## Verification command

```powershell
powershell -ExecutionPolicy Bypass -File scripts/validate.ps1
```
