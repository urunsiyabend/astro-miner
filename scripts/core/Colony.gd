class_name Colony
extends RefCounted

## The colony map of Planet 1 (GDD v3 §4): a habitat dome in the middle and fixed plots around
## it. A building stands on its plot from the moment its star milestone unlocks it (level 0 is
## an empty plot waiting for the free build); a decoration appears on its plot when its
## cosmetic star milestone is reached. Positions are fractions of the map area, so the art can
## be swapped without touching the rules.

## One entry per star milestone, in the order of Economy.STAR_MILESTONES:
## {"building": b} unlocks building b, {"deco": plot id} adds a decoration.
const MILESTONES := [
	{"deco": "pad"},
	{"building": 0},
	{"deco": "greenhouse"},
	{"building": 1},
	{"deco": "antenna"},
	{"building": 2},
]

const DOME := Vector2(0.5, 0.42)

const PLOTS := [
	{"id": "power", "building": 0, "pos": Vector2(0.22, 0.21)},
	{"id": "workshop", "building": 1, "pos": Vector2(0.78, 0.21)},
	{"id": "lab", "building": 2, "pos": Vector2(0.80, 0.58)},
	{"id": "pad", "pos": Vector2(0.20, 0.58)},
	{"id": "greenhouse", "pos": Vector2(0.32, 0.84)},
	{"id": "antenna", "pos": Vector2(0.68, 0.84)},
]


static func plot_index(id: String) -> int:
	for i in PLOTS.size():
		if PLOTS[i].id == id:
			return i
	return -1


## Plot that holds building b.
static func building_plot(b: int) -> int:
	for i in PLOTS.size():
		if PLOTS[i].get("building", -1) == b:
			return i
	return -1


## Milestone index that brings plot i (its building's unlock, or its decoration), or -1.
static func plot_milestone(i: int) -> int:
	var plot: Dictionary = PLOTS[i]
	for m in MILESTONES.size():
		var c: Dictionary = MILESTONES[m]
		if c.get("building", -1) == plot.get("building", -2) or c.get("deco", "") == plot.id:
			return m
	return -1


## Stars needed before plot i is filled.
static func plot_stars(i: int) -> int:
	var m := plot_milestone(i)
	return Economy.STAR_MILESTONES[m] if m >= 0 else 0
