class_name Board
extends RefCounted

## Pure rules for one dig. No rendering, no scene tree access.
## Every random decision goes through `rng`, so a seed + move list replays exactly.

const W := 7
const H := 8

enum Terrain { GROUND, ROCK, BEDROCK }
enum Token { NONE, ORE, CRYSTAL, CELL, CHARGE }
enum Buried { ORE, CELL, CRYSTAL, EMPTY }

const ORE_TYPES := 3
const RES_CRYSTAL := 3  # index into haul[] after the three ore types

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# --- state -----------------------------------------------------------------
var terrain := PackedInt32Array()
var hp := PackedInt32Array()       # rock layers left
var buried := PackedInt32Array()   # what a rock hides
var reserve := PackedInt32Array()  # ore layers left under a ground cell
var dug := PackedInt32Array()      # layers dug out of a ground cell (drawn as a pit)
var token := PackedInt32Array()
var ore := PackedInt32Array()      # ore type when token == ORE
var robot := 0
var energy := 0
var haul := PackedInt32Array([0, 0, 0, 0])
var extracted := PackedInt32Array([0, 0, 0])  # chunks per ore type (objective counting)
var stats := {
	"moves": 0, "drills": 0, "groups": 0, "cascade_groups": 0, "chunks": 0,
	"rocks_broken": 0, "crystals": 0, "cells": 0, "charges_made": 0, "blasts": 0,
	"energy_refunded": 0, "rejected": 0, "pulses": 0,
}
var goals: Array = []  # [{type:"ore", ore:int, n:int} | {type:"rock", n} | {type:"crystal", n}]
var over := false
var complete := false
var rng := RandomNumberGenerator.new()

# --- rules (set from colony upgrades) ---------------------------------------
var cfg := {
	"capacity": 20,
	"ore_types": 3,
	"refund_base": 2,      # energy for a group of 3
	"refund_extra": 1,     # per chunk beyond 3
	"refund_bonus": 0,     # Lab Lv3
	"drill": false,
	"drill_cost": 2,
	"drill_power": 1,
	"crack_power": 1,
	"blast_radius": 1,
	"cell_energy": 6,
	"yield_bonus": 0,
	"reveal_reserve": 2,
	"blast_rock": 2,
	"pulse_cost": 3,
}

var record := true  # build per-step snapshots for the view; sims switch this off


static func idx(c: Vector2i) -> int:
	return c.y * W + c.x


static func pos(i: int) -> Vector2i:
	return Vector2i(i % W, i / W)


static func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


## Build a board from a site template (Array of H strings, W space-separated codes).
##   .  ground (reserve 2)    :  shallow ground (reserve 1)    o  deep ground (reserve 4)
##   _  exhausted empty ground  @  robot start   #  bedrock
##   1/2/3 rock layers hiding ore; suffix c = crystal, e = energy cell, x = nothing
## Set up a dig for a site from Sites.LIST. A site may pin its own seed, hand-place every
## token ("ore" rows) and start with less energy than the battery holds ("energy").
func setup_site(site: Dictionary, seed_value: int, rules: Dictionary = {}) -> void:
	setup(site.rows, int(site.get("seed", seed_value)), rules, site.goals, site.get("ore", []))
	if site.has("energy"):
		energy = mini(int(site.energy), cfg.capacity)


## layout: optional rows of hand-placed tokens (F C L ore, c crystal, e energy cell,
## b blast charge, - nothing) that replace the seeded fill.
func setup(rows: Array, seed_value: int, rules: Dictionary = {}, site_goals: Array = [], layout: Array = []) -> void:
	for k in rules:
		cfg[k] = rules[k]
	goals = site_goals.duplicate(true)
	var n := W * H
	terrain.resize(n); hp.resize(n); buried.resize(n); reserve.resize(n)
	token.resize(n); ore.resize(n); dug.resize(n)
	for i in n:
		terrain[i] = Terrain.GROUND; hp[i] = 0; buried[i] = Buried.ORE
		reserve[i] = 0; token[i] = Token.NONE; ore[i] = 0; dug[i] = 0
	assert(rows.size() == H, "site needs %d rows" % H)
	for y in H:
		var codes: PackedStringArray = String(rows[y]).split(" ", false)
		assert(codes.size() == W, "row %d needs %d cells" % [y, W])
		for x in W:
			_parse_cell(y * W + x, codes[x])
	energy = cfg.capacity
	if not layout.is_empty():
		_place_layout(layout)
		rng.seed = seed_value ^ 0x5EED
		return
	# Seeded fill; retry until the opening offers a match within 2 steps.
	var s := seed_value
	for attempt in 64:
		rng.seed = s
		_fill_ore()
		if first_step_to_match(2) != -1:
			break
		s = s * 31 + 7
	rng.seed = s ^ 0x5EED  # separate stream for surfacing ore


func _parse_cell(i: int, code: String) -> void:
	match code[0]:
		".":
			reserve[i] = 2; token[i] = Token.ORE
		":":
			reserve[i] = 1; token[i] = Token.ORE
		"o":
			reserve[i] = 4; token[i] = Token.ORE
		"_":
			reserve[i] = 0
		"@":
			# "@_": robot on ground with no vein below (tutorial sites)
			reserve[i] = 0 if code == "@_" else 2
			robot = i
		"#":
			terrain[i] = Terrain.BEDROCK
		"1", "2", "3":
			terrain[i] = Terrain.ROCK
			hp[i] = int(code[0])
			buried[i] = Buried.ORE
			if code.length() > 1:
				match code[1]:
					"c": buried[i] = Buried.CRYSTAL
					"e": buried[i] = Buried.CELL
					"x": buried[i] = Buried.EMPTY
		_:
			push_error("unknown cell code '%s'" % code)


func _place_layout(layout: Array) -> void:
	assert(layout.size() == H, "layout needs %d rows" % H)
	for y in H:
		var codes: PackedStringArray = String(layout[y]).split(" ", false)
		assert(codes.size() == W, "layout row %d needs %d cells" % [y, W])
		for x in W:
			var i := y * W + x
			if terrain[i] != Terrain.GROUND:
				continue
			token[i] = Token.NONE
			match codes[x]:
				"F": token[i] = Token.ORE; ore[i] = 0
				"C": token[i] = Token.ORE; ore[i] = 1
				"L": token[i] = Token.ORE; ore[i] = 2
				"c": token[i] = Token.CRYSTAL
				"e": token[i] = Token.CELL
				"b": token[i] = Token.CHARGE
				"-", "@": pass
				_: push_error("unknown layout code '%s'" % codes[x])
	token[robot] = Token.NONE


func _fill_ore() -> void:
	for i in W * H:
		if terrain[i] == Terrain.GROUND and token[i] == Token.ORE:
			ore[i] = _pick_no_line(i)


## Ore type that does not complete a line of 3 with the two cells left or above
## (the fill runs in row-major order, so only those neighbours are already set).
func _pick_no_line(i: int) -> int:
	var c := pos(i)
	var banned := []
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
		var a := c + d
		var b := c + d * 2
		if _is_ore(a) and _is_ore(b) and ore[idx(a)] == ore[idx(b)]:
			banned.append(ore[idx(a)])
	var choices := []
	for t in cfg.ore_types:
		if not banned.has(t):
			choices.append(t)
	return choices[rng.randi_range(0, choices.size() - 1)]


## Type for ore surfacing in cell c. A type that would immediately re-form a line is
## re-rolled once, so vein chains still happen but do not dominate.
func _surface_type(c: int) -> int:
	var t := rng.randi_range(0, cfg.ore_types - 1)
	if _would_line(c, t):
		t = rng.randi_range(0, cfg.ore_types - 1)
	return t


func _would_line(c: int, t: int) -> bool:
	var p := pos(c)
	for axis: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var n := 1
		var q := p + axis
		while _is_ore(q) and ore[idx(q)] == t:
			n += 1
			q += axis
		q = p - axis
		while _is_ore(q) and ore[idx(q)] == t:
			n += 1
			q -= axis
		if n >= 3:
			return true
	return false


func _is_ore(c: Vector2i) -> bool:
	return inside(c) and token[idx(c)] == Token.ORE and terrain[idx(c)] == Terrain.GROUND


# --- moves -----------------------------------------------------------------

## Attempt a robot move. Returns {ok, reason, steps:[...]}; steps carry snapshots when record.
func try_move(dir: Vector2i) -> Dictionary:
	var out := {"ok": false, "reason": "", "steps": []}
	if over:
		out.reason = "over"
		return out
	var from := pos(robot)
	var to := from + dir
	if not inside(to) or terrain[idx(to)] == Terrain.BEDROCK:
		out.reason = "wall"
		stats.rejected += 1
		return out
	var ti := idx(to)
	if terrain[ti] == Terrain.ROCK:
		if not cfg.drill:
			out.reason = "rock"
			stats.rejected += 1
			return out
		if energy < cfg.drill_cost:
			out.reason = "energy"
			stats.rejected += 1
			return out
		energy -= cfg.drill_cost
		stats.drills += 1
		var step := {"type": "drill", "cell": ti, "revealed": []}
		_damage_rock(ti, cfg.drill_power, step.revealed)
		_push(out.steps, step)
		_resolve(out.steps, -1)
		_finish_turn()
		out.ok = true
		return out

	energy -= 1
	stats.moves += 1
	var fi := robot
	var step := {"type": "move", "from": fi, "to": ti, "swap": false, "pickup": Token.NONE}
	var pivot := -1
	match token[ti]:
		Token.ORE:
			token[fi] = Token.ORE
			ore[fi] = ore[ti]
			token[ti] = Token.NONE
			step.swap = true
			pivot = fi
		Token.CRYSTAL:
			token[ti] = Token.NONE
			haul[RES_CRYSTAL] += 1
			stats.crystals += 1
			step.pickup = Token.CRYSTAL
		Token.CELL:
			token[ti] = Token.NONE
			energy = mini(cfg.capacity, energy + cfg.cell_energy)
			stats.cells += 1
			step.pickup = Token.CELL
		Token.CHARGE:
			token[ti] = Token.NONE
			step.pickup = Token.CHARGE
	robot = ti
	_push(out.steps, step)
	if step.pickup == Token.CHARGE:
		_blast(ti, out.steps)
	_resolve(out.steps, pivot)
	_finish_turn()
	out.ok = true
	return out


func _finish_turn() -> void:
	if goals_met():
		complete = true
		over = true
	elif energy <= 0:
		energy = 0
		over = true


## Seismic pulse: only when no match is reachable within 5 steps. Reshuffles the ore
## types already on the board (same counts) until a match is reachable within 2 steps.
func can_pulse() -> bool:
	return not over and energy >= cfg.pulse_cost and path_to_match(5).is_empty()


func pulse() -> Dictionary:
	var out := {"ok": false, "reason": "", "steps": []}
	if not can_pulse():
		out.reason = "pulse"
		return out
	energy -= cfg.pulse_cost
	stats.pulses += 1
	var cells := []
	var kinds := []
	for i in W * H:
		if terrain[i] == Terrain.GROUND and token[i] == Token.ORE:
			cells.append(i)
			kinds.append(ore[i])
	for attempt in 40:
		for k in range(kinds.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t = kinds[k]
			kinds[k] = kinds[j]
			kinds[j] = t
		for n in cells.size():
			ore[cells[n]] = kinds[n]
		if not has_line() and not path_to_match(2).is_empty():
			break
	_push(out.steps, {"type": "pulse", "cells": cells})
	_resolve(out.steps, -1)
	_finish_turn()
	out.ok = true
	return out


## End the dig voluntarily (haul is kept by the caller).
func recall() -> void:
	over = true


func _push(steps: Array, step: Dictionary) -> void:
	if record:
		step["snap"] = snapshot()
		steps.append(step)


# --- resolution ------------------------------------------------------------

func _resolve(steps: Array, pivot: int) -> void:
	var pass_no := 0
	while pass_no < 30:
		var groups := find_groups()
		if groups.is_empty():
			return
		var step := {"type": "match", "groups": [], "cracked": [], "revealed": [],
				"surfaced": [], "charges": [], "energy": 0, "cascade": pass_no > 0}
		var to_dig := []
		var cracked_set := {}
		for g in groups:
			var cells: Array = g.cells
			var kind: int = g.ore
			var n := cells.size()
			stats.groups += 1
			if pass_no > 0:
				stats.cascade_groups += 1
			stats.chunks += n
			extracted[kind] += n
			haul[kind] += n + cfg.yield_bonus
			var gain: int = cfg.refund_base + (n - 3) * cfg.refund_extra + cfg.refund_bonus
			step.energy += gain
			step.groups.append({"cells": cells, "ore": kind})
			var charge_at := -1
			if n >= 4:
				charge_at = pivot if cells.has(pivot) else _central(cells)
				stats.charges_made += 1
			for c in cells:
				if c == charge_at:
					token[c] = Token.CHARGE
					step.charges.append(c)
				else:
					to_dig.append(c)
			# crack each adjacent rock once per group
			var touched := {}
			for c in cells:
				for d in DIRS:
					var nb: Vector2i = pos(c) + d
					if inside(nb) and terrain[idx(nb)] == Terrain.ROCK:
						touched[idx(nb)] = true
			for r in touched:
				cracked_set[r] = true
				_damage_rock(r, cfg.crack_power, step.revealed)
		energy = mini(cfg.capacity, energy + step.energy)
		stats.energy_refunded += step.energy
		for c in to_dig:
			if _dig(c):
				step.surfaced.append(c)
		step.cracked = cracked_set.keys()
		_push(steps, step)
		pivot = -1
		pass_no += 1


## Remove the ore at c; surface a new chunk if the vein has reserve. Returns true if surfaced.
func _dig(c: int) -> bool:
	if reserve[c] > 0:
		reserve[c] -= 1
		dug[c] += 1
		token[c] = Token.NONE
		ore[c] = _surface_type(c)
		token[c] = Token.ORE
		return true
	token[c] = Token.NONE
	return false


func _damage_rock(r: int, amount: int, revealed: Array) -> void:
	if terrain[r] != Terrain.ROCK:
		return
	hp[r] = maxi(0, hp[r] - amount)
	if hp[r] > 0:
		return
	terrain[r] = Terrain.GROUND
	stats.rocks_broken += 1
	revealed.append(r)
	match buried[r]:
		Buried.ORE:
			reserve[r] = cfg.reveal_reserve
			token[r] = Token.ORE
			ore[r] = rng.randi_range(0, cfg.ore_types - 1)
		Buried.CRYSTAL:
			reserve[r] = 1
			token[r] = Token.CRYSTAL
		Buried.CELL:
			reserve[r] = 1
			token[r] = Token.CELL
		Buried.EMPTY:
			reserve[r] = 0
			token[r] = Token.NONE


func _blast(center: int, steps: Array) -> void:
	var queue := [center]
	var done := {}
	while not queue.is_empty():
		var c0: int = queue.pop_front()
		if done.has(c0):
			continue
		done[c0] = true
		stats.blasts += 1
		var step := {"type": "blast", "center": c0, "radius": cfg.blast_radius,
				"cells": [], "revealed": [], "surfaced": []}
		var rad: int = cfg.blast_radius
		var cp := pos(c0)
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var p := cp + Vector2i(dx, dy)
				if not inside(p):
					continue
				var i := idx(p)
				if i == robot:
					continue
				if terrain[i] == Terrain.ROCK:
					_damage_rock(i, cfg.blast_rock, step.revealed)
					step.cells.append(i)
					continue
				if terrain[i] != Terrain.GROUND:
					continue
				match token[i]:
					Token.ORE:
						extracted[ore[i]] += 1
						haul[ore[i]] += 1 + cfg.yield_bonus
						stats.chunks += 1
						step.cells.append(i)
						if _dig(i):
							step.surfaced.append(i)
					Token.CRYSTAL:
						token[i] = Token.NONE
						haul[RES_CRYSTAL] += 1
						stats.crystals += 1
						step.cells.append(i)
					Token.CELL:
						token[i] = Token.NONE
						energy = mini(cfg.capacity, energy + cfg.cell_energy)
						stats.cells += 1
						step.cells.append(i)
					Token.CHARGE:
						token[i] = Token.NONE
						step.cells.append(i)
						queue.append(i)
		_push(steps, step)


func _central(cells: Array) -> int:
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(pos(c))
	var mid := sum / cells.size()
	var best: int = cells[0]
	var bd := INF
	for c in cells:
		var d := Vector2(pos(c)).distance_squared_to(mid)
		if d < bd:
			bd = d
			best = c
	return best


## All match groups: straight lines of >=3 same ore, unioned when they share a cell.
func find_groups() -> Array:
	var in_line := {}  # cell -> true
	for y in H:
		var x := 0
		while x < W:
			var run := _run_len(Vector2i(x, y), Vector2i(1, 0))
			if run >= 3:
				for k in run:
					in_line[idx(Vector2i(x + k, y))] = true
			x += maxi(1, run)
	for x in W:
		var y := 0
		while y < H:
			var run := _run_len(Vector2i(x, y), Vector2i(0, 1))
			if run >= 3:
				for k in run:
					in_line[idx(Vector2i(x, y + k))] = true
			y += maxi(1, run)
	var groups := []
	var seen := {}
	var keys := in_line.keys()
	keys.sort()
	for start in keys:
		if seen.has(start):
			continue
		var kind := ore[start]
		var cells := []
		var stack := [start]
		seen[start] = true
		while not stack.is_empty():
			var c: int = stack.pop_back()
			cells.append(c)
			for d in DIRS:
				var nb: Vector2i = pos(c) + d
				if inside(nb):
					var ni := idx(nb)
					if in_line.has(ni) and not seen.has(ni) and ore[ni] == kind:
						seen[ni] = true
						stack.append(ni)
		cells.sort()
		groups.append({"cells": cells, "ore": kind})
	return groups


func _run_len(start: Vector2i, d: Vector2i) -> int:
	if not _is_ore(start):
		return 1
	var kind := ore[idx(start)]
	var n := 1
	var c := start + d
	while _is_ore(c) and ore[idx(c)] == kind:
		n += 1
		c += d
	return n


func has_line() -> bool:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if _run_len(c, Vector2i(1, 0)) >= 3 or _run_len(c, Vector2i(0, 1)) >= 3:
				return true
	return false


# --- search (hint, generator check, bots) -----------------------------------

## Breadth-first over robot steps (no resolution), returns the index into DIRS of the
## first step of the shortest path to a position that forms a line; -1 if none in depth.
func first_step_to_match(depth: int) -> int:
	var r := path_to_match(depth)
	return -1 if r.is_empty() else r[0]


func path_to_match(depth: int) -> Array:
	var start := {"robot": robot, "token": token, "ore": ore, "path": []}
	var frontier := [start]
	var visited := {}
	for level in depth:
		var next := []
		for st in frontier:
			for di in 4:
				var to: Vector2i = pos(st.robot) + DIRS[di]
				if not inside(to):
					continue
				var ti := idx(to)
				if terrain[ti] != Terrain.GROUND:
					continue
				var tk: PackedInt32Array = st.token.duplicate()
				var orr: PackedInt32Array = st.ore.duplicate()
				var fi: int = st.robot
				if tk[ti] == Token.ORE:
					tk[fi] = Token.ORE
					orr[fi] = orr[ti]
					tk[ti] = Token.NONE
				elif tk[ti] != Token.NONE:
					tk[ti] = Token.NONE  # pickups are consumed; still walkable
				var path: Array = st.path.duplicate()
				path.append(di)
				if _line_through(tk, orr, fi):
					return path
				var key := str(ti) + "|" + str(hash(tk)) + str(hash(orr))
				if visited.has(key):
					continue
				visited[key] = true
				next.append({"robot": ti, "token": tk, "ore": orr, "path": path})
		frontier = next
	return []


## Shortest robot route to a crystal, energy cell or blast charge on open ground; [] if none
## within depth. Walking only swaps ore around, so ore never blocks the route.
func path_to_pickup(depth: int) -> Array:
	var prev := {robot: -1}
	var frontier := [robot]
	for level in depth:
		var next := []
		for c in frontier:
			for di in 4:
				var to: Vector2i = pos(c) + DIRS[di]
				if not inside(to):
					continue
				var ti := idx(to)
				if terrain[ti] != Terrain.GROUND or prev.has(ti):
					continue
				prev[ti] = c
				if token[ti] == Token.CRYSTAL or token[ti] == Token.CELL or token[ti] == Token.CHARGE:
					var path := []
					var at := ti
					while prev[at] != -1:
						var d: Vector2i = pos(at) - pos(prev[at])
						path.push_front(DIRS.find(d))
						at = prev[at]
					return path
				next.append(ti)
		frontier = next
	return []


## Does the ore at cell c form a line of 3 (only c can change per step)?
func _line_through(tk: PackedInt32Array, orr: PackedInt32Array, c: int) -> bool:
	if tk[c] != Token.ORE:
		return false
	var kind := orr[c]
	var p := pos(c)
	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		var n := 1
		var q: Vector2i = p + axis
		while inside(q) and terrain[idx(q)] == Terrain.GROUND and tk[idx(q)] == Token.ORE and orr[idx(q)] == kind:
			n += 1
			q += axis
		q = p - axis
		while inside(q) and terrain[idx(q)] == Terrain.GROUND and tk[idx(q)] == Token.ORE and orr[idx(q)] == kind:
			n += 1
			q -= axis
		if n >= 3:
			return true
	return false


func clone() -> Board:
	var b := Board.new()
	b.terrain = terrain.duplicate(); b.hp = hp.duplicate(); b.buried = buried.duplicate()
	b.reserve = reserve.duplicate(); b.dug = dug.duplicate(); b.token = token.duplicate(); b.ore = ore.duplicate()
	b.robot = robot; b.energy = energy; b.haul = haul.duplicate()
	b.extracted = extracted.duplicate(); b.stats = stats.duplicate()
	b.goals = goals.duplicate(true); b.over = over; b.complete = complete
	b.cfg = cfg.duplicate(); b.record = false
	b.rng.seed = rng.seed
	b.rng.state = rng.state
	return b


# --- objectives ------------------------------------------------------------

func goal_progress(g: Dictionary) -> int:
	match g.type:
		"ore": return extracted[g.ore]
		"rock": return stats.rocks_broken
		"chunks": return stats.chunks
		"crystal": return stats.crystals
		"blast": return stats.blasts
	return 0


func goals_met() -> bool:
	if goals.is_empty():
		return false
	for g in goals:
		if goal_progress(g) < g.n:
			return false
	return true


func snapshot() -> Dictionary:
	return {
		"terrain": terrain.duplicate(), "hp": hp.duplicate(), "buried": buried.duplicate(),
		"reserve": reserve.duplicate(), "depth": dug.duplicate(), "token": token.duplicate(), "ore": ore.duplicate(),
		"robot": robot, "energy": energy, "haul": haul.duplicate(),
		"extracted": extracted.duplicate(), "rocks": stats.rocks_broken, "chunks": stats.chunks,
		"crystals": stats.crystals, "blasts": stats.blasts,
	}
