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
		"id": "drag",
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
		"id": "vein",
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
		"id": "landing",
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
		"id": "rocks",
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
		"id": "glint",
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
		"id": "ring", "energy": 18,
		"goals": [{"type": "rock", "n": 8}, {"type": "ore", "ore": 0, "n": 23}],
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
		"id": "rooms",
		"goals": [{"type": "ore", "ore": 1, "n": 17}],
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
		"id": "zigzag", "energy": 16,
		"goals": [{"type": "rock", "n": 12}],
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
		"id": "lode", "unlock": 0,
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
		"id": "longhaul", "building_level": true, "seed": 31,
		"goals": [{"type": "crystal", "n": 1}],
		"needs": {"building": 0, "level": 1},
		"rows": [
			"_ _ _ _ # # #",
			"_ # # # # # #",
			"_ _ _ _ _ _ _",
			"# # # # # # _",
			"_ _ _ _ _ _ _",
			"1 # # # # # #",
			". . @ . . . .",
			". . . . . . .",
		],
		"ore": [
			"- - - c - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"F F - C L C L",
			"C L F L C F C",
		],
		"script": [
			{"say": "The Power Station is online: look at the battery bar, it holds 26 energy now."},
			{"say": "The crystal is at the end of that long tunnel. Nothing to refill on the way in: the old battery would run dry halfway."},
			{"say": "First open the tunnel: swipe down, so that Ferrite lines up right next to the rock.", "until": "reveal", "focus": [Vector2i(0, 5), Vector2i(2, 7), Vector2i(0, 6), Vector2i(1, 6)]},
			{"say": "Matches refill the battery. Top it up to 26, then head through the tunnel to the crystal.", "until": "crystal", "focus": [Vector2i(0, 5)]},
		],
	},
	{
		"id": "nearby",
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
		"id": "battery", "guide": true, "seed": 5, "energy": 6,
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
			{"say": "The battery is nearly flat! When it hits zero, the robot has to head home."},
			{"say": "Swipe left: three Ferrite line up right under that rock and crack it.", "until": "reveal", "focus": [Vector2i(2, 3), Vector2i(3, 2)]},
			{"say": "An energy cell was buried in there. Drive onto it to recharge.", "until": "cell", "focus": [Vector2i(3, 2)]},
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
		"id": "checker",
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
		"id": "route",
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
		"id": "deep",
		"goals": [{"type": "crystal", "n": 1}, {"type": "ore", "ore": 2, "n": 25}],
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
		"id": "shallows", "energy": 20,
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
		"id": "well", "energy": 20,
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
		"id": "garden", "unlock": 1,
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
		"id": "vaults", "building_level": true, "seed": 32,
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
			{"say": "One more vault. Matches on the way refill the battery, and the corners hide energy cells.", "until": "crystal", "focus": [Vector2i(0, 0), Vector2i(6, 0)]},
		],
	},
	{
		"id": "stone",
		"goals": [{"type": "rock", "n": 4}],
		"rows": [
			"# # # # # # #",
			". 2 2 . 2 2 .",
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			". . . . . . .",
			". . . . . . .",
			"# . . . . . #",
		],
		"script": [
			{"say": "Stone has 2 layers: one match only chips it. Crack it twice, drill it, or blast it.", "focus": [Vector2i(1, 1), Vector2i(2, 1), Vector2i(4, 1), Vector2i(5, 1)]},
		],
	},
	{
		"id": "seam",
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
		"id": "rubble",
		"goals": [{"type": "rock", "n": 17}],
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
		"id": "strata", "energy": 17,
		"goals": [{"type": "rock", "n": 11}],
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
		"id": "pockets", "energy": 20,
		"goals": [{"type": "crystal", "n": 3}],
		"rows": [
			". . . . . . .",
			". 3c . . . 3c .",
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			". . . 3c . . .",
			". . . . . . .",
			"# . . . . . #",
		],
	},
	{
		"id": "maze",
		"goals": [{"type": "crystal", "n": 2}],
		"rows": [
			". . 2 . . . .",
			". . 3 . 2 2 .",
			"2c . 3 . . 3 .",
			". . . . 3 2c .",
			"2 3 . @ . . .",
			". . . . 3 . 3",
			". 3 2 . 3 . .",
			"# . . . . . #",
		],
	},
	{
		"id": "shale",
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
		"id": "core",
		"goals": [{"type": "crystal", "n": 2}],
		"needs": {"building": 1, "level": 1},
		"rows": [
			"o . . . . . o",
			". 3 2 2 2 3 .",
			". 2 2c 1e 2c 2 .",
			". 2 1 2 1 2 .",
			". 2 2c 1 2c 2 .",
			". 3 2 2 2 3 .",
			". . . @ . . .",
			"o . . . . . o",
		],
	},
	{
		"id": "openseam", "unlock": 2,
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
		"id": "readings", "building_level": true, "seed": 33, "energy": 14,
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


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return -1
