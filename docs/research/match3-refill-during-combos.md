# Does the board refill while a combo is still going off?

2026-10-21. Why: in Astro Miner a big combo (Black hole + another power-up, a chain) plays all
its effects, and only then do new gems fall. The question was whether other games keep
refilling during long combos.

## What the games do

| Game | What happens | Confidence |
|---|---|---|
| Royal Match | "Concurrent matching": the player can match while other parts of the board are still cascading (Deconstructor of Fun). That needs a real-time board where columns settle on their own. Whether columns refill during a Light Ball + Rocket volley comes from play only [?] | high (real-time), medium (combo) |
| Homescapes, CC Soda | named as having concurrent matching too; refilling during combos inferred [?] | medium |
| Candy Crush Saga | no input until all is settled, but gravity runs *between* effect phases: the wrapped candy "explodes… then flashes and waits until all candies are fully dropped and then explodes a second time" (CCS wiki). Colour Bomb + Striped turns gems striped, then detonates them | high (wrapped) |
| Toon Blast | no evidence [?] | low |

## How it is built

- **Unity Gem Hunter Match** (`Board.cs`): the board updates every frame. Each cell has a
  `ContainingGem`, an `IncomingGem` and a `Locked` flag. Matched gems vanish on a 0.3 s timer
  while other columns already fall. Rockets freeze gravity for the whole board while they fly
  (`LockMovement()`, a counter); gems already in the air keep falling and pass through the
  rocket unharmed.
- **MY.GAMES, Storyngton Hall** ("Divide and Conquer: A Deterministic and Scripted Match-3
  Engine", 2023): a fixed 20 Hz deterministic tick runs matches, spawner and gravity every
  tick, alongside effects. A hit chip counts down `damage_sequence_ticks` before it dies. A
  targeted chip is "marked as inaccessible", then destroyed.
- Shared idea: cells or gems that are about to be hit are reserved, deletion runs on a timer,
  and either the whole board's gravity waits or each column settles on its own.

## Recommendation for us (steps, not a real-time board)

1. **Waves.** A long combo or chain fires its power-ups in waves (1–3 at a time, or ordered by
   distance). After each wave the Board runs gravity and refill, then the next wave fires and
   hits whatever is in the cell by then, freshly fallen gems included. This is the
   wrapped-candy model. It is still an ordered step list, so it stays deterministic and testable.
2. **Overlap later (optional).** Stamp each step with a start time, so a fall can play while
   the next wave flies. The view plays steps by time and decides nothing.
3. Input stays blocked until everything is done. Royal Match's concurrent matching needs a
   true tick simulation, a much bigger change.

Sources: deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey;
candycrush.fandom.com/wiki/Wrapped_Candy, /Striped_Candy;
medium.com/my-games-company/divide-and-conquer-a-deterministic-and-scripted-match-3-engine-7b6e1ee16ec;
unity.com/blog/engine-platform/2d-puzzle-match-3-sample-gem-hunter-match.

## What we did (2026-10-21)

Step 1, waves: `Powers._drain` fires `WAVE` (3) power-ups, then calls `Board._gravity`, re-aims
its queue by where pieces fell, and fires the next wave. Step 2 (overlapping a fall with the
next wave's flight) is not done.
