extends SceneTree

## Budgets for the movement prototypes (Sites.PROTOS), drawn paths of up to 4 steps:
##   godot --headless --path . -s res://tools/tune_proto.gd -- [runs]
## The path bot weighs every path each turn, so it plays like an expert, not like a person
## (who sees a handful). The budget is the smallest at which it clears 90%, plus 40% for
## people; recalibrate the margin from real plays.
const HUMAN_MARGIN := 1.4

func _initialize() -> void:
	var runs := 16
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
	var rules := Economy.rules([1, 1, 1, 1])
	rules.path_max = 4
	var out := []
	for site in Sites.protos():
		var lo := 3
		var hi := 60
		while lo < hi:
			var mid := (lo + hi) / 2
			if _rate(site, rules, mid, runs).rate >= 0.9:
				hi = mid
			else:
				lo = mid + 1
		var res := _rate(site, rules, lo, runs)
		var budget := int(ceil(lo * HUMAN_MARGIN))
		print("%-20s bot %2d (clear %3d%%, used %4.1f, launches %4.1f)  -> budget %d" % [site.title, lo,
				int(res.rate * 100), res.used, res.launches, budget])
		out.append(budget)
	print("PROTO_ENERGY ", out)
	quit(0)


func _rate(site: Dictionary, rules: Dictionary, budget: int, runs: int) -> Dictionary:
	var s := site.duplicate()
	s.energy = budget
	var wins := 0
	var used := 0.0
	var launches := 0.0
	for k in runs:
		var b := Board.new()
		b.record = false
		b.setup_site(s, 700 + k * 17, rules)
		var rng := RandomNumberGenerator.new()
		rng.seed = k
		var guard := 0
		while not b.over and guard < 200:
			guard += 1
			if b.first_step_to_match(5) == -1 and b.can_pulse():
				b.pulse()
				continue
			b.try_path(Bots.choose_path(b, Bots.Kind.SLOPPY, rng))
		launches += b.stats.launches
		if b.complete:
			wins += 1
			used += b.stats.moves
	return {"rate": float(wins) / runs, "used": used / maxi(1, wins), "launches": launches / runs}
