# Power-ups in modern match-3 (research, 2026-10-19)

Why: our power-ups felt weak, the 5-match one most of all, and they neither combine nor set
each other off. Fan wikis (MediaWiki API), store pages, Naavik. [?] = unconfirmed.

## Our set, measured (open 9x9, mean over every cell and push direction)

| Ours | Shape | Cells | Genre equivalent | Cells |
|---|---|---|---|---|
| Drill | 4 in a row | **4** (best 8) | Rocket / striped: a full line, both ways | **8–9** |
| Quake | L/T | 11 (ring 2 out) | TNT / bomb: 5x5 | **24** |
| Prism | 5 in a row | 10 (4 diagonals) | Light Ball / colour bomb: a whole colour | **~20** (4 colours) |
| Geode | (unused by shape) | 5 recoloured | Coloring Candy (Soda) | – |

Nothing chains, nothing combines.

## The genre's set

| Game | 4 line | 2x2 | L/T | 5 line |
|---|---|---|---|---|
| Royal Match | Rocket (row or column, both ways, across the match) | Propeller (hits 4 neighbours, flies to a goal) | TNT 5x5 | Light Ball (a colour) |
| Royal Kingdom | Rocket | Spinner (random target) | Dynamite 5x5 | Electro Ball |
| Candy Crush | Striped (orientation from the swipe, two-way effect) | Jelly Fish (homing) | Wrapped (3x3, then again after settling) | Colour Bomb |
| Homescapes | Rocket | Paper Plane | Bomb r2 | Rainbow Ball |
| Toon Blast (groups) | 5 → Rocket | | 7 → Bomb | 9 → Disco Ball |
| Bejeweled | Flame 3x3 | | Star (row + column) | Hypercube; 6 line → Supernova |
| Two Dots (drawn) | | closed loop clears a colour; enclosed dots become bombs | | |
| Puzzle & Dragons (drawn) | no pieces: shapes are damage multipliers, combo count multiplies | | | |

## Combos (two power-ups swapped together)

Royal Match (wiki): Rocket+Rocket = row + column; Rocket+TNT = 3 rows + 3 columns;
TNT+TNT = 9x9; Propeller+X = carries X to the best target; Light Ball+X = the most common
colour turns into X and they all go off; Light Ball+Light Ball = whole board + a layer off every
obstacle. Candy Crush and Toon Blast follow the same table. **Universal rule: the 5-match piece
combined with anything turns a whole colour into that thing; with itself it clears the board.**

## Chains

Universal: a power-up caught in another's effect goes off too. A line piece fires along its own
orientation; Lily's Garden turns a parallel rocket hit by a rocket perpendicular, so a chain
never wastes it on the same line. A colour piece hit by a chain picks a colour (most common, or
the hitter's). One-way pieces hit by a chain pick a direction (Candy Crush's Coconut Wheel:
random). Chains are staggered on purpose (Candy Crush stripes at an interval; the wrapped
candy's second blast waits for the board to settle).

## Strength curve

Alone, the 5-match piece is only ~1–2x a rocket (Candy Crush wiki: the colour bomb is "quite
weak on its own considering how hard it is to make"); the jackpot is its **combos** (~5–10x).
Naavik: Royal Match makes its power-ups "demonstrably more potent" than rivals' (bigger bomb
radius) and keeps their animations short and fluid.

## One-way pieces

Rare. Nearly every line piece fires both ways. One-way: half a rocket's coverage for the same
cost, an undefined direction when chained, an arrow to read, useless near the edge. Candy
Crush's striped candy keeps the aiming (orientation from the swipe) but fires both ways.

## Ideas for a mining robot

Homing scout drone (Propeller), loop enclosure (Two Dots), colour conversion / magnet, a
rolling mine cart that leaves drills (Coconut Wheel), two-stage dynamite (wrapped), a charge
meter (Match Masters).

Sources: royalmatch.fandom.com (Rocket, TNT, Propeller, Light_Ball, Power-up_Combinations),
candycrush.fandom.com (Special_candies, Striped_Candy, Wrapped_Candy, Colour_Bomb, Jelly_Fish,
Coconut_Wheel_(special_candy)), candycrushsoda.fandom.com (Coloring_Candy),
homescapes.fandom.com/wiki/Power-ups, toonblast.fandom.com (Rocket, Bomb, Disco_Ball),
bejeweled.fandom.com (Flame_Gem, Star_Gem, Hypercube, Supernova_Gem), pad.fandom.com/wiki/Awoken_Skills,
en.wikipedia.org/wiki/Two_Dots_(video_game), naavik.co/digest/why-dream-games-success-is-a-challenge-to-replicate/,
bluestacks.com guides (Lily's Garden, Match Masters, Royal Kingdom).

## Homing pieces: how they pick a target (2026-10-19)

No studio publishes its algorithm. Evidence:
- **Candy Crush Fish 3.0** (King, PocketGamer.biz): the fish "analyse the entire board, identify
  whichever tile will bring the player the closest to their goal", "a multi-tier targeting
  system", and retarget at once if the tile is destroyed mid-flight. Older fish wikis give the
  tiers per level type: goal element (jelly, bottles, honey over a bear) → other blockers →
  the cell under an ingredient → random candy; random within a tier; one fish per square.
- **Royal Match Propeller**: clears its neighbours on take-off, then a goal/obstacle cell;
  Propeller+Propeller = 3 propellers on distinct targets; retargets if its target disappears
  (Deconstructor of Fun: it "picks another target that is better for the player").
  Propeller+Rocket/TNT carries the piece to the target, where it goes off (wiki: where "the
  most targets are located" [?]).
- **Homescapes Paper Plane** (Playrix help): "tend to target locked elements or level goals
  first"; Plane+Plane = 3 planes on different tiles.
So: not the nearest, the most useful: goal first, then obstacles, then whatever helps,
random among equals, never two on the same single target, retarget on the way.

Sources: pocketgamer.biz/how-player-feedback-memes-and-rebuilt-architecture-led-to-candy-crushs-fish-30/,
candycrush.fandom.com/wiki/Jelly_Fish, candycrushsoda.fandom.com/wiki/Candy_Fish,
royalmatch.fandom.com/wiki/Propeller, dreamgames.helpshift.com/hc/en/3-royal-match/faq/7-power-up-combinations/,
deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey,
playrix.helpshift.com/hc/en/14-homescapes/faq/16313-power-ups-and-how-to-use-them/.
