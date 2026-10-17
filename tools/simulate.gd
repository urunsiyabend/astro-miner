extends SceneTree

## Headless balance simulation.
##   godot --headless --path . -s res://tools/simulate.gd -- [runs] [--md out.md]
## Plays every site with three bot skill levels under several colony upgrade states and
## prints aggregate metrics. Results are deterministic for a given run count.

const CONFIGS := [
	{"name": "no upgrades", "levels": [0, 0, 0, 0]},
	{"name": "first upgrades", "levels": [1, 1, 1, 1]},
	{"name": "mid (P2 W2 L1)", "levels": [2, 2, 1]},
	{"name": "maxed (P3 W3 L3)", "levels": [3, 3, 3]},
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := 60
	var md_path := ""
	var types := 3
	var i := 0
	while i < args.size():
		if args[i] == "--md" and i + 1 < args.size():
			md_path = args[i + 1]
			i += 1
		elif args[i] == "--types" and i + 1 < args.size():
			types = int(args[i + 1])
			i += 1
		elif args[i] == "--campaign":
			_campaign(int(args[i + 1]) if i + 1 < args.size() and args[i + 1].is_valid_int() else 40)
			quit(0)
			return
		elif args[i].is_valid_int():
			runs = int(args[i])
		i += 1
	var t0 := Time.get_ticks_msec()
	var lines := []
	lines.append("Ore types: %d." % types)
	lines.append("Runs per cell: %d. Bots: RANDOM (careless), GREEDY (1-step), PLANNER (1-step + search)." % runs)
	lines.append("")
	for cfg in CONFIGS:
		lines.append("### Colony: %s" % cfg.name)
		lines.append("")
		lines.append("| Site | Bot | Clear % | Turns | Moves/match | Cascade % | Chunks | Rocks | Crystals | Charges | Exhausted % | Stuck turns % | Pulses |")
		lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		var rules := Economy.rules(cfg.levels)
		rules.ore_types = types
		for si in Sites.count():
			var site := Sites.get_site(si)
			for kind in [Bots.Kind.RANDOM, Bots.Kind.GREEDY, Bots.Kind.PLANNER]:
				var agg := _run_many(site, rules, kind, runs)
				lines.append("| %s | %s | %d | %.1f | %.2f | %.0f | %.1f | %.1f | %.2f | %.2f | %d | %.1f | %.2f |" % [
					site.id, ["random", "greedy", "planner"][kind], agg.clear, agg.turns,
					agg.mpm, agg.cascade, agg.chunks, agg.rocks, agg.crystals, agg.charges,
					agg.exhausted, agg.stuck, agg.pulses])
		lines.append("")
	lines.append("Elapsed: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var text := "\n".join(lines)
	print(text)
	if md_path != "":
		var f := FileAccess.open(md_path, FileAccess.WRITE)
		f.store_string(text + "\n")
	quit(0)


func _run_many(site: Dictionary, rules: Dictionary, kind: int, runs: int) -> Dictionary:
	var clear := 0
	var turns := 0.0
	var moves := 0.0
	var groups := 0.0
	var cascades := 0.0
	var chunks := 0.0
	var rocks := 0.0
	var crystals := 0.0
	var charges := 0.0
	var exhausted := 0
	var stuck := 0.0
	var pulses := 0.0
	for r in runs:
		var m := Bots.play(site, rules, 1000 + r, kind)
		if m.complete:
			clear += 1
		if m.exhausted:
			exhausted += 1
		turns += m.turns
		moves += m.moves
		groups += m.groups
		cascades += m.cascades
		chunks += m.chunks
		rocks += m.rocks
		crystals += m.crystals
		charges += m.charges
		stuck += m.stuck_turns
		pulses += m.pulses
	return {
		"clear": roundi(100.0 * clear / runs), "turns": turns / runs,
		"mpm": moves / maxf(1.0, groups), "cascade": 100.0 * cascades / maxf(1.0, groups),
		"chunks": chunks / runs, "rocks": rocks / runs, "crystals": crystals / runs,
		"charges": charges / runs, "exhausted": roundi(100.0 * exhausted / runs),
		"stuck": 100.0 * stuck / maxf(1.0, turns), "pulses": pulses / runs,
	}


## Campaign pacing: a bot plays the sites in order, after every dig buys whatever upgrade
## it can afford (cheapest first), replaying a site when it fails. Reports digs, moves and
## upgrades until each site is first cleared. Human time assumes ~2 s per move (assumption).
func _campaign(n: int) -> void:
	var sec_per_move := 2.0
	var lines := ["Campaign pacing, %d campaigns, PLANNER bot, %.0f s/move assumed:" % [n, sec_per_move], ""]
	lines.append("| Milestone | Digs (avg) | Moves (avg) | Est. minutes | Upgrades owned (avg) |")
	lines.append("|---|---|---|---|---|")
	var acc := []
	for si in Sites.count():
		acc.append({"digs": 0.0, "moves": 0.0, "ups": 0.0, "done": 0})
	var first_up_digs := 0.0
	var gave_up := 0
	for c in n:
		var coin := 0
		var star := 0
		var levels := [0, 0, 0, 0]
		var digs := 0
		var moves := 0
		var first_up := -1
		var site := 0
		while site < Sites.count() and digs < 60:
			var m := Bots.play(Sites.get_site(site), Economy.rules(levels), 9000 + c * 101 + digs, Bots.Kind.PLANNER)
			digs += 1
			moves += m.moves
			if m.complete:
				coin += Economy.clear_coin(site) + Economy.move_coin(m.energy_left)
				star += Economy.FIRST_CLEAR_STARS
				acc[site].digs += digs
				acc[site].moves += moves
				acc[site].ups += levels[0] + levels[1] + levels[2] + levels[3]
				acc[site].done += 1
				site += 1
			# Build/upgrade: a building unlocks at its star milestone (level 1 free), then Coin
			# buys level 2 and 3. Take the cheapest available each pass.
			var bought := true
			while bought:
				bought = false
				var best := -1
				var best_cost := 1 << 30
				for b in Economy.BUILDINGS.size():
					if star < Economy.STAR_UNLOCK[b] or levels[b] >= Economy.MAX_LEVEL:
						continue
					var cost := Economy.cost(b, levels[b])
					if Economy.can_afford(coin, cost) and cost < best_cost:
						best_cost = cost
						best = b
				if best >= 0:
					coin -= Economy.cost(best, levels[best])
					levels[best] += 1
					bought = true
					if first_up < 0:
						first_up = digs
		if site < Sites.count():
			gave_up += 1
		first_up_digs += first_up if first_up >= 0 else digs
	for si in Sites.count():
		var a: Dictionary = acc[si]
		var k := maxf(1.0, a.done)
		lines.append("| First clear of %s | %.1f | %.0f | %.1f | %.1f |" % [Sites.get_site(si).id,
				a.digs / k, a.moves / k, a.moves / k * sec_per_move / 60.0, a.ups / k])
	lines.append("")
	lines.append("First upgrade affordable after %.1f digs on average; %d/%d campaigns did not finish within 60 digs." % [first_up_digs / n, gave_up, n])
	print("\n".join(lines))
