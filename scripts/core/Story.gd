class_name Story
extends RefCounted

## What Mira, the colony chief, says outside the dig scripts in Sites: when a building goes
## up (and the reminder at the start of the next dig), and her advice in the colony.

const MASCOT := "MIRA"

## Lines when a star milestone unlocks a building (by Economy.BUILDINGS index); the colony then
## highlights its plot.
const UNLOCK := [
	["Good news: the colony can build a Power Station now! It makes Bombs for your digs."],
	["The Mining Workshop is ready to build! It comes with a drill, and it makes Lasers."],
	["We can build a Research Lab now! Its scanner sees inside rock, and it makes Magnets."],
	["We can build a Teleporter now! It makes Warps: send the robot anywhere in a dig."],
]

## Lines when a cosmetic star milestone adds something to the colony map (Colony plot id).
const DECO := {
	"pad": ["The robot has a proper landing pad now. The colony is starting to look like a colony!"],
}

## Lines when a building reaches a level: BUILT[building][level - 1]. Level 1 also hands out
## the first booster; levels 2-3 make boosters faster and hold more of them.
const BUILT := [
	[  # Power Station
		["Power Station online! It packs spare energy into Bombs.", "Here's your first one."],
		["Power Station upgraded: a Bomb every 4 digs now."],
		["Power Station maxed: a Bomb every 3 digs."],
	],
	[  # Mining Workshop
		["Mining Workshop built, and it came with a drill!",
				"In a dig, swipe into rock to drill it: one layer per bump, for 2 energy.",
				"It makes Lasers too. Here's your first one."],
		["Workshop upgraded: a Laser every 4 digs now."],
		["Workshop maxed: a Laser every 3 digs."],
	],
	[  # Research Lab
		["Research Lab built! Its scanner shows what's hiding under the rock before you crack it.",
				"And it makes Magnets. Here's your first one."],
		["Lab upgraded: a Magnet every 4 digs now."],
		["Lab maxed: a Magnet every 3 digs."],
	],
	[  # Teleporter
		["Teleporter online! It makes Warps: the robot jumps to any cell and swaps with what's there.",
				"Here's your first one."],
		["Teleporter upgraded: a Warp every 4 digs now."],
		["Teleporter maxed: a Warp every 3 digs."],
	],
]

## Short reminder shown at the start of the first dig after a building level, so a new tool
## is never something you have to discover by poking at it. REMIND[building][level - 1]; ""
## when the level changes nothing in a dig (it only makes boosters faster).
const REMIND := [
	["New booster: the Bomb! Tap it under the board, then tap a cell to blast it.", "", ""],
	["New tool: swipe into rock to drill off a layer (2 energy). And the Laser booster is in your bar!", "", ""],
	["The scanner is on: the icons on rock show what's buried inside. The Magnet is in your bar too!", "", ""],
	["New booster: the Warp! Tap it, then tap any cell to send the robot there.", "", ""],
]
## The booster half of a new building's reminder alone, for its own lesson dig.
const REMIND_BOOSTER := [
	"New booster: the Bomb! Tap it under the board, then tap a cell to blast it.",
	"New booster: the Laser! Tap it, then swipe: a beam fires from the robot.",
	"New booster: the Magnet! Tap it, then tap a gem: every gem of its colour flies in.",
	"New booster: the Warp! Tap it, then tap any cell to send the robot there.",
]


## Colony advice, only when something is new or in the way; otherwise Mira stays quiet ("").
## An affordable upgrade is pointed out once per building level.
static func advice() -> String:
	if Game.totals.digs == 0:
		return "Welcome to the outpost! The colony grows on ore. Tap DIG and send the robot out."
	var pending := Game.pending_build()
	if pending >= 0:
		return "Tap the glowing Build button on the %s first. It's free!" % Economy.BUILDINGS[pending].name
	var next := Game.next_dig()
	if next >= 0:
		var need: Dictionary = Sites.get_site(next).get("needs", {})
		if not need.is_empty() and Game.levels[need.building] < need.level:
			var bname: String = Economy.BUILDINGS[need.building].name
			if Economy.can_afford(Game.coin, Economy.cost(need.building, Game.levels[need.building])):
				return "The next site is behind a basalt shell. Build the %s: it comes with a drill." % bname
			return "The next site is behind a basalt shell. We need the %s and its drill. Supply runs gather the ore." % bname
	for b in Economy.BUILDINGS.size():
		var lv: int = Game.levels[b]
		var key := "afford_%d_%d" % [b, lv + 1]
		if lv >= 1 and lv < Economy.MAX_LEVEL and not Game.tips_seen.has(key) \
				and Economy.can_afford(Game.coin, Economy.cost(b, lv)):
			Game.tips_seen[key] = true
			return "We can afford the %s upgrade: %s." % [Economy.BUILDINGS[b].name, Economy.effect(b, lv + 1)]
	if next < 0 and not Game.tips_seen.has("all_charted"):
		Game.tips_seen["all_charted"] = true
		return "Every site is charted. Supply runs keep the ore coming so the colony can keep growing."
	return ""
