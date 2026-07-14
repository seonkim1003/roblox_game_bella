# Agent B Lane Status

Checkpoint: 2026-07-13

Integrated branch: `main`

Canonical shared plan: [INTEGRATED_RELEASE_PLAN.md](INTEGRATED_RELEASE_PLAN.md)

## Ownership

Agent B owns show orchestration and presentation:

- roles, session state, Director strategy, diagnostics, and effect dispatch
- `src/client/director/**`
- `src/client/finale/**`
- `src/server/world/**`
- finale, keepsake, performance-summary, and show-flow tests

Shared contract changes require stop-and-sync with Agent A.

## Completed

- Frozen bounded ingress contract, authoritative session state, transition timers, and reconnect snapshots.
- Full invitation, mood, act, interlude, finale, keepsake, encore, and replay flow.
- Director predictions, helpful cue cards, energy/cadence strategy, graph, projected grade, moments, and connection diagnostics.
- Server-owned card dispatch into Agent A's active minigame hooks before energy expenditure.
- Studio Round Lab and fake authoritative telemetry controls.
- Personalized performance summary, natural finale completion, accessibility controls, and complete keepsake actions.
- Authored Cheese Atelier, Garden Dash, Dream Studio, transition corridor, and result set with named camera markers.
- Responsive Director layout, reviewed art manifests, and runtime lighting/transparency/particle budget audit.
- Pure strategy, state, summary, finale-flow, accessibility, dashboard, dispatch, diagnostics, and reconnect-snapshot tests.

## Shared acceptance items

- Complete the live two-player, controller/touch, reconnect, accessibility, and mobile-profile matrix in the canonical plan.
- Verify Director disconnect and deterministic Showrunner takeover in Studio.
- Do not claim full mid-act visual rehydration: only authoritative sequence/state recovery is implemented today.
- Any richer `RoundSnapshot` payload is a coordinated Agent A/Agent B contract change.
