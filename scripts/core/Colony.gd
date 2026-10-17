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
	{"building": 3},
	{"building": 1},
	{"building": 2},
]

## Layout (after the col3 mockup): a 2:1 isometric grid of build sites joined by paths, painted
## as one ground layer (assets/colony/ground.png). The habitat dome stands on the big hub site
## at cell (0, 0); every plot is a site at its "cell" (i, j), one grid step along each axis:
## the four buildings on the hub's neighbours, the pad above them. (The greenhouse that stood
## on the Teleporter's plot is out of the colony for now: GDD v4 §1.)
const HUB := Vector2(0, 0)

const PLOTS := [
	{"id": "power", "building": 0, "cell": Vector2(-1, 0)},
	{"id": "workshop", "building": 1, "cell": Vector2(0, -1)},
	{"id": "lab", "building": 2, "cell": Vector2(1, 0)},
	{"id": "pad", "cell": Vector2(-1, -1)},
	{"id": "teleporter", "building": 3, "cell": Vector2(0, 1)},
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
