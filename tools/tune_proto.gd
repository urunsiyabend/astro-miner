extends SceneTree

## Budgets for the core-loop prototypes (Sites.PROTO_BOARDS in three modes): the smallest budget
## at which the SLOPPY bot clears ~82%, so the modes differ in feel, not in difficulty.
##   godot --headless --path . -s res://tools/tune_proto.gd -- [runs]
func _initialize() -> void:
	var runs := 30
	var only := ""  # A, B or C: one mode only
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
		else:
			only = a
	var rules := Economy.rules([1, 1, 1, 1])
	var out := {}
	for site in Sites.protos():
		if only != "" and not String(site.title).begins_with(only):
			continue
		var lo := 4
		var hi := 70
		var res := {}
		while lo < hi:
			var mid := (lo + hi) / 2
			var r := _rate(site, rules, mid, runs)
			if r.rate >= 0.82:
				hi = mid
			else:
				lo = mid + 1
		res = _rate(site, rules, lo, runs)
		print("%-26s budget %2d  clear %3d%%  used %4.1f  left %4.1f" % [site.title, lo, int(res.rate * 100), res.used, res.left])
		if not out.has(site.mode):
			out[site.mode] = []
		out[site.mode].append(lo)
	print("PROTO_ENERGY ", out)
	quit(0)


func _rate(site: Dictionary, rules: Dictionary, budget: int, runs: int) -> Dictionary:
	var s := site.duplicate()
	s.energy = budget
	var wins := 0
	var used := []
	var left := []
	for k in runs:
		var m := Bots.play(s, rules, 9100 + k * 37, Bots.Kind.SLOPPY)
		if m.complete:
			wins += 1
			used.append(m.moves + m.drills)
			left.append(m.energy_left)
	used.sort()
	left.sort()
	return {"rate": float(wins) / runs, "used": used[used.size() / 2] if not used.is_empty() else 0.0,
			"left": left[left.size() / 2] if not left.is_empty() else 0.0}
