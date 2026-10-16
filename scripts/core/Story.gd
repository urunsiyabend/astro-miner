class_name Story
extends RefCounted

## What Mira, the colony chief, says outside the dig scripts in Sites: when a building goes
## up (and the reminder at the start of the next dig), and her advice in the colony.

const MASCOT := "MIRA"

## Lines when a dig unlocks a building (Sites "unlock"); the colony then highlights its button.
const UNLOCK := [
	["Good news: the colony can build a Power Station now! It tops up every dig with extra energy."],
	["The Mining Workshop is ready to build! It comes with a drill that cuts through rock."],
	["We can build a Research Lab now! Its scanner lets you see what's inside rock."],
]

## Lines when a cosmetic star milestone adds something to the colony map (Colony plot id).
const DECO := {
	"pad": ["The robot has a proper landing pad now. The colony is starting to look like a colony!"],
	"greenhouse": ["We put up a greenhouse. Fresh air and fresh food: the crew is very happy."],
	"antenna": ["A long-range antenna is up. Corvo IV can talk to the rest of the system now."],
}

## Lines when a building reaches a level: BUILT[building][level - 1].
const BUILT := [
	[  # Power Station
		["Power Station online! Every dig now starts with +3 energy. Longer digs, more ore."],
		["Power Station upgraded: +6 energy on every dig now."],
		["Power Station maxed: +10 energy on every dig. The robot can really range out."],
	],
	[  # Mining Workshop
		["Mining Workshop built, and it came with a drill!",
				"In a dig, swipe into rock to drill it: one layer per bump, for 2 energy."],
		["Drill upgraded: each bump now knocks off 2 layers."],
		["Drilling costs just 1 energy now, and every match cracks 2 layers of the rock next to it."],
	],
	[  # Research Lab
		["Research Lab built! Its deep scanner shows what's hiding under the rock before you crack it."],
		["The lab studied the rock: broken rock now opens richer veins, 3 layers deep."],
		["The lab improved the robot's recycler: every match refunds 1 more energy."],
	],
]

## Short reminder shown at the start of the first dig after a building level, so a new tool
## is never something you have to discover by poking at it. REMIND[building][level - 1].
const REMIND := [
	["Power Station: every dig now gets +3 energy.", "Power Station: +6 energy every dig now.", "Power Station: +10 energy every dig."],
	["New tool: swipe into rock to drill off a layer (2 energy). Look for the orange drill marks.",
			"Your drill now knocks off 2 layers per bump.",
			"Drilling costs 1 energy, and matches crack 2 rock layers."],
	["The scanner is on: the icons on rock show what's buried inside.",
			"Broken rock opens 3-layer veins now.", "Each match refunds 1 more energy."],
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
			return "We can afford the %s upgrade: %s." % [Economy.BUILDINGS[b].name, Economy.BUILDINGS[b].effects[lv + 1]]
	if next < 0 and not Game.tips_seen.has("all_charted"):
		Game.tips_seen["all_charted"] = true
		return "Every site is charted. Supply runs keep the ore coming so the colony can keep growing."
	return ""
