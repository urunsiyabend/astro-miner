# The journey: level design roadmap

2026-10-19. The campaign is rebuilt as a journey for someone who has never played: every
mechanic is met on its own easy level, practised, then mixed with what came before. We build
it a few levels at a time, playtest, and go on. **This file is the plan; `Sites.LIST` is what is
built.** Levels not yet rebuilt keep their old design (marked *old*).

Sources: `docs/research/match3-mechanic-pacing.md` (when the big games add elements, how they
teach), `docs/research/match3-goals-obstacles.md` (goal types, obstacle families),
`docs/design/obstacles.md` (our rule table).

## Rules of the road

1. **One new thing per level, on an easy level.** A new element never debuts on a hard level
   (Royal Match, Homescapes). The level right after pairs it with something known; a harder
   level 3–5 later tests it (Homescapes: Apples 51/52/54).
2. **Show, don't tell.** A new verb is taught by a guided first move: a hand draws it, the
   board around it dims, and only that move is accepted (Royal Match's first levels). Mira
   says one short line, never a paragraph. After the guided move the level is free play.
3. **Front-load, then space out.** ~8–9 new elements in the first 100 levels, one every ~10
   early on (Royal Match: Grass 4, Cupboard 11, Mailbox 21); in chapter 1 a new *verb* every
   1–2 levels, because the verbs are the game.
4. **Every level has a problem, not just a count.** Each level's goal says what to solve
   (deliver, activate, free, connect) once those exist; Collect alone only in the first
   chapter.
5. **Sawtooth.** Tension rises for ~4 levels and drops; no hard level before ~39 (Royal Match's
   first), no super-hard before ~59. Early levels are short (Candy Crush: the longest level
   is the least fun) and nearly unlosable (1.0–1.1 attempts).
6. **Small boards first.** Level 1 is 7 wide, level 2 8 wide, Royal Match size (9) from level 3.
   Few colours first: 3 colours in level 1 (cascades, delight), 4 after.
7. **A chapter is a place.** 10 levels, ending in a reward level and a colony building.

## The verbs and elements, in the order they are met

| # | Thing | Kind | Rule in one line |
|---|---|---|---|
| 1 | Swipe | verb | the robot swaps with the gem it steps onto; 3 in a line match |
| 2 | Draw a path | verb | hold and draw up to 4 steps: the robot swaps all the way, one move |
| 3 | Drill | power-up | 4 in a row; push it and it bores on that way |
| 4 | Rock | obstacle | a match next to it cracks it (1–3 layers) |
| 5 | Falling robot | verb | clear under the robot and it drops down for free |
| 6 | Quake | power-up | an L or T; push it, it hits the ring two cells out |
| 7 | Crystal in rock | goal (Excavate) | break the rock to reveal it, then pick it up |
| 8 | Energy core + dock | goal (Deliver) | bring the core down onto the dock; the robot can push it |
| 9 | Prism | power-up | 5 in a row; four diagonal beams through rock |
| 10 | Cage | obstacle (cover) | locks a gem; match that gem or hit it with a power-up |
| 11 | Generator | goal (Activate) | 2x2; matches next to it charge it |
| 12 | Teleporter | board element | end a move on one, come out of its twin; power-ups teleport too |
| 13 | Launch pad | board element | a power-up resting on it is thrown to the target |
| 14 | Belt | board element | moves a step each turn, more for matches on it |
| 15 | Connect | goal (new) | open a passage between two stations (the path genre's own goal) |
| 16 | Rescue | goal (new) | free a trapped scout bot, then bring it home (Sequence) |

## Chapter plan

### Chapter 1 · Landing (levels 1–10): the verbs

| L | Teaches | Goal | Board | Notes |
|---|---|---|---|---|
| 1 | **Swipe** + match 3 | collect Ferrite | 7x7, 3 colours | guided first swipe; paths locked |
| 2 | **Draw a path** | collect two colours | 8x8, 4 colours | paths unlock; guided path makes two lines at once (combo) |
| 3 | **Drill** | collect + push a Drill | 9x9 | guided path lines up 4; guided push fires it down a row |
| 4 | practice: a path to a Drill | collect | 9 wide | *old: landing* |
| 5 | **Rock** | break rock | | *old: rocks* |
| 6 | **Falling robot** | reach the crystal at the bottom | | *old: vein* |
| 7 | **Quake** | | | |
| 8 | **Crystal in rock** (Excavate) | crystals | | *old: glint* |
| 9 | mix: rock + crystals + Drill | | | normal |
| 10 | reward: big cascades | | | colony: Power Station |

### Chapter 2 · The Shaft (11–20): Deliver
11 **energy core** (one core, one dock, open board) · 12 core + rock · 13 **Prism** ·
14 two-layer rock · 15 **cage** · 16 cores held up by cages (prototype Core run) ·
17 practice · 18 normal+ · 19 mix · 20 reward + building.

### Chapter 3 · The Power Plant (21–30): Activate
21 **generator** (one, open board) · 22 two generators + rock · 23 generators + cages ·
25 **teleporter** · 26 teleporter + core · 27–29 mixes (prototype Power grid) · 30 reward.

### Chapter 4 · The Launch Bay (31–40): moving things
31 **launch pad** · 33 pad + generator · 35 **belt** · 37 belt + core · **39 first hard** ·
40 reward.

### Chapter 5 · The Relay (41–50): Connect
41 **Connect** · 45 hard · 49 super-hard? (Royal Match's first super-hard is 59) · 50 reward.

### Chapter 6 (51–60): Rescue
51 **Rescue** · then mixes. From here one new element per ~10 levels, then ~20.

## How we build a level

1. Write its row here first: what it teaches, the goal, the board.
2. Hand-place the opening and pin the seed for a guided level; check the guided move does what
   Mira says with `tools/lesson_probe.gd` (it plays the guided moves and prints the board).
3. Record its solution in `tests/run_tests.gd` (TUTORIAL_SOLUTIONS); the tests replay it.
4. Budget: guided levels are given generous moves (Royal Match levels 1–10 are not lost);
   the path bot's moves +40%.
5. Play it on a phone. Then the next three.

## Built so far

- 2026-10-19: levels 1–3. Tutorial tools: a guided move with a hand and a spotlight (`"guide"`
  in a script line: only that move is accepted, a drawn path stays on its rail), paths locked
  per level (`"path_max"`), the `path` event for Mira's lines, `"explains"` so a special taught
  by a lesson gets no second note. All three are hand-placed with pinned seeds, chosen by
  scanning seeds so the guided move ends in a cascade and makes no special before its time.

| L | id | Guided move | What it shows | Goal | Moves | SLOPPY path bot (40 games) |
|---|---|---|---|---|---|---|
| 1 | first | swipe up (1 step) | a line, then 5 cascades: 6 Ferrite from one swipe | 20 Ferrite | 20 | 40/40, median 7, max 15 |
| 2 | path | up, right, right | two lines from one path, then cascades | 30 Cryo + 30 Ruby | 20 | 40/40, median 7, max 12 |
| 3 | drill | up, right (4 in a row), then a 4-step path onto the Drill from above | the Drill bores up the column, 5 lines cascade | 30 Lumen | 20 | 40/40, median 7, max 11 |

  The bot plays paths like an expert (it weighs ~160 paths a move); people will take more
  moves, so the budgets sit well above its worst game. Play them, then tune.
