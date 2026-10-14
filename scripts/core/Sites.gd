class_name Sites
extends RefCounted

## The campaign: digs in play order, one after the other. Players never see a site list or
## site names; they press "Dig" in the colony and get the next one.
## Terrain codes: see Board._parse_cell(). Rows are 7 cells wide, 8 rows tall. Optional keys:
##   "ore":    hand-placed tokens (see Board._place_layout); the opening is always the same
##   "seed":   fixed seed, so what surfaces after each match is always the same
##   "energy": starting energy (below the battery capacity)
##   "guide":  hand-crafted lesson; the hint arrow shows up quickly on every turn
##   "auto_hint": false keeps that arrow away when finding the answer is the lesson
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
		"id": "first", "guide": true, "seed": 3,
		"goals": [{"type": "chunks", "n": 15}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# . . . . . #",
			"# . . . . . #",
			"# . . @ . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- C L L C L -",
			"- L C F L C -",
			"- C F - F L -",
			"- L C L C F -",
			"- F L C F C -",
			"- - - - - - -",
		],
		"script": [
			{"say": "Hi, I'm Mira, chief of the Corvo IV colony. You drive our mining robot."},
			{"say": "The colony runs on ore. Line up 3 chunks of the same kind and the robot extracts them."},
			{"say": "The robot swaps places with the ore it steps into. Swipe up: that Ferrite drops into a line of 3.", "until": "match", "focus": [Vector2i(3, 4), Vector2i(3, 3)]},
			{"say": "Extracted! Each match digs that ground one layer deeper, and new ore rises from below.", "focus": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]},
			{"say": "The yellow pips show how much ore is left down there. When they run out, that vein is dry."},
			{"say": "Every step costs 1 energy from the bar up top, and matches give some back. Extract 15 ore!"},
		],
	},
	{
		"id": "landing", "unlock": 0,
		"goals": [{"type": "ore", "ore": 0, "n": 12}],
		"rows": [
			"1 . . . . . 1",
			". . . . . . .",
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			". . . . . . .",
			"1 . . . . . 1",
			"# 1 1 . 1 1 #",
		],
		"script": [
			{"say": "A full dig site. Every step drags one chunk behind you, so plan your route. We need 12 Ferrite."},
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
		"id": "rocks", "guide": true, "seed": 4,
		"goals": [{"type": "rock", "n": 4}, {"type": "crystal", "n": 1}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# 1 1 1c 1 1 #",
			"# . . @ . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# . . . . . #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- C C - L F -",
			"- F L C F L -",
			"- L F L C F -",
			"- C L F L C -",
			"- - - - - - -",
		],
		"script": [
			{"say": "Rock! The robot can't drive through it."},
			{"say": "But a match right next to rock cracks it. Each white pip on a rock is one layer."},
			{"say": "Swipe down: the Cryo below you lines up with the two beside you, right under the rocks.", "until": "reveal", "focus": [Vector2i(3, 4), Vector2i(1, 3), Vector2i(2, 3)]},
			{"say": "Cracked open! Broken rock turns into fresh ground, and some rock hides things. A crystal!", "focus": [Vector2i(3, 2)]},
			{"say": "Drive onto the crystal to pick it up.", "until": "crystal", "focus": [Vector2i(3, 2)]},
			{"say": "Crystals are rare. The colony needs them for its bigger buildings. Break one more rock to finish."},
		],
	},
	{
		"id": "rubble",
		"goals": [{"type": "rock", "n": 8}],
		"rows": [
			". . . . . . .",
			". . . @ . . .",
			". . . . . . .",
			"1 2 1 1 1 2 1",
			"2 1 2e 1 2 1 2",
			". . . . . . .",
			". . 1 1 1 . .",
			"# . . . . . #",
		],
		"script": [
			{"say": "A rock field. Matches crack the rock next to them: break 8."},
		],
	},
	{
		"id": "glint",
		"goals": [{"type": "crystal", "n": 2}],
		"rows": [
			"# . . . . . #",
			". . . @ . . .",
			". . . . . . .",
			". 1 2c 1 2c 1 .",
			"2 2 1 . 1 2 2",
			"2 1 . . . 1 2",
			"# 2 2 2 2 2 #",
			"# # 3 3c 3 # #",
		],
		"script": [
			{"say": "Crystal readings under this rock. Crack it open and collect 2 crystals."},
		],
	},
	{
		"id": "power", "guide": true, "seed": 7, "energy": 2,
		"goals": [{"type": "crystal", "n": 1}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# # # # # # #",
			"# _ _ _ _ _ #",
			"# _ _ @_ _ _ #",
			"# 3 3 3e 3 3 #",
			"# # # _ # # #",
			"# _ _ _ # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- C L F C L -",
			"- F F - F C -",
			"- - - - - - -",
			"- - - - - - -",
			"- c - - - - -",
		],
		"script": [
			{"say": "Careful, the battery is almost flat! When it hits zero the robot has to come home."},
			{"say": "Line up 4 at once and you also get a blast charge."},
			{"say": "Swipe up: that lines up 4 Ferrite.", "until": "charge", "focus": [Vector2i(3, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(4, 4)]},
			{"say": "There's the charge. Step onto it to set it off. Blasts smash even dark basalt.", "until": "blast", "focus": [Vector2i(3, 4)]},
			{"say": "An energy cell was buried in that basalt. Drive over it to refill the battery.", "until": "cell", "focus": [Vector2i(3, 5)]},
			{"say": "Full power! Now bring that crystal home.", "until": "crystal", "focus": [Vector2i(1, 7)]},
		],
	},
	{
		"id": "shale", "unlock": 1,
		"goals": [{"type": "ore", "ore": 1, "n": 15}, {"type": "crystal", "n": 1}],
		"rows": [
			": : : : : : :",
			": : : @ : : :",
			": : : : : : :",
			"2 1e 2 2 2 1e 2",
			". . . . . . .",
			". . . . . . .",
			"2 2 3 2c 3 2 2",
			"# 3 3 3 3 3 #",
		],
		"script": [
			{"say": "Shallow ground: these veins run dry fast. Energy cells hide under the rock."},
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
		"id": "vein",
		"goals": [{"type": "ore", "ore": 2, "n": 15}, {"type": "crystal", "n": 2}],
		"rows": [
			"2 o 2 . 2 o 2",
			"2 o 1 . 1 o 2",
			"1 . . @ . . 1",
			"2c . . . . . 2c",
			"1 . . . . . 1",
			"2 o 1 . 1 o 2",
			"2 o 2 . 2 o 2",
			"# 3 3e 3 3 3 #",
		],
		"script": [
			{"say": "Deep veins here, they keep giving. Match 4 for charges, they clear rock fast."},
		],
	},
	{
		"id": "core", "unlock": 2,
		"goals": [{"type": "crystal", "n": 3}],
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
		"script": [
			{"say": "The crystals sit inside a basalt shell. Swipe into rock to drill it, and use charges."},
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
	return "?"


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return -1
