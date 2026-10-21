# How Royal Match designs its levels, and why ours feel bland

Research brief, 2026-10-17. Dream Games has not published a level design talk or interview, so
this brief is built from the evidence available:

- **Per-level goals and moves** for levels 1–100, taken from AppTipper's level pages
  ([example](https://apptipper.com/royal-match-level-45-tips/)). The snapshot date is unknown
  (probably 2021–23). Counts are AppTipper's and may count layers or plates, not tiles.
- **Board layouts:** our own reading of the walkthrough thumbnail embedded on each AppTipper
  page (`i.ytimg.com/vi/<id>/maxresdefault.jpg`). These are mid-play frames, so some obstacles
  were already cleared. Marked *(obs.)*.
- **Element rules and first-appearance levels:** royalmatch.fandom.com element pages, read
  through the MediaWiki API (e.g. `api.php?action=parse&page=Mailbox&prop=wikitext`). The wiki
  has no per-level pages.
- **Hard and super-hard levels:** the Gamigion teardown
  ([Royal Match Level Design Insights](https://www.gamigion.com/royal-match-level-design-insights/)).
- **Design principles:** studio talks and teardowns (King, Playrix, KB Production, Deconstructor
  of Fun).

Anything marked *(inferred)* is our own conclusion. This brief does not repeat
`match3-level-design.md` (process, master sheet, sawtooth) or `match3-mechanic-pacing.md`
(introduction cadence across games). It covers **what is on each board, and why**.

> **Version drift.** The wiki puts Grass at L4 and Cupboard at L11, but AppTipper's videos
> show them at L9 and L13, so the early levels have been re-ordered at least once. From L21 on,
> both sources agree: Mailbox 21, Egg 31, Potion 41, Vase 51, Owl 61, Bush 71, Honey 81, Safe 91.

## 1. Levels 1–60

New = first level with that element in AppTipper's order. Tags: **H** = hard, **SH** = super
hard (Gamigion), **intro** = first level of a new element, **show** = saturation level (see
§2.5), **bonus** = coin level.

| L | Moves | Goals | New | Tag | Layout *(obs.)* |
|---|---|---|---|---|---|
| 1 | 20 | 15 red | – | tutorial | Preset tutorial board (splash in frame) |
| 2 | 25 | 18 blue, 18 yellow | Rocket shown | | Full 8×9 rectangle |
| 3 | 20 | 25 green, 25 red | | | Full 9-wide rectangle |
| 4 | 25 | 5 purple, 20 yellow | | | 5×5 central island plus 4 L-shaped corner pockets that hold the purple goal pieces |
| 5 | 25 | 60 blue, 30 red | TNT shown | | Jagged board seeded with ~12 TNTs: a power-up showcase |
| 6 | 30 | 48 box | Box | intro | Boxes frame the left column and the bottom-right; the centre is open |
| 7 | 23 | 54 box | | | Boxes down the left edge and in the right corners |
| 8 | 27 | 34 box | | | Boxes form an inverted pyramid that narrows the bottom of the board to a point |
| 9 | 30 | 49 grass | Grass | intro | Full board, grass in central patches |
| 10 | 25 | 73 grass | | | Notch at top centre; grass in the lower half and corners |
| 11 | 28 | 72 grass | | | Board split into two columns by a 1-cell gap; grass on the left half |
| 12 | 21 | 17 box, 32 grass | | | A row of boxes mid-board; grass on the right edge |
| 13 | 27 | 40 cupboard | Cupboard | intro | Full board, two 2×2 cupboards stacked mid-right |
| 14 | 30 | 40 cupboard, 40 box | | | A row of 4 cupboards along the bottom, boxes above |
| 15 | 26 | 30 cup, 40 box, 12 grass | | | Cupboards left and bottom-right; grass strip on the left |
| 16 | 23 | 36 box, 36 grass | | | Grass in the corners and along the edges |
| 17 | 23 | 20 cup, 63 box | | | Cupboards stacked on the right, boxes on the left |
| 18 | 24 | 18 box, 40 cup, 16 grass | | | Cupboards stacked down the **centre column** (a spine) |
| 19 | 27 | 40 cup, 20 box, 32 grass | | | A vertical slot splits the lower board; mirrored cupboards either side; grass in the bottom corners |
| 20 | 20 | coins | | bonus | Coin field |
| 21 | 28 | 50 mail | Mailbox | intro | Mailboxes form a **U-frame** (left, right, bottom) around an open middle |
| 22 | 25 | 60 mail | | | Diamond/cross board; mailboxes on the stepped rim |
| 23 | 20 | 25 box, 45 mail | | | L-shaped board; mailboxes down the left and along the bottom, with a row of boxes shielding the bottom mailboxes |
| 24 | 26 | 32 grass, 40 mail | | | Tall left column with mailboxes on its edge; two grass islands on the right |
| 25 | 26 | 36 box, 30 cup, 30 mail | | | Stepped board, pre-placed TNTs, mailbox row at the bottom |
| 26 | 23 | 15 box, 36 grass | | | Two horizontal bands with a gap; grass on the lower band |
| 27 | 21 | 40 cup, 16 box, 16 grass | | | Grass top-right, cupboard bottom-left: goals in **opposite corners** |
| 28 | 27 | 120 cup, 30 box | | | Cupboards stacked down both side columns (twin pillars) |
| 29 | 25 | 27 box, 18 grass, 50 mail | | | Detached 2-row strip on top; boxes in the bottom corners, mailbox row below |
| 30 | 22 | 200 mail | | show | Board almost all mailboxes, pre-placed TNTs in the open part |
| 31 | 28 | 60 egg | Royal Egg | intro | Eggs fill the bottom rows and left column; notches at top and bottom centre |
| 32 | 22 | 36 egg, 18 box | | | Eggs in the bottom band; hourglass sides |
| 33 | 25 | 32 egg, 32 grass | | | Two grass islands on top; scattered eggs in the lower band |
| 34 | 20 | 54 egg, 50 mail | | | Mailboxes frame the sides and bottom, eggs inside |
| 35 | 20 | 30 cup, 48 egg | | | Cupboard column outside the left edge; eggs at the bottom |
| 36 | 25 | 38 box, 50 mail | | | V-shaped staircase bottom lined with mailboxes and boxes |
| 37 | 22 | 40 cup, 32 box, 16 grass | | | Cupboard, boxes and grass packed into one lower-left pocket |
| 38 | 24 | 40 cup, 32 egg, 24 grass | | | A row of 4 cupboards forms a **wall**; a grass field sits on the other side |
| 39 | 22 | 63 egg, 9 box, 30 mail | | **H** | Full board, mailboxes at bottom centre |
| 40 | 20 | coins | | bonus | |
| 41 | 22 | 16 potion | Potion | intro | Octagonal board, two potions on the left |
| 42 | 24 | 28 potion, 27 egg | | | Potions stacked down the left and bottom-left |
| 43 | 20 | 32 potion, 8 box | | | Potions in the corners; lower-left notched |
| 44 | 26 | 40 egg, 40 mail | | | Rectangle, mailbox row along the bottom, TNT seeded |
| 45 | 22 | 20 potion, 20 box, 50 plates | | **H** | Potions down the left column vs cupboards down the right (mirrored pillars, different rules) |
| 46 | 30 | 40 cup, 16 box, 150 egg | | | Vertical egg bands, 4 cupboards across the bottom |
| 47 | 31 | 63 box, 14 grass, 63 mail | | | Mailbox row at the bottom, box column on the right edge |
| 48 | 22 | 36 egg, 15 box | | | **Strata:** alternating rows of boxes and eggs at the bottom |
| 49 | 26 | 8 potion, 28 box, 32 grass, 40 mail | | **H** | Two sections: potion top-left; below, a central mailbox column with grass on both sides |
| 50 | 20 | 4 potion, 72 egg | | show | Full board, one potion pocket bottom-left |
| 51 | 30 | 36 vase | Vase | intro | Vases in the bottom corners |
| 52 | 23 | 25 vase, 18 box | | | Vases fill the left half in a stepped arrow shape |
| 53 | 31 | 40 cup, 30 vase | | | Cupboards in the bottom corners and mid-sides |
| 54 | 24 | 30 vase, 42 box, 30 grass | | | Grass ring around the edge, vase column on the right, notch at top |
| 55 | 22 | 21 egg, 28 vase, 50 mail | | **H** | Split board: mailboxes on the edges of the top band, vases on the bottom row |
| 56 | 24 | 32 box, 16 potion, 40 mail | | | Mailboxes and boxes stair-stepped bottom-right |
| 57 | 27 | 16 egg, 16 box, 40 cup, 16 grass | | | (frame shows the win screen) |
| 58 | 26 | 24 egg, 6 box, 40 vase | | | Vases packed into the right columns |
| 59 | 21 | 16 potion, 36 box, 22 vase, 16 grass | | **SH** | Vase column left, potion pocket bottom-left, grass bottom-right: **4 goals, fewest moves** |
| 60 | 20 | coins | | bonus | |

Beyond L60 (AppTipper): Owl at L61 (85 owls, single goal); L70 has 49 owls and 500 eggs, with
eggs in a **checkerboard** across the whole board *(obs.)*. Bush at 71, Honey at 81 (an L-shaped
honey sheet top-right), Safe at 91 (4 safes in mirrored positions). Hard levels: 65, 75, 85, 95.
Super-hard levels: 69, 79, 89, 99.

## 2. Patterns in the data

### 2.1 Every goal is an object somewhere on the board
- Colour-collect goals ("collect 25 red") appear **only in L1–5**. From L6 to L100, every goal
  is a board object: box, grass, plate, mail, egg, potion, vase, owl, bush, honey or safe. That
  is 0 colour goals in 91 levels. In our game, `level-catalog.md` still has pure "30 gems /
  36 gems / 48 gems" digs.
- An object goal has a **where**, so it gives the board a direction and every match a reason.
  A colour goal can be scored anywhere, so no match is more right than another *(inferred)*.
- Generators close themselves when their quota is met (Mailbox, Magic Hat), so players never
  have to count ([DoF 2021](https://www.deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey)).

### 2.2 A fixed learning arc for each new element (L21–99, every area)
| Slot | What happens | Evidence |
|---|---|---|
| x1 | **The new element alone**, single goal | L21 mail, 31 egg, 41 potion, 51 vase, 61 owl, 71 bush, 81 honey, 91 safe: all single-goal |
| x2 | New element plus **one** known element | 22 mail (bigger), 32 egg+box, 42 potion+egg, 52 vase+box, 62 owl+egg, 72 bush+egg, 82 egg+honey, 92 safe+box |
| x3–x8 | New element in most levels (6–7 of 9), mixed with 1–2 older ones | mail in 6/9 of 21–29, egg 7/9, vase 7/9, potion 5/9 |
| x5, x9 | Hard / super hard: **3–4 goal types and 21–22 moves** | L39, 45, 55, 59 (L49: 4 goals, 26 moves) |
| x0 | Bonus (coins), or a saturation level ("show") | 20/40/60…; 30/50/70/90 |

- Goal types per level rise from ~1.4 (L1–10) to ~2.0 (L21–40) to ~2.5 (L41–70); the maximum
  of 4 first appears at L49.
- **Moves do not tighten in AppTipper's snapshot:** the average is ~25 in every band from L1
  to L100 (range 20–32). Gamigion claims 30–38 moves early, falling to 23–27. Either way,
  difficulty comes mainly from **goal mix, layout and fewer moves per goal**, not from cutting
  moves across the board *(inferred)*.

### 2.3 Layout: goals at the edges, a workshop in the middle
Across 55 readable frames *(obs.)*:
- **Goals hug the perimeter or the bottom.** Examples: mailbox U-frames (21, 34), bottom egg
  rows (31, 32), side pillars of cupboards or potions (28, 42, 45), corner vases (51) and corner
  pockets (4, 37, 50). The centre is usually open: you **build power-ups there and fire them at
  the edges**.
- **Obstacles form lines, not scatter.** Common shapes: frames, rows, columns, a spine (18),
  walls (38), strata (48), staircases (36, 56), a checkerboard (70). Random scatter is rare.
- **The silhouette changes almost every level.** Shapes seen: rectangle, island plus pockets,
  diamond, L, two columns, two bands, hourglass, funnel, octagon, arrow, notched. Most boards
  are mirror-symmetric; asymmetry is deliberate (23 L-shape, 52 arrow, 27 opposite corners).
- **Pockets and detached sections** (4, 11, 24, 26, 29, 33, 38, 49, 55): small regions where
  goals sit out of reach of normal matches. Reaching them is the puzzle, and power-ups are the
  key. The propeller always homes on a goal and even re-targets if its target vanishes
  ([DoF](https://www.deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey)),
  so a pocket is always reachable.
- **Shielded goals:** a cheaper obstacle placed in front of the real goal. L23 puts boxes in
  front of mailboxes and L38 a cupboard wall in front of grass. This gives an order of play:
  break the shield, then farm the goal.

### 2.4 Pre-placed power-ups
- L5 seeds about 12 TNTs (teaches combos). L25, L30 and L44 seed TNTs inside the goal field.
  Pre-placed power-ups mark where to go and give the opening move a payoff *(inferred)*.
- Butler's Gift (from L32): each win in a row adds start-of-level power-ups, building up to a
  rocket, propeller, TNT and light ball. Loss resets it
  ([wiki](https://royalmatch.fandom.com/wiki/Butler%27s_Gift)). Level designers can therefore
  assume many players open a level with 2–4 specials *(inferred)*.

### 2.5 Saturation ("show") levels
- L30: 200 mail. L50: 72 eggs. L70: 500 eggs in a checkerboard. L90: 68 honey.
- The board is flooded with the area's element and goal counts are huge, but every match hits
  something, so the level feels powerful. They sit mid-area, just after the learning arc
  *(inferred)*.

## 3. Principles behind purposeful levels

1. **One idea per level, readable in one glance.** Examples: "break through the wall" (38),
   "two pillars, two rules" (45), "dig down the strata" (48), "reach the corner pockets" (4).
   Playrix: "Each level should have an idea"; at most 3–4 elements
   ([GWO](https://gameworldobserver.com/2019/09/27/playrix-levels-elements-match-3)).
2. **The goal is the obstacle.** Clearing the board is the progress bar. Royal Match has
   almost no "survive the blocker while collecting colour X" levels; DoF notes almost every
   level is a full-board clear.
3. **Spatial goals give direction.** Put goals at the edges, bottom or in pockets, and leave
   open space to build specials. Every element on the board must matter: "all the pieces of
   the field… must somehow be involved in the gameplay"
   ([KB Production](https://wnhub.io/news/other/item-12989)). Cut cells you don't use
   ([Gamigion](https://www.gamigion.com/match-3-level-design-principles/)).
4. **Silhouette and symmetry.** A new shape each level; symmetry by default, broken for a
   reason. A level should read as a "mini-story" at first glance (Gamigion).
5. **Goals visible from move 1.** Task elements are on the board from the start (KB
   Production); no surprises that the player has to discover.
6. **An arc within the level** *(inferred from layouts)*:
   - Opening: the open centre makes specials easy, sometimes with seeded TNT.
   - Middle: break the shield or frame and farm the main goal.
   - End: the last goals sit in the hardest spot (a pocket, a corner, behind a pillar), so the
     final 2–4 moves are tense.
   Gamigion: goals should not finish too early, nor only on the last move.
7. **Near-miss tuning.**
   - Most losses need only 1–2 more moves; this makes the extra-moves purchase feel fair
     ([DoF](https://www.deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey)).
   - The King portrait gets nervous as you get close to losing
     ([Funovus](https://www.funovus.com/blogs/royal-match-dominates-match-3-what-can-all-designers-learn/)).
   - Tune with ~10 test plays, noting goals left on losses and moves left on wins (Gamigion).
8. **Power-ups are the core verb.**
   - Specials come from 4 in a line (rocket), a 2×2 square (propeller), L/T shapes (TNT) and
     5 in a line (light ball) ([wiki](https://royalmatch.fandom.com/wiki/Rocket)).
   - Power-up-only elements force you to make them: Owl 61, Safe 91, Porcelain Piggy 161,
     Stone 301, Chain 951, Metal Tube 751.
   - Boards are 8–9 wide with an open centre, so 2×2 squares and L/T shapes come up often
     *(obs.)*.
   - When no match exists, the game reshuffles instead of forcing a power-up (DoF).
9. **Short levels, shorter hard levels.**
   - King: "The longer the level is, the less likely it is to be fun"; harder levels should be
     shorter, and "crazy hard levels never pay off"
     ([mobilegamer.biz](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/)).
   - Royal Match hard levels: 21–22 moves against a ~25 average.
10. **Hard-level cadence.**
    - Hard at x5 and x9, super hard at x9 from L59; a bonus level follows immediately (x0).
      About 1.2 attempts on normal levels, ~1.6 on hard, up to ~2.5 on super hard (Gamigion).
    - The game labels hard levels "Hard" / "Super Hard" with a fire icon
      ([player forum](https://www.corada.com/voices/topics/4239), weak source), which tells
      players to bring boosters.
    - Every level must be beatable without boosters (Playrix).
11. **Vary a mechanic before adding a new one.** The same element appears as a frame, row,
    column, pillar, wall, strata, pocket, checkerboard or flood. It then gets harder variants
    much later:
    - Box (up to 4 layers) → Color Box (L121, colour-locked)
    - Honey (81) → Dark Honey (6601, 2 hits)
    - Ice (141) → Potion Tube (9401, colour-locked)
    - Porcelain Piggy (161) → Piggy Helmet (2401) → Giant Piggy (5401, shatters into helmets)
    - Grass (lower layer) → Bush (71, spreads 4×4 grass when broken) → Seed Box (1401,
      generates grass)
12. **Movement comes from elements, not gravity changes.**
    - Gravity is always top-down; no gravity-flip element appears in the wiki's list
      *(inferred)*.
    - Variety comes from Moving elements that fall with the pieces (egg, vase, oyster, piggy)
      versus Steady ones fixed in place (box, cupboard, mailbox, owl).
    - Drop-to-bottom collectibles: Bird 101; Frog 701, which climbs one tile each turn you fail
      to bring it down; Polar Bear (Ice Cube 2601).
    - Board movers: Conveyor Belt 3801 (shifts right every move), Purple Borders 6001
      (shifts part of the board).
13. **Layers that reveal.**
    - Honey and Force Field hide items underneath.
    - Curtain (181) covers part of the board until enough matching colours are collected.
    - Blinds (5601) reveal one row per hit.
    - Rock (501) reveals a Gem.
    - Marble (3601) reveals Plaster.
    Revealing turns clearing into discovery *(inferred)*.
14. **New-element cadence** (wiki): every 10 levels up to L100 (one per area start or
    midpoint), then every 20 (to ~200), 50 (to 1000), 100, and ~200. Details are in
    `match3-mechanic-pacing.md`.

## 4. Royal Match element catalogue

The **Verb** column is what the element asks the player to do. **Dec** is how rich the
decisions it creates are (L/M/H, *inferred*): H means it competes with other goals for your
moves, or depends on position, timing or colour.

| Element | L | Clears by | Verb | Dec |
|---|---|---|---|---|
| Box | 1 (6) | Adjacent match / power-up, up to 4 layers, steady | "match beside it"; used as frames, shields, walls | L–M |
| Grass | 4 (9) | Match **on** it (1–2 hits by shade), lower layer | "match on these cells": steers where you match | M |
| Cupboard (plates) | 11 (13) | Adjacent hits break plates; steady, 2×2 | "hammer one big target"; pillars and walls | M |
| Mailbox (envelopes) | 21 | Adjacent hits produce mail; closes at quota | "farm the generator"; one spot gives repeated value | M |
| Royal Egg | 31 | 1 adjacent hit; **moving** (falls) | "sweep the floor": fills the bottom and drifts | L–M |
| Potion Bottle | 41 | **Colour-specific** adjacent matches (4–5 colours) | "match the right colour next to it" | H |
| Vase | 51 | 2 states, moving | sturdier egg; packed fields | L–M |
| Owl | 61 | **Power-up only** | "make specials and aim them" | H |
| Bush | 71 | 5 hits → spreads a 4×4 of grass | "break the source, then mop up" | M–H |
| Honey | 81 | Adjacent match; upper layer hides items | "peel to reveal" | M |
| Safe | 91 | Power-up only, 5 states | "concentrate fire" | H |
| Bird | 101 | Bring it to the bottom row | "dig a path under it" | H |
| Color Box | 121 | Colour-specific, 3 layers | colour-locked box | H |
| Ice | 141 | Adjacent hits crush an ice bar | breakable border | M |
| Porcelain Piggy | 161 | Power-up only, moving | moving power-up target | H |
| Curtain | 181 | Collect N items of a colour to open | "colour quota unlocks area" | H |
| Magic Hat | 231 | 3 hits → diamonds onto the board | generator that dumps goal pieces | M |
| Flowerpot | 261 | Break → 3×3 leaves where it breaks | "where you break it matters" | H |
| Stone | 301 | Power-up only, 3 layers | heavy power-up sink | M–H |
| Dynamite Box | 351 | Every colour twice → **clears the board** | "set up the bomb" | H |
| Shelf | 401 | Adjacent hits break cups | container | M |
| Rock → Gem | 501 | Power-up, then match | two-step, two verbs | H |
| Soil | 551 | 5 matches beside one piece clear all linked soil | "pick the weak point" | H |
| Drill | 601 | Collect N of a colour → clears its lane | charged special | H |
| Light Bulb | 651 | Colour match; **colour changes each move** | "read this turn's colour" | H |
| Frog | 701 | Bring down; climbs back 1/turn | race against regression | H |
| Jar / Cauldron | 801/901 | Generators (cookies; pumpkins need 2 hits) | farm | M |
| Chain | 951 | Power-up only; locks a piece | "free the piece" | M–H |
| Pouch | 1001 | 3 matches → random power-up | reward cache | M |
| Lantern / Mole Box | 1101/1901 | **Consecutive** matches (2 / 4 in a row) or reset | "keep up the streak" | H |
| Launcher | 1601 | Power-up only → UFO goal | aim specials | H |
| Jelly | 1701 | **Spread** by matching from jelly cells | "paint the board": position chains | H |
| Magnet | 3201 | Bring magnets together | positional puzzle | H |
| Wall (multi-board) | 3401 | Clear board 1 to blow the wall → board 2 | staged level | M |
| Conveyor Belt | 3801 | Jars move right each move | moving target, timing | H |
| Fireworks / Laser | 4001/8801 | 2 / 5 hits → fires rockets / rays | obstacle turned into a weapon | H |
| Mushroom | 4601 | Regrows if none destroyed this move | "keep pressure each turn" | H |
| Purple Borders | 6001 | Uncleareable; shift part of the board each move | board in motion | H |

Players think hardest about colour-locked elements (Potion, Light Bulb, Color Box), position
(Bird, Frog, Flowerpot, Jelly, Magnet), power-up-only elements (Owl, Safe, Launcher), and
pressure over time (Lantern, Mushroom, Frog). Plain one-hit blockers (box, egg) are filler:
they shape the board and the order of play but give little choice on their own *(inferred)*.

## 5. What makes match-3 levels bland

| Mistake | Why it's bland | Royal Match does instead |
|---|---|---|
| Colour-count goals ("collect 30 gems") | No place to aim, every match is equal | Object goals from L6 |
| Rectangular board, every level | Levels look the same; no story in the silhouette | A new silhouette each level, cut cells |
| Obstacles scattered at random | Nothing reads at a glance; no order of play | Lines: frames, pillars, walls, strata |
| Goals in the open middle | Solved by accident through cascades | Goals at edges and pockets, middle left open to build specials |
| Every element on every level | Chaos; no idea | ≤3–4 elements; new one alone, then paired |
| New element taught once and dropped | Never mastered or varied | It appears in 6–7 of the next 9 levels, in new layouts |
| Specials hard to make (cramped, 4 colours plus blockers) | No "big move" moments | Open centre, 5 colours, power-up-only targets that ask for specials |
| Hard = fewer moves | Feels unfair, long and grindy | Hard = more goal types and awkward placement; short level |
| Goals finishing early, or only on the last move by luck | No arc, no near-miss | Last goals in the hardest spot; tuned so losses miss by 1–2 moves |
| Blockers that only absorb hits | Busywork | Each element has its own verb (colour, spread, regrow, move, reveal) |
| No reward beat after a spike | Fatigue | Bonus level right after the super-hard level; saturation levels mid-area |

Astro Miner today (from `docs/design/level-catalog.md`):
- Digs 2, 9, 14, 26 have pure "N gems" goals.
- Most boards are rectangles with 4 colours.
- "Break N" goals use scattered rocks.

## 6. Level checklist

Check each level before building or shipping it:

1. **Idea:** can I say it in one sentence ("dig through the strata to the crystals")? If not,
   it isn't ready.
2. **Goals:** every goal is an object at a location. No colour-count goal after the tutorial.
3. **Visible:** every goal is on screen from move 1, or its source (generator) is.
4. **Elements:** ≤3–4 kinds; at most 1 new; the new one is alone (x1) or paired with one known
   element (x2).
5. **Silhouette:** different from the previous level; unused cells cut; symmetric unless the
   asymmetry is the idea.
6. **Placement:**
   - Goals at the edges, bottom or in pockets.
   - An open "workshop" area (≥4×4) where 2×2 / L / T / 5-line shapes form.
   - Obstacles in lines or patterns, not scatter.
7. **Order of play:** is there a shield to break before the goal, or a source to break before
   the spread? The player should see a first, second and last step.
8. **Power-up demand:** does the level reward making specials (a pocket, a power-up-only
   target, a seeded TNT)? Is at least one goal reachable only by specials or by a deliberate
   path?
9. **Verb mix:** does at least one element need colour, position, timing or a special, not just
   "hit it"?
10. **Arc:** an easy opening (open centre or seeded special), a working middle, and the last
    goals in the hardest spot.
11. **Budget:** about 20–30 moves (energy). Hard levels are shorter, with more goal types, not
    just fewer moves.
12. **Near-miss:** across ~10 test plays, losses miss by 1–2 moves or goals. Wins rarely have
    more than ~25% of moves left. ≤1 reshuffle per attempt.
13. **Place in the chapter:** intro / pair / vary / show / hard / super hard / bonus. The level
    after a spike is a reward.
14. **Variation:** if the element was used before, is this a new arrangement (frame → wall →
    strata → pocket → flood)?
15. **Winnable without boosters,** and the bot's clear rate is within its tier.

## Sources

- [AppTipper: Royal Match level tips (goals and moves per level, 1–100)](https://apptipper.com/royal-match-level-45-tips/)
  and the YouTube walkthrough thumbnails embedded on those pages
- [Royal Match Wiki: element pages via MediaWiki API](https://royalmatch.fandom.com/api.php?action=parse&page=Mailbox&format=json&prop=wikitext):
  Box, Grass, Cupboard, Mailbox, Royal Egg, Potion Bottle, Vase, Owl, Bush, Honey, Safe, Bird, Color Box, Ice, Chain, Light Bulb, Frog, Jelly, Wall, Conveyor Belt and others;
  [Butler's Gift](https://royalmatch.fandom.com/wiki/Butler%27s_Gift),
  [Power-up Combinations](https://royalmatch.fandom.com/wiki/Power-up_Combinations)
- [Gamigion: Royal Match Level Design Insights (Anton Slashcev)](https://www.gamigion.com/royal-match-level-design-insights/)
- [Gamigion: Match-3 Level Design Principles (Anton Heorhiiev)](https://www.gamigion.com/match-3-level-design-principles/)
- [Deconstructor of Fun: Royal Match, the New King from Turkey (2021)](https://www.deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey)
- [Deconstructor of Fun: Royal Kingdom (2024): same engine and level design as Royal Match](https://www.deconstructoroffun.com/blog/2024/07/01/royal-kingdom-will-it-outgrow-its-big-brothers-influence)
- [Playrix: levels and elements for match-3 (Game World Observer, 2019)](https://gameworldobserver.com/2019/09/27/playrix-levels-elements-match-3)
- [KB Production: 10 tips for match-3 (WN Hub, 2017)](https://wnhub.io/news/other/item-12989)
- [How King defines a good Candy Crush level (mobilegamer.biz)](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/)
- [Funovus: Royal Match dominates match-3](https://www.funovus.com/blogs/royal-match-dominates-match-3-what-can-all-designers-learn/)
- [45 Match-3 Mechanics (Game Developer, 2018)](https://www.gamedeveloper.com/design/45-match-3-mechanics)
- [Pranay: Royal Match Breakdown Part 3 (2025)](https://pranaysarepaka.substack.com/p/royal-match-breakdown-part-3)
- [Eckmann et al., The Royal Crush: Analysis of Match-3 Mechanics (IEEE CoG 2024, Godot toolkit)](https://downloads.hci.informatik.uni-wuerzburg.de/2024-CoG-RoyalCrush.pdf)
- [Player forum: Hard / Super Hard labels (weak source)](https://www.corada.com/voices/topics/4239)


## Board evolution (2026-10-20, from the user's research and Royal Match screenshots)

Royal Match fills most of a board with obstacles (box blocks, egg fields, cupboard columns,
honey sheets) and gives the gems a small area; breaking obstacles frees cells, the playable area
grows, and with it the chance of combos and power-ups (a positive feedback loop). Purposes:
visible progress (the board changes under the player's hands), relief after constraint,
difficulty that changes within a level (problem solving → control → speed), bigger chains late
in the level, and attention steered by what is open. Design the board's state at moves 5, 10,
15, not only at the start. Sources the user cited: Game Developer, "What Makes Royal Match So
Good: Level Design" (board progression); Ekin Melis Sezer on Medium (narrow, separated areas
make choices harder); Gamigion, Naufal Tanansyah (few colours, more power-ups); levelwinner.com
and pranaysarepaka.substack.com screenshots (boards packed with boxes, eggs, mailboxes, grass).
