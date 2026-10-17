class_name Board
extends RefCounted

## Pure rules for one dig. No rendering, no scene tree access.
## Every random decision goes through `rng`, so a seed + move list replays exactly.

const W := 7
const H := 8

enum Terrain { GROUND, ROCK, BEDROCK }
enum Token { NONE, ORE, CRYSTAL, CELL, CHARGE }
enum Buried { ORE, CELL, CRYSTAL, EMPTY, TREASURE }

## What a line of 4 leaves (a site's "special", prototypes). BLAST is the original charge: step
## on it and it blows the 3x3 around it. The others go off when they are MOVED (the robot drags
## one, or a classic swap moves it), at the cell they land on, aimed by the way they moved:
##   DRILL  bores on in the direction it moved, taking every gem, until rock (2 layers off)
##   PRISM  four diagonal rays to the edges, through rock (1 layer off each)
##   GEODE  turns the 8 gems around it into its colour (and cracks rock next to it)
##   QUAKE  hits the ring two cells out, leaving the middle standing
enum Special { BLAST, DRILL, PRISM, GEODE, QUAKE }
const SPECIAL_IDS := {"blast": Special.BLAST, "drill": Special.DRILL, "prism": Special.PRISM,
		"geode": Special.GEODE, "quake": Special.QUAKE}
const ORE_TYPES := 4   # most ore colours a dig can use (a dig picks 3 or 4: cfg.ore_types)
const RES_CRYSTAL := 4  # index into haul[] after the ore types

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

# --- state -----------------------------------------------------------------
var terrain := PackedInt32Array()
var hp := PackedInt32Array()       # rock layers left
var hp0 := PackedInt32Array()      # rock layers at the start (how tough the rock looks)
var buried := PackedInt32Array()   # what a rock hides
var reserve := PackedInt32Array()  # ore layers left under a ground cell
var dug := PackedInt32Array()      # layers dug out of a ground cell (drawn as a pit)
var token := PackedInt32Array()
var ore := PackedInt32Array()      # ore type when token == ORE (a special keeps its gem's)
var spec := PackedInt32Array()     # which special a CHARGE token is (Special)
var robot := -1  # -1: no robot (the classic swap prototype)
var energy := 0
var haul := PackedInt32Array([0, 0, 0, 0, 0])
var extracted := PackedInt32Array([0, 0, 0, 0])  # chunks per ore type (objective counting)
var treasure_coin := 0   # Coin from chests opened this dig (paid even if the dig fails)
var stats := {
	"moves": 0, "drills": 0, "groups": 0, "cascade_groups": 0, "chunks": 0,
	"rocks_broken": 0, "crystals": 0, "cells": 0, "charges_made": 0, "blasts": 0, "treasures": 0,
	"energy_refunded": 0, "rejected": 0, "pulses": 0, "continues": 0, "boosters": 0,
}
var goals: Array = []  # [{type:"ore", ore:int, n:int} | {type:"rock", n} | {type:"crystal", n}]
var over := false
var complete := false
var rng := RandomNumberGenerator.new()

# --- rules (set from colony upgrades) ---------------------------------------
var cfg := {
	"capacity": 20,
	"ore_types": 3,
	# Energy is the dig's move budget (casual match-3 "moves"): every step costs 1 and a
	# match gives nothing back, so a dig ends when the budget runs out. Only energy cells
	# add energy.
	"refund_base": 0,      # energy for a group of 3
	"refund_extra": 0,     # per chunk beyond 3
	"drill": false,
	"drill_cost": 2,
	"drill_power": 1,
	"crack_power": 1,
	"blast_radius": 1,
	"cell_energy": 6,
	"treasure_coin": 5,    # Coin in one treasure chest
	"yield_bonus": 0,
	"reveal_reserve": 2,
	"blast_rock": 2,
	"pulse_cost": 3,
	# prototypes (a site's "mode"): "fall" keeps the robot but gems drop from above instead of
	# surfacing in place; "classic" also drops the robot: swap two neighbouring gems
	"gravity": false,
	"classic": false,
	"special": 0,  # Special left by a line of 4
	"portals": [],         # [[source cell, destination cell]]: what falls out of one drops into the other
	"spawn_top": false,    # new gems only enter runs that reach the top of the board
	"collect_bottom": false,  # crystals and cells are collected at the bottom of their run
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
## token ("ore" rows) and set its move budget ("energy"; the battery grows to hold it).
func setup_site(site: Dictionary, seed_value: int, rules: Dictionary = {}) -> void:
	var r := rules.duplicate()
	r.ore_types = clampi(int(site.get("colours", 3)), 3, ORE_TYPES)  # 4 colours: a harder dig
	var mode: String = site.get("mode", "robot")
	r.gravity = mode != "robot"
	r.classic = mode == "classic"
	r.special = SPECIAL_IDS.get(String(site.get("special", "blast")), Special.BLAST)
	var portals := []
	for pp in site.get("portals", []):
		portals.append([idx(pp[0]), idx(pp[1])])
	r.portals = portals
	r.spawn_top = site.get("spawn_top", false)
	r.collect_bottom = site.get("collect", false)
	setup(site.rows, int(site.get("seed", seed_value)), r, site.goals, site.get("ore", []))
	# Dig budget = the site's own budget (or a 20 base). A dig starts with a full budget unless
	# it pins a lower "start".
	cfg.capacity = int(site.get("energy", 20))
	energy = cfg.capacity
	if site.has("start"):
		energy = clampi(int(site.start), 0, cfg.capacity)


## Out of energy but not done: carry on with `n` more energy (the "+5 energy?" offer).
func continue_with(n: int) -> bool:
	if not over or complete or n <= 0:
		return false
	energy += n
	cfg.capacity = maxi(cfg.capacity, energy)
	over = false
	stats.continues += 1
	return true


## layout: optional rows of hand-placed tokens (F C L ore, c crystal, e energy cell,
## b blast charge, - nothing) that replace the seeded fill.
func setup(rows: Array, seed_value: int, rules: Dictionary = {}, site_goals: Array = [], layout: Array = []) -> void:
	for k in rules:
		cfg[k] = rules[k]
	goals = site_goals.duplicate(true)
	robot = -1
	var n := W * H
	terrain.resize(n); hp.resize(n); hp0.resize(n); buried.resize(n); reserve.resize(n)
	spec.resize(n)
	spec.fill(0)
	token.resize(n); ore.resize(n); dug.resize(n)
	for i in n:
		terrain[i] = Terrain.GROUND; hp[i] = 0; hp0[i] = 0; buried[i] = Buried.ORE
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
	if cfg.gravity:
		for i in n:  # every open cell holds a gem when gems fall (no empty floor, no veins)
			if terrain[i] == Terrain.GROUND and i != robot and token[i] == Token.NONE:
				token[i] = Token.ORE
	# Seeded fill; retry until the opening offers a match within 2 steps (classic: a swap).
	var s := seed_value
	for attempt in 64:
		rng.seed = s
		_fill_ore()
		if (cfg.classic and not find_swap().is_empty()) or (not cfg.classic and first_step_to_match(2) != -1):
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
			hp0[i] = hp[i]
			buried[i] = Buried.ORE
			if code.length() > 1:
				match code[1]:
					"c": buried[i] = Buried.CRYSTAL
					"t": buried[i] = Buried.TREASURE
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
	var ti := step_to(robot, dir)
	if ti < 0:
		out.reason = "wall"
		stats.rejected += 1
		return out
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
	var dd := pos(ti) - pos(fi)
	if absi(dd.x) + absi(dd.y) != 1:
		step.portal = true  # walked through a portal: the view pops it out of the other end
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
			# a cell always gives its full moves (a move booster), even on a full budget
			energy += cfg.cell_energy
			stats.cells += 1
			step.pickup = Token.CELL
		Token.CHARGE:
			if spec[ti] == Special.BLAST:
				token[ti] = Token.NONE
				step.pickup = Token.CHARGE
			else:
				# a moved special: the robot drags it back into its own old cell, where it goes off
				token[fi] = Token.CHARGE
				spec[fi] = spec[ti]
				ore[fi] = ore[ti]
				token[ti] = Token.NONE
				step.swap = true
				step.special = fi
	robot = ti
	_push(out.steps, step)
	if step.pickup == Token.CHARGE:
		_blast(ti, out.steps)
	elif step.has("special"):
		_special(fi, -dir, out.steps)
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


# --- boosters (GDD v4 §1): consumable help, 0 moves each ---------------------------

## Can booster k (Economy.Booster) be used on cell c (laser: on direction index c)?
func booster_ok(k: int, c: int) -> bool:
	if over:
		return false
	match k:
		Economy.Booster.BOMB:
			return c >= 0 and c < W * H and terrain[c] != Terrain.BEDROCK
		Economy.Booster.WARP:
			return c >= 0 and c < W * H and c != robot and terrain[c] == Terrain.GROUND
		Economy.Booster.LASER:
			return c >= 0 and c < 4 and not _laser_cells(c).is_empty()
		Economy.Booster.MAGNET:
			return c >= 0 and c < W * H and terrain[c] == Terrain.GROUND and token[c] == Token.ORE
	return false


## Use booster k on cell c (the Laser takes a DIRS index). Returns steps like try_move.
func use_booster(k: int, c: int) -> Dictionary:
	var out := {"ok": false, "reason": "", "steps": []}
	if not booster_ok(k, c):
		out.reason = "target"
		return out
	stats.boosters += 1
	var pivot := -1
	match k:
		Economy.Booster.BOMB:
			_push(out.steps, {"type": "bomb", "center": c})
			_blast(c, out.steps)
		Economy.Booster.WARP:
			pivot = _warp(c, out.steps)
		Economy.Booster.LASER:
			_laser(c, out.steps)
		Economy.Booster.MAGNET:
			_magnet(ore[c], c, out.steps)
	_resolve(out.steps, pivot)
	_finish_turn()
	out.ok = true
	return out


## The robot jumps to cell c and swaps with what it holds (a long-range swap); a pickup there
## is collected, a charge goes off. Returns the cell the swapped ore landed on (the match pivot).
func _warp(c: int, steps: Array) -> int:
	var from := robot
	var step := {"type": "warp", "from": from, "to": c, "pickup": Token.NONE}
	var pivot := -1
	match token[c]:
		Token.ORE:
			token[from] = Token.ORE
			ore[from] = ore[c]
			token[c] = Token.NONE
			pivot = from
		Token.CRYSTAL:
			token[c] = Token.NONE
			haul[RES_CRYSTAL] += 1
			stats.crystals += 1
			step.pickup = Token.CRYSTAL
		Token.CELL:
			token[c] = Token.NONE
			energy += cfg.cell_energy
			stats.cells += 1
			step.pickup = Token.CELL
		Token.CHARGE:
			token[c] = Token.NONE
			step.pickup = Token.CHARGE
	robot = c
	_push(steps, step)
	if step.pickup == Token.CHARGE:
		_blast(c, steps)
	return pivot


## Cells a laser fired from the robot along DIRS[d] passes, up to the board edge or bedrock.
func _laser_cells(d: int) -> Array:
	var out := []
	var p: Vector2i = pos(robot) + DIRS[d]
	while inside(p) and terrain[idx(p)] != Terrain.BEDROCK:
		out.append(idx(p))
		p += DIRS[d]
	return out


## A beam from the robot to the edge: every ore on it is extracted, every rock loses a layer,
## pickups are collected.
func _laser(d: int, steps: Array) -> void:
	var cells := _laser_cells(d)
	var step := {"type": "laser", "dir": d, "from": robot, "cells": cells, "hit": [],
			"revealed": [], "surfaced": [], "cracked": []}
	for i in cells:
		if terrain[i] == Terrain.ROCK:
			_damage_rock(i, cfg.crack_power, step.revealed)
			step.cracked.append(i)
			continue
		if not _take(i):
			continue
		step.hit.append(i)
		if token[i] == Token.ORE:
			step.surfaced.append(i)
	_push(steps, step)


## Every ore of `kind` on the board flies to the robot and is extracted.
func _magnet(kind: int, at: int, steps: Array) -> void:
	var step := {"type": "magnet", "at": at, "ore": kind, "cells": [], "surfaced": []}
	for i in W * H:
		if terrain[i] != Terrain.GROUND or token[i] != Token.ORE or ore[i] != kind:
			continue
		_take(i)
		step.cells.append(i)
		if token[i] == Token.ORE:
			step.surfaced.append(i)
	_push(steps, step)


## Take what lies on ground cell i as a booster hit: ore is extracted (and the cell digs),
## crystals and energy cells are collected. False when there was nothing to take.
func _take(i: int) -> bool:
	match token[i]:
		Token.ORE:
			extracted[ore[i]] += 1
			haul[ore[i]] += 1 + cfg.yield_bonus
			stats.chunks += 1
			_dig(i)
			return true
		Token.CRYSTAL:
			token[i] = Token.NONE
			haul[RES_CRYSTAL] += 1
			stats.crystals += 1
			return true
		Token.CELL:
			token[i] = Token.NONE
			energy += cfg.cell_energy
			stats.cells += 1
			return true
	return false


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
		if cfg.gravity:
			_gravity(steps)
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
			var gain: int = cfg.refund_base + (n - 3) * cfg.refund_extra
			step.energy += gain
			step.groups.append({"cells": cells, "ore": kind})
			var charge_at := -1
			if n >= 4:
				charge_at = pivot if cells.has(pivot) else _central(cells)
				stats.charges_made += 1
			for c in cells:
				if c == charge_at:
					token[c] = Token.CHARGE
					spec[c] = cfg.special
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


# --- moved specials (prototypes) ------------------------------------------------------

## The special at cell c was just moved in direction d: it goes off there (see Special).
func _special(c: int, d: Vector2i, steps: Array) -> void:
	var kind := spec[c]
	var colour := ore[c]
	token[c] = Token.NONE
	stats.blasts += 1
	var step := {"type": "special", "kind": kind, "at": c, "dir": DIRS.find(d), "rays": [], "hit": [],
			"cracked": [], "revealed": [], "turned": [], "ore": colour}
	match kind:
		Special.DRILL:
			step.rays.append(_ray(c, d, 2, true, step))
		Special.PRISM:
			for dd in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				step.rays.append(_ray(c, dd, 1, false, step))
		Special.QUAKE:
			var cp := pos(c)
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if maxi(absi(dx), absi(dy)) != 2:
						continue
					var p := cp + Vector2i(dx, dy)
					if inside(p):
						_hit(idx(p), 1, step)
		Special.GEODE:
			var cp := pos(c)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var p := cp + Vector2i(dx, dy)
					if (dx == 0 and dy == 0) or not inside(p):
						continue
					var i := idx(p)
					if terrain[i] == Terrain.ROCK:
						_damage_rock(i, 1, step.revealed)
						step.cracked.append(i)
					elif terrain[i] == Terrain.GROUND and token[i] == Token.ORE and ore[i] != colour:
						ore[i] = colour
						step.turned.append(i)
			# the geode itself becomes a plain gem of its colour, ready to line up with them
			token[c] = Token.ORE
	_push(steps, step)


## A ray from c along d to the edge (bedrock ends it): takes every gem and pickup; rock loses
## `power` layers and, with `stop_at_rock`, ends the ray. Returns [c, last cell reached].
func _ray(c: int, d: Vector2i, power: int, stop_at_rock: bool, step: Dictionary) -> Array:
	var p := pos(c) + d
	var last := c
	while inside(p) and terrain[idx(p)] != Terrain.BEDROCK:
		var i := idx(p)
		last = i
		var was_rock := terrain[i] == Terrain.ROCK
		_hit(i, power, step)
		if was_rock and stop_at_rock:
			break
		p += d
	return [c, last]


func _hit(i: int, power: int, step: Dictionary) -> void:
	if terrain[i] == Terrain.ROCK:
		_damage_rock(i, power, step.revealed)
		step.cracked.append(i)
	elif terrain[i] == Terrain.GROUND and i != robot and _take(i):
		step.hit.append(i)


# --- gravity (prototypes "fall" and "classic") ---------------------------------------

## An open cell things can fall through: any ground (the robot falls too).
func _open(p: Vector2i) -> bool:
	return inside(p) and terrain[idx(p)] == Terrain.GROUND


## Gems drop to fill the holes, column by column, inside each run of open cells (rock and
## bedrock split a column); new gems drop in from the top of each run. The robot is a piece of
## the board like any gem: clear what is under it and it falls, a free move down (prototype B's
## core idea: matching under the robot is a way to travel). In the classic
## mode a crystal or energy cell that reaches the bottom of its run is collected (as Candy
## Crush's ingredients), which opens a hole and drops again.
func _gravity(steps: Array) -> void:
	var dst_of := {}  # portal destination cell -> its source
	for pp in cfg.portals:
		dst_of[pp[1]] = pp[0]
	for guard in 40:
		var moves := []
		var spawns := []
		var robot_fall := []
		var warps := []
		for x in W:
			var y := H - 1
			while y >= 0:
				if not _open(Vector2i(x, y)):
					y -= 1
					continue
				var bottom := y
				while y >= 0 and _open(Vector2i(x, y)):
					y -= 1
				var top := y + 1
				var write := bottom
				for yy in range(bottom, top - 1, -1):
					var i := idx(Vector2i(x, yy))
					if i == robot:
						if yy != write:
							robot = idx(Vector2i(x, write))
							robot_fall = [i, robot]
						write -= 1
					elif token[i] != Token.NONE:
						if yy != write:
							var w := idx(Vector2i(x, write))
							token[w] = token[i]
							ore[w] = ore[i]
							spec[w] = spec[i]
							token[i] = Token.NONE
							moves.append([i, w])
						write -= 1
				# new gems drop in at the top of the run, unless a portal feeds it, or (spawn_top)
				# it does not reach the top of the board: those runs only get what falls into them
				var top_cell := idx(Vector2i(x, top))
				if dst_of.has(top_cell) or (cfg.spawn_top and top > 0):
					continue
				var drop := write - top + 1
				for yy in range(write, top - 1, -1):
					var i := idx(Vector2i(x, yy))
					token[i] = Token.ORE
					ore[i] = _surface_type(i)
					spawns.append([i, drop])
		# portals: what sits at a source drops out of the destination, the robot included
		for pp in cfg.portals:
			var src: int = pp[0]
			var dst: int = pp[1]
			if token[dst] != Token.NONE or dst == robot:
				continue
			if src == robot:
				robot = dst
				robot_fall = [src, dst]
				warps.append([src, dst])
			elif token[src] != Token.NONE:
				token[dst] = token[src]
				ore[dst] = ore[src]
				spec[dst] = spec[src]
				token[src] = Token.NONE
				warps.append([src, dst])
		var collected := []
		if cfg.classic or cfg.collect_bottom:
			for i in W * H:
				if (token[i] == Token.CRYSTAL or token[i] == Token.CELL) and not _open(pos(i) + Vector2i(0, 1)):
					if token[i] == Token.CRYSTAL:
						haul[RES_CRYSTAL] += 1
						stats.crystals += 1
					else:
						energy += cfg.cell_energy
						stats.cells += 1
					token[i] = Token.NONE
					collected.append(i)
		if moves.is_empty() and spawns.is_empty() and collected.is_empty() and robot_fall.is_empty() and warps.is_empty():
			return
		_push(steps, {"type": "fall", "moves": moves, "spawns": spawns, "collected": collected,
				"robot": robot_fall, "warps": warps})


# --- classic swap (prototype "classic") ------------------------------------------------

func _swappable(i: int) -> bool:
	return terrain[i] == Terrain.GROUND and i != robot and token[i] != Token.NONE


## Swap the gem at cell c with its neighbour in direction d. Only a swap that makes a line (or
## sets off a charge) is taken and costs a move; any other swaps back for free.
func try_swap(c: int, d: Vector2i) -> Dictionary:
	var out := {"ok": false, "reason": "", "steps": []}
	if over:
		out.reason = "over"
		return out
	var b := pos(c) + d
	if not inside(b) or not _swappable(c) or not _swappable(idx(b)):
		out.reason = "wall"
		return out
	var ib := idx(b)
	_swap_cells(c, ib)
	var charge := token[c] == Token.CHARGE or token[ib] == Token.CHARGE
	if not charge and not _line_through(token, ore, c) and not _line_through(token, ore, ib):
		_swap_cells(c, ib)
		stats.rejected += 1
		out.reason = "nomatch"
		return out
	energy -= 1
	stats.moves += 1
	_push(out.steps, {"type": "swap", "a": c, "b": ib})
	for cc in [ib, c]:
		if token[cc] == Token.CHARGE:
			if spec[cc] == Special.BLAST:
				token[cc] = Token.NONE
				_blast(cc, out.steps)
			else:
				_special(cc, d if cc == ib else -d, out.steps)
	_resolve(out.steps, ib)
	_finish_turn()
	out.ok = true
	return out


func _swap_cells(a: int, b: int) -> void:
	var t := token[a]
	var o := ore[a]
	var sp := spec[a]
	token[a] = token[b]
	ore[a] = ore[b]
	spec[a] = spec[b]
	token[b] = t
	ore[b] = o
	spec[b] = sp


## A swap that makes a line: [cell, DIRS index], or [] when the board has none.
func find_swap() -> Array:
	for i in W * H:
		if not _swappable(i):
			continue
		for di in [1, 2]:
			var b: Vector2i = pos(i) + DIRS[di]
			if not inside(b) or not _swappable(idx(b)):
				continue
			var ib := idx(b)
			_swap_cells(i, ib)
			var ok := token[i] == Token.CHARGE or token[ib] == Token.CHARGE \
					or _line_through(token, ore, i) or _line_through(token, ore, ib)
			_swap_cells(i, ib)
			if ok:
				return [i, di]
	return []


## Classic: no swap left makes a line, so the gems reshuffle (free, as in any match-3).
func shuffle_classic() -> Dictionary:
	var out := {"ok": true, "reason": "", "steps": []}
	var cells := []
	var kinds := []
	for i in W * H:
		if terrain[i] == Terrain.GROUND and token[i] == Token.ORE:
			cells.append(i)
			kinds.append(ore[i])
	for attempt in 60:
		for k in range(kinds.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t = kinds[k]
			kinds[k] = kinds[j]
			kinds[j] = t
		for n in cells.size():
			ore[cells[n]] = kinds[n]
		if not has_line() and not find_swap().is_empty():
			break
	stats.pulses += 1
	_push(out.steps, {"type": "pulse", "cells": cells})
	_resolve(out.steps, -1)
	return out


## Remove the ore at c; surface a new chunk if the vein has reserve. Returns true if surfaced.
func _dig(c: int) -> bool:
	if cfg.gravity:
		token[c] = Token.NONE  # the hole is filled from above (_gravity)
		return false
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
		Buried.TREASURE:
			# the chest bursts open: its Coin is banked, the cell is left bare
			reserve[r] = 0
			token[r] = Token.NONE
			stats.treasures += 1
			treasure_coin += cfg.treasure_coin


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
						energy += cfg.cell_energy
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

## The cell a step from c in direction d reaches, or -1 (edge, bedrock). A portal links its
## source to its destination both ways: down out of the source drops into the destination,
## up out of the destination climbs back into the source.
func step_to(c: int, d: Vector2i) -> int:
	var p := pos(c) + d
	if inside(p) and terrain[idx(p)] != Terrain.BEDROCK:
		return idx(p)
	for pp in cfg.portals:
		if d == Vector2i(0, 1) and pp[0] == c:
			return pp[1]
		if d == Vector2i(0, -1) and pp[1] == c:
			return pp[0]
	return -1


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
				var ti := step_to(st.robot, DIRS[di])
				if ti < 0:
					continue
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


## Every way to make a line within `depth` steps (shortest first, at most `limit`): each is
## a list of DIRS indices. A path stops at its first line, as a player's plan would.
func paths_to_matches(depth: int, limit: int) -> Array:
	var out := []
	var frontier := [{"robot": robot, "token": token, "ore": ore, "path": []}]
	var visited := {}
	for level in depth:
		var next := []
		for st in frontier:
			for di in 4:
				var ti := step_to(st.robot, DIRS[di])
				if ti < 0:
					continue
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
					tk[ti] = Token.NONE
				var path: Array = st.path.duplicate()
				path.append(di)
				if _line_through(tk, orr, fi):
					out.append(path)
					if out.size() >= limit:
						return out
					continue
				var key := str(ti) + "|" + str(hash(tk)) + str(hash(orr))
				if visited.has(key):
					continue
				visited[key] = true
				next.append({"robot": ti, "token": tk, "ore": orr, "path": path})
		frontier = next
	return out


## Walking route (DIRS indices) from the robot to every open cell, ore ignored (walking only
## swaps it). Index -> path; the robot's own cell maps to [].
func walk_routes(depth: int) -> Dictionary:
	var routes := {robot: []}
	var frontier := [robot]
	for level in depth:
		var next := []
		for c in frontier:
			for di in 4:
				var ti := step_to(c, DIRS[di])
				if ti < 0:
					continue
				if terrain[ti] != Terrain.GROUND or routes.has(ti):
					continue
				var path: Array = routes[c].duplicate()
				path.append(di)
				routes[ti] = path
				next.append(ti)
		frontier = next
	return routes


## Shortest robot route to a crystal, energy cell or blast charge on open ground; [] if none
## within depth. Walking only swaps ore around, so ore never blocks the route.
func path_to_pickup(depth: int) -> Array:
	var prev := {robot: -1}
	var frontier := [robot]
	for level in depth:
		var next := []
		for c in frontier:
			for di in 4:
				var ti := step_to(c, DIRS[di])
				if ti < 0:
					continue
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


## The gems, where they lie now, that line up at the end of `path` (a path_to_match result):
## the robot's swaps are followed so a gem it carries is found at its current cell.
func match_gems(path: Array) -> Array:
	var tk := token.duplicate()
	var orr := ore.duplicate()
	var src := PackedInt32Array()
	src.resize(W * H)
	for i in W * H:
		src[i] = i
	var r := robot
	var fi := -1
	for di in path:
		var ti := step_to(r, DIRS[di])
		if ti < 0:
			return []
		fi = r
		if tk[ti] == Token.ORE:
			tk[fi] = Token.ORE
			orr[fi] = orr[ti]
			src[fi] = src[ti]
			tk[ti] = Token.NONE
		elif tk[ti] != Token.NONE:
			tk[ti] = Token.NONE
		r = ti
	if fi < 0 or tk[fi] != Token.ORE:
		return []
	var kind := orr[fi]
	var out := []
	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		var run := [fi]
		for sgn in [1, -1]:
			var q: Vector2i = pos(fi) + axis * sgn
			while inside(q) and terrain[idx(q)] == Terrain.GROUND and tk[idx(q)] == Token.ORE and orr[idx(q)] == kind:
				run.append(idx(q))
				q += axis * sgn
		if run.size() >= 3:
			for c in run:
				if not out.has(src[c]):
					out.append(src[c])
	return out


## Hide one treasure chest in this dig (a rare bonus): a single-layer rock that hid plain ore
## becomes a chest; with none, an ore cell away from the robot turns into one. Uses its own
## rng so the dig's own random stream (what surfaces) is unchanged.
func place_treasure(r: RandomNumberGenerator) -> int:
	var rocks := []
	var ground := []
	for i in W * H:
		if terrain[i] == Terrain.ROCK and hp[i] == 1 and buried[i] == Buried.ORE:
			rocks.append(i)
		elif terrain[i] == Terrain.GROUND and token[i] == Token.ORE and i != robot \
				and absi(pos(i).x - pos(robot).x) + absi(pos(i).y - pos(robot).y) >= 2:
			ground.append(i)
	var at := -1
	if not rocks.is_empty():
		at = rocks[r.randi_range(0, rocks.size() - 1)]
	elif not ground.is_empty():
		at = ground[r.randi_range(0, ground.size() - 1)]
		terrain[at] = Terrain.ROCK
		token[at] = Token.NONE
		hp[at] = 1
		hp0[at] = 1
	if at >= 0:
		buried[at] = Buried.TREASURE
	return at


func clone() -> Board:
	var b := Board.new()
	b.terrain = terrain.duplicate(); b.hp = hp.duplicate(); b.hp0 = hp0.duplicate(); b.buried = buried.duplicate()
	b.reserve = reserve.duplicate(); b.dug = dug.duplicate(); b.token = token.duplicate(); b.ore = ore.duplicate()
	b.spec = spec.duplicate()
	b.robot = robot; b.energy = energy; b.haul = haul.duplicate()
	b.extracted = extracted.duplicate(); b.stats = stats.duplicate(); b.treasure_coin = treasure_coin
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
		"treasure": return stats.treasures
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
		"terrain": terrain.duplicate(), "hp": hp.duplicate(), "hp0": hp0.duplicate(), "buried": buried.duplicate(),
		"reserve": reserve.duplicate(), "depth": dug.duplicate(), "token": token.duplicate(), "ore": ore.duplicate(), "spec": spec.duplicate(),
		"robot": robot, "energy": energy, "haul": haul.duplicate(),
		"extracted": extracted.duplicate(), "rocks": stats.rocks_broken, "chunks": stats.chunks,
		"crystals": stats.crystals, "blasts": stats.blasts, "treasures": stats.treasures,
		"treasure_coin": treasure_coin,
	}
