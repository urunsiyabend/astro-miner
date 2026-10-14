# Match-3 level design: what the industry does, and what it means for Astro Miner

Date: 2026-10-14. Sources are listed at the end. Most are studio talks (King, Playrix, Wooga)
and practitioner analyses (Royal Match teardowns, Gamigion, Room 8). Numbers from third-party
teardowns are indicative, not official.

## 1. What the sources agree on

### 1.1 Levels are planned as a sequence before any level is built
- **Master sheet.** Playrix and Gamigion plan every level in a table before designing it:
  position, target difficulty, goals, which elements it uses, level type, screenshot. The
  element introduction order and the difficulty curve are fixed first; designers then build
  to the sheet. This keeps an element from vanishing for long stretches or appearing too often.
- **Process (King, GDC 2016):** concept → layout → creation → balancing → testing, and the
  testing never ends. Levels start as paper sketches. King's principal designer: a designer's
  feeling that a level is "going to be awesome" is usually wrong; play data decides.

### 1.2 Every level has one idea
- Playrix: each level needs a **central idea**: a special strategy, a random layout, a preset
  match. King calls it the **hook**: what makes this level different from the last one, often
  a twist on a mechanic the player already knows.
- **3–4 elements per level at most** (Playrix, King). More makes the board chaotic.
- Consecutive levels should **differ in board shape**, not only in elements (Gamigion). Cut
  unused areas; use symmetry and patterns, break them only for a gameplay reason.
- Each element must have a **distinct property** (blocks, falls, layered, reacts only to a
  colour…). King's blocker framework lists 16 characteristics; the most common ones are
  *stationary, colourless, layered, removable, cleared by a match beside it* because they read
  clearly and give visible progress.

### 1.3 New elements: a short learning arc, then they become normal
- Royal Match (teardown of levels 1–100): a new mechanic is taught over **2–3 learning boards**,
  then comes a **hard spike**, sometimes a super-hard peak, then a bonus level. 11 new blocks
  between levels 1 and 91; 4 boosters at 8, 14, 17, 19.
- Candy Crush Soda introduces a blocker in one form, then adds its harder form a few levels
  later (1-layer cupcakes at 9, 2-layer at 11).
- New elements come **fast early, slowly later** (Playrix); 1–2 per update once live.
- Teaching sequence (scaffolding): **introduce in isolation → reinforce with a variation → test
  with more challenge**, then withdraw support until the player plays unaided.

### 1.4 Teach by doing, and stop teaching
- Players skim text. Let them do the action and see the result; dim the rest of the screen
  and highlight only the element that matters while teaching.
- The FTUE (first-time experience) gets the most attention; designers may prescribe the exact
  first moves of tutorial levels (Room 8).
- Explain a feature **the first time** it is met, not again. Support is withdrawn once the
  player has shown they can do it. Tutorials should be skippable.
- King's *flow* pillar keeps the player moving toward the goal "sometimes with hints": hints are
  a fallback when stuck, not a voice-over.

### 1.5 Difficulty is a rhythm, not a ramp
- **Sawtooth:** difficulty rises, then dips on purpose so the player recovers, then rises again.
- Royal Match 1–100: normal levels ~1.2 attempts; hard levels at 39, 45, 49, 55, 65, 75, 85, 95
  (~1.6 attempts); super-hard at 59, 69, 79, 89, 99 (up to ~2.5); a bonus level every 10th.
  Move budgets tighten from 30–38 (levels 1–20) to 23–27 (61–100).
- Playrix: avoid runs of consecutive very hard levels. King: "crazy hard levels never pay off",
  and **the longer a level is, the less likely it is to be fun**, so hard levels should be short.
- Difficulty and fun are separate: hard can be fun, easy can be dull. The least fun levels at
  King were hard, skill-heavy puzzle levels.
- **Every level must be winnable without boosters** (Playrix).

### 1.6 Tuning signals (Gamigion)
- Play the final version ~10 times; note goals left on losses and moves left on wins.
- Many moves left on a win → too easy. Losses with most goals left → something is wrong.
- Two reshuffles in one attempt → redesign the level.
- Goals should not complete very early, nor only on the last move.

## 2. Where Astro Miner goes wrong today (v0.6.0)

| Problem | Where | Rule it breaks |
|---|---|---|
| Mira keeps talking forever: action lines replay on every attempt, the hint arrow auto-appears on lesson digs, colony advice never stops | `DigScreen`, `Story.advice` | 1.4: explain once, then withdraw support |
| Lessons are tiny one-solution boards or cram 4 mechanics into one dig (`power`: battery + charge + blast + energy cell) | `first`, `rocks`, `power` | 1.2 (≤3–4 elements, one idea), 1.3 (isolate → vary → test) |
| No learning arc: after a lesson the next dig is an old random site with nothing to do with what was just taught | campaign order | 1.3 (2–3 learning boards, then a test) |
| Open sites have no idea or hook; same 7×8 rectangle shapes, goal is "collect N" | `landing`, `rubble`, `glint`, `shale`, `vein`, `core` | 1.2 (one idea, varied shapes) |
| No planned curve: no breathers, no deliberate hard levels, no energy-budget progression | whole campaign | 1.1 (master sheet), 1.5 (sawtooth) |
| Difficulty measured only by bots, which don't plan | `tools/simulate.gd` | 1.1 (play data decides); bots are a sanity check only |

## 3. Rules for Astro Miner from here

1. **Master sheet first** (`docs/design/level-plan.md`): every level gets a row with its idea,
   elements (≤3, at most 1 new), goal, energy budget, target difficulty and shape. Levels are
   built from the sheet, not invented one by one.
2. **One idea per level**, written in one sentence. If it can't be, the level isn't ready.
3. **Introduce → vary → test.** A new element gets 2–3 learning levels, then a harder level
   that mixes it with something known. Its harder form (2–3 rock layers, deeper veins) comes
   a few levels later, not on day one.
4. **Guidance budget:**
   - First encounter of a mechanic: one short Mira line + highlighted first move. Nothing else.
   - Never repeat a line on a retry or a later level.
   - Hint arrow only when the player taps Hint, or after a long idle (8–10 s) in the first
     ~5 levels. After that, only on request.
   - Colony: Mira speaks only when something new happens (unlock, first affordable upgrade);
     otherwise she stays quiet.
5. **Sawtooth per chapter of 10:** learn, learn, vary, breather, test (hard), breather,
   vary, hard, super-hard (short), reward. Hard levels are short.
6. **Shapes:** consecutive levels differ in shape; use symmetry; cut unused cells with bedrock.
7. **Energy is the move budget:** start generous, tighten slowly per chapter; tune by playing
   each level ~10 times (energy left on wins, goals left on losses).
8. **Every level winnable without optional upgrades.** A building's own level needs that
   building, nothing else.

## Sources

- [Playrix: Creating levels and elements for match-3 games (Game World Observer)](https://gameworldobserver.com/2019/09/27/playrix-levels-elements-match-3)
- [How King defines a 'good' Candy Crush Saga level (Mobilegamer.biz)](https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/)
- [King on finding the fun in Candy Crush (PocketGamer.biz)](http://www.pocketgamer.biz/king-on-finding-the-fun-in-candy-crush/)
- [Video: King's guide to level design for casual games (Game Developer)](https://www.gamedeveloper.com/design/video-king-s-guide-to-level-design-for-casual-games)
- [GDC Vault: Level Design Saga: Creating Levels for Casual Games](https://gdcvault.com/play/1023799/Level-Design-Saga-Creating-Levels)
- [Lucien Chen (King), Blockers: Analyzing Difficulty Drivers in Candy Crush Games, GDC 2020 (slides)](https://media.gdcvault.com/gdcsummer2020/presentations/GDC2020%20Final%20PPT.pdf)
- [GDC 2020: how King learned from RPGs to create blockers (Pocket Tactics)](https://www.pockettactics.com/candy-crush-soda-saga/blockers)
- [Royal Match Level Design Insights (Gamigion)](https://www.gamigion.com/royal-match-level-design-insights/)
- [Match-3 level design principles (Gamigion)](https://www.gamigion.com/match-3-level-design-principles/)
- [Game Analysis of Royal Match (Medium)](https://medium.com/@ekinmelissezer/game-analysis-for-royal-match-and-toon-blast-9c4bff8ef48b)
- [Royal Match – The New King from Turkey? (Deconstructor of Fun)](https://www.deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey)
- [Smart & Casual: The State of Tile Puzzle Games Level Design, Part 1 (Game Developer)](https://www.gamedeveloper.com/design/smart-casual-the-state-of-tile-puzzle-games-level-design-part-1)
- [How to Play and Deconstruct Match 3 Games Like a Pro (Match3Place)](https://www.match3place.com/2022/09/30/how-to-play-and-deconstruct-match-3-games-like-a-pro/)
- [Tropicats behind the scenes: how a match-3 level is made (Wooga)](https://www.wooga.com/blog/tropicats-behind-the-scenes-how-a-match-3-level-is-made-977a77ca9b4b)
- [Why game tutorials fail (GDevelop)](https://gdevelop.io/blog/improve-game-tutorials)
- [Game Mechanics: Game Progress (Stanislav Stankovic)](https://stanislav-stankovic.medium.com/game-mechanics-game-progress-2ee92523b7b4)
- [Key algorithmic tricks for match 3 game development (Logic Simplified)](https://logicsimplified.com/newgames/key-algorithmic-tricks-for-match-3-game-development/)
- [Candy Crush Soda Saga wiki (cupcake introduction levels)](https://candycrushsoda.fandom.com/wiki/File:Ice2.png)
