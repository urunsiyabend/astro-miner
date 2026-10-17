class_name Economy
extends RefCounted

## Colony buildings, their costs, the boosters they make, and how levels turn into Board rules.
## Economy v4 (docs/design/gdd-v4.md):
##   Coin  — earned by CLEARING a dig: a fixed reward for the chapter plus 1 per move left
##           (a failed or recalled dig earns none). The only SPENT currency: building upgrades.
##   Star  — +1 per dig first-clear, nothing else; NEVER spent. Star N means N digs cleared, so
##           the colony milestones (STAR_MILESTONES) land on known digs.
## Buildings give NO permanent board power. Building one opens its mechanic (the Workshop's
## Drill, the Lab's Scanner) and starts its booster production; its level only sets how fast
## it makes boosters and how many it holds until collected. Board help is consumable.
## RES_NAMES names the board's ore types and crystal (for goal text), not currency banks.

const RES_NAMES := ["Ferrite", "Cryo", "Lumen", "Ruby", "Crystal"]

## Boosters, in unlock order: used during a dig from the bar under the board, 0 moves each.
enum Booster { BOMB, WARP, LASER, MAGNET }
const BOOSTERS := [
	{"id": "bomb", "name": "Bomb", "building": 0, "tip": "Tap a cell: blasts 3x3"},
	{"id": "warp", "name": "Warp", "building": 3, "tip": "Tap a cell: the robot warps there"},
	{"id": "laser", "name": "Laser", "building": 1, "tip": "Swipe: a beam from the robot"},
	{"id": "magnet", "name": "Magnet", "building": 2, "tip": "Tap a gem: pulls every gem of its colour"},
]

## Index order is save order (Game.levels): the Teleporter came last, so it is 3.
const BUILDINGS := [
	{"id": "power", "name": "Power Station", "booster": Booster.BOMB, "costs": [0, 75, 135]},
	{"id": "workshop", "name": "Mining Workshop", "booster": Booster.LASER, "costs": [0, 95, 165],
			"opens": "Drill: bump rock to break a layer (2 energy)"},
	{"id": "lab", "name": "Research Lab", "booster": Booster.MAGNET, "costs": [0, 110, 190],
			"opens": "Scanner: see what rock hides"},
	{"id": "teleporter", "name": "Teleporter", "booster": Booster.WARP, "costs": [0, 85, 150]},
]

const MAX_LEVEL := 3
const FIRST_CLEAR_STARS := 1

## Production by building level: one booster every PRODUCE_EVERY[lv] cleared digs. A building
## holds ONE until the player taps its bubble to collect it, and makes no other meanwhile (a
## bubble always means "one is ready"; the level only makes it come sooner).
const PRODUCE_EVERY := [0, 5, 4, 3]
const HOLD := [0, 1, 1, 1]

## Cumulative-star thresholds for the Planet-1 colony milestones (GDD v3 §4, v4 §1). Star is
## one per cleared dig, so milestone k arrives exactly at dig STAR_MILESTONES[k].
const STAR_MILESTONES := [4, 10, 14, 20, 30]
## Star needed to unlock each building, by building index [power, workshop, lab, teleporter].
## Power at 10: the Bomb arrives as chapter 1 ends (iteration 1, docs/design/level-plan.md).
const STAR_UNLOCK := [10, 20, 30, 14]


## Coin cost to take a building from current_level to current_level+1, or -1 at max.
## Level 0 -> 1 is free (0): a star milestone grants it.
static func cost(building: int, current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return -1
	return BUILDINGS[building].costs[current_level]


static func can_afford(coin: int, c: int) -> bool:
	return c >= 0 and coin >= c


## What a building does at a level (the upgrade card's Now / Next lines).
static func effect(building: int, level: int) -> String:
	if level <= 0:
		return "Not built yet"
	var bname: String = BOOSTERS[BUILDINGS[building].booster].name
	return "Makes a %s every %d digs" % [bname, PRODUCE_EVERY[level]]


## Board rule overrides for a set of building levels [power, workshop, lab, teleporter]. Only
## mechanics: the Drill (Workshop) and the Scanner (Lab). No level changes the board.
static func rules(levels: Array) -> Dictionary:
	var r := {}
	r.drill = levels[1] >= 1
	r.scanner = levels[2] >= 1
	return r


## Coin for clearing a dig, by chapter of 10 digs.
const CLEAR_COIN := [8, 10, 12]
const COIN_PER_MOVE := 1


static func clear_coin(site_index: int) -> int:
	var n := maxi(1, Sites.dig_number(site_index))
	return CLEAR_COIN[clampi((n - 1) / 10, 0, CLEAR_COIN.size() - 1)]


## Chance that a dig hides a treasure chest, after `dry` digs without one.
const TREASURE_BASE := 0.12
const TREASURE_STEP := 0.06
const TREASURE_MAX := 0.5


static func treasure_chance(dry: int) -> float:
	return minf(TREASURE_MAX, TREASURE_BASE + TREASURE_STEP * maxi(0, dry))


## Coin for the moves left when a dig is cleared.
static func move_coin(moves_left: int) -> int:
	return maxi(0, moves_left) * COIN_PER_MOVE
