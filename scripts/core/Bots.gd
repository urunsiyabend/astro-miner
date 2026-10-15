class_name Bots
extends RefCounted

## Scripted players used by tests and the balance simulation. They are proxies for
## "careless", "reasonable" and "planning" humans, not models of real players.

enum Kind { RANDOM, GREEDY, PLANNER }


static func choose(b: Board, kind: int, rng: RandomNumberGenerator) -> Vector2i:
	match kind:
		Kind.RANDOM:
			return _random_dir(b, rng)
		Kind.GREEDY:
			return _best(b, rng, false)
		_:
			return _best(b, rng, true)


static func _random_dir(b: Board, rng: RandomNumberGenerator) -> Vector2i:
	var opts := _legal(b)
	if opts.is_empty():
		return Board.DIRS[0]
	return opts[rng.randi_range(0, opts.size() - 1)]


static func _legal(b: Board) -> Array:
	var out := []
	for d in Board.DIRS:
		var t: Vector2i = Board.pos(b.robot) + d
		if not Board.inside(t):
			continue
		var tt := b.terrain[Board.idx(t)]
		if tt == Board.Terrain.GROUND or (tt == Board.Terrain.ROCK and b.cfg.drill and b.energy >= b.cfg.drill_cost):
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


static func _value(b: Board, plan: bool) -> float:
	var v := 0.0
	for g in b.goals:
		var need: int = g.n
		var have := mini(b.goal_progress(g), need)
		v += have * 6.0
	v += b.stats.chunks * 0.5
	v += b.energy * 1.0
	# a match is worth making for its own sake (it digs, cracks rock, surfaces new ore); this
	# used to come from the energy a match refunded, before energy became a move budget
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
		var rp := Board.pos(b.robot)
		for i in Board.W * Board.H:
			if b.terrain[i] == Board.Terrain.ROCK:
				dmg -= b.hp[i]
			if b.token[i] == Board.Token.CRYSTAL or b.token[i] == Board.Token.CHARGE:
				var p := Board.pos(i)
				nearest = mini(nearest, absi(p.x - rp.x) + absi(p.y - rp.y))
		v += dmg * (1.5 if wants_rock else 0.3)
		if nearest < 99:
			v -= nearest * 1.2
	return v


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
		if b.first_step_to_match(5) == -1:
			stuck_turns += 1
			if kind != Kind.RANDOM and b.can_pulse():
				b.pulse()
				continue
		var d := choose(b, kind, rng)
		var r := b.try_move(d)
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
