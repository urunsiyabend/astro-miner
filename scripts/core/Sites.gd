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
		"id": "first", "guide": true, "seed": 42,
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
			{"say": "Extracted! New ore rises from below. Line up 6 Ferrite in all."},
		],
	},
	{
		"id": "drag", "energy": 20,
		"goals": [{"type": "ore", "ore": 1, "n": 9}],
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
		"id": "vein", "energy": 15,
		"goals": [{"type": "chunks", "n": 15}],
		"rows": [
			"# # # # # # #",
			"# : . o . : #",
			"# : . o . : #",
			"# : . o . : #",
			"# : . @ . : #",
			"# : . o . : #",
			"# : . o . : #",
			"# # # # # # #",
		],
		"script": [
			{"say": "The yellow pips under a chunk show how much ore is left below it. The middle vein runs deep, the edges dry up fast.", "focus": [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 5), Vector2i(3, 6)]},
		],
	},
	{
		"id": "landing", "energy": 22,
		"goals": [{"type": "ore", "ore": 2, "n": 12}],
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
		"id": "rocks", "energy": 32,
		"goals": [{"type": "rock", "n": 4}],
		"rows": [
			"# # # # # # #",
			"# 1 1 1 1 1 #",
			"# o o o o o #",
			"# . . @ . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"script": [
			{"say": "Rock! The robot can't drive through it, but a match right next to it cracks it. Make a line just under the rocks.", "until": "reveal", "focus": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]},
			{"say": "Broken rock turns into ground with fresh ore in it. Break 4."},
		],
	},
	{
		"id": "glint", "energy": 16,
		"goals": [{"type": "crystal", "n": 1}, {"type": "chunks", "n": 10}],
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
		# gold rush: a bonus dig with no fail. Chests everywhere; open as many as the moves
		# allow, every chest is Coin. Announced by its own card and banner (DigScreen).
		"id": "rush1", "gold_rush": true, "energy": 14,
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
		"id": "ring", "energy": 26,
		"goals": [{"type": "rock", "n": 5}, {"type": "ore", "ore": 0, "n": 14}],
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
		"id": "rooms", "energy": 27,
		"goals": [{"type": "ore", "ore": 1, "n": 12}],
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
		# hand-made (seed 71, picked by tools/handmade_probe.gd): with a random fill it was a
		# coin flip whether the last rocks could be reached in time. This opening and the 11 of
		# 14 rocks leave room for wasted moves: greedy, planner and a sloppy planner (12% random
		# moves) all clear it, with ~16 energy left
		"id": "zigzag", "energy": 30, "seed": 71,
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
		"ore": [
			"- - - - - - -",
			"F - L - L - F",
			"- - F - F - -",
			"L - F L F - L",
			"L - - F - - L",
			"- L - @ - L -",
			"- C C - C F -",
			"- - - - - - -",
		],
	},
	{
		"id": "lode", "energy": 15, "unlock": 0,
		"goals": [{"type": "chunks", "n": 25}],
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
		# three rooms, each closed by a rock gate; every room is a small puzzle (a pair next to
		# the gate, the third gem one row away: walk over and step onto it), the crystal is in
		# the rock in the top-left corner. The intended route takes 23 moves: the old battery
		# (22) falls one short, the Power Station's 25 leaves room for two wasted moves.
		"id": "longhaul", "building_level": true, "seed": 31, "energy": 22,
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
			{"say": "The Power Station is online: you have 25 moves now, three more than before."},
			{"say": "The crystal is in the top room, behind two rock gates. Each room hides a match that cracks its gate."},
			{"say": "Two Ferrite sit by the gate. Walk over and step down onto the third.", "until": "reveal", "focus": [Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 7)]},
			{"say": "Gate's open. Same trick in every room: find the pair next to the gate.", "until": "crystal"},
		],
	},
	{
		"id": "nearby", "energy": 16,
		"goals": [{"type": "crystal", "n": 2}],
		"rows": [
			". . . . . . .",
			". o . . . o .",
			". . 1c . 1c . .",
			". . . @ . . .",
			". o . . . o .",
			". . . . . . .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		# the cell lesson: 12 moves for 12 Ferrite is not enough, the buried cell's 6 more
		# moves are (the route takes 14, so 4 to spare). It starts on a full budget: opening
		# on a half-empty one read as moves taken away.
		"id": "battery", "guide": true, "seed": 5, "energy": 9,
		"goals": [{"type": "ore", "ore": 0, "n": 12}],
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
			{"say": "12 Ferrite in 12 moves is too tight. But there's an energy cell buried in that rock: it's worth 6 more moves."},
			{"say": "Swipe left: three Ferrite line up right under that rock and crack it.", "until": "reveal", "focus": [Vector2i(2, 3), Vector2i(3, 2)]},
			{"say": "There's the cell. Drive onto it for 6 more moves.", "until": "cell", "focus": [Vector2i(3, 2)]},
		],
	},
	{
		"id": "charge", "guide": true, "seed": 9,
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
		"id": "checker", "energy": 32,
		"goals": [{"type": "crystal", "n": 2}],
		"rows": [
			". . . . . . .",
			". 1 . 1c . 1 .",
			". . . . . . .",
			". 1e . 1 . 1e .",
			". . . @ . . .",
			". 1 . 1c . 1 .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "route", "energy": 39,
		"goals": [{"type": "crystal", "n": 2}],
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
		"id": "deep", "energy": 29,
		"goals": [{"type": "crystal", "n": 1}, {"type": "ore", "ore": 2, "n": 14}],
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
		"id": "shallows", "energy": 30,
		"goals": [{"type": "crystal", "n": 2}],
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
		"id": "well", "energy": 30,
		"goals": [{"type": "crystal", "n": 1}],
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
		"id": "garden", "energy": 40, "unlock": 1,
		"goals": [{"type": "crystal", "n": 3}],
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
		"id": "stone", "energy": 45,
		"goals": [{"type": "rock", "n": 4}],
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
		"id": "seam", "energy": 16,
		"goals": [{"type": "chunks", "n": 32}],
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
		"id": "rubble", "energy": 28,
		"goals": [{"type": "rock", "n": 9}],
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
		"id": "strata", "energy": 39,
		"goals": [{"type": "rock", "n": 6}],
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
		"id": "pockets", "energy": 45,
		"goals": [{"type": "crystal", "n": 3}],
		"rows": [
			". . 1c . 1c . .",
			". . . . . . .",
			". 1e . . . 1e .",
			". . . @ . . .",
			". . . . . . .",
			". 1c . . . 1c .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "maze", "energy": 45,
		"goals": [{"type": "crystal", "n": 2}],
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
		"id": "shale", "energy": 34,
		"goals": [{"type": "ore", "ore": 1, "n": 12}, {"type": "crystal", "n": 1}],
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
		"id": "core", "energy": 45,
		"goals": [{"type": "crystal", "n": 2}],
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
		"id": "openseam", "energy": 22, "unlock": 2,
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
		"id": "readings", "building_level": true, "seed": 33, "energy": 42,
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
	return LIST[clampi(i, 0, LIST.size() - 1)]


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
	if LIST[clampi(i, 0, LIST.size() - 1)].get("gold_rush", false):
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
