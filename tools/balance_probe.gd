extends SceneTree

## Campaign balance as a real player meets it: buildings unlock by Star, every upgrade is
## bought as soon as it is affordable, a failed dig is retried (new seed) until cleared.
## Per dig: budget (site energy + Power bonus), moves used, moves left, attempts, Coin, levels.
##   godot --headless --path . -s res://tools/balance_probe.gd  [-- greedy|planner|random]
func _initialize() -> void:
	var kind := Bots.Kind.PLANNER
	for a in OS.get_cmdline_user_args():
		kind = {"greedy": Bots.Kind.GREEDY, "planner": Bots.Kind.PLANNER, "random": Bots.Kind.RANDOM, "sloppy": Bots.Kind.SLOPPY}.get(a, kind)
	var runs := 12
	var n_sites := Sites.count()
	var acc := []  # per dig: [budget, moves, left, attempts, coin, lv0, lv1, lv2, cumcoin]
	for si in n_sites:
		acc.append([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	for r in runs:
		var levels := [0, 0, 0, 0]
		var coin := 0
		var star := 0
		var earned := 0
		for si in n_sites:
			var site: Dictionary = Sites.get_site(si)
			# the colony: free level 1 on unlock, then greedy upgrades
			for b in Economy.BUILDINGS.size():
				if levels[b] == 0 and star >= Economy.STAR_UNLOCK[b]:
					levels[b] = 1
			var bought := true
			while bought:
				bought = false
				for b in Economy.BUILDINGS.size():
					var c := Economy.cost(b, levels[b])
					if levels[b] >= 1 and c > 0 and coin >= c:
						coin -= c
						levels[b] += 1
						bought = true
			var need: Dictionary = site.get("needs", {})
			if not need.is_empty() and levels[need.building] < need.level:
				levels[need.building] = need.level  # the campaign forces it; never blocks here
			var attempts := 0
			var m := {}
			while attempts < 8:
				attempts += 1
				m = Bots.play(site, Economy.rules(levels), 1000 + r * 97 + si * 13 + attempts, kind)
				if m.complete or site.get("gold_rush", false):
					break
			var gain: int = 0
			if m.complete or site.get("gold_rush", false):
				gain = (0 if site.get("gold_rush", false) else Economy.clear_coin(si)) + Economy.move_coin(m.energy_left)
				star += Economy.FIRST_CLEAR_STARS
			coin += gain
			earned += gain
			var budget: int = int(site.get("energy", 20))
			var row: Array = [budget, m.moves, m.energy_left, attempts, gain, levels[0], levels[1], levels[2], earned, levels[3]]
			for k in row.size():
				acc[si][k] += float(row[k]) / runs
	print("| # | id | budget | moves | left | left% | tries | Coin | P W L T | cum Coin |")
	for si in n_sites:
		var a: Array = acc[si]
		print("| %d | %s | %.0f | %.1f | %.1f | %.0f%% | %.1f | %.0f | %.1f %.1f %.1f %.1f | %.0f |" % [
			si + 1, Sites.get_site(si).id, a[0], a[1], a[2], 100.0 * a[2] / maxf(1.0, a[0]), a[3], a[4],
			a[5], a[6], a[7], a[9], a[8]])
	quit(0)
