# Core Loop Evaluation — Astro Miner v0.1.0

Date: 2026-10-14. Evaluator: the developer (automated tooling + self-play by screenshots).
**No human playtest has been run yet.** Everything below is either a measured simulation
result, a verified build/test result, or an explicitly labelled judgement.

## 1. What was measured and how

| Instrument | What it is | Where |
|---|---|---|
| Rule tests | 65 headless checks of matching, swaps, digging, cracking, energy, drill, blasts, goals, determinism, generator, pulse, economy, save/load, a bot smoke test | `tests/run_tests.gd` |
| Balance simulation | 3 scripted bots × 6 sites × 4 colony states × 100 seeds | `tools/simulate.gd`, results in `simulation-results.md` |
| Campaign pacing | Planner bot plays the sites in order and buys upgrades as soon as it can, 40 campaigns | `tools/simulate.gd --campaign`, results in `campaign-pacing.md` |
| In-game field log | Local counters shown at the bottom of the colony screen and saved in `user://save.json` (digs, clears, depletions, recalls, moves, extractions, moves per extraction, cascades, rock, crystals, pulses, hints, upgrades; last 60 digs) | `autoload/Game.gd` |
| Android smoke test | Signed release APK installed on an Android 14 (API 34) x86_64 emulator with ARM translation; launched; touch swipes drove the robot | see §7 |

Bots:
- **random** — picks any legal move. Proxy for a player who does not understand the rules.
- **greedy** — tries all 4 moves on a copy of the board (with a *re-seeded* RNG, so it cannot
  see future ore) and takes the best immediate result; otherwise walks toward the nearest
  reachable match.
- **planner** — greedy plus a penalty for distance to the next match and a value for crack
  progress / proximity to crystals. Not an optimal solver.

## 2. Key numbers (100 seeds per cell, no upgrades unless stated)

| Site | Random clear % | Greedy clear % | Planner clear % | Planner moves per match | Cascade % of matches |
|---|---|---|---|---|---|
| Landing Zone | 18 | 100 | 100 | 1.39 | 24 |
| Rubble Field | 3 | 98 | 99 | 1.76 | 18 |
| Glint Pocket | 2 | 77 | 87 | 2.29 | 15 |
| Shale Shelf | 0 | 38 | 64 | 2.27 | 12 |
| Deep Vein | 0 | 26 | 49 | 2.25 | 17 |
| Core Chamber | 0 | 17 | 9 | 2.29 | 11 |

Core Chamber with upgrades (planner): first upgrades P1/W1/L1 → 25 %, mid P2/W2/L1 → 71 %,
maxed → 100 %.

Campaign pacing (planner, buying upgrades greedily): first upgrade after **1.6 digs**;
all six sites cleared after **7.7 digs / 244 moves** with **5.3 upgrades** owned. At an assumed
2 s per move that is ~8 minutes of board time; with colony visits, reading and failed digs a
human first session is estimated at **12-20 minutes** (assumption, not measured).

"Stuck turns" (no match reachable within 5 steps) stay at 0-3 % on the first three sites and
5-14 % on the rock-heavy sites; the **Pulse** fallback resolves them (≈1.7-5 pulses per dig on
those sites at base level).

## 3. Evaluation against the brief

### A. Immediate comprehension

- Controls: swipe anywhere / tap an adjacent cell / arrow keys. Movement chevrons around the
  robot, energy number on the robot's chest, a goal bar, and a first-site tip. The first site
  auto-shows a hint arrow after 4 s of inactivity.
- Consequences are animated in order: the swap slides both pieces, matched chunks flash and fly
  into the haul counters, rock shakes and loses a pip, new ore pops up from below, reveal rings
  mark uncovered cells, floating text shows ore and energy gained.
- **Cannot be established automatically:** whether a newcomer understands "the robot drags the
  ore it walks into" without reading. This is the single biggest comprehension risk (Six Match
  itself was known for not explaining its rules).

### B. Moment-to-moment decisions

- Skill clearly matters: the random bot clears 0-18 % of sites, the greedy/planner bots
  77-100 % of the early sites. A careless player gets ~5-12 moves per match; a thoughtful one
  1.4-2.3. That gap is the measurable sign that moves are not interchangeable.
- Positioning matters beyond the next match: on sites where goals sit under rock, the planner
  (which values crack progress and crystal proximity) beats greedy by 10-25 percentage points
  (Glint, Shale, Deep Vein). On Core Chamber at base level it does *not* (9 % vs 17 %), which
  suggests the bots' heuristics are weak there, not that positioning is irrelevant.
- **Concern:** 1.4-2.3 moves per match for competent play means a match is available almost
  every other step. That is far easier than Six Match's "match within six" and may make the
  early sites feel like *harvesting* rather than *planning*. The difficulty comes from the
  energy budget and the rock layout, not from finding matches. 4 ore types were simulated as
  an alternative: ~2-3 moves per match, but objectives became much harder and less readable.
  Kept at 3 for v0.1; **this is the first thing to tune after human play.**
- Matching satisfaction (flash, fly-to-counter, sound, haptic tick) can only be judged by a
  human holding the phone.

### C. Progression

- Haul per dig: 30-90 chunks; first building affordable after 1-2 digs; Lv2 upgrades gated by
  crystals, which come from the crystal sites and first clears.
- Upgrades change rules, and the simulation shows they move outcomes: e.g. Shale Shelf planner
  clear rate 64 % → 83 % (mid) → 99 % (max); Core Chamber 9 % → 71 % → 100 %.
- Upgrade effects are made visible in the next dig: the battery bar is physically longer, a
  "Colony tech" line lists active perks, drill icons appear next to the robot when facing rock,
  and the scanner draws buried content onto rock.
- Reason to start another dig: the next locked site, a crystal-gated upgrade, or farming a
  cleared site. After all sites are cleared and buildings maxed there is **no further goal**
  (expected for a prototype; ~20-30 minutes of content).

### D. Repetition

- Six sites with different structures (open, rock band, crystal pockets, shallow veins with
  energy cells, deep veins with charges, rock shell). Ore is reseeded each dig.
- Risk: a single board size, a single robot verb set and no hazards. Sliding Seas players
  already call a far richer game "a little repetitive". This prototype will likely feel
  repetitive within 20-30 minutes; the open question is whether it is fun *before* that.
- Variation in board states: cascades 10-25 % of matches, depletion reshapes the ground every
  dig, and rock opening changes where the action is. Measured, not judged.

### E. Distinctiveness

- Not a conventional match-3: you never swap freely; every step is a route; extraction digs the
  ground, veins run dry, rock hides things, and the colony changes rules (drill, scanner, blast
  size, battery). The mining theme drives the mechanics rather than decorating them.
- The colony is mechanically connected (every level changes a rule) but thin as a toy: no
  placement, no characters. That is deliberate for v0.1.

## 4. Problems found and fixed during evaluation

1. **Initial fill starved one ore type.** The no-line check looked at unfilled neighbours
   (default type 0), so Ferrite almost never appeared at the start — fatal on the Ferrite
   tutorial. Fixed (only already-filled left/up neighbours are checked) and covered by tests.
2. **Cascades dominated** (30-40 % of matches, veins exhausted within a few moves). Surfacing ore
   that would immediately re-match is now re-rolled once: cascades 10-25 %.
3. **Dead boards.** Up to 40 % of turns on rock-heavy sites had no match within 5 steps. Added
   **Pulse** (Six Match's bomb, adapted): only usable when stuck, costs 3 energy, reshuffles ore.
4. **Final site too hard** (≈0-10 % even with first upgrades). Shell softened and objective
   reduced from 4 to 3 crystals.
5. **Site list below the fold** on first launch. Added a large "DIG: next site" button.

## 5. What automated evaluation cannot establish

- Whether it is **fun**. Bots measure difficulty, skill gap and starvation; they do not feel
  satisfaction, curiosity or boredom.
- Whether the robot-drag rule is **intuitive** on first contact.
- Whether 1.4-2.3 moves per match feels **too easy / too mindless**.
- Whether animations feel **responsive** on a real phone (timings: swap 0.10 s, match flash
  0.16 s, surfacing 0.12 s; one input is buffered during animation) — only checked on desktop
  and an emulator.
- Whether depletion reads as "the vein ran dry, go further" or as "the game took my ore".
- Whether upgrades feel **exciting** rather than merely effective.

## 6. Suggested human playtest protocol (for the APK)

1. Fresh install, no explanation. Note how many moves until the first deliberate match.
2. Ask after the first dig: "What does the robot do when it moves?" and "Why did that rock
   change?"
3. Play 15 minutes. Check the field log at the bottom of the colony screen: moves per
   extraction, battery depletions vs clears, pulses, hints.
4. Ask: "Did you ever plan more than one move ahead?" "Which upgrade changed how you played?"
   "When did you want to stop?"
5. Signals to continue investing: players voluntarily replay a site, talk about routes
   ("I'll pull the cyan up, then..."), and notice the drill/scanner. Signals to stop or pivot:
   random swiping still clears sites, or players do not understand dragging after 2 digs.

## 7. Build and device verification

- Desktop (Linux, Godot 4.7.2): game runs; screenshots of colony, all dig sites and mid-move
  animation reviewed.
- Headless: tests 65/65 pass; simulation and campaign runs complete without script errors.
- Android export: signed release APK, package `io.github.urunsiyabend.astrominer`,
  versionCode 1000, versionName 0.1.0, minSdk 24, arm64-v8a + armeabi-v7a.
- Emulator (API 34, x86_64 + ARM translation, host GPU): install OK, launch OK, colony renders,
  "DIG" button starts a dig, swipes move the robot and produce a match.
- Renderer: the Mobile (Vulkan) renderer could not present frames in the headless emulator —
  the same happens with flux-puzzle, which works on the real phone, so that is an emulator
  limitation. The prototype ships with the **GL Compatibility** renderer, the one that was
  verified rendering on Android here. On a software-only GPU (SwiftShader) Godot's canvas shader
  exceeds the uniform limit; real phone GPUs are not affected by that limit, but very old /
  software-rendered devices may show a black screen.

## 8. Verdict (judgement, not measurement)

The loop is **coherent and mechanically differentiated**, the progression **works on paper and
in simulation**, and the build is **stable**. Whether it is fun is unproven. The most likely
weakness is that matches are too easy to find with three ore types, which would turn a
positional puzzle into a harvesting game. Recommendation: one round of human playtests
(3-5 people, 15 minutes each) before any further content; if the "planning" signal is weak,
test 4 ore types or a rule that only lines including the dragged chunk count.
