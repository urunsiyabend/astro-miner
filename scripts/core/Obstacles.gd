class_name Obstacles
extends RefCounted

## Board obstacles: everything on a cell besides gems, pickups and rock, and the one table that
## says what hits each kind. The Board never asks "is this a cage?": it asks what a cell allows
## (locked, solid) and reports every hit here through Board._strike, the single way anything on
## the board gets damaged. A new obstacle is a new row in KINDS (plus its art), not new code
## in the Board's matching, gravity or power-up paths.
##
## How a cell can be hit (Hit):
##   ON     a gem on the cell is part of a match
##   NEXT   a match next to the cell (once per match group per obstacle, however many of its
##          cells the group touches)
##   POWER  a power-up, a blast or a booster reaches the cell (once per power-up per obstacle)
## Where an obstacle sits (Layer):
##   PIECE  takes the cells instead of gems (Board.Terrain.BLOCK): solid, nothing falls through,
##          the robot and paths can't enter. May span several cells; it is hit as one object.
##   COVER  sits over the gem in its cell and locks it: the robot can't swap it, it doesn't
##          fall, and it holds up the cells above it. The gem stays when the cover breaks.
##   FLOOR  lies on the cell, under whatever is on it, and blocks nothing (Royal Match's
##          grass): a hit clears it AND goes on to the gem (a match on it takes the gem too).
## Rock (Board.Terrain.ROCK) keeps its own layers and hidden contents but follows the same
## rule: a PIECE hit by NEXT and POWER.

enum Hit { ON, NEXT, POWER }
enum Layer { PIECE, COVER, FLOOR }

## kind -> rule.
##   need    hits it takes to finish
##   size    cells it spans, from its top-left cell (PIECE)
##   stays   a finished PIECE stays on the board (switched on) instead of leaving it
##   goal    the goal type ("type" in a site's goals) it counts toward when finished
const KINDS := {
	# a power generator: matches next to it charge it; full, it switches on (an Activate goal)
	"generator": {"layer": Layer.PIECE, "hit_by": [Hit.NEXT, Hit.POWER], "need": 6,
			"size": Vector2i(2, 2), "stays": true, "goal": "generator"},
	# a steel cage over a gem: match that gem, or hit it with a power-up, to break it
	"cage": {"layer": Layer.COVER, "hit_by": [Hit.ON, Hit.POWER], "need": 1,
			"size": Vector2i(1, 1), "stays": false, "goal": "cage"},
	# a cave web on the floor: a match on top of it, or a power-up, clears a layer (a site may
	# place a thicker one: [cell, "web", 2])
	"web": {"layer": Layer.FLOOR, "hit_by": [Hit.ON, Hit.POWER], "need": 1,
			"size": Vector2i(1, 1), "stays": false, "goal": "web"},
}

var items: Array = []   # {kind, cells: Array (top-left first), left: hits still needed}
var piece := {}         # cell -> item index, while the piece is on the board
var cover := {}         # cell -> item index, while the cover is on the board
var floors := {}        # cell -> item index, while the floor layer is on the board
var finished := {}      # goal type -> obstacles of that goal finished


## Put an obstacle of `kind` with its top-left on cell `at` (a board of width w); `layers`
## overrides how many hits it needs (a thicker web). Returns the cells it takes.
func place(kind: String, at: Vector2i, w: int, layers := 0) -> Array:
	assert(KINDS.has(kind), "unknown obstacle '%s'" % kind)
	var rule: Dictionary = KINDS[kind]
	var cells := []
	for dy in rule.size.y:
		for dx in rule.size.x:
			cells.append((at.y + dy) * w + at.x + dx)
	var id := items.size()
	var need: int = layers if layers > 0 else int(rule.need)
	items.append({"kind": kind, "cells": cells, "left": need, "need": need})
	var layer := _layer(rule.layer)
	for c in cells:
		assert(not layer.has(c), "two obstacles on one layer of cell %d" % c)
		layer[c] = id
	return cells


func _layer(l: int) -> Dictionary:
	match l:
		Layer.PIECE: return piece
		Layer.COVER: return cover
	return floors


## A cover locks the gem in cell c.
func locked(c: int) -> bool:
	return cover.has(c)


## What a hit `h` on cell c would land on: the cover over the gem first, then the piece, or -1.
## A finished piece that stays on the board takes no more hits.
func target(c: int, h: int) -> int:
	for layer in [cover, piece]:
		if layer.has(c):
			var id: int = layer[c]
			var it: Dictionary = items[id]
			if it.left > 0 and KINDS[it.kind].hit_by.has(h):
				return id
	return -1


## Hit cell c in way h. `seen` is shared by one source of hits (a match group, a power-up), so a
## multi-cell obstacle counts that source once. Returns what happened, for the view
## ({id, kind, cell, left, need, done, freed}), or {} when nothing here takes this hit.
func hit(c: int, h: int, seen: Dictionary) -> Dictionary:
	return _hit_item(target(c, h), c, seen)


## The floor layer of cell c takes hit h (it never stops the hit: the Board carries on to
## what lies on the cell). Same result as hit().
func hit_floor(c: int, h: int, seen: Dictionary) -> Dictionary:
	var id: int = floors.get(c, -1)
	if id < 0 or int(items[id].left) <= 0 or not KINDS[items[id].kind].hit_by.has(h):
		return {}
	return _hit_item(id, c, seen)


## A floor layer on cell c that hit h would clear, or -1.
func floor_target(c: int, h: int) -> int:
	var id: int = floors.get(c, -1)
	if id >= 0 and int(items[id].left) > 0 and KINDS[items[id].kind].hit_by.has(h):
		return id
	return -1


func _hit_item(id: int, c: int, seen: Dictionary) -> Dictionary:
	if id < 0 or seen.has(id):
		return {}
	seen[id] = true
	var it: Dictionary = items[id]
	var rule: Dictionary = KINDS[it.kind]
	it.left -= 1
	var out := {"id": id, "kind": it.kind, "cell": c, "cells": it.cells.duplicate(),
			"left": it.left, "need": it.need, "done": it.left == 0, "freed": []}
	if it.left == 0:
		finished[rule.goal] = int(finished.get(rule.goal, 0)) + 1
		if not rule.stays:
			var layer := _layer(rule.layer)
			for cc in it.cells:
				layer.erase(cc)
			if rule.layer == Layer.PIECE:
				out.freed = it.cells.duplicate()  # the Board opens these cells
	return out


func count_finished(goal: String) -> int:
	return int(finished.get(goal, 0))


func clone() -> Obstacles:
	var o := Obstacles.new()
	o.items = items.duplicate(true)
	o.piece = piece.duplicate()
	o.cover = cover.duplicate()
	o.floors = floors.duplicate()
	o.finished = finished.duplicate()
	return o


## What the view draws: every obstacle with its cells and hits left.
func snapshot() -> Array:
	return items.duplicate(true)
