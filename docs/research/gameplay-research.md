# Gameplay Research: Sliding Seas, Six Match, and Mining/Puzzle References

Research date: 2026-10-14. Purpose: identify the mechanics worth prototyping for a
space-mining match puzzle with a small colony meta-layer, *before* committing to a design.

## Evidence legend

Every claim below is tagged with how it was established:

- **[V-footage]** Verified by watching frames of actual gameplay footage (in-game tutorial
  text and board states), extracted frame-by-frame from the videos listed in Sources.
- **[V-store]** Verified from the official store listing or the developer's press page
  (developer-authored, therefore accurate about features but promotional in tone).
- **[R]** Reported by an independent third party (review, guide, forum, user review). Plausible,
  not personally verified.
- **[I]** My inference from the above. Treat as a hypothesis.

---

## 1. Sliding Seas (Mugshot Games, 2021)

### 1.1 Context

- Developed by Mugshot Games Pty Ltd, a two-person studio of brothers Steve and Mike Yap
  (Sydney/Newcastle, Australia). Their first puzzle game, after the tower-defense hybrids
  CastleMine (2012) and Digfender (2015). Global launch 27 Aug 2021 on iOS and Android.
  [V-store: press page]
- Awards cited by the developer: Apple Game of the Day, Apple Top 10 Match-3 Games (2021),
  TouchArcade Best Mobile Games of 2021. [V-store]
- Developer pitch: "a new land-merging mechanic that adds a new dimension to Match 3, height!"
  [V-store]. TouchArcade framed it as Threes!/Triple Town-style match-and-merge mixed with a
  light city builder. [R]
- App Store: 4.8/5 from ~3.6K ratings, free with IAP, >1,000 levels, ~50 new levels per month,
  offline play. [V-store; "50 a month" R from user reviews]
- No developer postmortem or design interview was found. The analysis below is therefore
  based on footage, store copy, press coverage and player reviews.

### 1.2 Core puzzle mechanics

**Verified from the in-game tutorial (frame captures of the "How To Play" video):**

1. **Input is a swap.** The very first tutorial line is *"Swap tiles to match 3 in a row."*
   A hand cursor drags one tile into an orthogonal neighbour. [V-footage]
2. **Tiles are heights, not colours.** The tile set is a single ladder:
   deep water (dark blue) → mid water → shallow water (light blue) → sand (land) → grass
   (highest level). The colour *is* the level. [V-footage]
3. **Matches merge upward instead of clearing.** Tutorial: *"Each match joins the tiles
   together to create a higher tile."* *"Keep matching until you create an island!"*
   Frame sequences show a matched group flashing, collapsing into one tile of the next
   level, the other cells of the group vacating, the columns above dropping, and new tiles
   entering from the top edge. [V-footage]
4. **Large matches create special tiles.** *"You can create a Raft by matching 4 or more
   water tiles."* *"You can create a Shelter by matching 4 or more land tiles."* Pop-up
   labels "MATCH 4 LIFE RAFT!", "MATCH 5 SHELTER!", "MAX HEIGHT SHELTER!". [V-footage]
5. **Survivors ride on tiles.** Survivors appear on water tiles with a life-preserver
   speech bubble (*"Look! A Survivor has appeared!"*). They move with the tile beneath them
   (including falling). *"This Survivor is safe!"* when their tile becomes land.
   *"But Survivors also need Shelter!"* — they must end up on a shelter. [V-footage]
6. **Max height auto-shelters.** *"Survivors will create Shelter automatically if they reach
   the highest level."* [V-footage]
7. **Objective counter.** HUD shows "1/3", "3/4" survivors; the level is won when the target
   number reaches shelter ("Get 3 Survivors to Shelter to win this level!"). [V-footage]
8. **The board grows in the tutorial.** Level 1 starts at 3×2, then expands to 4×4 and 5×4;
   level 3 is 5×6. Early levels are tiny on purpose. [V-footage]
9. **Power-up slots** (three locked icons: dynamite-like, whirlwind, magnet) appear under
   the board by level 3; dynamite destroys tiles. [V-footage for slots; R for effect]

**Reported by third parties:**

- When a survivor's needs are not met for a while they "call out", and the player then has
  **12 moves** to land/shelter them or the level fails. [R: AppGamer, Player.One,
  Common Sense Media]
- Most rounds have no global move limit; the pressure is per-survivor. [R: Common Sense]
- Locked crates break slowly as you match next to them and give resources. [R: AppGamer]
- Later modes: pirates, penguins, turtles, whirlpools/tornado that shuffles the board,
  treasure/luggage rescue, volcanoes, coral that must be broken so survivors drop to boats
  (Level 273 answer). [R + V-store for mode names]
- Hints appear after ~5-10 s of inactivity; can be turned off. [R]
- Lives (5/5 visible in HUD [V-footage]), diamonds to extend a failed round, optional ads to
  double rewards. [R]

**Unverified (not claimed):** whether a swap that makes no match is reverted or allowed; the
exact merge position rule; exact refill distribution. The design below does not depend on them.

### 1.3 Why it feels good (game feel)

- **Every match leaves a mark.** Matches do not delete progress; they *build* something
  (land rising out of the sea). The board is a visible record of what you did. [I, strongly
  supported by footage and the "this is, but isn't, a match-3" reviewer comment]
- **Readable ladder.** One ladder of 5 heights is easier to parse than 6 unrelated colours,
  and "lighter = closer to shore" is diegetic. Downside: a reviewer notes shades of blue
  are hard to tell apart. [R: Player.One]
- **Goals live on the board.** Survivors are objects with a position you must route by
  reshaping terrain under them. This gives a spatial "where" to every move, not just a
  "what colour". [I]
- **Short, legible animation.** Matches flash, collapse into one tile, columns drop. Reviewers
  praise that "the animations are not so in your face". [R]
- **Soft pressure.** Most levels have no global move cap; reviewers repeatedly call it
  "relaxing" and "not stressful". Pressure only appears when a survivor calls out. [R]
- **Celebration beats.** Level-complete screen with rescued survivors, then the boat
  delivers them to the island, which grows ("Your island will continue to grow as more
  Survivors arrive!"). [V-footage]

### 1.4 Progression and retention

- **Survivors → island.** Rescued survivors populate the home island; the island visibly
  grows (trees, houses, paths) between levels. [V-footage]
- **VIPs → buildings → missions.** Some survivors are VIPs who staff buildings (pizzeria,
  grocer), which add missions. Finding VIPs is "an element of chance that keeps me coming
  back". [R]
- **Mostly cosmetic meta.** Island decoration and buildings are primarily cosmetic/collection;
  gameplay benefit comes from currency, power-ups and lives rather than the island itself.
  [I from reviews; one reviewer "hasn't spent much time" on the island and still loves it]
- **Variety is the retention engine.** Users praise "the variety of level mechanics"
  (rescue, pirates, luggage, turtles, whirlpools) far more than the island. [R]
- **Failure is soft.** You still earn currency when you lose a level. [R]
- **Live content cadence**: daily missions, weekend events, monthly collectibles,
  50 levels/month. [R + V-store]

### 1.5 Player reception

Sample: the 100 most recent US App Store reviews (RSS feed, fetched 2026-10-14):
83× 5★, 8× 4★, 5× 3★, 2× 2★, 2× 1★.

Praised:
- "a creative take on traditional matching puzzle games"; "I hate anything resembling a
  'match 3' type game. This is, but isn't."
- "one of the few games that actually need some strategy and thinking but not in a stressful
  way"; "no timers to rush against".
- Respectful monetisation: ads are opt-in for doubled rewards; playable without paying.
- Variety of level types; cute survivors; short-session friendly; offline.

Criticised:
- **Repetition**: "can get a little repetitive" (multiple reviews).
- **Perceived manipulated randomness** near the end of a level: "the 'randomness' of the
  pieces that fall are not random anymore ... especially when you're THIS CLOSE to winning".
  [R] — whether true or not, *opaque refill randomness erodes trust*.
- **Lives and waiting**: lives timer limits play; players run out of levels and wait.
- Stability (crashes/ads glitches) and sound settings not respected.
- Power-ups expensive (3 dynamite = 900 diamonds) [R: Player.One]; difficulty spikes /
  late levels "almost impossible" [R].
- Colour-shade discrimination accessibility issue. [R]

### 1.6 Lessons for a small independent developer

1. A match should **change the place**, not only increment a counter.
2. Put objectives **on the board** as positioned objects.
3. A **single readable ladder** of states beats many arbitrary colours; add shape cues for
   accessibility.
4. Keep pressure **local and visible** (per-object timers) rather than a global stress timer.
5. **Never punish failure with total loss** — keep the haul.
6. **Make refill trustworthy**: deterministic, seeded, and never "rigged" near the end.
7. Variety of objective types matters more than meta decoration for retention.
8. Their meta is mostly cosmetic — an opportunity: make the meta **mechanically** matter.

---

## 2. Six Match (Aaron Steed, 2018; premium update 2023)

### 2.1 Verified/reported mechanics

- **You are a tile.** "Enter the Match-3 board as Mr Swap-With-Coins ... It's like a sliding
  tile puzzle crossed with a Match-3 game." [V-store] Swiping moves the character one cell;
  "each step swaps him with any coin he lands on". [R: AppUnwrapper] The character works like
  the hole in a 15-puzzle: one move displaces exactly one coin by one cell. [I]
- **The six-move rule.** The character shows a 6. Each move counts down; a move that produces
  a match resets it to 6; reaching 0 ends the game. [R: AppUnwrapper, AppSpy]
- **Help button = hint + insurance.** Six uses per game; tells you whether a match is still
  reachable, and if none is possible it drops a bomb next to you that clears a row/column.
  When used up it becomes "Cash In" (bank tile bonus) — a push-your-luck decision. [R]
- **Specials:** wild-card coins from 4-matches or junction (L/T) matches, which create bombs;
  match cards for bonus score. [V-store]
- **Obstacles:** bolted tiles stuck until matched — pushing against them shifts the whole row
  or column (coin-cages "push whole lines of coins"); unmatchable diamonds collected only at
  the bottom of the board, which can clog the board; skulls that explode and cost moves;
  dice coins (2023). [V-store + R]
- **Swipe anywhere** controls, constant auto-save, endless score attack, plus a puzzle mode
  with bite-sized handcrafted challenges and undo/redo (2023). [V-store + R]
- **Fairness:** "I had a full six moves available and it told me there was no match possible"
  only a couple of times; "the game seems to make sure tiles fall in a way that it's almost
  always on you if you fail". [R]
- **Discovery:** nothing is explained; mechanics are learned by experimentation. [R: AppSpy]
- Reception: tiny but enthusiastic (46 App Store ratings, 4.8). TouchArcade forum:
  "Whoever came up with the mechanics of this game is a genius"; "one-more-try addiction".
  Complaint: no way to disable the auto-help prompt. [R]

### 2.2 Why it works

- **Constrained agency creates planning.** Because only one coin moves per step and only
  from where you were standing, a match is a *route*, not a glance. You plan 2-5 steps ahead
  like a sliding puzzle. [I]
- **The 6-counter is a combo meter.** It rewards maintaining a chain of matches and makes
  wandering expensive, while a reset makes success feel like breathing again. [I]
- **Position is state.** Where you end a match matters for the next one — this is what
  generic swap-anywhere match-3 lacks entirely. [I]

### 2.3 Where it fails / touchscreen issues

- Hard counter reset is binary: 6 moves is either plenty or hopeless; it cannot be upgraded
  smoothly (bad for a meta-progression layer). [I]
- Swiping anywhere moves the character, so accidental swipes are costly; no undo in the
  endless mode. [I]
- Opaque rules (no tutorial) are charming for enthusiasts but hostile to casual players. [I/R]
- Endless score attack has no spatial progression; the board never "goes" anywhere. [I]

### 2.4 Useful for a mining game

- Robot-as-tile movement (displaces one tile per step) — **adopt**.
- Match refunds movement budget — **adopt, as a battery** (upgradeable, partial refund).
- Unmatchable valuables that must be routed/collected — **adapt** (buried crystals the robot
  picks up).
- Line-pushing bolts — **reject for v0.1** (complex; revisit later).
- Help/insurance with push-your-luck cash-in — **adapt** as a free hint plus "Recall to base"
  (bank your haul any time).

---

## 3. Comparison

| Aspect | Sliding Seas | Six Match |
|---|---|---|
| Input | Swap any two adjacent tiles | Move a character; it swaps with one coin |
| What a match does | Merges tiles into a higher "height" tile | Clears coins; gravity refills |
| Persistent board change | Yes (land rises, shelters) | No (score only) |
| Goal objects on board | Survivors to route to shelter | Diamonds to bring down |
| Pressure | Per-survivor 12-move timer; mostly relaxed | Global 6-move combo counter |
| Structure | 1,000+ handcrafted levels + meta island | Endless score attack + puzzle mode |
| Meta | Island growth, VIPs (mostly cosmetic) | None |
| Strength | Meaningful transformation, warmth, variety | Deep positional planning from one rule |
| Weakness | Repetition, opaque refill, lives/IAP friction | Binary pressure, opacity, no progression |

**Conflict:** Six Match's movement constraint makes each match expensive (several moves);
Sliding Seas' merge ladder needs *many* matches per goal (5 heights). Combining both on the
same board would make goals very slow and the board hard to read. [I]

---

## 4. Additional references (brief)

- **Mr. Driller (Namco, 1999):** drill down a falling-block shaft; same-colour blocks join
  and fall in chains; constant oxygen drain refilled by air capsules; X-blocks cost oxygen to
  drill. Lesson: an **air/energy meter plus pickups** turns digging into routing; **hard
  blocks that cost resource to drill** create a clean dig-vs-detour decision. [R: Wikipedia,
  Giant Bomb]
- **Swap Sword (Alec Thomson, 2016):** character on a match-3 board, each turn either move
  (attack) or match; roguelike dungeon. Confirms that a *character on the board* is readable
  on touch and supports one-handed play. [R: AppUnwrapper, TouchArcade]
- **Puzzle Craft (2012) / Puzzle Craft 2 (2015):** line-drawing match boards gather resources
  to build a village; field boards have fixed moves, **mine boards' moves depend on food and
  supplies bought in town** — the economy directly sets puzzle budget. Reviewers praised the
  economy more than the puzzle, and criticised a lack of mechanical innovation. Lesson: tie
  meta to puzzle budget, but the puzzle itself must be strong. [R: Engadget,
  AllAboutWindowsPhone, AppSpy]
- **Triple Town / Threes!:** merge ladders where combining creates a higher tier in place;
  Sliding Seas' acknowledged lineage. [R: TouchArcade]
- **Motherload / SteamWorld Dig (genre knowledge):** dig, return to base, upgrade fuel/drill,
  dig deeper. The surface-return loop is the canonical mining meta. [I, general knowledge;
  not re-verified for this report]

---

## 5. Opportunities for differentiation

1. **Excavation as transformation.** Instead of raising land (Sliding Seas), matches
   *lower* the ground: each extraction digs the cell one layer deeper until the vein is
   exhausted, and cracks surrounding rock to open new ground. The board becomes a visible map
   of your dig.
2. **Robot positioning as the core skill** (Six Match), but with an *upgradeable* battery
   rather than a binary 6-counter, so the colony can change the puzzle's budget smoothly.
3. **Meta with mechanical teeth.** Each colony building changes a rule the player feels in
   the next run (battery size, drilling, deep scanning, blast size) — unlike Sliding Seas'
   mostly cosmetic island.
4. **Hidden information to explore.** Rock hides what is beneath (ore pocket, energy cell,
   crystal). Uncovering is a reward in itself; a scanner upgrade turns guesses into plans.
5. **Trustworthy determinism.** Seeded refill, no rigged drops, and a visible "Recall" that
   always banks your haul.

## 6. Design risks

- **Too easy with 3 minerals.** With swap-anything boards, 3 colours make matches trivial;
  with a robot that displaces only one tile per step this is less clear — must be measured
  by simulation, not guessed.
- **Too slow.** Robot movement makes each match cost several moves; if matches are rare the
  game becomes a sliding-puzzle slog.
- **Board starvation.** If cells deplete, late runs may have nothing left to match.
- **Readability.** Two layers (tokens on terrain) plus rock plus robot can get noisy on a
  phone; needs strong value contrast and shape coding.
- **Meta grind.** Upgrades must arrive within the first 10-15 minutes or the loop is not
  testable.

## 7. Recommended mechanics to prototype

1. Robot-as-tile movement on a ~7×7 board (swipe or tap adjacent).
2. Three mineral types (shape + colour), straight-line 3+ matches, L/T unions.
3. Extraction digs the cell one layer; a new ore surfaces from below while the vein lasts.
4. Rock cover (1-3 layers) cracked by adjacent matches; reveals buried content.
5. Battery: 1 energy per step, partial refund per match; energy cells as pickups.
6. 4+ match leaves a blast charge (the "raft/shelter" equivalent of a big match).
7. Buried crystals: expose, then walk the robot onto them.
8. Three colony buildings, each altering a puzzle rule.
9. Automated bots (random / greedy / lookahead) to measure difficulty, skill gap and
   starvation before any human playtest.

---

## Sources

Sliding Seas
- Mugshot Games press page: https://www.mugshotgames.com/about/press/
- App Store listing: https://apps.apple.com/us/app/sliding-seas/id1436245163
- App Store reviews RSS (100 most recent): https://itunes.apple.com/us/rss/customerreviews/id=1436245163/sortby=mostrecent/json
- Google Play listing (could not be parsed at research time): https://play.google.com/store/apps/details?id=com.mugshotgames.slidingseas
- Common Sense Media review: https://www.commonsensemedia.org/app-reviews/sliding-seas
- Player.One review: https://www.player.one/sliding-seas-review-match-three-142252
- TouchArcade launch article: https://toucharcade.com/2021/08/24/sliding-seas-iphone-ipad-android-release-date/
- TouchArcade forum thread: https://toucharcade.com/community/threads/416218
- Pocket Gamer launch article: https://www.pocketgamer.com/sliding-seas/sliding-seas-is-an-adorable-match-3-puzzle-where-you-save-shipwrecked-survivors-/
- AppGamer tips / Q&A: https://www.appgamer.com/sliding-seas-cheats-tips/ and https://www.appgamer.com/sliding-seas/level-273-how-do-you-get-survivors-on-sides-into-center
- mxdwn Games: https://games.mxdwn.com/news/new-mobile-game-sliding-seas-hits-stores-this-week/
- Gameplay footage, "Sliding Seas - Relaxing Match & Merge Puzzle [How To Play]" (in-game tutorial; frames extracted at 0-24 s, 20-260 s, 170-182 s): https://www.youtube.com/watch?v=7fsQ3IW2NXo
- Official trailer: https://www.youtube.com/watch?v=MozdW1bYq6c

Six Match
- App Store listing: https://apps.apple.com/app/id1327790148
- AppUnwrapper review: https://appunwrapper.com/2018/01/15/six-match-is-my-new-match-3-obsession/
- AppSpy launch article: https://www.appspy.com/news/11536/high-scores-and-secrets-await-in-challenging-tactical-match-3-six-match-for-ios-and-android
- TouchArcade 2023 premium update: https://toucharcade.com/2023/01/05/six-match-puzzler-match3-game-premium-price-iphone-app-store-update-controller-support/
- TouchArcade forum thread: https://toucharcade.com/community/threads/317038

Other references
- Swap Sword review (AppUnwrapper): https://www.appunwrapper.com/2016/11/29/swap-sword-review/
- Puzzle Craft (Engadget): https://www.engadget.com/2012-08-20-daily-ipad-app-puzzle-craft-is-puzzle-farming-bliss.html
- Puzzle Craft (AllAboutWindowsPhone): https://allaboutwindowsphone.com/reviews/item/17220_Puzzle_Craft.php
- Mr. Driller (Wikipedia): https://en.wikipedia.org/wiki/Mr._Driller_(video_game)
- Mr. Driller (Giant Bomb): https://giantbomb.com/mr-driller/3030-8221/
