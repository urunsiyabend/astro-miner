# Astro Miner — GDD v3

> **Partly superseded by `gdd-v4.md` (2026-10-17):** buildings no longer give permanent board
> power (no Power budget bonus, no Workshop/Lab upgrade effects); they make boosters. Level
> length and difficulty targets are in v4 §3.

> Status: **approved 2026-10-15** (user sign-off). This supersedes the direction in
> `prototype-gdd.md` (v0.1). The turn/board rules in v0.1 §3–§4 and §8 still hold and are
> not repeated here; v3 changes the **audience framing, energy model, economy, meta and
> planet structure**. Open questions are listed in §9 — nothing here is final until the user
> signs off.

## 0. What changed from v0.1 (why v3 exists)

The prototype proved the core loop (robot-as-tile, matches that dig/crack/reveal). Play and
research (`docs/research/`, `docs/evaluation/`) then showed four problems v3 fixes:

1. **Energy was a soft score, not a constraint.** Matches refunded energy, so a dig rarely
   ended on running out. v3 makes energy a **move budget** (casual match-3 "moves").
2. **Three ore currencies were meaningless.** Each dig gave roughly equal amounts of all
   three (`tools/econ_probe.gd`), so the player never chose between them. v3 collapses them
   to **one currency (Coin)** and adds a scarce second one (**Star**).
3. **The 3-building × 3-level meta was flat.** v3 replaces it with a **visually growing
   colony** (Sliding Seas model): bringing resources home changes what you see.
4. **The game was too short and too samey** (31 digs, one board shape). v3 introduces
   **planets**, each with its own tileset, ore set and one new mechanic, and a longer arc.

## 1. Audience and session

- **Casual.** Reference feel: *Sliding Seas*, *Royal Match*, *Homescapes*. Played in short
  bursts (a bus ride). Low strategy pressure, high completion satisfaction, stress-relief.
- **Session shape:** open app → colony (see it grow) → one dig (2–3 min) → reward → colony.
- **First 20–30 digs are near-guaranteed wins** (bot planner ≥ ~85%). Roughly 1 in 5 is a
  harder "spike". No unannounced new mechanic, no sudden difficulty jump.

## 2. Energy = move budget (implemented; near-miss pending)

- Each dig carries its **own energy budget** (`energy` key in `Sites.gd`); the battery grows
  to hold it. A step costs 1 energy; drilling costs the drill cost.
- **Matches no longer refund energy.** The only energy sources are **energy cells** (buried
  under rock) and the **Research Lab Lv3 bonus** (+1 per match). Running out ends the dig.
- Budget rule of thumb: `20–35` moves per dig for casual pacing; current budgets live in
  `Sites.gd` and `docs/design/level-plan.md`. Measure with `tools/tune_moves.gd` and
  `tools/levels.gd`.
- **Near-miss (designed, not yet built).** When energy runs out with the goal unfinished:
  show "Out of energy — N left to go" + a **+5 energy** button (free, once per dig for now;
  later an ad or paid continue) that calls `Board.continue_with(5)`, plus **Give up**. Lives
  in `DigScreen._show_result` on `reason == "energy"`. *Deferred by user; keep in roadmap.*

## 3. Economy — two currencies

Replaces "Ferrite / Cryo / Lumen / Crystal" as four separate banks. The three ore **colours
stay** on the board (the puzzle still needs three matchable types); they just no longer bank
separately.

| Currency | Earned from | Spent on | Feel |
|---|---|---|---|
| **Coin** | every ore chunk extracted (all three ore types → Coin), + a flat per-dig clear reward | the bulk of colony growth and common upgrades | frequent, "soft" |
| **Star** | crystals recovered; objective completion / first clears; performance (energy left) | gating the next colony milestone and premium upgrades | scarce, "hard" |

- Research backing (`docs/research/`, CONTINUE §4): Homescapes/Royal Match use a star + coin
  split; a single soft currency plus a scarce star reads clearly and keeps the meta legible.
- **Reward shape:** per-dig reward is **fixed per dig** (not proportional to chunks mined),
  plus Stars for performance — so grinding a cleared dig does not inflate the economy
  (Lostgarden value-chains, Clash of Clans pricing; CONTINUE §4).
- Pricing: each upgrade priced in its main currency; cost ≈ per-dig income × how many digs it
  should take; ×1.6–2 per level; always leave **repeatable sinks** (colony modules, boosts).

## 4. Colony — visual growth (replaces 3×3 building meta)

- The colony **grows visually** as resources arrive (Sliding Seas): new modules, lights,
  structures appear at Star/Coin milestones. The growth *is* the progress the player chases;
  **dig numbers become debug-only** and leave the UI.
- Buildings/upgrades still exist but are **boosts inside the growth frame**, released slowly
  (current powerups are too strong and arrive too fast — pace them out).
- **Unlock/upgrade split (decided, §9.6):**
  - **Star unlocks a building.** Reaching a Star milestone opens the next building — this *is*
    a visible colony-growth beat (Mira announces it, the structure appears). Star is **spent**
    on the unlock (a hard-currency sink). ~6 unlock milestones per planet (§9.2).
  - **Coin upgrades a building** (L2, L3). Each level is a **Coin cost** (the soft-currency
    sink). Keeps a repeatable spend, as research wants.
  - So: Star gates *what you have*, Coin gates *how good it is*.
- **Planet 1 milestone ladder (decided 2026-10-15).** Six cumulative-Star thresholds; the
  three functional buildings sit at milestones 2/4/6, cosmetic colony-growth beats between:

  | # | Star ≥ | ~dig | content |
  |---|---|---|---|
  | 1 | 4 | ~4 | cosmetic module A |
  | 2 | 8 | ~8 | **Power Station** (functional) |
  | 3 | 14 | ~14 | cosmetic module B |
  | 4 | 20 | ~20 | **Mining Workshop** (drill) |
  | 5 | 26 | ~26 | cosmetic module C |
  | 6 | 30 | ~30 | **Research Lab** (scanner) |

  Thresholds tuned against `tools/econ_probe.gd`: star accrues ~1/dig (mostly first-clears),
  so arriving at a building's needs-dig (digs 11/21/31) means 10/20/30 digs were cleared,
  **guaranteeing** the unlock in time whatever the crystal luck. Reaching a threshold reveals
  the milestone (Mira announces, the colony grows). This
  replaces the old "clear dig N → unlock building" gate (`Sites` `unlock` key). Building
  upgrades (L2/L3) remain **Coin** costs in `Economy.gd`.
- **Power Station — new meaning (decided):** since each dig now carries its own budget and the
  battery auto-sizes to it, a raw capacity upgrade only mattered for longhaul/supply runs.
  Power Station now adds **+N energy to every dig's budget**. Proposed levels: **+0 / +3 / +6
  / +10** (tune against `tools/tune_moves.gd`). This is a global, legible difficulty softener
  — exactly what casual wants.
- Mining Workshop (drill) and Research Lab (scanner, veins, +1 energy/match) keep their
  mechanical effects but are **gated slower** than in v0.1.

## 5. Planets

- The game is **a sequence of planets**. Each planet has its **own tileset, its own ore set,
  and one new mechanic** introduced gently.
- **Progress is percentage-based:** you may advance to the next planet after reaching a
  completion **threshold** (not 100%), leaving some digs optional — this both lengthens the
  game and respects short sessions.
- Planet 1 = **Corvo IV** (current lavender board, shipped art). Planet 2 = **Verdis**
  (green top faces, warm sand sides; draft art in `assets/tiles/verdis/`, not yet used by any
  dig). Verdis needs: its own rocks, sky, and **one new mechanic** (TBD — see §9).

## 6. Route planning (board variety)

- Boards must make **routing a real decision**. Today levels are too same-shaped. v3: vary
  bedrock walls, vein depth and rock placement per planet/chapter so the player plans a path,
  not just the next match. The robot-as-tile constraint is the whole point — lean on it.

## 7. Onboarding & narrative (unchanged in spirit)

- **Mira** still explains everything as it appears (tap lines once, action lines every time;
  focus cells pulse). New planets and new mechanics each get a Mira introduction.
- Every dig opens with its **goal card**; goal icons sit above the board; counted chunks fly
  into them.

## 8. Tech / tooling (unchanged)

- Godot 4.7.2, GDScript, 2D, portrait, Android-first. Rules/rendering split; seeded RNG;
  deterministic replay. Headless tests (`tests/run_tests.gd`) and balance tools
  (`tools/levels.gd`, `tools/tune_moves.gd`, `tools/econ_probe.gd`, `tools/simulate.gd`).

## 9. Open questions (need a decision before building)

1. ~~Star earning weights.~~ **DECIDED (2026-10-15):** **+1 Star per crystal**, **+1 Star per
   dig first-clear** (one-time). Star is a **cumulative progress counter, never spent.**
   Coin is the only spent (sink) currency. **Coin (revised 2026-10-16):** only a clear pays:
   a fixed reward by chapter (8/10/12) **+ 1 Coin per move left**; a failed or recalled dig
   pays none. Treasure chests (rare, bad-luck protected) and gold rush digs add Coin.
2. ~~Colony growth granularity.~~ **DECIDED (2026-10-15, revised 2026-10-16):** milestone-
   based, **5 milestones on Planet 1 (4, 8, 14, 20, 30 Star)**, the antenna beat removed;
   functional buildings at 8/20/30, cosmetic beats between.
3. ~~Verdis mechanic.~~ **DECIDED (2026-10-16): spreading vines.** Vines grow into a
   neighbouring empty or ore cell every 3 moves and seal it; a match next to a vine cuts it
   (same adjacency rule as cracking rock). Green-planet theme, light pressure, easy to learn,
   built on the existing rock/crack system.
4. ~~Planet completion threshold %.~~ **DECIDED (2026-10-16):** **~30 digs (+2 gold rush)
   per planet.** A planet is complete when its colony reaches its last star milestone
   (30 Star on Planet 1); that opens the next planet. No separate % meter: the star bar is
   the progress.
5. ~~Powerup pacing.~~ **DECIDED (2026-10-16):** keep **one building per ~10 digs**
   (Star unlocks 8/20/30 → Power ~dig 10, Workshop ~dig 20, Lab ~dig 30); levels 2–3 are
   bought with Coin. Each chapter ends with a new tool.
6. ~~Do the three buildings survive as-is?~~ **DECIDED (2026-10-15):** buildings survive, but
   **Star unlocks each building** (a growth milestone) and **Coin pays for its upgrades**
   (L2/L3). See §4 "Unlock/upgrade split".

## 10. Roadmap (from CONTINUE §3)

1. ~~Dig: energy = moves~~ (done) + near-miss (deferred).
2. **This document → approve.**
3. Colony → visual Sliding-Seas-style growth.
4. Planet structure: Verdis tileset/ore/mechanic + percentage progression.
5. Semi-automatic level generator (bot solver measures difficulty).
