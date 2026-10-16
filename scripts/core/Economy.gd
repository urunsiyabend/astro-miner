class_name Economy
extends RefCounted

## Colony buildings, their costs, and how levels translate into Board rules.
## Economy v3 (GDD v3): two currencies.
##   Coin  — every ore chunk merges into one soft currency; the only SPENT currency,
##           used to upgrade a building to level 2 and 3.
##   Star  — a scarce, NEVER-SPENT progress counter (+1 per crystal, +1 per dig first-clear).
##           Reaching a star milestone unlocks the next building (granted free at level 1) and
##           grows the colony. See STAR_MILESTONES / STAR_UNLOCK.
## RES_NAMES names the board's ore types and crystal (for goal text), not currency banks.

const RES_NAMES := ["Ferrite", "Cryo", "Lumen", "Crystal"]

const BUILDINGS := [
	{
		"id": "power", "name": "Power Station",
		"effects": ["+0 energy", "+3 energy every dig", "+6 energy every dig", "+10 energy every dig"],
		"costs": [0, 75, 135],  # Coin to reach level 1, 2, 3 (level 1 is free, granted by a star milestone)
	},
	{
		"id": "workshop", "name": "Mining Workshop",
		"effects": ["No drill", "Drill: bump rock, -1 layer (2 energy)",
				"Drill removes 2 layers", "Drill costs 1, matches crack 2 layers"],
		"costs": [0, 80, 140],
	},
	{
		"id": "lab", "name": "Research Lab",
		"effects": ["No scanner", "Deep Scanner: see what rock hides",
				"Broken rock opens richer veins (3 layers)", "+1 energy per match"],
		"costs": [0, 70, 140],
	},
]

const MAX_LEVEL := 3
const FIRST_CLEAR_STARS := 1

## Cumulative-star thresholds for the six Planet-1 colony milestones (GDD v3 §4). The three
## functional buildings sit at milestones 2/4/6; the others are cosmetic colony-growth beats.
## Tuned against tools/econ_probe.gd: star accrues ~1/dig (mostly first-clears), so arriving at
## a building's needs-dig (digs 11/21/31) means 10/20/30 digs were cleared, GUARANTEEING the
## building unlocks in time regardless of how many crystals the player found.
const STAR_MILESTONES := [4, 8, 14, 20, 26, 30]
## Star needed to unlock each building [power, workshop, lab] — milestones 2/4/6.
const STAR_UNLOCK := [8, 20, 30]
## Extra energy the Power Station adds to EVERY dig's budget, by level.
const POWER_BUDGET_BONUS := [0, 3, 6, 10]


## Coin cost to take a building from current_level to current_level+1, or -1 at max.
## Level 0 -> 1 is free (0): a star milestone grants it.
static func cost(building: int, current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return -1
	return BUILDINGS[building].costs[current_level]


static func can_afford(coin: int, c: int) -> bool:
	return c >= 0 and coin >= c


## Board rule overrides for a given set of building levels [power, workshop, lab].
static func rules(levels: Array) -> Dictionary:
	var p: int = levels[0]
	var w: int = levels[1]
	var l: int = levels[2]
	var r := {}
	r.budget_bonus = POWER_BUDGET_BONUS[p]
	r.drill = w >= 1
	r.drill_power = 2 if w >= 2 else 1
	r.drill_cost = 1 if w >= 3 else 2
	r.crack_power = 2 if w >= 3 else 1
	r.scanner = l >= 1
	r.reveal_reserve = 3 if l >= 2 else 2
	r.refund_bonus = 1 if l >= 3 else 0
	return r


## Bonus Coin for finishing an objective with energy left: 1 Coin per 2 energy.
static func completion_bonus(energy_left: int) -> int:
	return energy_left / 2
