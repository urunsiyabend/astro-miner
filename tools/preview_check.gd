extends SceneTree

## The drawn-path preview must tell the truth: before every move of a bot game it asks
## Board.preview_path what the path will do, plays the path for real and compares.
##   godot --headless --path . -s res://tools/preview_check.gd -- [runs]
## Checked: the lines that match first, where their specials form, where each dragged
## special goes off and which way, and the combo a path that drags several makes. Moves whose
## first match comes after a fall (a pickup or a blast opened a hole first) are skipped: the
## preview stops before gravity. Exits 1 on a mismatch, so it can gate a commit.

func _initialize() -> void:
	var runs := 4
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
	var rules := Economy.rules([1, 1, 1, 1])
	rules.path_max = 4
	var sites := []
	for i in 16:
		var s: Dictionary = Sites.get_site(i)
		if not s.has("ore") and not s.get("gold_rush", false):
			sites.append(s)
	sites.append_array(Sites.protos())
	var checked := 0
	var skipped := 0
	var bad := 0
	for site in sites:
		for k in runs:
			var b := Board.new()
			b.setup_site(site, 7000 + k * 31, rules)
			var rng := RandomNumberGenerator.new()
			rng.seed = k
			var guard := 0
			while not b.over and guard < 60:
				guard += 1
				var dirs := Bots.choose_path(b, Bots.Kind.SLOPPY, rng)
				var pv := b.preview_path(dirs)
				var r := b.try_path(dirs)
				if not r.ok or pv.is_empty():
					continue
				var why := _compare(pv, r.steps)
				if why == "skip":
					skipped += 1
				elif why != "":
					bad += 1
					print("MISMATCH %s seed %d move %d: %s" % [site.id, k, guard, why])
				else:
					checked += 1
	print("preview_check: %d moves agree, %d skipped (fall first), %d mismatches" % [checked, skipped, bad])
	quit(1 if bad > 0 else 0)


func _compare(pv: Dictionary, steps: Array) -> String:
	# power-ups the path merges: the move merges the same ones, into the same cell
	var merges := steps.filter(func(s): return s.type == "merge")
	if not pv.combo.is_empty() or not merges.is_empty():
		if pv.combo.is_empty() or merges.is_empty():
			return "combo: preview %s, move %s" % [pv.combo.get("name", "-"), merges.map(func(m): return m.name)]
		if merges[0].to != pv.combo.at or merges[0].name != pv.combo.name:
			return "combo %s at %d, preview said %s at %d" % [merges[0].name, merges[0].to, pv.combo.name, pv.combo.at]
	# dragged specials that go off in place fire right after the walk, in order
	for c in pv.specials:
		var aim: Array = pv.specials[c]
		if aim[0] != c:
			continue  # thrown by a pad or a teleporter: it travels first
		var fired := steps.filter(func(s): return s.type == "special" and s.at == c)
		if fired.is_empty():
			return "special at %d never went off" % c
		if Board.DIRS[fired[0].dir] != aim[1]:
			return "special at %d fired %s, preview said %s" % [c, Board.DIRS[fired[0].dir], aim[1]]
	var first := {}
	for s in steps:
		if s.type == "match":
			first = s
			break
		if s.type not in ["move", "teleport"]:
			return "skip" if not pv.groups.is_empty() or s.type == "fall" else ""
	if first.is_empty():
		return "" if pv.groups.is_empty() else "preview showed %d lines, none matched" % pv.groups.size()
	var real := _cells_of(first.groups)
	var shown := _cells_of(pv.groups)
	if real != shown:
		return "matched %s, preview showed %s" % [real, shown]
	var at_real: Array = first.charges.duplicate()
	var at_shown: Array = pv.groups.filter(func(g): return g.special >= 0).map(func(g): return g.at)
	at_real.sort()
	at_shown.sort()
	if at_real != at_shown:
		return "specials formed at %s, preview showed %s" % [at_real, at_shown]
	return ""


func _cells_of(groups: Array) -> Array:
	var out := []
	for g in groups:
		out.append_array(g.cells)
	out.sort()
	return out
