# Astro Miner

A mobile-first puzzle prototype built in **Godot 4.7** (GDScript, 2D, portrait, Android-first).

You steer a small mining robot across a 7×8 dig site on an alien planet. The robot *is* a
tile: every step swaps it with the ore chunk in front of it, so each move drags one chunk
one cell. Line up three of a kind to extract it. Extraction digs the ground one layer deeper,
cracks the rock around it and uncovers what the rock was hiding: more ore, energy cells,
crystals. Bring the haul back to the colony and build upgrades that change how the next dig
plays (bigger battery, a drill, a deep scanner, bigger blasts).

> This is an experimental prototype for validating the core loop. Placeholder vector art,
> procedural sound, no monetisation, no online services.

## How to play

- **Swipe** anywhere on the board (or tap an adjacent cell, or use arrow keys/WASD) to move.
- The robot swaps places with the ore it moves into. Walking onto a crystal, energy cell or
  blast charge picks it up / sets it off.
- **3+ in a line** of the same ore (orange squares, cyan circles, yellow triangles) is
  extracted. You gain the ore and refund some battery.
- Each extraction **digs** the cell: new ore rises from below until the vein is exhausted
  (each dug layer adds a stepped bench to the pit, neighbouring pits merge, and an exhausted
  vein shows a bare cracked floor; warm pips at the bottom of the cell show the layers left).
  Rock stands above the ground as stacked slabs, one per layer.
- Rock next to an extraction **cracks** one layer (white pips on the rock). Broken rock opens
  fresh ground and reveals what it hid.
- **4+ in a line** leaves a **blast charge**; step on it to blow up the 3×3 around you.
- Every step costs 1 energy. Out of energy, or **Recall**, ends the dig. The haul is always kept.
- **Hint** shows the first step toward the nearest match. If nothing is in reach it turns into
  **Pulse**, which reshuffles the ore on the board for 3 energy.

Colony buildings (three levels each) appear **one at a time**. The colony shows only the
buildings you have plus a teaser for the next one ("unlocks after dig #N"). When a dig unlocks
a building, Mira announces it, the screen dims around its Build button with an arrow pointing
at it (level 1 is free), she explains the new tool, and then the spotlight moves to DIG. The
next dig is a full hand-made level that cannot be finished without that building but still
mixes in matching, rock and energy. Upgrades after that cost ore and crystals.

| Building | Effect |
|---|---|
| Power Station | Battery 20 → 26 → 32 → 40 |
| Mining Workshop | Drill (bump rock to remove a layer) → stronger drill → cheaper drill + matches crack 2 layers |
| Research Lab | Deep Scanner (see what rock hides) → broken rock opens 3-layer veins → +1 energy per match |

There is no level list: the colony has one **DIG** button and digs simply follow each other.
**Mira**, the colony chief, explains everything as it comes up. Three hand-crafted lesson digs
(fixed layout and seed) each teach several mechanics through her lines: some wait for a tap,
others stay under the board until you have done what she asked, with the cells she means
pulsing. Every dig opens with its goal as big icons, and the goal icons sit right above the
board while you play; the goal card stays up for a moment before it can be tapped away. When a
dig unlocks a building, the DIG button waits ("Build first") until you build it. After the
last dig the button becomes a **supply run** on a site you already cleared.

## Install on Android (Obtainium)

1. Install [Obtainium](https://github.com/ImranR98/Obtainium).
2. *Add App* → paste `https://github.com/urunsiyabend/astro-miner` → *Add*.
3. Install. New tagged releases appear as updates and install over the old version
   (same package id `io.github.urunsiyabend.astrominer`, same signing key, increasing
   version code), so progress is kept.

Or download the APK directly from the [Releases](https://github.com/urunsiyabend/astro-miner/releases) page.

## Run on desktop

```bash
godot --path .                                      # play (mouse emulates touch)
godot --headless --path . -s res://tests/run_tests.gd          # rule tests
godot --headless --path . -s res://tools/simulate.gd -- 100    # balance simulation
```

## Project layout

```
scripts/core/        pure rules, no rendering (unit-tested)
  Board.gd           grid, robot moves, match/dig/crack/reveal resolution, search
  Sites.gd           handcrafted dig-site templates and objectives
  Economy.gd         building costs and how levels map to board rules
  Bots.gd            scripted players for tests and balance simulation
scripts/ui/          rendering and input
  BoardView.gd       draws a board snapshot and replays the step list from Board
  DigScreen.gd       HUD, hint/pulse/recall, results panel
  ColonyScreen.gd    bank, building upgrades, site list, local field log
  ColonyView.gd      the colony skyline that grows with building levels
  FxLayer.gd         flying ore chunks, debris, floating text
autoload/
  Game.gd            persistent state (JSON save in user://), local play metrics
  Sfx.gd             procedurally synthesised sound effects
tests/run_tests.gd   headless test suite
tools/simulate.gd    headless balance simulation (writes markdown tables)
docs/research/       gameplay research (Sliding Seas, Six Match, references)
docs/design/         prototype GDD
docs/evaluation/     core-loop evaluation + simulation results
```

Rules and rendering are separated: `Board.try_move()` resolves a whole turn immediately and
returns a list of steps (move, match, blast, ...) with snapshots; the view only animates them.
Every random decision uses the board's seeded RNG, so a seed plus a move list replays exactly.

## Release pipeline

`.github/workflows/release.yml`: every push to `main` (a merged PR) reads `config/version`
from `project.godot`. If tag `vX.Y.Z` does not exist yet, it runs the tests and a short
simulation, exports a signed release APK with Godot headless, verifies the signing certificate
against a pinned SHA-256 fingerprint, then creates the tag and a GitHub Release with
`astro-miner-vX.Y.Z-android.apk` attached. If the version is already released, nothing is
built, so **bump `config/version` in the PR that should ship**. Pushing a `vX.Y.Z` tag by hand
still works the same way. Version code is derived from the tag (`major*1000000 + minor*1000 + patch`), so it
always increases with the version. Signing material lives only in repository secrets
(`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`).

## License

MIT, see [LICENSE](LICENSE). All art and audio are generated in code.
