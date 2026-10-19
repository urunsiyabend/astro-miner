class_name Bots
extends RefCounted

## Scripted players used by tests and the balance simulation. They are proxies for
## "careless", "reasonable" and "planning" humans, not models of real players.

## SLOPPY: the planner wasting a move now and then (12% random), the human proxy for tuning.
enum Kind { RANDOM, GREEDY, PLANNER, SLOPPY }
const SLOPPY_RATE := 0.12


static func choose(b: Board, kind: int, rng: RandomNumberGenerator) -> Vector2i:
	match kind:
		Kind.RANDOM:
			return _random_dir(b, rng)
		Kind.GREEDY:
			return _best(b, rng, false)
		Kind.SLOPPY:
			return _random_dir(b, rng) if rng.randf() < SLOPPY_RATE else _plan(b, rng)
		_:
			return _plan(b, rng)


## Drawn paths (cfg.path_max > 1): every path up to path_max steps (no straight backtrack) is
## played on a clone (fresh surfacing RNG) and scored by the planner's value, as a player
## weighing where to draw; a single step can still drill. SLOPPY draws a random path now and
## then. Returns the path's directions.
static func choose_path(b: Board, kind: int, rng: RandomNumberGenerator) -> Array:
	var paths := []
	_paths_from(b, b.robot, -1, [], paths)
	for d in _legal(b):
		var ti := b.step_to(b.robot, d)
		if ti >= 0 and b.terrain[ti] == Board.Terrain.ROCK:
			paths.append([d])  # a drill bump
	if paths.is_empty():
		return [Board.DIRS[0]]
	if kind == Kind.RANDOM or (kind == Kind.SLOPPY and rng.randf() < SLOPPY_RATE):
		return paths[rng.randi_range(0, paths.size() - 1)]
	var base := _value(b, true)
	var seed := rng.randi()
	var best: Array = paths[0]
	var best_s := -INF
	for p in paths:
		var c := b.clone()
		c.rng.seed = seed
		if not c.try_path(p).ok:
			continue
		var s := _value(c, true) - base
		if c.complete:
			s += 1000.0
		s += rng.randf() * 0.01
		if s > best_s:
			best_s = s
			best = p
	return best


static func _paths_from(b: Board, at: int, prev: int, cur: Array, out: Array) -> void:
	if cur.size() >= b.cfg.path_max:
		return
	for d in Board.DIRS:
		var ti := b.step_to(at, d)
		if ti < 0 or ti == prev or not b.can_enter(ti):
			continue
		var next: Array = cur.duplicate()
		next.append(d)
		out.append(next)
		_paths_from(b, ti, at, next, out)


static func _random_dir(b: Board, rng: RandomNumberGenerator) -> Vector2i:
	var opts := _legal(b)
	if opts.is_empty():
		return Board.DIRS[0]
	return opts[rng.randi_range(0, opts.size() - 1)]


static func _legal(b: Board) -> Array:
	var out := []
	for d in Board.DIRS:
		var ti := b.step_to(b.robot, d)
		if ti < 0:
			continue
		var tt := b.terrain[ti]
		if b.can_enter(ti) or (tt == Board.Terrain.ROCK and b.cfg.drill and b.energy >= b.cfg.drill_cost):
			out.append(d)
	return out


## Evaluate each legal move on a clone whose surfacing RNG is reseeded, so bots
## cannot peek at future ore.
static func _best(b: Board, rng: RandomNumberGenerator, plan: bool) -> Vector2i:
	var opts := _legal(b)
	if opts.is_empty():
		return Board.DIRS[0]
	var base := _value(b, plan)
	var best_d: Vector2i = opts[0]
	var best_s := -INF
	for d in opts:
		var c := b.clone()
		c.rng.seed = rng.randi()
		c.try_move(d)
		var s := _value(c, plan) - base
		if plan and not c.over:
			var p := c.path_to_match(3)
			s -= 0.8 * (p.size() if not p.is_empty() else 5)
		s += rng.randf() * 0.01
		if s > best_s:
			best_s = s
			best_d = d
	if not plan and best_s <= 0.05:
		var step := b.first_step_to_match(4)
		if step != -1:
			return Board.DIRS[step]
	return best_d


## PLANNER: thinks in short plans, as a player does, not single steps. Candidates are every
## line within reach, the walk to an open pickup, and (with the Drill) the walk to a rock worth
## opening plus the bumps to open it. Each plan is played out on a clone (fresh surfacing RNG,
## no peeking) and scored by value gained per move spent; the first step of the best is taken
## and the bot plans again next turn.
const PLAN_DEPTH := 4
const PLAN_MATCHES := 14


static func _plan(b: Board, rng: RandomNumberGenerator) -> Vector2i:
	var plans: Array = b.paths_to_matches(PLAN_DEPTH, PLAN_MATCHES)
	var pick := b.path_to_pickup(14)
	if not pick.is_empty():
		plans.append(pick)
	if b.cfg.drill:
		plans.append_array(_drill_plans(b))
	if plans.is_empty():
		return _best(b, rng, true)
	var base := _value(b, true)
	var best: Array = plans[0]
	var best_s := -INF
	var seed := rng.randi()
	for p in plans:
		var c := b.clone()
		c.rng.seed = seed
		var spent := 0
		for di in p:
			if c.over:
				break
			var e0 := c.energy
			if not c.try_move(Board.DIRS[di]).ok:
				break
			spent += maxi(1, e0 - c.energy)
		var s := (_value(c, true) - base) / maxf(1.0, spent)
		if c.complete:
			s += 1000.0
		s += rng.randf() * 0.01
		if s > best_s:
			best_s = s
			best = p
	return Board.DIRS[best[0]]


## With the Drill: for the nearest rocks worth opening (buried crystal, cell or chest, or any
## rock while a rock goal is open), walk to a side of it and bump until it breaks.
static func _drill_plans(b: Board) -> Array:
	var wants_rock := false
	for g in b.goals:
		if g.type == "rock" and b.goal_progress(g) < g.n:
			wants_rock = true
	var routes := b.walk_routes(14)
	var found := []
	for i in Board.W * Board.H:
		if b.terrain[i] != Board.Terrain.ROCK:
			continue
		var worth := wants_rock or b.buried[i] == Board.Buried.CRYSTAL \
				or b.buried[i] == Board.Buried.CELL or b.buried[i] == Board.Buried.TREASURE
		if not worth:
			continue
		var best_route: Array = []
		var best_dir := -1
		for di in 4:
			var side: Vector2i = Board.pos(i) - Board.DIRS[di]
			if not Board.inside(side) or not routes.has(Board.idx(side)):
				continue
			var r: Array = routes[Board.idx(side)]
			if best_dir == -1 or r.size() < best_route.size():
				best_route = r
				best_dir = di
		if best_dir == -1:
			continue
		var plan: Array = best_route.duplicate()
		for k in b.hp[i] + 1:  # the bumps, then the step in (picks up what it hid)
			plan.append(best_dir)
		found.append([best_route.size(), plan])
	found.sort_custom(func(x, y): return x[0] < y[0])
	var out := []
	for k in mini(5, found.size()):
		if not found[k][1].is_empty():
			out.append(found[k][1])
	return out


## Classic prototype: every swap that makes a line, played out on a clone (fresh surfacing
## RNG) and scored by the planner's value; RANDOM and the SLOPPY share pick a random one.
static func classic_choice(b: Board, kind: int, rng: RandomNumberGenerator) -> Array:
	var swaps := []
	for i in Board.W * Board.H:
		if not b._swappable(i):
			continue
		for di in [1, 2]:
			var p: Vector2i = Board.pos(i) + Board.DIRS[di]
			if not Board.inside(p) or not b._swappable(Board.idx(p)):
				continue
			var j := Board.idx(p)
			b._swap_cells(i, j)
			var ok := b.token[i] == Board.Token.CHARGE or b.token[j] == Board.Token.CHARGE \
					or b._line_through(b.token, b.ore, i) or b._line_through(b.token, b.ore, j)
			b._swap_cells(i, j)
			if ok:
				swaps.append([i, di])
	if swaps.is_empty():
		return []
	if kind == Kind.RANDOM or (kind == Kind.SLOPPY and rng.randf() < SLOPPY_RATE):
		return swaps[rng.randi_range(0, swaps.size() - 1)]
	var base := _value(b, true)
	var best: Array = swaps[0]
	var best_s := -INF
	var seed := rng.randi()
	for mv in swaps:
		var c := b.clone()
		c.rng.seed = seed
		c.try_swap(mv[0], Board.DIRS[mv[1]])
		var sc := _value(c, true) - base + (1000.0 if c.complete else 0.0) + rng.randf() * 0.01
		if sc > best_s:
			best_s = sc
			best = mv
	return best


static func _value(b: Board, plan: bool) -> float:
	var v := 0.0
	for g in b.goals:
		var need: int = g.n
		var have := mini(b.goal_progress(g), need)
		# a big goal item (crystal, rock, chest) must outweigh the walk to the next one, or picking
		# it up looks like a loss to the planner (the nearest target jumps further away)
		v += have * (6.0 if not plan or g.type == "ore" or g.type == "chunks" else 40.0)
	v += b.energy * 1.0
	if plan:
		# the planner plays for the goal: a stray match is worth little on its own (it digs and
		# surfaces new ore), the goal counters above carry what matters
		v += b.stats.chunks * 0.2
		v += b.stats.groups * 0.5
		v += b.stats.crystals * 2.0
	else:
		v += b.stats.chunks * 0.5
		# a match is worth making for its own sake (it digs, cracks rock, surfaces new ore)
		v += b.stats.groups * 2.0
		v += b.stats.crystals * 8.0
	if b.complete:
		v += 200.0
	if plan:
		# crack progress matters when goals live under rock
		var wants_rock := false
		for g in b.goals:
			if g.type != "ore":
				wants_rock = true
		var dmg := 0
		var nearest := 99
		if b.robot < 0:
			return v  # the classic prototype has no robot to route
		var dist := _walk_dist(b)
		for i in Board.W * Board.H:
			if b.terrain[i] == Board.Terrain.ROCK:
				dmg -= b.hp[i]
			# pickups in the open, and a crystal still buried (the crystal digs need the
			# route to it): distance along the board, walls and rock included
			var target := b.token[i] == Board.Token.CRYSTAL or b.token[i] == Board.Token.CHARGE \
					or (b.terrain[i] == Board.Terrain.ROCK and b.buried[i] == Board.Buried.CRYSTAL)
			if target and dist[i] >= 0:
				nearest = mini(nearest, dist[i])
		v += dmg * (1.5 if wants_rock else 0.3)
		# obstacles on their way to done (a generator charging, a cage cracking), and energy
		# cores on their way down to the docks, are progress the bot can see
		for it in b.obs.items:
			v -= int(it.left) * 3.0
		if not b.cfg.docks.is_empty():
			for i in Board.W * Board.H:
				if b.token[i] == Board.Token.CORE:
					v += Board.pos(i).y * 4.0
		if nearest < 99:
			# a crystal still owed to the goal is worth heading for: each step closer must beat the
			# move it costs, or the bot spends the budget on stray matches and stalls in sight of it
			var owed := false
			for g in b.goals:
				if g.type == "crystal" and b.goal_progress(g) < g.n:
					owed = true
			v -= nearest * (3.0 if owed else 1.2)
	return v


## Cost from the robot to every cell, in moves; -1 where unreachable. Bedrock is a wall. Rock
## costs what opening it takes: each layer is a drill bump (drill cost) once the Drill is
## built, else about 3 moves of matching beside it. Cost falls as the rock is worn down, so
## drilling or cracking toward a buried target is progress the bot can see.
static func _walk_dist(b: Board) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(Board.W * Board.H)
	d.fill(-1)
	d[b.robot] = 0
	var layer: int = int(b.cfg.drill_cost) if b.cfg.drill else 3
	var open := [b.robot]
	while not open.is_empty():
		# tiny board: pick the closest open cell by scan (Dijkstra without a heap)
		var bi := 0
		for k in open.size():
			if d[open[k]] < d[open[bi]]:
				bi = k
		var c: int = open[bi]
		open.remove_at(bi)
		for dir in Board.DIRS:
			var n := b.step_to(c, dir)
			if n < 0:
				continue
			var nd := d[c] + 1 + (b.hp[n] * layer if b.terrain[n] == Board.Terrain.ROCK else 0)
			if d[n] == -1 or nd < d[n]:
				d[n] = nd
				open.append(n)
	return d


## Play one full dig; returns a metrics dictionary.
static func play(site: Dictionary, rules: Dictionary, seed_value: int, kind: int, max_turns := 400) -> Dictionary:
	var b := Board.new()
	b.record = false
	b.setup_site(site, seed_value, rules)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + kind
	var turns := 0
	var stuck_turns := 0
	var rejected := 0
	while not b.over and turns < max_turns:
		if b.cfg.classic:
			var mv := classic_choice(b, kind, rng)
			if mv.is_empty():
				stuck_turns += 1
				if stuck_turns > 20:
					break
				b.shuffle_classic()
				continue
			if b.try_swap(mv[0], Board.DIRS[mv[1]]).ok:
				turns += 1
			else:
				rejected += 1
				if rejected > 20:
					break
			continue
		if b.first_step_to_match(5) == -1:
			stuck_turns += 1
			if kind != Kind.RANDOM and b.can_pulse():
				b.pulse()
				continue
		var r := {}
		if b.cfg.path_max > 1:
			r = b.try_path(choose_path(b, kind, rng))
		else:
			r = b.try_move(choose(b, kind, rng))
		if not r.ok:
			rejected += 1
			if rejected > 20:
				break
			continue
		turns += 1
	return {
		"complete": b.complete, "turns": turns, "moves": b.stats.moves, "drills": b.stats.drills,
		"groups": b.stats.groups, "cascades": b.stats.cascade_groups, "chunks": b.stats.chunks,
		"rocks": b.stats.rocks_broken, "crystals": b.stats.crystals, "charges": b.stats.charges_made,
		"blasts": b.stats.blasts, "haul": b.haul.duplicate(), "energy_left": b.energy,
		"stuck_turns": stuck_turns, "pulses": b.stats.pulses, "exhausted": (not b.complete) and b.energy <= 0,
	}
