class_name Sites
extends RefCounted

## Handcrafted dig-site templates (terrain only; ore types are seeded per dig).
## Codes: see Board.setup(). Rows are 7 cells wide, 8 rows tall.

const LIST := [
	{
		"id": "landing", "name": "Landing Zone",
		"tip": "Swipe to move. The robot swaps with the ore it steps into. Line up 3 to extract.",
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
		"crystal": return "Recover %d crystal%s" % [g.n, "" if g.n == 1 else "s"]
	return "?"
