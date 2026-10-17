extends SceneTree

## Level check for the campaign.
##   godot --headless --path . -s res://tools/levels.gd -- [runs] [id[:PREFIX] ...]
## A PREFIX (e.g. first:U) makes the solver start with the moves Mira asks for.
## For every dig (or only the ids given), with the buildings a player has at that point:
## - random-ore digs: GREEDY and PLANNER clear rate over `runs` seeds, energy left on wins and
##   goal progress on losses (the tuning signals from docs/research/match3-level-design.md);
## - hand-made digs ("ore" layout): a beam search for a solution, printed as a move string.

const NAMES := {Vector2i(0, -1): "U", Vector2i(1, 0): "R", Vector2i(0, 1): "D", Vector2i(-1, 0): "L"}


func _initialize() -> void:
	var runs := 40
	var only := []
	var prefix := {}
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
		else:
			var parts: PackedStringArray = a.split(":")
			only.append(parts[0])
			if parts.size() > 1:
				prefix[parts[0]] = parts[1]
	for i in Sites.count():
		var site := Sites.get_site(i)
		if not only.is_empty() and not only.has(site.id):
			continue
		var levels := campaign_levels(i)
		var rules := Economy.rules(levels)
		var head := "%2d %-10s" % [i + 1, site.id]
		if site.has("ore"):
			var sol := solve(site, rules, prefix.get(site.id, ""))
			print("%s hand-made   solution: %s" % [head, sol if sol != "" else "NONE FOUND"])
			continue
		var parts := []
		for kind in [Bots.Kind.GREEDY, Bots.Kind.PLANNER]:
			var wins := 0
			var left := 0
			var prog := 0.0
			for s in runs:
				var m := _play(site, rules, 1000 + s, kind)
				if m.complete:
					wins += 1
					left += m.energy_left
				else:
					prog += m.progress
			var lost := runs - wins
			parts.append("%s %3d%% (left %4.1f, lost at %3d%%)" % [
				"greedy" if kind == Bots.Kind.GREEDY else "planner", wins * 100 / runs,
				float(left) / maxi(1, wins), int(100.0 * prog / maxi(1, lost))])
		print("%s %s" % [head, "   ".join(parts)])
	quit(0)


## Building levels a player has at campaign dig i: Star = digs cleared (GDD v4), so every
## building whose star milestone is at most i is up, at level 1.
static func campaign_levels(i: int) -> Array:
	var lv := [0, 0, 0, 0]
	for b in Economy.BUILDINGS.size():
		if i >= Economy.STAR_UNLOCK[b]:
			lv[b] = 1
	return lv


func _play(site: Dictionary, rules: Dictionary, seed_value: int, kind: int) -> Dictionary:
	var b := Board.new()
	b.record = false
	b.setup_site(site, seed_value, rules)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + kind
	var rejected := 0
	for t in 300:
		if b.over:
			break
		if b.first_step_to_match(5) == -1 and b.can_pulse():
			b.pulse()
			continue
		if not b.try_move(Bots.choose(b, kind, rng)).ok:
			rejected += 1
			if rejected > 20:
				break
	var p := 0.0
	for g in b.goals:
		p += minf(1.0, float(b.goal_progress(g)) / g.n)
	return {"complete": b.complete, "energy_left": b.energy, "progress": p / b.goals.size()}


## Beam search over move strings; hand-made digs pin their seed, so a replay is exact.
static func solve(site: Dictionary, rules: Dictionary, prefix := "", width := 400, depth := 70) -> String:
	var root := Board.new()
	root.record = false
	root.setup_site(site, 0, rules)
	var dirs := {"U": Vector2i(0, -1), "R": Vector2i(1, 0), "D": Vector2i(0, 1), "L": Vector2i(-1, 0)}
	for ch in prefix:
		if not root.try_move(dirs[ch]).ok or (root.over and not root.complete):
			return ""
		if root.complete:
			return prefix
	var frontier := [[root, prefix]]
	var seen := {}
	for step in depth:
		var scored := []
		for item in frontier:
			for d in Board.DIRS:
				var b: Board = item[0].clone()
				if not b.try_move(d).ok:
					continue
				var path: String = item[1] + NAMES[d]
				if b.complete:
					return path
				if b.over:
					continue
				var key := "%d|%d|%s|%s|%s" % [b.robot, b.energy, str(b.token), str(b.ore), str(b.hp)]
				if seen.has(key):
					continue
				seen[key] = true
				scored.append([Bots._value(b, true), b, path])
		if scored.is_empty():
			return ""
		scored.sort_custom(func(x, y): return x[0] > y[0])
		frontier = []
		for k in mini(width, scored.size()):
			frontier.append([scored[k][1], scored[k][2]])
	return ""
