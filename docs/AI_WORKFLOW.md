# AI-Directed Workflow

The human role on this project is creative direction and playtesting. AI agents handle implementation and automated verification.

## For each feature

1. Describe the player experience, mood, success condition, and what must not change.
2. Ask the agent to inspect the repository and implement the feature end to end.
3. Require the agent to run `scripts/validate.ps1`.
4. Connect Roblox Studio to Rojo and play the feature.
5. Report concrete observations: what felt good, what was confusing, what broke, and the desired adjustment.

## Prompt template

```text
Build [feature] for this Roblox birthday game.

Player experience: [what the player should feel and do]
Visual mood: [colors, references, atmosphere]
Success condition: [observable result]
Constraints: [mobile/controller support, performance, existing behavior]

Inspect the existing project first, implement the complete feature, add focused tests,
run scripts/validate.ps1, and tell me exactly what to test in Roblox Studio.
```

Keep feedback observable. "The camera clips through the cake near the stairs" produces a better iteration than "make it better."
