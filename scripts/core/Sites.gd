class_name Sites
extends RefCounted

## The campaign: digs in play order, one after the other. Players never see a site list or
## site names; they press "Dig" in the colony and get the next one. The order follows the
## master sheet in docs/design/level-plan.md: chapters of 10 whose difficulty climbs step by step
## up to a reward dig, a building unlocked at the end of each chapter and that
## building's own hand-made dig right after it. Digs with an "ore" layout are always the same;
## the others keep their shape and goals but get fresh ore every attempt.
## Mira's script is said the first time a dig is played and never repeated.
## Terrain codes: see Board._parse_cell(). Rows are 7 cells wide, 8 rows tall. Optional keys:
##   "ore":    hand-placed tokens (see Board._place_layout); the opening is always the same
##   "seed":   fixed seed, so what surfaces after each match is always the same
##   "energy": starting energy (below the battery capacity)
##   "guide":  hand-made lesson (fixed layout); its intended solution is replayed by the tests
##   "needs":  colony building level required before this dig can start
##   "unlock": building that becomes available once this dig is cleared; Mira then asks you
##             to build it (level 1 is free) and points you at DIG
##   "building_level": the hand-made dig right after a building: it needs the new tool to
##             finish, but mixes it with matching, rock and energy like any other dig
##   "script": what Mira says. A line without "until" waits for a tap; a line with "until"
##             stays up while you play and moves on when that event happens (see DigScreen).
##             "focus" cells pulse on the board.

const LIST := [
	{
		"id": "first", "mode": "fall", "colours": 4, "guide": true, "seed": 42,
		"goals": [{"type": "ore", "ore": 0, "n": 6}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# . . . . . #",
			"# . . . . . #",
			"# . . @ . . #",
			"# . . . . . #",
			"# # # # # # #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- C L F C L -",
			"- L C F L C -",
			"- C F - F L -",
			"- L C L C F -",
			"- - - - - - -",
			"- - - - - - -",
		],
		"script": [
			{"say": "Hi, I'm Mira, chief of the Corvo IV colony. You drive our mining robot, and the colony runs on the ore you bring home."},
			{"say": "Swipe up: the robot swaps places with the Ferrite above it, and three Ferrite line up.", "until": "match", "focus": [Vector2i(3, 3), Vector2i(3, 4), Vector2i(2, 4), Vector2i(4, 4)]},
			{"say": "Extracted! New gems drop in from above. Line up 6 Ferrite in all."},
		],
	},
	{
		"id": "drag", "mode": "fall", "colours": 4, "tier": "intro", "energy": 18,
		"goals": [{"type": "chunks", "n": 30}],
		"rows": [
			"# # # # # # #",
			"# # . . . # #",
			"# . . . . . #",
			"# . . . . . #",
			"# . . @ . . #",
			"# . . . . . #",
			"# # . . . # #",
			"# # # # # # #",
		],
	},
	{
		"id": "vein", "mode": "fall", "colours": 4, "tier": "intro", "energy": 22,
		"goals": [{"type": "crystal", "n": 1}, {"type": "chunks", "n": 15}],
		"rows": [
			". . . @ . . .",
			". . . . . . .",
			". . . . . . .",
			". . . . . . .",
			". . . . . . .",
			". . . . . . .",
			". . . 1c . . .",
			"# . . . . . #",
		],
		"script": [
			{"say": "Gems fall into the gaps, and so does the robot! Clear the gems right under it and it drops down for free."},
			{"say": "That crystal is at the bottom. Match under the robot to ride down to it."},
		],
	},
	{
		"id": "landing", "mode": "fall", "colours": 4, "tier": "intro", "energy": 30,
		"goals": [{"type": "ore", "ore": 2, "n": 15}],
		"rows": [
			"# . . . . . #",
			". . . . . . .",
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			". . . . . . .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "rocks", "mode": "fall", "colours": 4, "tier": "intro", "energy": 20,
		"goals": [{"type": "rock", "n": 5}],
		"rows": [
			"# # # # # # #",
			"# . . . . . #",
			"# . . . . . #",
			"# 1 1 1 1 1 #",
			"# . . . . . #",
			"# . . @ . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"script": [
			{"say": "Rock! The robot can't drive through it, but a match right next to it cracks it. Make a line just above or below the rocks.", "until": "reveal", "focus": [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]},
			{"say": "Broken rock opens up, and gems fall into the gap. Break 5."},
		],
	},
	{
		"id": "ring", "mode": "fall", "colours": 4, "tier": "normal", "energy": 24,
		"goals": [{"type": "rock", "n": 8}, {"type": "chunks", "n": 42}],
		"rows": [
			"# : : : : : #",
			": : : : : : :",
			": : 1 1 1 : :",
			": : 1 o 1 : :",
			": : 1 1 1 : :",
			": : : @ : : :",
			": : : : : : :",
			"# : : : : : #",
		],
	},
	{
		"id": "glint", "mode": "fall", "colours": 4, "tier": "intro", "energy": 17,
		"goals": [{"type": "crystal", "n": 1}, {"type": "chunks", "n": 15}],
		"rows": [
			"# # # # # # #",
			"# . . 1c . . #",
			"# . . . . . #",
			"# . . @ . . #",
			"# 1 . . . 1 #",
			"# . . . . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"script": [
			{"say": "That rock glints: there's a crystal inside! Make a match next to it to crack it open.", "until": "reveal", "focus": [Vector2i(3, 1)]},
			{"say": "Drive onto the crystal to pick it up. The colony needs crystals for its bigger buildings.", "until": "crystal", "focus": [Vector2i(3, 1)]},
		],
	},
	{
		"id": "nearby", "mode": "fall", "colours": 4, "tier": "normal", "energy": 16,
		"goals": [{"type": "crystal", "n": 3}, {"type": "chunks", "n": 18}],
		"rows": [
			". . . . . . .",
			". o . . . o .",
			". . 1c . 1c . .",
			". . . @ . . .",
			". o . . . o .",
			". . 1c . 1c . .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "rooms", "mode": "fall", "colours": 4, "tier": "normal", "energy": 24,
		"goals": [{"type": "chunks", "n": 36}],
		"rows": [
			"# # # # # # #",
			": : : 1 : : :",
			": : : 1 : : :",
			": @ : 1 : : :",
			": : : 1 : : :",
			": : : 1 : : :",
			"# # # # # # #",
			"# # # # # # #",
		],
	},
	{
		"id": "lode", "mode": "fall", "colours": 4, "tier": "reward", "energy": 12,
		"goals": [{"type": "chunks", "n": 30}],
		"rows": [
			"o o . o . o o",
			"o . . o . . o",
			". . o o o . .",
			"o o o @ o o o",
			". . o o o . .",
			"o . . o . . o",
			"o o . o . o o",
			"# o o . o o #",
		],
	},
	{
		# the Bomb lesson (GDD v4, iteration 1): the Power Station has just handed out a free Bomb.
		# Rubble clumps 2x2 are slow to crack with matches (only their outer cells touch open
		# ground), a Bomb on a clump breaks all four at once
		"id": "quarry", "mode": "fall", "colours": 4, "tier": "normal", "energy": 36,
		"goals": [{"type": "rock", "n": 10}],
		"rows": [
			". . . . . . .",
			". 1 1 . 1 1 .",
			". 1 1 . 1 1 .",
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			". . 1 1 1 . .",
			"# . . . . . #",
		],
	},
	{
		# gold rush: a bonus dig with no fail. Chests everywhere; open as many as the moves
		# allow, every chest is Coin. Announced by its own card and banner (DigScreen).
		"id": "rush1", "mode": "fall", "colours": 4, "gold_rush": true, "energy": 14,
		"goals": [{"type": "treasure", "n": 10}],
		"rows": [
			". . . . . . .",
			". 1t . . . 1t .",
			". . . 1t . . .",
			"1t . . . . . 1t",
			". . 1t @ 1t . .",
			". . . . . . .",
			". 1t . . . 1t .",
			". . . 1t . . .",
		],
	},
	{
		# a rubble zig-zag on scarce ground; with falling gems (iteration 1) its old hand-made
		# opening no longer applies, so it rolls fresh gems like any other dig
		"id": "zigzag", "mode": "fall", "colours": 4, "tier": "normal", "energy": 24,
		"goals": [{"type": "rock", "n": 11}],
		"rows": [
			"# # # # # # #",
			": _ : 1 : _ :",
			"1 1 : 1 : 1 1",
			": 1 : : : 1 :",
			": 1 1 : 1 1 :",
			"_ : 1 @ 1 : _",
			"# : : _ : : #",
			"# # # # # # #",
		],
	},
	{
		# the cell lesson (falling gems): 9 moves for 20 Ferrite is not enough, the buried cell's 6
		# more moves are (the solver's route takes 13). It starts on a full budget: opening
		# on a half-empty one read as moves taken away.
		"id": "battery", "mode": "fall", "colours": 4, "guide": true, "seed": 5, "energy": 9,
		"goals": [{"type": "ore", "ore": 0, "n": 20}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# . . 1e . . #",
			"# . . @ . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- C L - F C -",
			"- C F - F F -",
			"- F L C L C -",
			"- C C L F L -",
			"- L F C C F -",
			"- - - - - - -",
		],
		"script": [
			{"say": "20 Ferrite in 9 moves is too tight. But there's an energy cell buried in that rock: it's worth 6 more moves."},
			{"say": "Make a match right next to that rock to crack it open.", "until": "reveal", "focus": [Vector2i(3, 2)]},
			{"say": "There's the cell! Drive onto it for 6 more moves.", "until": "cell"},
		],
	},
	{
		# energy cells, practised: shallow ground runs dry fast, and the cells sit under rubble, so
		# cracking the right rock first buys the moves to finish
		"id": "cellar", "mode": "fall", "colours": 4, "tier": "normal", "energy": 14,
		"goals": [{"type": "chunks", "n": 48}],
		"rows": [
			": : : : : : :",
			": 1e : 1 : 1e :",
			": : : : : : :",
			". . . @ . . .",
			": : : : : : :",
			": 1 : 1e : 1 :",
			": : : : : : :",
			"# : : : : : #",
		],
	},
	{
		# a variation, not a new mechanic: 2-layer rock (a match cracks one layer, so each needs two)
		"id": "boulders", "mode": "fall", "colours": 4, "tier": "normal", "energy": 21,
		"goals": [{"type": "rock", "n": 5}, {"type": "chunks", "n": 18}],
		"rows": [
			". . . . . . .",
			". 2 . . . 2 .",
			". . . 2 . . .",
			". . . @ . . .",
			". 2 . . . 2 .",
			". . . . . . .",
			". . 2 . 2 . .",
			"# . . . . . #",
		],
		"script": [
			{"say": "Some rocks here are tougher: two layers. A match next to one only cracks a layer, so hit it twice."},
		],
	},
	{
		# three rooms, each closed by a rock gate; every room is a small puzzle (a pair next to
		# the gate, the third gem one row away: walk over and step onto it), the crystal is in
		# the rock in the top-left corner. The intended route takes 23 moves; 25 leaves room for
		# two wasted moves. (v4: it no longer teaches the Power Station, whose +moves are gone;
		# the Bomb lesson replaces it when the levels are redone.)
		"id": "longhaul", "building_level": true, "seed": 31, "energy": 25,
		"goals": [{"type": "crystal", "n": 1}],
		"needs": {"building": 0, "level": 1},
		"rows": [
			"1c . . . . . .",
			". . . . . . .",
			"# # # # # 1 #",
			". . . . . . .",
			". . . . . . .",
			"# 1 # # # # #",
			". . . . . @ .",
			". . . . . . .",
		],
		"ore": [
			"- C L F C F C",
			"L L F C F C F",
			"- - - - - - -",
			"L F L F L C C",
			"C C F L C F L",
			"- - - - - - -",
			"F F C L C - L",
			"C L F C L C F",
		],
		"script": [
			{"say": "The crystal is in the top room, behind two rock gates. Each room hides a match that cracks its gate."},
			{"say": "Two Ferrite sit by the gate. Walk over and step down onto the third.", "until": "reveal", "focus": [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 7)]},
			{"say": "Gate's open. Same trick in every room: find the pair next to the gate.", "until": "crystal"},
		],
	},
	{
		"id": "charge", "guide": true, "seed": 9, "energy": 14,
		"goals": [{"type": "blast", "n": 2}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# 1 1 1 1 1 #",
			"# . . . . . #",
			"# . . @ . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- C L F C L -",
			"- F F - F C -",
			"- L C L L F -",
			"- C L C F C -",
			"- - - - - - -",
		],
		"script": [
			{"say": "Line up 4 at once and the robot leaves a blast charge behind."},
			{"say": "Swipe up: that lines up 4 Ferrite.", "until": "charge", "focus": [Vector2i(3, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(4, 4)]},
			{"say": "There's the charge. Step onto it to set it off!", "until": "blast", "focus": [Vector2i(3, 4)]},
			{"say": "Boom! A blast clears everything around it, rock too. Make another line of 4 and set off one more."},
		],
	},
	{
		"id": "checker", "tier": "hard", "energy": 21,
		"goals": [{"type": "crystal", "n": 2}],
		"rows": [
			". . . . . . .",
			". 1 . 2c . 1 .",
			". . . . . . .",
			". 1e . 1 . 1e .",
			". . . @ . . .",
			". 1 . 2c . 1 .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "route", "tier": "normal", "energy": 37,
		"goals": [{"type": "crystal", "n": 2}, {"type": "chunks", "n": 27}],
		"rows": [
			"1 . 1c 1 1c . 1",
			". . . . . . .",
			"# . . . . . #",
			"# # . . . # #",
			"# # . @ . # #",
			"# # . . . # #",
			"# # . . . # #",
			"# # # # # # #",
		],
	},
	{
		"id": "deep", "tier": "normal", "energy": 31,
		"goals": [{"type": "crystal", "n": 1}, {"type": "chunks", "n": 42}],
		"rows": [
			"o : : : : : o",
			": o : : : o :",
			": : o 1c o : :",
			": : : @ : : :",
			": : o : o : :",
			": o : : : o :",
			"o : : : : : o",
			"# : : : : : #",
		],
	},
	{
		"id": "rush2", "gold_rush": true, "energy": 16,
		"goals": [{"type": "treasure", "n": 12}],
		"rows": [
			"1t . . 1t . . 1t",
			". . . . . . .",
			". 1t . . . 1t .",
			". . 1t . 1t . .",
			"1t . . @ . . 1t",
			". . 1t . 1t . .",
			". 1t . . . 1t .",
			". . . 1t . . .",
		],
	},
	{
		"id": "shallows", "tier": "superhard", "energy": 19,
		"goals": [{"type": "crystal", "n": 3}],
		"rows": [
			": : : : : : :",
			"1c : : : : : 1c",
			": : 1e : 1e : :",
			": : : @ : : :",
			": : : : : : :",
			": : 1e : 1e : :",
			": : : 1c : : :",
			"# : : : : : #",
		],
	},
	{
		"id": "well", "tier": "breather", "energy": 24,
		"goals": [{"type": "crystal", "n": 1}, {"type": "chunks", "n": 12}],
		"rows": [
			"# . . . . . #",
			"# . . @ . . #",
			"# 1 . . . 1 #",
			"# . 1 . 1 . #",
			"# 1 . . . 1 #",
			"# . 1 . 1 . #",
			"# . . 1e . . #",
			"# # . 1c . # #",
		],
	},
	{
		"id": "garden", "tier": "reward", "energy": 41, "unlock": 1,
		"goals": [{"type": "crystal", "n": 4}],
		"rows": [
			". . 1c . 1c . .",
			". o . . . o .",
			". . . . . . .",
			"1c . . @ . . 1c",
			". . . . . . .",
			". o . . . o .",
			". . 1e . 1e . .",
			"# . . . . . #",
		],
	},
	{
		"id": "vaults", "building_level": true, "seed": 32, "energy": 42,
		"goals": [{"type": "crystal", "n": 2}],
		"needs": {"building": 1, "level": 1},
		"rows": [
			"3c # . . . # 3c",
			"_ # . . . # _",
			". . . . . . .",
			". . 2 . 2 . .",
			". . . . . . .",
			". . . . . . .",
			"1e . . . . . 1e",
			"# . . @ . . #",
		],
		"ore": [
			"- - L F L - -",
			"- - L L C - -",
			"F C C L C F C",
			"C F - F - F C",
			"C F C C L L F",
			"F C F F C L F",
			"- C C L F C -",
			"- F L - L C -",
		],
		"script": [
			{"say": "Two crystals, sealed in basalt vaults three layers thick. Matches barely scratch them."},
			{"say": "But now you have a drill! Stand in a vault's doorway and swipe up into the rock."},
			{"say": "Get to a doorway and swipe up into the basalt.", "until": "drill", "focus": [Vector2i(0, 1), Vector2i(6, 1)]},
			{"say": "Each bump knocks off a layer for 2 energy. Keep drilling, then grab the crystal.", "until": "crystal", "focus": [Vector2i(0, 0), Vector2i(6, 0)]},
			{"say": "One more vault. The corners hide energy cells, so grab one if the battery runs low.", "until": "crystal", "focus": [Vector2i(0, 0), Vector2i(6, 0)]},
		],
	},
	{
		"id": "stone", "tier": "normal", "energy": 34,
		"goals": [{"type": "rock", "n": 6}],
		"rows": [
			"# # # # # # #",
			". . 2 . 2 . .",
			". . . . . . .",
			". 2 . @ . 2 .",
			". . . . . . .",
			". . 2 . 2 . .",
			". . . . . . .",
			"# . . . . . #",
		],
		"script": [
			{"say": "Stone has 2 layers: one match only chips it. Crack it twice, drill it, or blast it.", "focus": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(5, 1)]},
		],
	},
	{
		"id": "seam", "tier": "normal", "colours": 4, "energy": 26,
		"goals": [{"type": "chunks", "n": 30}],
		"rows": [
			"o o o o o o o",
			". . . . . . .",
			": : : : : : :",
			". . . @ . . .",
			"o o o o o o o",
			". . . . . . .",
			": : : : : : :",
			"# . . . . . #",
		],
	},
	{
		"id": "rubble", "tier": "hard", "energy": 18,
		"goals": [{"type": "rock", "n": 14}],
		"rows": [
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			"1 1e 1 1 1 1e 1",
			"1 1 1e 1 1e 1 1",
			". . . . . . .",
			". . 1 1 1 . .",
			"# . . . . . #",
		],
	},
	{
		"id": "strata", "tier": "normal", "energy": 48,
		"goals": [{"type": "rock", "n": 10}],
		"rows": [
			"o . 2 . 2 . o",
			". 2 . . . 2 .",
			"2 . o . o . 2",
			". . . @ . . .",
			"2 . o . o . 2",
			". 2 . . . 2 .",
			"o . 2 . 2 . o",
			"# . . . . . #",
		],
	},
	{
		"id": "pockets", "tier": "normal", "energy": 36,
		"goals": [{"type": "crystal", "n": 4}],
		"rows": [
			". . 2c . 2c . .",
			". . . . . . .",
			". 1e . . . 1e .",
			". . . @ . . .",
			". . . . . . .",
			". 2c . . . 2c .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "maze", "tier": "normal", "energy": 24,
		"goals": [{"type": "crystal", "n": 3}],
		"rows": [
			"# # # # # # #",
			". . 2 . 2 . .",
			". 1c . . . 1c .",
			". . . @ . . .",
			". 2 . 1e . 2 .",
			". . . 2 . . .",
			". . 1c . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "shale", "tier": "superhard", "colours": 4, "energy": 28,
		"goals": [{"type": "ore", "ore": 1, "n": 8}, {"type": "crystal", "n": 1}],
		"rows": [
			": : : : : : :",
			": : : @ : : :",
			": : : : : : :",
			"2 1e 2 2 2 1e 2",
			". . . . . . .",
			". . . . . . .",
			"2 2 3 1c 3 2 2",
			"# 3 3 3 3 3 #",
		],
	},
	{
		"id": "core", "tier": "breather", "energy": 23,
		"goals": [{"type": "crystal", "n": 2}, {"type": "chunks", "n": 15}],
		"needs": {"building": 1, "level": 1},
		"rows": [
			"# # # # # # #",
			"o . . . . . o",
			". 2 2 2 2 2 .",
			". 2 2c 1e 2c 2 .",
			". . . @ . . .",
			". 2 2 2 2 2 .",
			"o . . . . . o",
			"# . . . . . #",
		],
	},
	{
		"id": "openseam", "tier": "reward", "energy": 28, "unlock": 2,
		"goals": [{"type": "chunks", "n": 30}],
		"rows": [
			"2 o 2 . 2 o 2",
			"2 o 1 . 1 o 2",
			"1 . . @ . . 1",
			"2e . . . . . 2e",
			"1 . . . . . 1",
			"2 o 1 . 1 o 2",
			"2 o 2 . 2 o 2",
			"# 3 3e 3 3 3 #",
		],
	},
	{
		"id": "readings", "building_level": true, "seed": 33, "energy": 34,
		"goals": [{"type": "crystal", "n": 2}],
		"needs": {"building": 2, "level": 1},
		"rows": [
			". 2x . 2x . 2c .",
			". . . . . . .",
			"2x . 2e . 2x . 2x",
			". . . . . . .",
			". 2c . 2x . 2e .",
			". . . . . . .",
			". . . . . . .",
			". . . @ . . .",
		],
		"ore": [
			"C - L - L - F",
			"C F C L C L F",
			"- L - C - C -",
			"F F L C L C L",
			"L - C - F - C",
			"C L F C L L C",
			"L F F C F L F",
			"L C L - L F L",
		],
		"script": [
			{"say": "The lab's scanner is on: the icons on each rock show what's buried inside."},
			{"say": "Ten rocks, two crystals, and a small battery. Don't waste energy on empty rock."},
			{"say": "Find the rocks with a crystal icon, then drill or crack them open.", "until": "crystal", "focus": [Vector2i(5, 0), Vector2i(1, 4)]},
			{"say": "One more! The green battery icons are energy cells, if you run low.", "until": "crystal", "focus": [Vector2i(5, 0), Vector2i(1, 4)]},
		],
	},
]

static func count() -> int:
	return LIST.size()


static func get_site(i: int) -> Dictionary:
	if i >= LIST.size() and i - LIST.size() < protos().size():
		return protos()[i - LIST.size()]
	return LIST[clampi(i, 0, LIST.size() - 1)]


# --- prototypes ------------------------------------------------------------------------
## Core-loop prototypes to compare by playing (Settings > Prototypes): the same five boards in
## three modes, so the loop is the only difference. They sit after the campaign (index
## count() + k), never count as progress and pay nothing.
##   A "robot":   the robot walks, each step drags one gem, matched gems surface from below
##   B "fall":    the robot walks, matched gems vanish and new ones drop in from above
##   C "classic": no robot; swap two neighbouring gems; gems drop in from above
## Each board also tries one special for a line of 4 (Board.Special): geode, drill, prism,
## quake, and the original blast on the last board for comparison.
const PROTO_MODES := [["A", "robot", "Robot"], ["B", "fall", "Robot + falling gems"], ["C", "classic", "Classic swap"]]
const PROTO_BOARDS := [
	{"name": "Open field", "special": "geode", "energy": 22, "goals": [{"type": "ore", "ore": 0, "n": 18}],
		"rows": ["# . . . . . #", ". . . . . . .", ". . . . . . .", ". . . @ . . .",
			". . . . . . .", ". . . . . . .", ". . . . . . .", "# . . . . . #"]},
	{"name": "Rubble band", "special": "drill", "energy": 24, "goals": [{"type": "rock", "n": 7}, {"type": "chunks", "n": 20}],
		"rows": [". . . . . . .", ". . . . . . .", "1 1 1 1 1 1 1", ". . . . . . .",
			". . . @ . . .", ". . . . . . .", ". . . . . . .", "# . . . . . #"]},
	{"name": "Crystal vaults", "special": "prism", "energy": 26, "goals": [{"type": "crystal", "n": 3}],
		"rows": [". . . . . . .", ". 1c . . . 1c .", ". . . . . . .", ". . . @ . . .",
			". . . . . . .", ". . . 1c . . .", ". . . . . . .", "# . . . . . #"]},
	{"name": "Cells and rooms", "special": "quake", "energy": 22, "goals": [{"type": "chunks", "n": 36}],
		"rows": [". . . # . . .", ". 1e . # . 1 .", ". . . # . . .", ". . . @ . . .",
			". . . . . . .", ". 1 . # . 1e .", ". . . # . . .", "# . . # . . #"]},
	{"name": "Mixed", "special": "blast", "energy": 28, "goals": [{"type": "rock", "n": 5}, {"type": "crystal", "n": 2}],
		"rows": [". . . . . . .", ". 2 . . . 2 .", ". . 1c . 1c . .", ". . . @ . . .",
			". 2 . . . 2 .", ". . . . . . .", ". . 1 . 1 . .", "# . . . . . #"]},
]
## Extra boards for the falling-gem mode only (B6+): odd maps in Royal Match's spirit.
##   portals: [[source, destination]]: what falls out of the source cell drops in at the
##            destination (the robot too: fall through to reach the other chamber)
##   spawn_top: new gems only enter runs that reach the top of the board (pockets under a rock
##            shelf drain and open up, and the robot can drop into them)
##   collect: a crystal or cell is collected when it reaches the bottom of its run
const PROTO_FALL_EXTRA := [
	{"name": "Twin chambers", "special": "drill", "energy": 26, "goals": [{"type": "crystal", "n": 2}],
		"portals": [[Vector2i(1, 2), Vector2i(1, 4)], [Vector2i(5, 2), Vector2i(5, 4)]],
		"rows": [". . . . . . .", ". . . @ . . .", ". . . . . . .", "# # # # # # #",
			". . . . . . .", ". 1c . . . 1c .", ". . . . . . .", "# . . . . . #"]},
	{"name": "Funnel", "special": "geode", "energy": 22, "goals": [{"type": "chunks", "n": 45}],
		"rows": [". . . . . . .", ". . . . . . .", "# . . . . . #", "# . . @ . . #",
			"# # . . . # #", "# # . . . # #", "# # # . # # #", "# # # . # # #"]},
	{"name": "Side stream", "special": "prism", "energy": 24, "goals": [{"type": "rock", "n": 6}],
		"portals": [[Vector2i(0, 7), Vector2i(4, 0)], [Vector2i(1, 7), Vector2i(5, 0)], [Vector2i(2, 7), Vector2i(6, 0)]],
		"rows": [". . . # . . .", ". . . # 1 . 1", ". . . # . . .", ". @ . # 1 . 1",
			". . . # . . .", ". . . # 1 . 1", ". . . # . . .", ". . . # . . ."]},
	{"name": "Hollow pockets", "special": "quake", "energy": 24, "spawn_top": true,
		"goals": [{"type": "rock", "n": 6}, {"type": "chunks", "n": 20}],
		"rows": [". . . . . . .", ". . . @ . . .", ". . . . . . .", "1 1 . 1 . 1 1",
			". . . . . . .", ". . . . . . .", "1 1 1 . 1 1 1", ". . . . . . ."]},
	{"name": "Crystal drop", "special": "drill", "energy": 22, "collect": true,
		"goals": [{"type": "crystal", "n": 3}],
		"rows": [". 1c . . . 1c .", ". . . . . . .", ". . . 1c . . .", ". . . @ . . .",
			". . . . . . .", ". . . . . . .", ". . . . . . .", "# . . . . . #"]},
	{"name": "Chain lake", "special": "geode", "energy": 20, "goals": [{"type": "ore", "ore": 2, "n": 30}],
		"rows": ["# . . . . . #", ". . . . . . .", ". . . . . . .", ". . . @ . . .",
			". . . . . . .", ". . . . . . .", ". . . . . . .", "# # . . . # #"]},
]

## Budgets per mode and board, tuned with tools/tune_proto.gd (SLOPPY bot, ~82%).
const PROTO_ENERGY := {"robot": [40, 21, 24, 23, 17], "fall": [23, 30, 22, 20, 17], "classic": [16, 23, 16, 13, 15],
		"fall_extra": [16, 20, 24, 15, 27, 44]}

## What each special does, for the prototype's goal card.
const SPECIAL_TIPS := {
	"blast": "Line of 4: a Blast charge. Step on it: it blows up the 3x3 around it.",
	"drill": "Line of 4: a Drill Core. Move it: it bores on the way it moved until rock.",
	"prism": "Line of 4: a Prism. Move it: four diagonal beams cut through everything.",
	"geode": "Line of 4: a Geode. Move it: the 8 gems around it turn its colour.",
	"quake": "Line of 4: a Quake. Move it: it shakes the ring two cells out.",
}

static var _protos: Array = []


static func protos() -> Array:
	if _protos.is_empty():
		for m in PROTO_MODES:
			for k in PROTO_BOARDS.size():
				var site: Dictionary = PROTO_BOARDS[k].duplicate(true)
				site.id = "proto_%s%d" % [m[0], k + 1]
				site.proto = true
				site.mode = m[1]
				site.title = "%s%d %s" % [m[0], k + 1, site.name]
				if m[1] != "robot":
					# falling gems cascade by themselves: with 3 colours a board plays itself (B1 took
					# 5 moves for 18 Ferrite against the robot's 21), so they get one colour more
					site.colours = 4
				var budgets: Array = PROTO_ENERGY.get(m[1], [])
				if k < budgets.size():
					site.energy = budgets[k]
				if m[1] == "classic":
					# a swap anywhere plus cascades clears far more per move than the robot does:
					# bigger ore goals and tougher rock keep a classic board as long as the others
					var rows := []
					for r in site.rows:
						var codes := []
						for code in String(r).replace("@", ".").split(" ", false):
							if code.length() >= 1 and code[0] in ["1", "2"]:
								code = "3" + code.substr(1)
							codes.append(code)
						rows.append(" ".join(codes))
					site.rows = rows
					for g in site.goals:
						if g.type == "ore" or g.type == "chunks":
							g.n = int(g.n * 3)
				_protos.append(site)
		for k in PROTO_FALL_EXTRA.size():
			var site: Dictionary = PROTO_FALL_EXTRA[k].duplicate(true)
			var n := PROTO_BOARDS.size() + k + 1
			site.id = "proto_B%d" % n
			site.proto = true
			site.mode = "fall"
			site.colours = 4
			site.title = "B%d %s" % [n, site.name]
			var budgets: Array = PROTO_ENERGY.get("fall_extra", [])
			if k < budgets.size():
				site.energy = budgets[k]
			_protos.append(site)
	return _protos


## Campaign index of prototype k of mode m (0..2).
static func proto_index(m: int, k: int) -> int:
	return LIST.size() + m * PROTO_BOARDS.size() + k


## The prototype picker's rows: [label, [[button text, campaign index], ...]] per mode.
static func proto_rows() -> Array:
	var rows := []
	for m in PROTO_MODES.size():
		var buttons := []
		for i in protos().size():
			var site: Dictionary = protos()[i]
			if String(site.title).begins_with(PROTO_MODES[m][0]):
				buttons.append([String(site.title).split(" ")[0].substr(1), LIST.size() + i])
		rows.append(["%s: %s" % [PROTO_MODES[m][0], PROTO_MODES[m][2]], buttons])
	return rows


static func goal_text(g: Dictionary) -> String:
	match g.type:
		"ore": return "Extract %d %s" % [g.n, Economy.RES_NAMES[g.ore]]
		"rock": return "Break %d rock" % g.n
		"chunks": return "Extract %d ore" % g.n
		"crystal": return "Recover %d crystal%s" % [g.n, "" if g.n == 1 else "s"]
		"blast": return "Set off %d blast%s" % [g.n, "" if g.n == 1 else "s"]
	return "?"


## The number a dig is known by (gold rush bonus digs sit between digs and have none, so
## inserting one does not renumber the campaign); 0 for a gold rush.
static func dig_number(i: int) -> int:
	if i >= LIST.size() or LIST[clampi(i, 0, LIST.size() - 1)].get("gold_rush", false):
		return 0
	var n := 0
	for j in mini(i + 1, LIST.size()):
		if not LIST[j].get("gold_rush", false):
			n += 1
	return n


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return -1
