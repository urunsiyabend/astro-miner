class_name Economy
extends RefCounted

## Colony buildings, their costs, and how levels translate into Board rules.

const RES_NAMES := ["Ferrite", "Cryo", "Lumen", "Crystal"]

const BUILDINGS := [
	{
		"id": "power", "name": "Power Station",
		"effects": ["Battery 20", "Battery 26", "Battery 32", "Battery 40"],
		# cost per level 1..3: [ferrite, cryo, lumen, crystal]
		"costs": [[20, 12, 0, 0], [45, 30, 0, 2], [80, 55, 0, 4]],
	},
	{
		"id": "workshop", "name": "Mining Workshop",
		"effects": ["No drill", "Drill: bump rock, -1 layer (2 energy)",
				"Drill removes 2 layers", "Drill costs 1, matches crack 2 layers"],
		"costs": [[15, 0, 15, 0], [0, 40, 40, 2], [70, 0, 70, 4]],
	},
	{
		"id": "lab", "name": "Research Lab",
		"effects": ["No scanner", "Deep Scanner: see what rock hides",
				"Blast charges hit 5x5", "+1 energy per match"],
		"costs": [[0, 12, 18, 0], [35, 35, 0, 3], [0, 60, 80, 5]],
	},
]

const MAX_LEVEL := 3
const FIRST_CLEAR_CRYSTALS := 1


static func cost(building: int, current_level: int) -> Array:
	if current_level >= MAX_LEVEL:
		return []
	return BUILDINGS[building].costs[current_level]


static func can_afford(bank: Array, c: Array) -> bool:
	if c.is_empty():
		return false
	for i in 4:
		if bank[i] < c[i]:
			return false
	return true


## Board rule overrides for a given set of building levels [power, workshop, lab].
static func rules(levels: Array) -> Dictionary:
	var p: int = levels[0]
	var w: int = levels[1]
	var l: int = levels[2]
	var r := {}
	r.capacity = [20, 26, 32, 40][p]
	r.drill = w >= 1
	r.drill_power = 2 if w >= 2 else 1
	r.drill_cost = 1 if w >= 3 else 2
	r.crack_power = 2 if w >= 3 else 1
	r.scanner = l >= 1
	r.blast_radius = 2 if l >= 2 else 1
	r.refund_bonus = 1 if l >= 3 else 0
	return r


## Bonus ore for finishing an objective with energy left: 1 chunk per 2 energy,
## spread across the three ore types (deterministic).
static func completion_bonus(energy_left: int) -> Array:
	var n := energy_left / 2
	var b := [0, 0, 0, 0]
	for i in n:
		b[i % 3] += 1
	return b
