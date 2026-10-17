extends SceneTree

## Drawn paths vs single steps: the same digs played by the SLOPPY bot with path_max 1 (today),
## 3, 4 and 5, each at the dig's current budget.
##   godot --headless --path . -s res://tools/path_probe.gd -- [runs] [lengths, e.g. 1,4]
## Per dig and length: clear rate, median moves a win takes, dry moves (no match, no special:
## a move that only walks), matches and specials per move.

func _initialize() -> void:
	var runs := 16
	var lengths := [1, 3, 4, 5]
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			runs = int(a)
		elif "," in a:
			lengths = Array(a.split(",")).map(func(x): return int(x))
	var sites := []
	for i in 16:
		var s: Dictionary = Sites.get_site(i)
		if not s.has("ore") and not s.get("gold_rush", false):
			sites.append(s)
	for s in Sites.protos():
		if s.get("proto", false):
			sites.append(s)
	var total := {}
	for site in sites:
		var line := "%-12s" % site.id
		for L in lengths:
			var r := _measure(site, L, runs)
			line += "  L%d clear %3d%% used %4.1f dry %2d%% m/mv %.2f sp/mv %.2f" % [L, int(r.rate * 100),
					r.used, int(r.dry * 100), r.matches, r.specials]
			if not total.has(L):
				total[L] = {"rate": 0.0, "used": 0.0, "dry": 0.0, "matches": 0.0, "specials": 0.0}
			for k in total[L]:
				total[L][k] += r[k] / sites.size()
		print(line)
	for L in lengths:
		var t: Dictionary = total[L]
		print("MEAN L%d clear %3d%% used %4.1f dry %2d%% matches/move %.2f specials/move %.2f" % [L,
				int(t.rate * 100), t.used, int(t.dry * 100), t.matches, t.specials])
	quit(0)


func _measure(site: Dictionary, L: int, runs: int) -> Dictionary:
	var rules := Economy.rules([1, 1, 1, 1])
	rules.path_max = L
	var wins := 0
	var used := []
	var moves := 0
	var dry := 0
	var groups := 0
	var specials := 0
	for k in runs:
		var b := Board.new()
		b.record = false
		b.setup_site(site, 4000 + k * 13, rules)
		var rng := RandomNumberGenerator.new()
		rng.seed = k * 7 + L
		var guard := 0
		while not b.over and guard < 200:
			guard += 1
			if b.first_step_to_match(5) == -1 and b.can_pulse():
				b.pulse()
				continue
			var g0: int = b.stats.groups
			var s0: int = b.stats.blasts
			var r := b.try_path(Bots.choose_path(b, Bots.Kind.SLOPPY, rng)) if L > 1 \
					else b.try_move(Bots.choose(b, Bots.Kind.SLOPPY, rng))
			if not r.ok:
				continue
			moves += 1
			if b.stats.groups == g0 and b.stats.blasts == s0:
				dry += 1
		groups += b.stats.groups
		specials += b.stats.blasts
		if b.complete:
			wins += 1
			used.append(b.stats.moves + b.stats.drills)
	used.sort()
	return {"rate": float(wins) / runs, "used": float(used[used.size() / 2]) if not used.is_empty() else 0.0,
			"dry": float(dry) / maxi(1, moves), "matches": float(groups) / maxi(1, moves),
			"specials": float(specials) / maxi(1, moves)}
