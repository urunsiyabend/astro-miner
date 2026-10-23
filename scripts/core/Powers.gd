class_name Powers
extends RefCounted

## Power-ups: what shape makes which, what each does, how they set each other off (chains) and
## how two or more merge on one path (combos). The Board calls in here when a power-up goes off
## and reports every cell it reaches through Board._strike, like any other hit, so obstacles
## need no power-up code. Design: docs/design/powerups.md.
##   Pulsar     4 in a row: twin beams both ways along the axis it was pushed, through rock
##              (a layer each)
##   Nova       an L or T: a 5x5 blast
##   Black hole 5 in a row: swallows every gem of the colour of the gem the robot swapped just
##              before it (Royal Match's Light Ball takes the colour it is swapped with); with
##              none (the path's first step, a chain, a pad), the most common colour
##   Scout drone a 2x2 square: hits its 4 neighbours, then flies to the most useful cell
## A power-up that another's effect reaches goes off too, one link after the other; a chained
## Pulsar fires across the line that hit it, so a chain never wastes it on a cleared line.
## A long chain goes off in waves of WAVE: between them the board settles and refills (Candy
## Crush's wrapped candy waits for the drop before its second blast), so the next wave hits
## what fell in. docs/research/match3-refill-during-combos.md

const S := Board.Special
## which of two merged power-ups leads a combo
const STRENGTH := {S.BLACKHOLE: 4, S.NOVA: 3, S.PULSAR: 2, S.DRONE: 1, S.BLAST: 0}
const WAVE := 3  # power-ups in a chain that go off before the board settles again


## The power-up a match leaves by its shape, or -1 (a plain line of 3, or a bent 4): 5 or more
## in a row a Black hole, a row and a column of 3 crossing a Nova, 4 in a row a Pulsar, a 2x2
## square a Scout drone.
static func by_shape(cells: Array) -> int:
	var set := {}
	for c in cells:
		set[Board.pos(c)] = true
	var row := 0
	var col := 0
	for p in set:
		row = maxi(row, _run(set, p, Vector2i(1, 0)))
		col = maxi(col, _run(set, p, Vector2i(0, 1)))
	if maxi(row, col) >= 5:
		return S.BLACKHOLE
	if row >= 3 and col >= 3:
		return S.NOVA
	if maxi(row, col) >= 4:
		return S.PULSAR
	for p in set:
		if set.has(p + Vector2i(1, 0)) and set.has(p + Vector2i(0, 1)) and set.has(p + Vector2i(1, 1)):
			return S.DRONE
	return -1


static func _run(set: Dictionary, p: Vector2i, d: Vector2i) -> int:
	if set.has(p - d):
		return 0  # counted from the run's first cell
	var n := 0
	while set.has(p + d * n):
		n += 1
	return n


# --- going off ---------------------------------------------------------------------------

## The power-up on cell c goes off, pushed along `axis` (a DIRS vector), and everything it sets
## off after it: a queue of [cell, axis], drained in order (each one a step: link 1, 2, ...).
static func fire(b: Board, c: int, axis: Vector2i, steps: Array, colour := -1) -> void:
	_drain(b, [[c, axis, colour]], steps)


## The colour a Black hole swallows: the one it was brought in with, else the most common
## (-1 for any other power-up, or a board with no gems).
static func swallow_colour(b: Board, kind: int, colour: int) -> int:
	if kind != S.BLACKHOLE:
		return -1
	if colour >= 0:
		return colour
	var top := _common_colours(b, 1)
	return top[0] if not top.is_empty() else -1


static func _drain(b: Board, queue: Array, steps: Array, link := 0) -> void:
	var queued := {}
	for job in queue:
		queued[job[0]] = true
	var fired := 0
	while not queue.is_empty():
		if fired >= WAVE and b.cfg.gravity:
			# a wave is done: the board settles and refills, and what is still to go off is
			# found where it fell to (a cell queued but already gone off can take a new one)
			fired = 0
			var went: Dictionary = b._gravity(steps)
			b.claimed.clear()
			queued.clear()
			for jb in queue:
				jb[0] = went.get(jb[0], jb[0])
				queued[jb[0]] = true
		var job: Array = queue.pop_front()
		var c: int = job[0]
		if b.token[c] != Board.Token.CHARGE:
			continue
		link += 1
		fired += 1
		if b.spec[c] == S.BLAST:
			b.token[c] = Board.Token.NONE
			b._blast(c, steps)
			continue
		var kind := b.spec[c]
		var step := _new_step(b, kind, c, job[1], link)
		b.token[c] = Board.Token.NONE
		b.stats.blasts += 1
		effect(b, kind, c, job[1], step, queue, queued, int(job[2]) if job.size() > 2 else -1)
		b._push(steps, step)


static func _new_step(b: Board, kind: int, c: int, axis: Vector2i, link: int) -> Dictionary:
	return {"type": "special", "kind": kind, "at": c, "dir": Board.DIRS.find(axis), "rays": [],
			"area": [], "sucked": [], "flights": [], "hit": [], "cracked": [], "revealed": [],
			"turned": [], "obstacles": [], "ore": b.ore[c], "link": link, "combo": ""}


## What `kind` does at cell c (its token is already gone): every cell it reaches is hit, and a
## power-up it reaches is queued to go off next.
static func effect(b: Board, kind: int, c: int, axis: Vector2i, step: Dictionary, queue: Array, queued: Dictionary, colour := -1) -> void:
	var seen := {}  # one power-up hits a multi-cell obstacle once
	match kind:
		S.PULSAR:
			_lines(b, c, axis, 1, step, seen, queue, queued)
		S.NOVA:
			_area(b, c, 2, step, seen, queue, queued)
		S.BLACKHOLE:
			var k := swallow_colour(b, kind, colour)
			step.colour = k
			if k >= 0:
				_swallow(b, c, k, step, seen, queue, queued)
		S.DRONE:
			_drone(b, c, -1, step, seen, queue, queued)


## Beams both ways along `axis` through c, `width` lines wide (1, 3, 5: a combo is wider).
static func _lines(b: Board, c: int, axis: Vector2i, width: int, step: Dictionary, seen: Dictionary, queue: Array, queued: Dictionary) -> void:
	var side := Vector2i(axis.y, axis.x)
	var cp := Board.pos(c)
	for k in range(-(width / 2), width / 2 + 1):
		var start := cp + side * k
		if not Board.inside(start):
			continue
		var s := Board.idx(start)
		if k != 0:
			_hit(b, s, c, step, seen, queue, queued)
		for d in [axis, -axis]:
			var p: Vector2i = start + d
			var last := s
			while Board.inside(p) and b.terrain[Board.idx(p)] != Board.Terrain.BEDROCK:
				last = Board.idx(p)
				_hit(b, last, c, step, seen, queue, queued)
				p += d
			step.rays.append([s, last])


## Every cell within `r` (a square) of c.
static func _area(b: Board, c: int, r: int, step: Dictionary, seen: Dictionary, queue: Array, queued: Dictionary) -> void:
	var cp := Board.pos(c)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := cp + Vector2i(dx, dy)
			if (dx != 0 or dy != 0) and Board.inside(p):
				step.area.append(Board.idx(p))
				_hit(b, Board.idx(p), c, step, seen, queue, queued)


## Every gem of colour k is pulled into the black hole. The gems it takes count as a match
## for what is next to them (Candy Crush's colour bomb: frosting "can't be destroyed unless a
## candy next to it is destroyed by the colour bomb"): rock beside a swallowed gem cracks, once.
static func _swallow(b: Board, c: int, k: int, step: Dictionary, seen: Dictionary, queue: Array, queued: Dictionary) -> void:
	var taken := {}
	for i in Board.W * Board.H:
		if i != c and b.terrain[i] == Board.Terrain.GROUND and b.token[i] == Board.Token.ORE and b.ore[i] == k:
			step.sucked.append(i)
			taken[i] = true
			_hit(b, i, c, step, seen, queue, queued)
	var touched := {}
	for i in taken:
		for d in Board.DIRS:
			var nb: Vector2i = Board.pos(i) + d
			if Board.inside(nb) and not taken.has(Board.idx(nb)) and Board.idx(nb) != c:
				touched[Board.idx(nb)] = true
	var next_seen := {}
	for nb in touched:
		b._strike(nb, Obstacles.Hit.NEXT, b.cfg.crack_power, step, next_seen)


## The `n` most common gem colours on the board, most common first (ties: the lower colour).
static func _common_colours(b: Board, n: int) -> Array:
	var count := []
	count.resize(Board.ORE_TYPES)
	count.fill(0)
	for i in Board.W * Board.H:
		if b.terrain[i] == Board.Terrain.GROUND and b.token[i] == Board.Token.ORE:
			count[b.ore[i]] += 1
	var kinds := range(Board.ORE_TYPES)
	kinds.sort_custom(func(x, y): return count[x] > count[y] or (count[x] == count[y] and x < y))
	return kinds.slice(0, n).filter(func(k): return count[k] > 0)


## A power-up reaches cell i (from the one at src): rock or an obstacle takes the hit; a
## power-up there is queued to go off (a Pulsar across the line from src); a gem or pickup is
## taken. The robot is never hit.
static func _hit(b: Board, i: int, src: int, step: Dictionary, seen: Dictionary, queue: Array, queued: Dictionary) -> void:
	if i == b.robot:
		return
	b.claimed[i] = true
	if b._strike(i, Obstacles.Hit.POWER, 1, step, seen):
		return
	if b.terrain[i] != Board.Terrain.GROUND:
		return
	if b.token[i] == Board.Token.CHARGE:
		if not queued.has(i):
			queued[i] = true
			var dv := Board.pos(i) - Board.pos(src)
			var away := Vector2i(signi(dv.x), 0) if absi(dv.x) >= absi(dv.y) else Vector2i(0, signi(dv.y))
			queue.append([i, Vector2i(away.y, away.x) if away != Vector2i.ZERO else Vector2i(0, -1)])
		return
	if b._take(i):
		step.hit.append(i)


# --- the scout drone -----------------------------------------------------------------------

## Take-off: the 4 neighbours of c are hit. Then the drone flies to the most useful cell left
## (target) and hits it; carrying another power-up (`carry`), that one goes off there instead.
static func _drone(b: Board, c: int, carry: int, step: Dictionary, seen: Dictionary, queue: Array, queued: Dictionary, takeoff := true) -> void:
	if takeoff:
		for d in Board.DIRS:
			var p: Vector2i = Board.pos(c) + d
			if Board.inside(p):
				_hit(b, Board.idx(p), c, step, seen, queue, queued)
	var aim := target(b, carry)
	if aim.is_empty():
		return
	var t: int = aim[0]
	step.flights.append([c, t, carry])
	b.claimed[t] = true
	# it hits where it lands; carrying a power-up, that one goes off there too (Homescapes' plane
	# "clears a Level Goal, then activates swapped Power-up")
	_hit(b, t, c, step, {}, queue, queued)
	if carry >= 0:
		effect(b, carry, t, aim[1], step, queue, queued)


## Where a drone goes: not the nearest cell, the most useful one (Candy Crush's fish: "whichever
## tile will bring the player the closest to their goal"). Cells already hit this move are left
## alone. Carrying a power-up, a landing cell is worth everything that power-up would reach.
## Returns [cell, axis] or [] (nothing worth it).
static func target(b: Board, carry := -1) -> Array:
	var best := []
	var best_v := 0.0
	for i in Board.W * Board.H:
		if b.claimed.has(i) or i == b.robot or b.terrain[i] == Board.Terrain.BEDROCK:
			continue
		var axis := Vector2i(0, -1)
		var v := 0.0
		match carry:
			S.PULSAR:
				var vr := _footprint(b, i, Vector2i(1, 0))
				var vc := _footprint(b, i, Vector2i(0, 1))
				v = maxf(vr, vc)
				axis = Vector2i(1, 0) if vr >= vc else Vector2i(0, 1)
			S.NOVA:
				v = _footprint(b, i, Vector2i.ZERO)
			_:
				v = value(b, i)
		if v <= 0.0:
			continue
		v += _noise(b, i)
		if v > best_v:
			best_v = v
			best = [i, axis]
	return best


## What a carried power-up landing on i would reach: a Pulsar's line (axis), a Nova's 5x5.
static func _footprint(b: Board, i: int, axis: Vector2i) -> float:
	var v := maxf(0.0, value(b, i))
	var cp := Board.pos(i)
	if axis == Vector2i.ZERO:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var p := cp + Vector2i(dx, dy)
				if (dx != 0 or dy != 0) and Board.inside(p):
					v += maxf(0.0, value(b, Board.idx(p)))
		return v
	for d in [axis, -axis]:
		var p: Vector2i = cp + d
		while Board.inside(p):
			v += maxf(0.0, value(b, Board.idx(p)))
			p += d
	return v


## How useful a hit on cell i is for this dig's goals (docs/design/powerups.md):
##   1000  it moves an unfinished goal on (a rock it asks for, the rock over a crystal, a
##         generator, a cage, the cell holding an energy core up, a gem of an asked colour: 300)
##    500  any other obstacle
##     10  a gem; 50 another power-up (a chain)
##   +300  the hit finishes the obstacle (its last layer or charge)
##   +100  nothing can step next to it (walled in): the cells a player can't reach
## <= 0 for cells a hit can't help (a finished generator, an energy core, empty floor).
static func value(b: Board, i: int) -> float:
	if b.claimed.has(i) or i == b.robot:
		return 0.0
	var v := 0.0
	match b.terrain[i]:
		Board.Terrain.BEDROCK:
			return 0.0
		Board.Terrain.ROCK:
			v = 1000.0 if _wants(b, "rock") or (b.buried[i] == Board.Buried.CRYSTAL and _wants(b, "crystal")) \
					or b.buried[i] == Board.Buried.TREASURE else 500.0
			if b.hp[i] <= 1:
				v += 300.0
		Board.Terrain.BLOCK:
			var id := b.obs.target(i, Obstacles.Hit.POWER)
			if id < 0:
				return 0.0
			var it: Dictionary = b.obs.items[id]
			v = 1000.0 if _wants(b, Obstacles.KINDS[it.kind].goal) else 500.0
			if int(it.left) <= 1:
				v += 300.0
		Board.Terrain.GROUND:
			var web := b.obs.floor_target(i, Obstacles.Hit.POWER)
			if web >= 0:
				var wi: Dictionary = b.obs.items[web]
				v = (1000.0 if _wants(b, Obstacles.KINDS[wi.kind].goal) else 300.0) + (300.0 if int(wi.left) <= 1 else 0.0)
			if b.obs.locked(i):
				v = (1000.0 if _wants(b, "cage") else 500.0) + 300.0
			else:
				match b.token[i]:
					Board.Token.ORE:
						v = maxf(v, 10.0)
						if _wants(b, "ore", b.ore[i]):
							v = maxf(v, 300.0)
						var up := Board.pos(i) + Vector2i(0, -1)
						if Board.inside(up) and b.token[Board.idx(up)] == Board.Token.CORE and _wants(b, "core"):
							v = maxf(v, 1000.0)
					Board.Token.CRYSTAL:
						v = maxf(v, 1000.0 if _wants(b, "crystal") else 100.0)
					Board.Token.CHARGE:
						v = maxf(v, 50.0)
					_:
						if v <= 0.0:
							return 0.0
	var open := false
	for d in Board.DIRS:
		var p: Vector2i = Board.pos(i) + d
		if Board.inside(p) and b.can_enter(Board.idx(p)):
			open = true
	if not open:
		v += 100.0
	return v


static func _wants(b: Board, type: String, colour := -1) -> bool:
	for g in b.goals:
		if g.type == type and (colour < 0 or int(g.get("ore", -1)) == colour) and b.goal_progress(g) < g.n:
			return true
	return false


## A tie-break that never touches the dig's random stream (what falls in stays the same).
static func _noise(b: Board, i: int) -> float:
	return float((i * 7919 + int(b.stats.moves) * 104729) % 97) / 97.0


# --- combos: power-ups merged on one path -----------------------------------------------------

## Names the view calls out, by the two leading power-ups and the tier.
static func combo_name(kinds: Array) -> String:
	var k := _sorted(kinds)
	if k.size() >= 4:
		return "BIG BANG"
	var a: int = k[0]
	var c: int = k[1]
	var big := k.size() == 3
	if a == S.BLACKHOLE and c == S.BLACKHOLE:
		return "EVENT HORIZON"
	if a == S.BLACKHOLE:
		return "DOUBLE COLLAPSE" if big else "COLLAPSE"
	if a == S.NOVA and c == S.NOVA:
		return "HYPERNOVA" if big else "SUPERNOVA"
	if a == S.NOVA and c == S.PULSAR:
		return "MEGA FLARE" if big else "FLARE"
	if a == S.PULSAR and c == S.PULSAR:
		return "STAR CROSS" if big else "CROSS"
	if c == S.DRONE and a != S.DRONE:
		return "SQUADRON" if big else "PAYLOAD"
	return "SWARM" if big else "TRIO"


static func _sorted(kinds: Array) -> Array:
	var k := kinds.duplicate()
	k.sort_custom(func(x, y): return STRENGTH[x] > STRENGTH[y])
	return k


## Two or more power-ups dragged on one path merge into the last one (at) and go off as one,
## pushed along `axis`. Two: Royal Match's combo table in our pieces; each extra one raises it
## a tier ("doubled"); four: the Big Bang. Then whatever they set off chains on.
static func combo(b: Board, at: int, axis: Vector2i, kinds: Array, steps: Array, colour := -1) -> void:
	var k := _sorted(kinds)
	var tier := mini(k.size() - 1, 3)  # 1 pair, 2 three, 3 four
	var a: int = k[0]
	var c: int = k[1]
	var step := _new_step(b, a, at, axis, 1)
	step.combo = combo_name(kinds)
	step.kinds = k
	b.stats.blasts += 1
	var seen := {}
	var queue := []
	var queued := {}
	if tier >= 3 or (a == S.BLACKHOLE and c == S.BLACKHOLE):
		for i in Board.W * Board.H:  # the whole board, a layer off every obstacle
			if Board.inside(Board.pos(i)) and i != at:
				step.area.append(i)
				_hit(b, i, at, step, seen, queue, queued)
	elif a == S.BLACKHOLE:
		# a colour (two, for three power-ups) turns into copies of the other one, and they all go off
		var flip := false
		var cols := _common_colours(b, tier)
		if colour >= 0:  # the colour it was brought in with leads, the most common follows
			cols = ([colour] + _common_colours(b, tier + 1).filter(func(k): return k != colour)).slice(0, tier)
		for col in cols:
			for i in Board.W * Board.H:
				if b.terrain[i] == Board.Terrain.GROUND and b.token[i] == Board.Token.ORE and b.ore[i] == col \
						and not b.obs.locked(i) and i != b.robot:
					b.token[i] = Board.Token.CHARGE
					b.spec[i] = c
					step.turned.append(i)
					queue.append([i, Vector2i(1, 0) if flip else Vector2i(0, 1)])
					queued[i] = true
					flip = not flip
	elif a == S.NOVA and c == S.NOVA:
		_area(b, at, 4 if tier == 1 else maxi(Board.W, Board.H), step, seen, queue, queued)
	elif a == S.NOVA and c == S.PULSAR:
		var w := 3 if tier == 1 else 5
		_lines(b, at, Vector2i(1, 0), w, step, seen, queue, queued)
		_lines(b, at, Vector2i(0, 1), w, step, seen, queue, queued)
	elif a == S.PULSAR and c == S.PULSAR:
		var w2 := 1 if tier == 1 else 3
		_lines(b, at, Vector2i(1, 0), w2, step, seen, queue, queued)
		_lines(b, at, Vector2i(0, 1), w2, step, seen, queue, queued)
	elif c == S.DRONE:
		# drones: 3 (5 for three power-ups); one leading a stronger power-up carries it
		var carry := a if a != S.DRONE else -1
		var n := (1 if tier == 1 else 3) if carry >= 0 else (3 if tier == 1 else 5)
		for j in n:
			_drone(b, at, carry, step, seen if j == 0 else {}, queue, queued, j == 0)
	b._push(steps, step)
	_drain(b, queue, steps, 1)
