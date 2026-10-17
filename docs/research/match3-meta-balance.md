# Match-3 meta, economy and difficulty: how the top studios balance it

Research brief, 2026-10-17. Written to answer one question: our buildings give permanent board
power and by dig ~20 the game plays itself. How do Dream Games, Playrix, King, Peak, Spyke
keep a meta meaningful without trivialising the puzzle?

Confidence: **[S]** reputable (trade press, studio talk, paper, analytics firm), **[W]** weak
(fan guide, single consultant, secondary write-up), **[I]** our inference. No studio publishes
target win rates; Royal Match per-level coin figures were not found.

## 1. What the meta does: power or cosmetic?

In every leading casual match-3 the meta is **cosmetic/narrative, paid for by board progress**,
and never makes the board easier. Board help comes only from **consumables**.

- **Royal Match** (Dream Games): one star per win, spent on preset decoration tasks; stars can't
  be bought. Dream A/B/C-tested no meta / episode meta / light decoration meta; data favoured
  the light decoration meta because it "never overshadows the core puzzle". [S]
  https://naavik.co/digest/why-dream-games-success-is-a-challenge-to-replicate/
- **Royal Kingdom** (Dream Games): v1 tied the meta to play (boss levels every 10, an enemy
  attack could destroy your castle, repaired with potions). Underperformed its sibling (UK
  ARPDAU ~$0.14 vs $0.25+). Whether the meta caused it is unproven. [S]
  https://www.deconstructoroffun.com/blog/2024/07/01/royal-kingdom-will-it-outgrow-its-big-brothers-influence
- **Homescapes / Gardenscapes** (Playrix): win = coins + a star; the star goes to renovation and
  story tasks; spending buys consumables that "make it easier" but never skip play. [S]
  https://www.pocketgamer.biz/how-does-homescapes-monetise/ ,
  https://gamerefinery.com/casual-match3-meta-layer-new-winning-formula
- **Fishdom** (Playrix): the edge case. The aquarium boosts **income** (+20 coins per level per
  tank star), not the board; decorations give no board bonus. [S/W]
  https://wnhub.io/news/analytics/item-2098
- **Candy Crush** (King): no decoration meta; saga map; gold bars buy boosters. [S]
- **Toon Blast** (Peak): A/B-tested with and without a saga map (2017) and dropped it; events
  and teams carry it. [S] https://mobilefreetoplay.com/peak-games-toon-blast-death-of-saga/
- **Spyke Games**: Tile Busters copies the Royal Riches town meta (build 5 objects, next town):
  light progression, not power. [S]
  https://www.deconstructoroffun.com/blog/2023/12/1/tile-busters-leaving-the-reddest-ocean-to-find-a-blue-spot
- **Power metas exist** mostly in puzzle-RPGs (Empires & Puzzles, Best Fiends; ~23% of US
  top-grossing match-3 have character/upgrade metas, 31% building/decorating, 46% none). There
  content scales against the player (enemy HP) and power creep needs constant rebalancing. [S/W]
  https://www.gamerefinery.com/match3-meta-layers-matching-types/ ,
  https://oldcynic.com/empires-puzzles-power-creep
- **Timed production precedent:** Empires & Puzzles' Forge crafts consumable battle items
  (bombs, arrows, potions) over time; Puzzles & Survival runs a 4X base with timers. Hardcore
  hybrids, not casual match-3. [I, from memory, not re-checked]

## 2. Coin economy

- Coins buy **consumables only**: extra moves, pre-level boosters, lives. Royal Match +5 moves
  = 900 coins, rising on repeat continues (reported 1,900). Homescapes 1 life = 900 coins. [S/W]
- Leftover moves: Candy Crush turns them into **score** (Sugar Crush), not currency; Playrix
  pays coins for them (Fishdom "level value + saved-moves bonus + star bonus"). [S/W]
- Royal Match is ~5x as generous as Candy Crush, yet players spent only ~16% of what they
  collected in their first 6 days (Candy Crush ~77%). Generosity is safe because coins can
  only buy one-use help: hoarding cannot compound. [S]
  https://blog.liquidandgrit.com/royal-matchs-economy-is-more-generous-and-less-costly-than-candy-crush-saga-s-744f43389104
- Income vs sink [I]: at ~50–100 coins per win and a 900-coin continue, one continue costs
  10–20 wins of income.

## 3. Difficulty design

- About **1 in 5 levels is "hard"** in top match-3 (Soda 1 in 4); King's first hard level is
  around level 10; 64% colour-code difficulty on the map. [S]
  https://wnhub.io/news/game-design/item-14053
- **Royal Match 1–100** [W] https://www.gamigion.com/royal-match-level-design-insights/ :
  normal ~1.2 attempts, hard (39, 45, 49, 55, 65…) ~1.6, super-hard (59, 69, 79, 89, 99)
  up to ~2.5. Moves tighten: 30–38 (1–20), 25–30 (21–60), 23–27 (61–100).
- Homescapes went from 35 to 25 moves and 5 to 4 colours after Royal Match launched. [S]
- Fail-rate targets in use [W/S] (devtodev): some teams 30–40% easy / 80–85% hard, others
  50–60% / 90–95%. https://devtodev.com/education/articles/en/381/game-level-progression
- **King, GDC 2024** [S]
  https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/ :
  - The highest-converting level was also the biggest churn point; easier kept players longer.
  - **Harder levels should be shorter.**
  - They prune the 100 least-fun levels; hard "puzzly" levels were the least engaging.
  - "Very hard levels don't pay off long term."
- **King bot:** a CNN trained to imitate human moves predicts difficulty better than MCTS; a
  15-level episode estimate went from 7 days of playtests to under a minute. [S]
  https://www.gwern.net/doc/reinforcement-learning/imitation-learning/2018-gudmundsson.pdf
- Near-miss: Royal Match levels are built for "lost by 1–2 moves", where the continue
  converts. [W/I]

## 4. Level time and pacing

- Classic match-3 level: **~1–3 min, 20–35 moves** [I from S/W]; sessions up to ~30 min,
  Candy Crush players average ~38 min/day. [S]
  https://www.gameanalytics.com/blog/match-3-games-metrics-guide
- Lives pace play only on failure: 5 lives, ~30 min regen (Candy Crush, Royal Match;
  Homescapes 25 min). [W/S]
- Candy Crush players reach level ~100 in ~5 days. [W] We were doing 30 digs in 15–20 min.

## 5. How they stop the game becoming trivial

1. No permanent power: all help is consumable.
2. Move budgets tighten; blockers/mechanics stack.
3. Sawtooth: hard ~every 5, super-hard ~every 10, breather after each peak.
4. Escalating continue prices.
5. Capping runaway: Royal Kingdom pulled meta currency from the top win-streak tier.
6. Live-ops sinks (events, teams, passes).
7. Continuous retuning with telemetry and bots.
8. Dynamic difficulty for churn-risk players raised retention and spend (RCT, 300k players). [S]
   https://doi.org/10.1016/j.ijresmar.2025.01.006

## 6. Warnings

- Puzzle-RPG power creep forces rebalancing; hybrid-casual power metas (Archero) peak and fade.
- Idle math: cost × r^n against linear benefit keeps upgrades slowing down by themselves. [S]
  https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i
- **Our loop:** permanent board power → more moves left → more Coin → more permanent power.
  Every top casual match-3 breaks at least one link of this loop.
