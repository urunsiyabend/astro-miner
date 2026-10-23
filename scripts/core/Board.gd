class_name Board
extends RefCounted

## Pure rules for one dig. No rendering, no scene tree access.
## Every random decision goes through `rng`, so a seed + move list replays exactly.

## Board size: set by each dig from its rows (setup), 7x8 by default. Only one board size is
## live at a time (a dig and its clones), so it is shared, not per board.
static var W := 7
static var H := 8

## BLOCK: a cell taken by a piece obstacle (Obstacles: a generator...), solid like rock.
enum Terrain { GROUND, ROCK, BEDROCK, BLOCK }
## CORE: an energy core to deliver (a Deliver goal): it falls like a gem, never matches, the robot
## can push it along, and it is delivered when it comes to rest on a dock (cfg.docks).
enum Token { NONE, ORE, CRYSTAL, CELL, CHARGE, CORE }
enum Buried { ORE, CELL, CRYSTAL, EMPTY, TREASURE }

## The power-ups (Powers.gd). BLAST is the robot dig's old charge: step on it and it blows the
## 3x3 around it. The others go off when they are MOVED (the robot drags one), at the cell they
## land on, aimed by the way they moved: PULSAR (4 in a row) twin beams, NOVA (L/T) a 5x5 blast,
## BLACKHOLE (5 in a row) a colour, DRONE (2x2) flies to the most useful cell.
enum Special { BLAST, PULSAR, NOVA, BLACKHOLE, DRONE }
const SPECIAL_IDS := {"blast": Special.BLAST, "pulsar": Special.PULSAR, "nova": Special.NOVA,
		"blackhole": Special.BLACKHOLE, "drone": Special.DRONE}
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
	"energy_refunded": 0, "rejected": 0, "cores": 0, "paths": 0, "launches": 0, "teleports": 0, "pulses": 0, "continues": 0, "boosters": 0,
}
var goals: Array = []  # [{type:"ore", ore:int, n:int} | {type:"rock", n} | {type:"crystal", n} | ...]
var obs := Obstacles.new()  # generators, cages...: what they are and what hits them
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
	"special": -1,  # Special a line of 4 leaves; -1: by the shape of the match (Powers.by_shape)
	"portals": [],         # [[source cell, destination cell]]: what falls out of one drops into the other
	"spawn_top": false,    # new gems only enter runs that reach the top row (not under bedrock either)
	"collect_bottom": false,  # crystals and cells are collected at the bottom of their run
	# drawn paths (Puzzle & Dragons): hold the robot and draw up to this many steps; the robot
	# swaps with every gem on the way and the board resolves once, at the end, for one move
	"path_max": 1,
	# movement elements (falling-gem digs):
	"pads": {},     # launch pad cell -> target cell: a special, crystal or cell that comes to
	                # rest on the pad flies to the target (a special goes off there)
	"belts": [],    # conveyors [cell, ...]: after every move everything on one moves a cell along
	                # it (the robot rides too), and what leaves the last cell comes back on the first
	"teleports": {},  # teleporter cell -> its twin (both ways): a move or path that ends on one
	                  # puts the robot on the twin; a special that comes to rest on one appears on
	                  # the twin and goes off there
	"docks": {},    # cells where an energy core that comes to rest is delivered
}

var record := true  # build per-step snapshots for the view; sims switch this off
var pushed := {}  # teleporter cell -> the way the special on it was pushed (this move)
var claimed := {}  # cells power-ups already reached this move (a drone looks elsewhere)


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
	# a site may pin one special (prototypes); otherwise falling-gem digs pick it by the match's
	# shape, and robot digs keep the original step-on blast charge
	r.special = SPECIAL_IDS.get(String(site.get("special", "")), Special.BLAST if mode == "robot" else -1)
	# the site's size first: every cell below is turned into an index on this board
	H = site.rows.size()
	W = String(site.rows[0]).split(" ", false).size()
	var portals := []
	for pp in site.get("portals", []):
		portals.append([idx(pp[0]), idx(pp[1])])
	r.portals = portals
	r.spawn_top = site.get("spawn_top", false)
	r.collect_bottom = site.get("collect", false)
	var pads := {}
	for pd in site.get("pads", []):
		pads[idx(pd[0])] = idx(pd[1])
	r.pads = pads
	var belts := []
	for loop in site.get("belts", []):
		belts.append(loop.map(func(c): return idx(c)))
	r.belts = belts
	var teleports := {}
	for t in site.get("teleports", []):
		teleports[idx(t[0])] = idx(t[1])
		teleports[idx(t[1])] = idx(t[0])
	r.teleports = teleports
	var docks := {}
	for d in site.get("docks", []):
		docks[idx(d)] = true
	r.docks = docks
	setup(site.rows, int(site.get("seed", seed_value)), r, site.goals, site.get("ore", []))
	# obstacles ([[top-left cell, kind], ...], Obstacles.KINDS): a piece takes its cells, a
	# cover goes over the gem already there
	for ob in site.get("obstacles", []):
		var cells := obs.place(ob[1], ob[0], W, int(ob[2]) if ob.size() > 2 else 0)
		for c in cells:
			if Obstacles.KINDS[ob[1]].layer == Obstacles.Layer.PIECE:
				terrain[c] = Terrain.BLOCK
				token[c] = Token.NONE
			elif Obstacles.KINDS[ob[1]].layer == Obstacles.Layer.FLOOR:
				pass  # it lies under whatever the cell holds
			else:
				assert(token[c] == Token.ORE, "a cover needs a gem under it (cell %d)" % c)
				for belt in cfg.belts:
					assert(not belt.has(c), "a cover can't ride a belt (cell %d)" % c)
	for c in site.get("cores", []):
		token[idx(c)] = Token.CORE
	# pre-placed specials ([[cell, "drill"], ...]): a gem that already carries one, as Royal
	# Match seeds a TNT to show what a level wants
	for sp in site.get("specials", []):
		var si := idx(sp[0])
		if token[si] == Token.ORE:
			token[si] = Token.CHARGE
			spec[si] = SPECIAL_IDS[sp[1]]
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


## layout: optional rows of hand-placed tokens (F C L R ore, c crystal, e energy cell,
## b blast charge, - nothing) that replace the seeded fill.
func setup(rows: Array, seed_value: int, rules: Dictionary = {}, site_goals: Array = [], layout: Array = []) -> void:
	for k in rules:
		cfg[k] = rules[k]
	goals = site_goals.duplicate(true)
	obs = Obstacles.new()
	robot = -1
	var n := W * H
	terrain.resize(n); hp.resize(n); hp0.resize(n); buried.resize(n); reserve.resize(n)
	spec.resize(n)
	spec.fill(0)
	token.resize(n); ore.resize(n); dug.resize(n)
	for i in n:
		terrain[i] = Terrain.GROUND; hp[i] = 0; hp0[i] = 0; buried[i] = Buried.ORE
		reserve[i] = 0; token[i] = Token.NONE; ore[i] = 0; dug[i] = 0
	H = rows.size()
	W = String(rows[0]).split(" ", false).size()
	n = W * H
	terrain.resize(n); hp.resize(n); hp0.resize(n); buried.resize(n); reserve.resize(n)
	spec.resize(n)
	spec.fill(0)
	token.resize(n); ore.resize(n); dug.resize(n)
	for i in n:
		terrain[i] = Terrain.GROUND; hp[i] = 0; hp0[i] = 0; buried[i] = Buried.ORE
		reserve[i] = 0; token[i] = Token.NONE; ore[i] = 0; dug[i] = 0
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
				"R": token[i] = Token.ORE; ore[i] = 3
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


## Ore type that does not complete a line of 3 with the two cells left or above, or a square
## (the fill runs in row-major order, so only those neighbours are already set).
func _pick_no_line(i: int) -> int:
	var c := pos(i)
	var banned := []
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
		var a := c + d
		var b := c + d * 2
		if _is_ore(a) and _is_ore(b) and ore[idx(a)] == ore[idx(b)]:
			banned.append(ore[idx(a)])
	# nor a 2x2 square with the three cells up and to the left
	var l := c + Vector2i(-1, 0)
	var u := c + Vector2i(0, -1)
	var ul := c + Vector2i(-1, -1)
	if _is_ore(l) and _is_ore(u) and _is_ore(ul) and ore[idx(l)] == ore[idx(u)] and ore[idx(u)] == ore[idx(ul)]:
		banned.append(ore[idx(l)])
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
## A step into rock is a drill bump (with the Drill); any other step is a one-cell path.
func try_move(dir: Vector2i) -> Dictionary:
	var out := {"ok": false, "reason": "", "steps": []}
	if over:
		out.reason = "over"
		return out
	var ti := step_to(robot, dir)
	if ti < 0 or terrain[ti] == Terrain.BLOCK or obs.locked(ti):
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
		belt_boost = 0
		var step := {"type": "drill", "cell": ti, "revealed": []}
		_damage_rock(ti, cfg.drill_power, step.revealed)
		_push(out.steps, step)
		_resolve(out.steps, -1)
		_turn_end(out.steps)
		_finish_turn()
		out.ok = true
		return out
	return _move([dir], [ti], false)


## The cells a drawn path visits from the robot (start excluded), or [] if a step is not
## allowed: off the board, bedrock, rock or an obstacle (a path never drills), a caged gem,
## longer than path_max, or straight back onto the cell it just left (that only undoes the
## last swap).
func path_cells(dirs: Array) -> Array:
	var out := []
	if dirs.is_empty() or dirs.size() > cfg.path_max or robot < 0:
		return []
	var cur := robot
	var prev := -1
	for d in dirs:
		var ti := step_to(cur, d)
		if ti < 0 or not can_enter(ti) or ti == prev:
			return []
		out.append(ti)
		prev = cur
		cur = ti
	return out


## One move along a drawn path: costs one move whatever its length. A one-step path is
## try_move (it may be a drill bump).
func try_path(dirs: Array) -> Dictionary:
	if dirs.size() == 1:
		return try_move(dirs[0])
	var out := {"ok": false, "reason": "", "steps": []}
	if over:
		out.reason = "over"
		return out
	var cells := path_cells(dirs)
	if cells.is_empty():
		out.reason = "path"
		stats.rejected += 1
		return out
	stats.paths += 1
	return _move(dirs, cells, true)


## What a drawn path would do if the finger lifted now, without doing it: played by the same
## code as the move itself (_walk) on a clone, so what the player is shown can't disagree with
## what happens. {} if the path isn't allowed. Otherwise:
##   snap      the board after the robot's swaps (and a teleport at the end), before matching
##   twin      the teleporter the robot will come out of, or -1
##   groups    [{cells, ore, special (-1: none), at}]: the lines that will match, and the
##             special each leaves and where
##   specials  dragged special's cell -> [cell it goes off at, the way it fires, the colour a
##             Black hole will swallow (-1 for other power-ups)]
##   combo     {} or, when it dragged two or more: {at, from, kinds, name} (Powers.combo)
func preview_path(dirs: Array) -> Dictionary:
	var cells := path_cells(dirs)
	if cells.is_empty():
		return {}
	var b := clone()
	var w := b._walk(dirs, cells, [], true)
	var specials := {}
	var moved: Array = w.moved.filter(func(m): return b.token[m[0]] == Token.CHARGE)
	var combo := {}
	if moved.size() >= 2:
		var kinds: Array = moved.map(func(m): return b.spec[m[0]])
		combo = {"at": moved[-1][0], "from": moved.map(func(m): return m[0]), "kinds": kinds, "colour": _combo_colour(moved),
				"name": Powers.combo_name(kinds)}
	else:
		for m in moved:
			specials[m[0]] = b.special_aim(m[0], m[1]) + [Powers.swallow_colour(b, b.spec[m[0]], m[2])]
	var end := b.robot
	var tp := b._teleport_robot([])
	var pivot: int = tp if tp >= 0 else w.pivot
	var groups := []
	for g in b.find_groups():
		var special := -1
		var at: int = g.cells[0]
		if g.cells.size() >= 4 and b._charge_cell(g.cells, pivot) >= 0:
			special = b._special_kind(g.cells)
			at = b._charge_cell(g.cells, pivot)
		groups.append({"cells": g.cells, "ore": g.ore, "special": special, "at": at})
	return {"snap": b.snapshot(), "twin": b.robot if b.robot != end else -1, "groups": groups,
			"specials": specials, "combo": combo}


## A player's move along `cells` (one cell for a step, more for a drawn path): the walk, then
## what it set off, then the board resolves once, the belts run and the turn ends. `live`: the
## path was shown step by step while it was drawn, so the view doesn't play the walk again.
func _move(dirs: Array, cells: Array, live: bool) -> Dictionary:
	var out := {"ok": true, "reason": "", "steps": []}
	energy -= 1
	stats.moves += 1
	pushed.clear()
	claimed.clear()
	belt_boost = 0
	var w := _walk(dirs, cells, out.steps, live)
	for c in w.charges:
		_blast(c, out.steps)
	var moved: Array = w.moved.filter(func(m): return token[m[0]] == Token.CHARGE)
	if moved.size() >= 2:
		# a path that dragged two or more power-ups merges them into the last one (Powers.combo)
		var at: int = moved[-1][0]
		var kinds := []
		for m in moved:
			kinds.append(spec[m[0]])
			token[m[0]] = Token.NONE
		_push(out.steps, {"type": "merge", "from": moved.map(func(m): return m[0]), "to": at, "kinds": kinds,
				"name": Powers.combo_name(kinds)})
		Powers.combo(self, at, moved[-1][1], kinds, out.steps, _combo_colour(moved))
	for m in moved if moved.size() == 1 else []:
		if cfg.teleports.has(m[0]):
			pushed[m[0]] = m[1]  # it travels first (_launch), still heading this way
		elif not cfg.pads.has(m[0]):
			Powers.fire(self, m[0], m[1], out.steps, m[2])
	var tp := _teleport_robot(out.steps)
	_resolve(out.steps, tp if tp >= 0 else w.pivot)
	_turn_end(out.steps)
	_finish_turn()
	return out


## The robot walks `cells`, swapping with each gem it meets (pickups are collected, a blast
## charge is stepped on), with no matching on the way. A special it drags is pushed back into
## the cell the robot just left. Returns {moved: [[cell, way pushed, colour]] the dragged
## specials where they ended up, in order, with the colour of the gem the robot swapped just
## before it (-1: none; a Black hole swallows that colour); charges: blast charges stepped on;
## pivot: the cell the last swapped gem landed on (where a line it makes leaves its special)}.
func _walk(dirs: Array, cells: Array, steps: Array, live: bool) -> Dictionary:
	var moved := []
	var charges := []
	var pivot := -1
	var came := -1  # the colour of the gem the robot swapped on its last step, or -1
	for k in cells.size():
		var fi := robot
		var gem := -1
		var ti: int = cells[k]
		var d: Vector2i = dirs[k]
		var step := {"type": "move", "from": fi, "to": ti, "swap": false, "pickup": Token.NONE}
		if live:
			step.path = true
		var dd := pos(ti) - pos(fi)
		if absi(dd.x) + absi(dd.y) != 1:
			step.portal = true  # walked through a portal: the view pops it out of the other end
		match token[ti]:
			Token.ORE:
				token[fi] = Token.ORE
				ore[fi] = ore[ti]
				spec[fi] = 0
				token[ti] = Token.NONE
				step.swap = true
				pivot = fi
				gem = ore[fi]
			Token.CORE:
				token[fi] = Token.CORE
				token[ti] = Token.NONE
				step.swap = true
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
					charges.append(ti)
				else:
					token[fi] = Token.CHARGE
					spec[fi] = spec[ti]
					ore[fi] = ore[ti]
					token[ti] = Token.NONE
					step.swap = true
					for m in moved:
						if m[0] == ti:
							moved.erase(m)  # dragged again: it goes off where it ends up
							break
					moved.append([fi, -d, came])
		came = gem
		robot = ti
		_push(steps, step)
	return {"moved": moved, "charges": charges, "pivot": pivot}


## The colour a combo's Black hole works on: the gem the robot swapped just before it, or -1.
func _combo_colour(moved: Array) -> int:
	for m in moved:
		if spec[m[0]] == Special.BLACKHOLE and int(m[2]) >= 0:
			return m[2]
	return -1


## Where a special that came to rest on cell c, pushed along d, goes off, and the way it fires:
## a pad throws it to the pad's target (firing along the throw), a teleporter puts it on the
## twin (still heading d), anywhere else it goes off in place. [cell, Vector2i].
func special_aim(c: int, d: Vector2i) -> Array:
	if cfg.pads.has(c):
		return [cfg.pads[c], _pad_dir(c)]
	if cfg.teleports.has(c):
		return [cfg.teleports[c], d]
	return [c, d]


## What a launch pad throws: a special, a crystal, an energy cell or an energy core; never a
## plain gem or the robot (a robot thrown into a sealed room could never leave).
static func pad_throws(tk: int) -> bool:
	return tk == Token.CHARGE or tk == Token.CRYSTAL or tk == Token.CELL or tk == Token.CORE


## The way pad p throws: along the longer axis from the pad to its target.
func _pad_dir(p: int) -> Vector2i:
	var dv := pos(cfg.pads[p]) - pos(p)
	return Vector2i(signi(dv.x), 0) if absi(dv.x) > absi(dv.y) else Vector2i(0, signi(dv.y))


## Launch pads: a special, crystal, energy cell or energy core that comes to rest on a pad flies
## to the pad's target. A special goes off where it lands (a Drill bores on in the flight's
## direction), a crystal or cell lands there. Plain gems and the robot stay put (a robot
## thrown into a sealed room could never leave). Returns true if anything flew.
func _launch(steps: Array) -> bool:
	var any := false
	for p in cfg.teleports:
		var t: int = cfg.teleports[p]
		if token[p] != Token.CHARGE or t == robot or terrain[t] != Terrain.GROUND or obs.locked(t) \
				or token[t] == Token.CORE:
			continue
		# a special on a teleporter appears on the twin and goes off there, still heading the way
		# it was pushed (straight on if it fell in)
		var d: Vector2i = pushed.get(p, Vector2i(0, 1))
		pushed.erase(p)
		var step := {"type": "teleport", "from": p, "to": t, "robot": false}
		if token[t] != Token.NONE:
			_take(t)
		token[t] = Token.CHARGE
		ore[t] = ore[p]
		spec[t] = spec[p]
		token[p] = Token.NONE
		stats.launches += 1
		_push(steps, step)
		Powers.fire(self, t, d, steps)
		any = true
	for p in cfg.pads:
		var t: int = cfg.pads[p]
		var dir := _pad_dir(p)
		var tk := token[p]
		if not pad_throws(tk):
			continue
		if t == robot or terrain[t] != Terrain.GROUND or obs.locked(t) or token[t] == Token.CORE:
			continue  # nothing lands on the robot, a wall, a caged gem or a core
		var step := {"type": "launch", "from": p, "to": t, "robot": false, "token": tk, "ore": ore[p], "spec": spec[p]}
		if token[t] != Token.NONE:
			_take(t)  # whatever was there is knocked out and counts as taken
		token[t] = tk
		ore[t] = ore[p]
		spec[t] = spec[p]
		token[p] = Token.NONE
		stats.launches += 1
		_push(steps, step)
		if tk == Token.CHARGE:
			Powers.fire(self, t, dir, steps)
		any = true
	return any


## The robot's move ended on a teleporter: it appears on the twin, and what stood there
## (a gem or special) takes the robot's place on the first one (a crystal or cell is picked
## up). Only the player's own move does this, never a fall, so the robot cannot bounce
## back and forth. Returns the cell the swapped gem landed on (a match pivot) or -1.
func _teleport_robot(steps: Array) -> int:
	if not cfg.teleports.has(robot):
		return -1
	var a := robot
	var t: int = cfg.teleports[a]
	if terrain[t] != Terrain.GROUND or obs.locked(t):
		return -1
	var pivot := -1
	match token[t]:
		Token.CORE:
			token[a] = Token.CORE
		Token.ORE, Token.CHARGE:
			token[a] = token[t]
			ore[a] = ore[t]
			spec[a] = spec[t]
			pivot = a
		Token.CRYSTAL:
			haul[RES_CRYSTAL] += 1
			stats.crystals += 1
		Token.CELL:
			energy += cfg.cell_energy
			stats.cells += 1
	token[t] = Token.NONE
	robot = t
	stats.teleports += 1
	_push(steps, {"type": "teleport", "from": a, "to": t, "robot": true})
	return pivot


## After the player's move has resolved, the conveyors run: one step, plus one for every gem
## matched on a belt this move (a match on a belt pushes it on), at most BELT_MAX, each step
## followed by the board resolving (a belt can carry a gem into a line, or a special onto a
## pad). Every belt is a cycle: everything on it moves one cell along, the robot too, and what
## leaves the last cell comes back on the first (a line's ends are a pair of gates; a belt
## whose ends touch simply turns round). A belt that is not a closed loop is also a shelf:
## nothing on it falls through it, and gaps on it fill from above.
const BELT_MAX := 6
var belt_boost := 0  # gems matched on belts during this move


func _turn_end(steps: Array) -> void:
	if cfg.belts.is_empty() or over:
		return
	var done := 0
	while done < mini(1 + belt_boost, BELT_MAX) and not over:
		_belt_step(steps)
		_resolve(steps, -1)
		done += 1
	belt_boost = 0


func _belt_step(steps: Array) -> void:
	var moves := []
	var robot_move := []
	for belt in cfg.belts:
		var n: int = belt.size()
		var tk := []
		var orr := []
		var sp := []
		for c in belt:
			tk.append(token[c]); orr.append(ore[c]); sp.append(spec[c])
		var new_robot := robot
		for k in n:
			var from: int = belt[k]
			var to: int = belt[(k + 1) % n]
			token[to] = tk[k]; ore[to] = orr[k]; spec[to] = sp[k]
			if tk[k] != Token.NONE:
				moves.append([from, to])
			if robot == from:
				new_robot = to
		if new_robot != robot:
			robot_move = [robot, new_robot]
			robot = new_robot
	_push(steps, {"type": "belt", "moves": moves, "robot": robot_move})


## The cells that hold up what is on them: every cell of a belt that is not a closed loop.
func _belt_shelf() -> Dictionary:
	var out := {}
	for belt in cfg.belts:
		if _belt_is_loop(belt):
			continue
		for c in belt:
			out[c] = true
	return out


static func _belt_is_loop(belt: Array) -> bool:
	var ends := pos(belt[0]) - pos(belt[belt.size() - 1])
	return absi(ends.x) + absi(ends.y) == 1


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
			return c >= 0 and c < W * H and c != robot and terrain[c] == Terrain.GROUND and not obs.locked(c)
		Economy.Booster.LASER:
			return c >= 0 and c < 4 and not _laser_cells(c).is_empty()
		Economy.Booster.MAGNET:
			return c >= 0 and c < W * H and terrain[c] == Terrain.GROUND and token[c] == Token.ORE and not obs.locked(c)
	return false


## Use booster k on cell c (the Laser takes a DIRS index). Returns steps like try_move.
func use_booster(k: int, c: int) -> Dictionary:
	var out := {"ok": false, "reason": "", "steps": []}
	if not booster_ok(k, c):
		out.reason = "target"
		return out
	stats.boosters += 1
	belt_boost = 0
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
	_turn_end(out.steps)
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
		Token.CORE:
			token[from] = Token.CORE
			token[c] = Token.NONE
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
			"revealed": [], "surfaced": [], "cracked": [], "obstacles": []}
	var seen := {}
	for i in cells:
		if _strike(i, Obstacles.Hit.POWER, cfg.crack_power, step, seen):
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
		if terrain[i] != Terrain.GROUND or token[i] != Token.ORE or ore[i] != kind or obs.locked(i):
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
		if (not cfg.pads.is_empty() or not cfg.teleports.is_empty()) and _launch(steps):
			pass_no += 1
			continue  # what flew left holes and blasts: settle again before matching
		var groups := find_groups()
		if groups.is_empty():
			return
		var step := {"type": "match", "groups": [], "cracked": [], "revealed": [],
				"surfaced": [], "charges": [], "energy": 0, "cascade": pass_no > 0, "obstacles": []}
		var to_dig := []
		for g in groups:
			var cells: Array = g.cells
			var kind: int = g.ore
			var n := cells.size()
			stats.groups += 1
			if pass_no > 0:
				stats.cascade_groups += 1
			for belt in cfg.belts:
				for c in cells:
					if belt.has(c):
						belt_boost += 1  # a match on a belt pushes it on (_turn_end)
			stats.chunks += n
			extracted[kind] += n
			haul[kind] += n + cfg.yield_bonus
			var gain: int = cfg.refund_base + (n - 3) * cfg.refund_extra
			step.energy += gain
			step.groups.append({"cells": cells, "ore": kind})
			var charge_at := -1
			var made := _special_kind(cells)
			if made >= 0:
				charge_at = _charge_cell(cells, pivot)
				if charge_at >= 0:
					stats.charges_made += 1
			# the group hits what is on its own cells (a cage keeps its gem: the hit breaks the
			# cage instead) and, once each, every rock and obstacle next to it
			var seen := {}
			for c in cells:
				if _strike(c, Obstacles.Hit.ON, cfg.crack_power, step, seen):
					continue
				if c == charge_at:
					token[c] = Token.CHARGE
					spec[c] = made
					step.charges.append(c)
				else:
					to_dig.append(c)
			var touched := {}
			for c in cells:
				for d in DIRS:
					var nb: Vector2i = pos(c) + d
					if inside(nb) and not cells.has(idx(nb)):
						touched[idx(nb)] = true
			for nb in touched:
				_strike(nb, Obstacles.Hit.NEXT, cfg.crack_power, step, seen)
		energy = mini(cfg.capacity, energy + step.energy)
		stats.energy_refunded += step.energy
		for c in to_dig:
			if _dig(c):
				step.surfaced.append(c)
		_push(steps, step)
		pivot = -1
		pass_no += 1


# --- moved specials --------------------------------------------------------------------

## The power-up a match leaves, or -1: the site's own (cfg.special, for 4 or more), else by
## its shape (Powers.by_shape).
func _special_kind(cells: Array) -> int:
	if cfg.special >= 0:
		return cfg.special if cells.size() >= 4 else -1
	return Powers.by_shape(cells)


## Where a match leaves its power-up: on the gem that was moved into it (the pivot), else in
## the middle of the match; -1 when that gem is caged (the match only breaks the cage).
func _charge_cell(cells: Array, pivot: int) -> int:
	var c := pivot if cells.has(pivot) else _central(cells)
	return -1 if obs.locked(c) else c


## The one way anything on the board damages a cell (a match on it or next to it, a power-up,
## a blast, a booster): rock loses `power` layers (it takes NEXT and POWER hits), an obstacle
## takes the hit by its own rule (Obstacles.KINDS). `seen` is shared by one source of hits so a
## multi-cell obstacle counts it once. Records what happened on `step` for the view. Returns
## true when rock or an obstacle took the hit, so it goes no further (a caged gem stays).
func _strike(i: int, h: int, power: int, step: Dictionary, seen: Dictionary) -> bool:
	# a floor layer (a web) takes its hit and lets it through to what lies on the cell; under
	# rock (a shielded web) it waits until the rock has gone
	if terrain[i] == Terrain.GROUND:
		var fl := obs.hit_floor(i, h, seen)
		if not fl.is_empty():
			step.get_or_add("obstacles", []).append(fl)
	var r := obs.hit(i, h, seen)
	if not r.is_empty():
		step.get_or_add("obstacles", []).append(r)
		for c in r.freed:
			terrain[c] = Terrain.GROUND  # a piece that leaves opens its cells (gravity fills them)
		return true
	if obs.target(i, h) >= 0:
		return true  # this source already hit the obstacle (through another of its cells)
	if obs.locked(i) and h != Obstacles.Hit.NEXT:
		return true  # a cover this hit can't break still keeps its gem
	if terrain[i] == Terrain.ROCK and h != Obstacles.Hit.ON:
		_damage_rock(i, power, step.get_or_add("revealed", []))
		var cracked: Array = step.get_or_add("cracked", [])
		if not cracked.has(i):
			cracked.append(i)
		return true
	return terrain[i] == Terrain.BLOCK


# --- gravity (prototypes "fall" and "classic") ---------------------------------------

## An open cell things can fall through: any ground (the robot falls too) but a caged gem's,
## which holds still and holds up what is above it.
func _open(p: Vector2i) -> bool:
	return inside(p) and terrain[idx(p)] == Terrain.GROUND and not obs.locked(idx(p))


## Gems drop to fill the holes (`_fall_straight`), new gems drop in where the board opens to the
## sky, and holes under rock fill diagonally (`_slide_diagonal`). The robot is a piece of
## the board like any gem: clear what is under it and it falls, a free move down (prototype B's
## core idea: matching under the robot is a way to travel). In the classic
## mode a crystal or energy cell that reaches the bottom of its run is collected (as Candy
## Crush's ingredients), which opens a hole and drops again. Returns where each piece that was
## on the board went: {cell it was in: cell it is in now} (Powers re-aims its queue by it).
func _gravity(steps: Array) -> Dictionary:
	var went := {}  # cell a piece is in now -> the cell it started in
	var shelf := _belt_shelf()
	var dst_of := {}  # portal destination cell -> its source
	for pp in cfg.portals:
		dst_of[pp[1]] = pp[0]
	for guard in 40:
		# one step is the whole settle: straight drops, new gems, diagonal slides, again until
		# nothing moves, and every piece's route through it (Gem Hunter Match: each piece falls
		# along its own path at once, not a pass at a time, docs/research/match3-fluid-falls.md)
		var trail := {}  # cell -> grid points of the route of the piece now in it, from its start
		var fresh := {}  # cell -> the top row of the run the new gem in it came in through
		var waves := {}  # x -> new gems dropped into the column so far: the next ones come behind
		var robot_from := robot
		for settle in 60:
			if not _fall_straight(shelf, dst_of, trail, fresh, waves) and \
					not _slide_diagonal(shelf, (guard + settle) % 2 == 0, trail, fresh):
				break
		var moves := []
		var spawns := []
		var paths := {}
		for c in trail:
			paths[c] = trail[c]
			if fresh.has(c):
				spawns.append([c, fresh[c]])
			else:
				moves.append([idx(Vector2i(trail[c][0])), c])
		var robot_fall := [robot_from, robot] if robot != robot_from else []
		var warps := []
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
		for i in cfg.docks:
			if token[i] == Token.CORE:  # a core at rest on a dock is delivered
				token[i] = Token.NONE
				stats.cores += 1
				collected.append(i)
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
		for batch in [moves, warps]:  # each batch moves at once: map from before it
			var nw := {}
			var left := {}
			for m in batch:
				left[m[0]] = true
			for now in went:
				if not left.has(now):
					nw[now] = went[now]
			for m in batch:
				nw[m[1]] = went.get(m[0], m[0])
			went = nw
		for c in collected:
			went.erase(c)
		if moves.is_empty() and spawns.is_empty() and collected.is_empty() and robot_fall.is_empty() and warps.is_empty():
			break
		_push(steps, {"type": "fall", "moves": moves, "spawns": spawns, "paths": paths,
				"collected": collected, "robot": robot_fall, "warps": warps})
	var out := {}
	for now in went:
		out[went[now]] = now
	return out


## A piece moves from cell a to cell b: its route (trail) and whether it is new go with it.
func _carry(a: int, b: int, trail: Dictionary, fresh: Dictionary) -> void:
	token[b] = token[a]
	ore[b] = ore[a]
	spec[b] = spec[a]
	token[a] = Token.NONE
	var route: Array = trail.get(a, [Vector2(pos(a))])
	trail.erase(a)
	trail[b] = route + [Vector2(pos(b))]
	if fresh.has(a):
		fresh[b] = fresh[a]
		fresh.erase(a)


## One pass of straight drops, column by column inside each run of open cells (rock and
## bedrock split a column); new gems drop in at the top of a run that opens to the sky. True if
## anything moved.
func _fall_straight(shelf: Dictionary, dst_of: Dictionary, trail: Dictionary, fresh: Dictionary, waves: Dictionary) -> bool:
	var moved := false
	for x in W:
		var y := H - 1
		while y >= 0:
			if not _open(Vector2i(x, y)):
				y -= 1
				continue
			var bottom := y
			# a belt is a shelf: what is on it never falls through, so a belt cell can only be
			# the bottom of a run, and the cells under it are a run of their own
			while y >= 0 and _open(Vector2i(x, y)) and (y == bottom or not shelf.has(idx(Vector2i(x, y)))):
				y -= 1
			var top := y + 1
			var write := bottom
			for yy in range(bottom, top - 1, -1):
				var i := idx(Vector2i(x, yy))
				if i == robot:
					if yy != write:
						robot = idx(Vector2i(x, write))
						moved = true
					write -= 1
				elif token[i] != Token.NONE:
					if yy != write:
						_carry(i, idx(Vector2i(x, write)), trail, fresh)
						moved = true
					write -= 1
			# new gems drop in only where the board opens to the sky: a run whose top is the top
			# row, or has nothing but bedrock (cells cut out of the board) above it. Under rock
			# they don't appear out of thin air: gems slide in diagonally from the neighbours
			# (below), or wait until the rock breaks. A portal feeds its own run.
			if dst_of.has(idx(Vector2i(x, top))) or not _sky_above(x, top):
				continue
			var drop := write - top + 1
			for yy in range(write, top - 1, -1):
				var i := idx(Vector2i(x, yy))
				token[i] = Token.ORE
				ore[i] = _surface_type(i)
				trail[i] = [Vector2(x, yy - drop - int(waves.get(x, 0))), Vector2(x, yy)]
				fresh[i] = top
				moved = true
			if drop > 0:
				waves[x] = int(waves.get(x, 0)) + drop
	return moved


## The column above (x, y) opens to the sky: y is the top row, or every cell above is bedrock
## (cut out of the board's silhouette). With spawn_top, only the top row.
func _sky_above(x: int, y: int) -> bool:
	for yy in range(y - 1, -1, -1):
		if cfg.spawn_top or terrain[idx(Vector2i(x, yy))] != Terrain.BEDROCK:
			return false
	return true


## Diagonal fill (Candy Crush, Royal Match), one pass, bottom row first: an empty open cell
## whose cell above can't feed it (rock, bedrock, a caged gem, the robot) takes a gem from
## above-left or above-right that can't fall straight itself. `left_first` alternates the side,
## so neither drifts. Runs only once straight drops are done. True if anything slid.
func _slide_diagonal(shelf: Dictionary, left_first: bool, trail: Dictionary, fresh: Dictionary) -> bool:
	var taken := {}
	for y in range(H - 1, 0, -1):
		for x in W:
			var to := Vector2i(x, y)
			var ti := idx(to)
			if not _open(to) or ti == robot or token[ti] != Token.NONE or shelf.has(ti):
				continue
			var up := to + Vector2i(0, -1)
			if _open(up) and idx(up) != robot:
				continue  # it fills straight from above
			for dx in ([-1, 1] if left_first else [1, -1]):
				var from := to + Vector2i(dx, -1)
				if not _open(from):
					continue
				var fi := idx(from)
				if fi == robot or taken.has(fi) or token[fi] == Token.NONE or shelf.has(fi):
					continue
				var below := from + Vector2i(0, 1)
				if _open(below) and idx(below) != robot and token[idx(below)] == Token.NONE:
					continue  # it falls straight instead
				_carry(fi, ti, trail, fresh)
				taken[ti] = true
				taken[fi] = true
				break
	return not taken.is_empty()


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
	claimed.clear()
	for cc in [ib, c]:
		if token[cc] == Token.CHARGE:
			Powers.fire(self, cc, d if cc == ib else -d, out.steps)
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
	var others := []
	while not queue.is_empty():
		var c0: int = queue.pop_front()
		if done.has(c0):
			continue
		done[c0] = true
		stats.blasts += 1
		var step := {"type": "blast", "center": c0, "radius": cfg.blast_radius,
				"cells": [], "revealed": [], "surfaced": [], "obstacles": []}
		var seen := {}
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
				if _strike(i, Obstacles.Hit.POWER, cfg.blast_rock, step, seen):
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
						step.cells.append(i)
						if spec[i] == Special.BLAST:
							token[i] = Token.NONE
							queue.append(i)
						else:
							others.append(i)  # another power-up goes off as itself, after
		_push(steps, step)
	for i in others:
		var dv := pos(i) - pos(center)
		Powers.fire(self, i, Vector2i(0, 1) if absi(dv.x) >= absi(dv.y) else Vector2i(1, 0), steps)


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
	# a 2x2 square of one colour matches too (it leaves a Scout drone)
	for y in H - 1:
		for x in W - 1:
			var sq := _square(Vector2i(x, y))
			for c in sq:
				in_line[c] = true
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
			if _run_len(c, Vector2i(1, 0)) >= 3 or _run_len(c, Vector2i(0, 1)) >= 3 or not _square(c).is_empty():
				return true
	return false


## The 4 cells of the 2x2 square with top-left p, if they are gems of one colour; else [].
func _square(p: Vector2i) -> Array:
	var cells := [p, p + Vector2i(1, 0), p + Vector2i(0, 1), p + Vector2i(1, 1)]
	for q in cells:
		if not _is_ore(q) or ore[idx(q)] != ore[idx(p)]:
			return []
	return cells.map(func(q): return idx(q))


# --- search (hint, generator check, bots) -----------------------------------

## The cell a step from c in direction d reaches, or -1 (edge, bedrock). A portal links its
## source to its destination both ways: down out of the source drops into the destination,
## up out of the destination climbs back into the source.
## The cells the robot can walk to from where it stands (rock, bedrock, obstacle pieces and
## caged gems wall it in): the part of the board it can play now. A board cut into rooms opens
## room by room as their gates break (Royal Match's board evolution). Robot-less: everything.
func reach() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(W * H)
	if robot < 0:
		out.fill(1)
		return out
	var stack := [robot]
	out[robot] = 1
	while not stack.is_empty():
		var c: int = stack.pop_back()
		for d in DIRS:
			var n := step_to(c, d)
			if n >= 0 and out[n] == 0 and can_enter(n):
				out[n] = 1
				stack.append(n)
	return out


## The robot (or a path) can step onto cell i: open ground, not a caged gem.
func can_enter(i: int) -> bool:
	return terrain[i] == Terrain.GROUND and not obs.locked(i)


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
				if not can_enter(ti):
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
				if not can_enter(ti):
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
				if not can_enter(ti) or routes.has(ti):
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
				if not can_enter(ti) or prev.has(ti):
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
	# a 2x2 square through c
	for corner in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var tl: Vector2i = p + corner
		var all := true
		for q in [tl, tl + Vector2i(1, 0), tl + Vector2i(0, 1), tl + Vector2i(1, 1)]:
			if not inside(q) or terrain[idx(q)] != Terrain.GROUND or tk[idx(q)] != Token.ORE or orr[idx(q)] != kind:
				all = false
				break
		if all:
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
	b.obs = obs.clone()
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
		"core": return stats.cores
		"generator", "cage", "web": return obs.count_finished(g.type)
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
		"treasure_coin": treasure_coin, "obstacles": obs.snapshot(), "reach": reach(),
		"progress": goals.map(func(g): return goal_progress(g)),
	}
