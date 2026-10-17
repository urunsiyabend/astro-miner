extends SceneTree

## Move-budget tuner for GDD v4 §3. Each random-ore dig has a "tier" (Sites); the tier sets the
## first-attempt clear rate the SLOPPY bot (the planner wasting 12% of its moves: the human
## proxy) must reach. For every dig this binary-searches the smallest budget that reaches it,
## then reports how long a win takes and what is left on a win (target median 2-5).
##   godot --headless --path . -s res://tools/tune_v4.gd -- [runs] [id ...]
## Prints one line per dig and a ready-to-paste `"id": budget` list. Hand-made digs ("ore"
## layout) and gold rushes are skipped: their budget comes from their recorded solution.

const TARGET := {"intro": 0.92, "normal": 0.82, "breather": 0.88, "hard": 0.55,
		"superhard": 0.35, "reward": 0.95}
const LevelsTool := preload("res://tools/levels.gd")


func _initialize() -> void:
	var runs := 40
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
		else:
			only.append(a)
	var out := []
	for i in Sites.count():
		var site: Dictionary = Sites.get_site(i)
		if site.has("ore") or site.get("gold_rush", false):
			continue
		if not only.is_empty() and not only.has(site.id):
			continue
		var tier: String = site.get("tier", "normal")
		var target: float = TARGET.get(tier, 0.82)
		var rules := Economy.rules(LevelsTool.campaign_levels(i))
		var lo := 4
		var hi := 90
		var best := {}
		while lo < hi:
			var mid := (lo + hi) / 2
			var r := _rate(site, rules, mid, runs)
			if r.rate >= target:
				hi = mid
				best = r
			else:
				lo = mid + 1
		if best.is_empty() or best.budget != lo:
			best = _rate(site, rules, lo, runs)
		print("%2d %-9s %-9s c%d  target %3d%%  budget %2d  clear %3d%%  used %4.1f  left %4.1f" % [
			i, site.id, tier, int(site.get("colours", 3)), int(target * 100), lo, int(best.rate * 100),
			best.used, best.left])
		out.append('"%s": %d' % [site.id, lo])
	print("BUDGETS {" + ", ".join(out) + "}")
	quit(0)


## Clear rate of the sloppy bot with `budget` moves over `runs` fixed seeds, and the median
## moves used / left on a win.
func _rate(site: Dictionary, rules: Dictionary, budget: int, runs: int) -> Dictionary:
	var s := site.duplicate()
	s.energy = budget
	var wins := 0
	var used := []
	var left := []
	for k in runs:
		var m := Bots.play(s, rules, 7000 + k * 31, Bots.Kind.SLOPPY)
		if m.complete:
			wins += 1
			used.append(m.moves + m.drills)
			left.append(m.energy_left)
	used.sort()
	left.sort()
	return {"budget": budget, "rate": float(wins) / runs,
			"used": used[used.size() / 2] if not used.is_empty() else 0.0,
			"left": left[left.size() / 2] if not left.is_empty() else 0.0}
