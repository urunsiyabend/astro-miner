class_name Sites
extends RefCounted

## Dig sites in play order. Terrain codes: see Board._parse_cell(). Rows are 7 cells wide,
## 8 rows tall. Ore types are seeded per dig unless the site pins them:
##   "ore":    hand-placed tokens (see Board._place_layout), so the opening is always the same
##   "seed":   fixed seed, so what surfaces after each match is always the same
##   "energy": starting energy (below the battery capacity)
##   "guide":  show the hint arrow quickly on every turn (tutorial sites)
## Each mechanic gets a small hand-crafted tutorial site right before the site that uses it.

const LIST := [
	{
		"id": "step", "name": "First Step", "guide": true, "seed": 1,
		"tip": "Swipe up. The robot swaps places with the ore it steps into.",
		"goals": [{"type": "ore", "ore": 0, "n": 3}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# # # # # # #",
			"# # _ _ _ # #",
			"# # _ _ _ # #",
			"# # _ @_ _ # #",
			"# # # # # # #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- - C L C - -",
			"- - L F L - -",
			"- - F - F - -",
			"- - - - - - -",
			"- - - - - - -",
		],
	},
	{
		"id": "pull", "name": "Pull", "guide": true, "seed": 2,
		"tip": "The ore you step into slides to where you stood. Plan two steps to line up 3 Cryo.",
		"goals": [{"type": "ore", "ore": 1, "n": 3}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# _ _ _ _ _ #",
			"# _ _ @_ _ _ #",
			"# _ _ _ _ _ #",
			"# _ _ _ _ _ #",
			"# # # # # # #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- C C L C F -",
			"- L F - F L -",
			"- F L C L C -",
			"- C F L F L -",
			"- - - - - - -",
			"- - - - - - -",
		],
	},
	{
		"id": "landing", "name": "Landing Zone",
		"tip": "A full dig site. Every step drags one chunk: plan a route to line up Ferrite.",
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
	},
	{
		"id": "veins", "name": "Veins", "guide": true, "seed": 3,
		"tip": "Each match digs the ground deeper and new ore rises from below. The pips show how much is left.",
		"goals": [{"type": "chunks", "n": 24}],
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
			"- C L F C L -",
			"- L C F L C -",
			"- C F - F L -",
			"- L C L C F -",
			"- F L C F C -",
			"- - - - - - -",
		],
	},
	{
		"id": "crack", "name": "Crack", "guide": true, "seed": 4,
		"tip": "Matches crack the rock next to them. Broken rock opens new ground.",
		"goals": [{"type": "rock", "n": 4}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# 1 1 1 1 1 #",
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
	},
	{
		"id": "rubble", "name": "Rubble Field",
		"tip": "Matches crack the rock next to them. Broken rock opens fresh ground.",
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
	},
	{
		"id": "gem", "name": "Gem", "guide": true, "seed": 5,
		"tip": "Crystals hide under rock. Crack the rock open, then drive onto the crystal.",
		"goals": [{"type": "crystal", "n": 1}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# # # 1c # # #",
			"# _ _ @_ _ _ #",
			"# _ _ _ _ _ #",
			"# _ _ _ _ _ #",
			"# # # # # # #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- C C - L F -",
			"- F L C F L -",
			"- L F L C F -",
			"- - - - - - -",
			"- - - - - - -",
		],
	},
	{
		"id": "glint", "name": "Glint Pocket",
		"tip": "Crystals hide under rock. Crack it open, then drive the robot onto the crystal.",
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
	},
	{
		"id": "battery", "name": "Low Battery", "guide": true, "seed": 6, "energy": 3,
		"tip": "Every step costs energy and the battery is nearly flat. Crack the rock: an energy cell refills it.",
		"goals": [{"type": "crystal", "n": 1}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# # # # # # #",
			"# _ _ _ _ _ #",
			"# _ _ @_ _ _ #",
			"# # # 1e # # #",
			"# _ _ _ # # #",
			"# _ # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- C L F L C -",
			"- C F - F L -",
			"- - - - - - -",
			"- - - - - - -",
			"- c - - - - -",
		],
	},
	{
		"id": "shale", "name": "Shale Shelf",
		"tip": "Shallow ground runs dry fast. Energy cells under rock refill the battery.",
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
	},
	{
		"id": "blast", "name": "Blast", "guide": true, "seed": 7,
		"tip": "Match 4 to leave a blast charge. Step on it to blast the 3x3 around it, even basalt.",
		"goals": [{"type": "rock", "n": 3}],
		"rows": [
			"# # # # # # #",
			"# # # # # # #",
			"# # # # # # #",
			"# _ _ _ _ _ #",
			"# _ _ @_ _ _ #",
			"# 3 3 3 3 3 #",
			"# # # # # # #",
			"# # # # # # #",
		],
		"ore": [
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
			"- C L F C L -",
			"- F F - F C -",
			"- - - - - - -",
			"- - - - - - -",
			"- - - - - - -",
		],
	},
	{
		"id": "vein", "name": "Deep Vein",
		"tip": "Deep veins keep giving. Match 4 to leave a blast charge, then step on it.",
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
	},
	{
		"id": "core", "name": "Core Chamber",
		"tip": "A basalt shell guards the chamber. Charges and the drill make short work of it.",
		"goals": [{"type": "crystal", "n": 3}],
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
