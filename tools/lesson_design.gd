extends SceneTree

## Building a level of the journey (docs/design/journey.md, "How we build a level"):
##   godot --headless --path . -s res://tools/lesson_design.gd -- <mode> <site id> [moves...]
## Moves are drawn paths of U D L R letters ("URR"); for a guided level they are the hand's
## moves, played first.
##   scan   seeds 1-400 for the guided moves: prints the ones where they make no power-up
##          before its time and leave a match in reach, best cascades first. Options (after the
##          moves): specials=N (power-ups the moves must make, default 0), rocks=N (at most
##          this many rocks broken by them)
##   solve  a winning move list (the guided moves, then the path bot): for TUTORIAL_SOLUTIONS
##   rate   40 games of the SLOPPY path bot after the guided moves: clear rate and moves used
##          (budget = the site's, or budget=N); a site without a pinned seed gets fresh boards
## Then `tools/lesson_probe.gd` prints the board move by move.

const MAP := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: lesson_design.gd -- scan|solve|rate <site id> [moves...] [key=value...]")
		quit(1)
		return
	var site: Dictionary = Sites.get_site(Sites.index_of(args[1])).duplicate(true)
	var moves := []
	var opts := {}
	for k in range(2, args.size()):
		if "=" in args[k]:
			opts[args[k].get_slice("=", 0)] = int(args[k].get_slice("=", 1))
		else:
			moves.append(Array(args[k].split("", false)).map(func(ch): return MAP[ch]))
	if opts.has("budget"):
		site.energy = opts.budget
	match args[0]:
		"scan": _scan(site, moves, opts)
		"solve": _solve(site, moves)
		"rate": _rate(site, moves)
	quit(0)


static func _board(site: Dictionary, seed_value: int) -> Board:
	var rules := Economy.rules([1, 1, 1, 1])
	rules.path_max = int(site.get("path_max", 4))
	var b := Board.new()
	b.record = false
	b.setup_site(site, seed_value, rules)
	return b


static func _word(dirs: Array) -> String:
	var w := ""
	for d in dirs:
		for ch in MAP:
			if MAP[ch] == d:
				w += ch
	return w


func _scan(site: Dictionary, moves: Array, opts: Dictionary) -> void:
	var found := []
	for sd in range(1, 401):
		site.seed = sd
		var b := _board(site, 0)
		var lines := []
		var ok := true
		for m in moves:
			var g0: int = b.stats.groups
			if not b.try_path(m).ok:
				ok = false
				break
			lines.append(b.stats.groups - g0)
		if not ok or b.stats.charges_made != int(opts.get("specials", 0)):
			continue
		if opts.has("rocks") and b.stats.rocks_broken > int(opts.rocks):
			continue
		if b.path_to_match(4).is_empty():
			continue  # the first free move must have something to do
		found.append([b.stats.cascade_groups, sd, lines, b.goals.map(func(g): return b.goal_progress(g))])
	found.sort_custom(func(x, y): return x[0] > y[0])
	for f in found.slice(0, 10):
		print("seed %d: lines %s, cascades %d, goals %s" % [f[1], f[2], f[0], f[3]])


func _solve(site: Dictionary, moves: Array) -> void:
	var best := []
	for t in 30:
		var b := _board(site, 0)
		var words := []
		for m in moves:
			b.try_path(m)
			words.append(_word(m))
		var rng := RandomNumberGenerator.new()
		rng.seed = t
		while not b.over:
			var dirs := Bots.choose_path(b, Bots.Kind.PLANNER if t == 0 else Bots.Kind.SLOPPY, rng)
			if not b.try_path(dirs).ok:
				break
			words.append(_word(dirs))
		if b.complete and (best.is_empty() or words.size() < best.size()):
			best = words
	print("solution: %s (%d moves)" % [best, best.size()] if not best.is_empty() else "no solution in 30 games")


func _rate(site: Dictionary, moves: Array) -> void:
	var used := []
	var wins := 0
	for t in 40:
		var b := _board(site, 500 + t * 17)
		for m in moves:
			b.try_path(m)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + t
		while not b.over:
			if not b.try_path(Bots.choose_path(b, Bots.Kind.SLOPPY, rng)).ok:
				break
		if b.complete:
			wins += 1
			used.append(b.stats.moves)
	used.sort()
	if used.is_empty():
		print("%s: SLOPPY path bot cleared 0/40 (budget %d)" % [site.id, int(site.get("energy", 20))])
		return
	print("%s: SLOPPY path bot cleared %d/40, moves used min %d median %d max %d (budget %d)" % [site.id,
			wins, used[0], used[used.size() / 2], used[-1], int(site.get("energy", 20))])
