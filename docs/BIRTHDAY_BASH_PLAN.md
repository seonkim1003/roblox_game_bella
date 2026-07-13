# Bella's Birthday Bash — Build Plan

A private **2-player live show** built in Roblox. **Bella** is the star who plays three
satisfying minigames; **you (the Director)** secretly run the show from a control panel —
pacing it, summoning her dogs, sending live messages and surprises, and closing on a cozy
finale where a brooding **Robert-as-Batman** makes his grand entrance.

This document is the single source of truth for **two coding agents working in parallel on the
same machine**. Read the whole thing before writing code. The most important sections are
[§7 Two-Agent Protocol](#7-two-agent-protocol) and [§8 Ownership Map](#8-ownership-map) — they
exist so the two agents never edit the same file.

---

## 1. Design decisions (locked)

| Decision | Choice |
|---|---|
| Format | Asymmetric 2-player: **Star** (Bella) + **Director** (you) |
| Scope | Short & polished — a party hub + **3 minigames** + finale |
| Vibe | Playfully challenging, never rage-inducing |
| Minigames | Ratthew's Cheese Tower · Gigi & Rambo Dash · ASMR Satisfy Station |
| Director powers | Run the show (launch/switch/pace/difficulty) · Summon Gigi & Rambo · Live messages + surprises (confetti/cake/balloons/ASMR bursts) |
| Robert Pattinson | **Brooding Batman**, revealed as the **grand finale** |
| Ending | **Cozy quiet moment** — soft scene + your message, Bat-Rob steps out of the shadows |
| Delivery | **Private publish, two devices** (Bella's phone/PC + your laptop join the same private server; developed & tested locally first) |
| Controls | Bella's side works on **both touch and keyboard/mouse** |

---

## 2. Inputs still needed from you (personalization)

The build can start immediately with placeholders. These get dropped into
`src/shared/Config.luau` and swapped in during the polish milestone (M3). Nothing below blocks
agents from starting.

- [ ] **Timing** — Bella's birthday date / when it must be ready.
- [ ] **Roblox userIds** — yours (Director) and Bella's (Star), for automatic role assignment.
- [ ] **Bella** — nickname, favorite color(s), a favorite song/artist (palette + music vibe).
- [ ] **Gigi & Rambo** — coat colors, size, personalities; **photos** if you want them used
      (local build lets us use real photos as decals).
- [ ] **Inside jokes / catchphrases** — for hidden touches and the Bat-Rob gag.
- [ ] **Finale message** — the words for the cozy ending (or say "draft it").
- [ ] **Guardrails** — anything she'd dislike (jump scares, sudden loud noises, spiders, hard
      platforming). Defaults assume *no* jump scares and *no* precision platforming.
- [ ] **Ratthew's extra role** — mascot cheering between games, or just the Cheese Tower star?

Until provided, `Config.luau` ships with safe defaults (name "Bella", dogs "Gigi"/"Rambo",
a placeholder message, all guardrails ON).

---

## 3. Experience flow

```
Join  →  Role assigned (Director panel  |  Star intro)
      →  HUB (cozy party lobby; Director welcomes, can summon dogs / send messages any time)
      →  Minigame 1: Ratthew's Cheese Tower      (Director launches, sets difficulty)
      →  Minigame 2: Gigi & Rambo Dash
      →  Minigame 3: ASMR Satisfy Station
         (order is Director's call; surprises can fire between any of them)
      →  FINALE (Director triggers): lights dim, cozy night scene, your message appears
         line by line, Gigi & Rambo curl up, brooding Bat-Rob steps out of the rain →
         "Happy Birthday, Bella."
```

The **Director never plays** — their whole screen is the control panel + a live view of how
Bella's doing. The **Star never sees** the controls — only the polished experience.

---

## 4. The three minigames

Each is deliberately small, **client-simulated for juice, server-tracked for the show**
(server relays Bella's live progress to the Director; this is a trusted 2-player game so there is
no anti-cheat burden). Each implements the shared [Minigame interface](#62-minigame-lifecycle-interface).

### 4.1 Ratthew's Cheese Tower  *(the "satisfying tower" heart)*
- **Play:** A cheese wheel swings on a pendulum; tap/click to drop it onto the growing stack.
  Land it aligned → clean stack + camera rises; misalign → it wobbles and overhangs get trimmed.
  Stack as high as you can before it topples.
- **Challenge dial (Director):** pendulum speed, wheel size.
- **Juice:** squish on land, ASMR *plop/squelch*, wobble jiggle, rising camera, Ratthew cheering.
- **Controls:** tap (mobile) / click or Space (desktop).

### 4.2 Gigi & Rambo Dash  *(the most personal)*
- **Play:** The two dachshunds auto-run; Bella steers/lane-swaps to **catch falling treats** and
  dodge puddles. Stretchy "wiener" bodies stretch as they lunge.
- **Challenge dial:** treat/obstacle density, speed ramp.
- **Juice:** wiener-stretch, happy barks, treat *pop*, tail wags, combo counter.
- **Controls:** swipe / tilt (mobile) / arrows or A-D (desktop).

### 4.3 ASMR Satisfy Station  *(pure sensory)*
- **Play:** A tray of colorful jellies/soap/kinetic-sand. Slice, squish, and pop for combos;
  the occasional "perfect slice" timing bonus keeps it lightly challenging without pressure.
- **Challenge dial:** combo window tightness (kept gentle).
- **Juice:** max ASMR — crinkles, squelches, pops, jiggle physics, oddly-satisfying particle bursts.
- **Controls:** tap/drag (mobile) / click-drag (desktop).

---

## 5. Director panel

A screen-space UI only the Director sees. Powers (all confirmed):

- **Run the show** — Start Hub · Launch Minigame ▸ (Cheese/Dash/Station) · End Minigame ·
  **Difficulty slider** (easier ⇄ harder, live) · **Start Finale**.
- **Summon Gigi & Rambo** — pick a trick (trot in / spin / cuddle) → dogs appear on Bella's screen.
- **Messages + Surprises** — type a custom message → shows on Bella's screen; one-tap surprises:
  Confetti · Cake · Balloons · ASMR burst.
- **Live status** — current phase, Bella's current score/progress, connection state.

Every button is a `Director_Command` to the server; the server is authoritative and broadcasts
the resulting `Show_Event` so both screens stay in sync.

---

## 6. Architecture & the frozen contract

Standard toolchain already in the repo: **Rojo · strict Luau · Wally (Promise/Signal/Trove) ·
selene · stylua · Lune tests · `scripts/validate.ps1`**. (ProfileStore is unused — no persistence
needed for a one-time show; leave the dependency, don't wire it.)

### 6.1 Folder layout & the contract layer

Files marked **[CONTRACT]** are created in **Milestone 0** and then **frozen** — changing them
afterward requires both agents to agree (see §7). Everything else has a single owner.

```
src/
  shared/                         [CONTRACT]  ← the interface both sides compile against
    Net.luau                      all RemoteEvent names + payload types (single source)
    Types.luau                    ShowPhase, MinigameId, DirectorCommand, FeedbackKind, ...
    ShowConstants.luau            minigame ids, phase order, difficulty bounds
    Config.luau                   personalization (placeholders now, real values in M3)
  server/
    Main.server.luau              [CONTRACT] bootstrap: role service + show director + folder-load minigames
    RoleService.luau              [B]
    ShowDirectorService.luau      [B]  the show brain (owns minigame lifecycle via the interface)
    SurpriseService.luau          [B]  dogs, messages, confetti, cake, balloons, asmr bursts
    FinaleService.luau            [B]  cozy finale + Bat-Rob sequence
    world/HubBuilder.luau         [B]  builds hub + minigame stages + finale set
    minigames/
      CheeseTowerServer.luau      [A]
      DogDashServer.luau          [A]
      SatisfyStationServer.luau   [A]
  client/
    Main.client.luau              [CONTRACT] bootstrap: read role → start Star or Director controller
    star/
      StarController.luau         [A]  routes Show_Events to the right minigame client
      InputRouter.luau            [A]  touch + keyboard/mouse abstraction
      StarHud.luau                [A]  Bella's in-game HUD (score, messages, surprise overlays)
    minigames/
      CheeseTowerClient.luau      [A]
      DogDashClient.luau          [A]
      SatisfyStationClient.luau   [A]
    juice/
      Feedback.luau               [A]  (STUB in M0)  particles, confetti, squish, camera kicks
      SoundKit.luau               [A]  (STUB in M0)  named ASMR/sfx playback
      Squish.luau                 [A]
    director/
      DirectorController.luau     [B]
      DirectorPanel.luau          [B]  the control-panel UI
    finale/
      FinalePresenter.luau        [B]  cozy finale as seen on Bella's screen
tests/
  CheeseTower.spec.luau           [A]
  ShowState.spec.luau             [B]
  Config.spec.luau                [either]
```

**Bootstraps stay frozen via folder-loading, not editing.** `Main.server` and
`ShowDirectorService` discover minigames by iterating the `server/minigames` folder and reading
each module's exported `id` — so **adding a minigame never edits a shared file**. Likewise
`StarController` discovers `client/minigames` modules by `id`. Adding content = adding a file in
your own folder.

### 6.2 Minigame lifecycle interface  *(the A↔B seam — frozen in M0)*

Both a server and a client module per minigame, each exporting `id` and implementing:

```lua
-- server/minigames/*Server.luau
export type MinigameServer = {
    id: MinigameId,
    start: (self: MinigameServer, ctx: ShowContext) -> (),
    stop: (self: MinigameServer) -> (),
}
-- ShowContext (given by ShowDirectorService) provides:
--   ctx.players.star : Player
--   ctx.difficulty() : number         -- 0..1, live
--   ctx.broadcast(event, payload)     -- → Show_Event to both clients
--   ctx.complete(result)              -- minigame tells the show it's done

-- client/minigames/*Client.luau
export type MinigameClient = {
    id: MinigameId,
    start: (self: MinigameClient, ctx: ClientContext) -> (),
    stop: (self: MinigameClient) -> (),
}
-- ClientContext provides:
--   ctx.feedback : Feedback  (A's juice lib)   ctx.sound : SoundKit
--   ctx.reportScore(n)      -- → server → Director live view
--   ctx.onEvent(cb)         -- Show_Events for this minigame
```

### 6.3 Networking (defined in `Net.luau`, frozen in M0)

| Channel | Dir | Payload | Purpose |
|---|---|---|---|
| `Role_Assigned` | S→C | `{ role: "Director"\|"Star" }` | told once on join |
| `Director_Command` | C→S | `{ action, payload }` | every panel button |
| `Show_Event` | S→C(both) | `{ event, payload }` | phase/minigame/dogs/message/surprise/finale |
| `Minigame_Score` | C→S | `{ id, score, data }` | Bella's live progress → Director |

Server is authoritative for phase + role; clients simulate juice. `Director_Command` actions:
`StartHub`, `LaunchMinigame{id}`, `EndMinigame`, `SetDifficulty{level}`, `SummonDogs{trick}`,
`SendMessage{text}`, `Surprise{kind}`, `StartFinale`.

### 6.4 Roles

`RoleService` assigns **Director** to `Config.directorUserId` and **Star** to
`Config.starUserId`. Fallback when ids are unset: **first joiner = Director, second = Star**,
plus a dev override so a solo agent can test either side.

### 6.5 The stub-first rule (why the agents don't block each other)

M0 ships **stub** versions of the two cross-lane dependencies so each agent can compile and run
alone from minute one:
- `Feedback.luau` / `SoundKit.luau` (owned by A) ship as **working no-op stubs** in M0 → Agent B
  can call `ctx.feedback.confetti()` in the finale immediately; A fills them in later.
- `ShowContext` / a tiny **manual test harness** (owned by B) ships in M0 → Agent A can launch a
  minigame standalone without the real director.

---

## 7. Two-Agent Protocol

**The golden rule:** *after Milestone 0, no file has two authors.* Each agent edits only files in
its lane (§8). The `[CONTRACT]` files are frozen; touching one requires a stop-and-sync.

### 7.1 Physical isolation on one machine — use two git worktrees

Both agents share a disk, so isolate the working trees:

```bash
# M0 is done and committed on 'main' first (see §9). Then:
git worktree add ../bash-agent-A -b feat/player-experience
git worktree add ../bash-agent-B -b feat/director-show
```

- Agent **A** works in `../bash-agent-A`, Agent **B** in `../bash-agent-B`. File writes can't
  collide; each can run `scripts/validate.ps1` independently (separate `sourcemap.json`/`artifacts`).
- Integrate by merging both branches into `integration` at each checkpoint (§9), where the real
  **2-player local test** happens.

*(Simpler alternative if you'd rather run both in one tree: keep both in the main working
directory and rely on §8 ownership. It works because lanes are disjoint, but you lose independent
validation and risk a race on `sourcemap.json`/`artifacts/`. Worktrees are recommended.)*

### 7.2 Rules

1. **Stay in your lane.** Only edit files your lane owns in §8.
2. **Contract is frozen.** Need a new remote / type / config field / interface change? Stop, agree
   on it, one agent edits the `[CONTRACT]` file, both re-sync, *then* continue.
3. **Depend on stubs, never on the other agent's progress.** Code against the M0 interfaces and
   stubs (§6.5). Never wait on the other lane.
4. **Add content by adding files.** New minigame / surprise = new file in your folder; the
   folder-loaders pick it up. Don't edit bootstraps.
5. **Validate before every integration.** `scripts/validate.ps1` must pass in your worktree.
6. **Integrate at checkpoints only** (§9), not continuously.

### 7.3 Conflict-risk files (coordinate before touching)

`Net.luau`, `Types.luau`, `ShowConstants.luau`, `Config.luau`, `Main.server.luau`,
`Main.client.luau`. If one truly must change mid-milestone, it's a §7.2-rule-2 stop-and-sync.

---

## 8. Ownership map

| Lane | Owns | Theme |
|---|---|---|
| **Agent A — Player Experience** | everything under `client/star`, `client/minigames`, `client/juice`, `server/minigames`, and `CheeseTower.spec` | Bella's side: the 3 minigames end-to-end + the juice/feedback library + touch/desktop input |
| **Agent B — Director & Show** | `RoleService`, `ShowDirectorService`, `SurpriseService`, `FinaleService`, `world/HubBuilder`, `client/director/*`, `client/finale/*`, and `ShowState.spec` | The show: control panel, orchestration/state machine, dogs/messages/surprises, hub world, cozy finale + Bat-Rob |
| **Shared [CONTRACT]** | `Net`, `Types`, `ShowConstants`, `Config`, both `Main` bootstraps | Frozen after M0; change only by stop-and-sync |

A publishes the **juice API + minigame modules**; B consumes the juice API in the finale and
**launches** A's minigames through the interface. Neither reads the other's internals.

---

## 9. Milestones & build order

### M0 — Foundation *(serialize: one agent or you, on `main`, then freeze & commit)*
This is the only non-parallel step and it's the linchpin. Deliver:
- Folder layout above; `default.project.json` already maps `src/{shared,server,client}` (no edit needed).
- `Net`, `Types`, `ShowConstants`, `Config` (placeholders), both `Main` bootstraps with the
  folder-loaders and role-based client boot.
- `ShowContext`/`ClientContext` + a manual test harness (B-side stub) and `Feedback`/`SoundKit`
  no-op stubs (A-side stub).
- **Gate:** two players can join, get roles, land in an empty hub, and the Director panel can fire
  a `StartHub` `Show_Event` that both clients log. `validate.ps1` green. **Commit, then branch (§7.1).**

### M1 — Vertical slice *(parallel)*
- **A:** Cheese Tower fully juicy (client + server) · Star shell (InputRouter, StarHud, camera) ·
  real `Feedback`/`SoundKit`.
- **B:** Director panel that can Launch/End a minigame + set difficulty · `ShowDirectorService`
  state machine · Summon Dogs · Send Message.
- **Checkpoint 1:** merge → `integration`; 2-player test: Director launches Cheese Tower, Bella
  plays it, Director sees her live score, sends a message, summons the dogs.

### M2 — Content complete *(parallel)*
- **A:** Gigi & Rambo Dash + ASMR Satisfy Station (client + server), both tuned "playful".
- **B:** Surprises (confetti/cake/balloons/ASMR burst) · Finale sequence + cozy scene +
  brooding Bat-Rob reveal · Hub world + stage set dressing.
- **Checkpoint 2:** merge → `integration`; full run start→finale with a real show.

### M3 — Personalization & ship *(together)*
- Fill `Config.luau` with your real details (§2); import dog photos; write/finalize finale message.
- Polish pass, guardrail audit (no jump scares etc.), performance check on mobile.
- **Publish to a private/friends-only place**; add your + Bella's userIds; **rehearsal run** on two
  real devices. Ready to gift. 🎂

---

## 10. Testing

- **Pure logic → Lune specs** (`scripts/validate.ps1` runs them): Cheese Tower scoring/overhang
  math [A], show state-machine transitions [B], `Config` shape [either].
- **Integration → Studio 2-player local test** at each checkpoint (one window Director, one Star).
- **Ship → two real devices** on the private server (M3 rehearsal).

## 11. Risks & mitigations

- *Asymmetric networking is the complexity spike* → keep minigames client-simulated + server-relayed;
  server only owns phase & role.
- *Two agents, one disk* → worktrees + frozen contract + stub-first (§6.5, §7).
- *Mobile controls* → InputRouter abstraction from M1; test touch early.
- *Publishing + real-person likeness* → stylized original Bat-Rob (not photos); private/friends-only
  place; real photos only as personal dog decals in the local build.
```
