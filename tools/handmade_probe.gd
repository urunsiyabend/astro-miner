extends SceneTree

## Finds a solid opening for a dig that should become hand-made.
##   godot --headless --path . -s res://tools/handmade_probe.gd -- <id> <seed_from> <seed_to> [runs]
## For every seed: the shortest move string the beam search finds, and the clear rate of the
## greedy and planner bots plus a "sloppy" planner that plays a random move 12% of the time
## (a player wasting a move now and then). Prints the opening of the best seed as an "ore" layout.
## With only <id>, it scores the dig as it is defined (its own seed and layout).

const CODES := ["F", "C", "L"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0]
	var site_i := -1
	for i in Sites.count():
		if Sites.get_site(i).id == id:
			site_i = i
	var base: Dictionary = Sites.get_site(site_i).duplicate(true)
	var rules := Economy.rules(preload("res://tools/levels.gd").campaign_levels(site_i))
	var runs := int(args[3]) if args.size() > 3 else 60
	var seeds := []
	if args.size() >= 3:
		for s in range(int(args[1]), int(args[2]) + 1):
			seeds.append(s)
	else:
		seeds.append(-1)
	var best := []
	for s in seeds:
		var site := base.duplicate(true)
		if s >= 0:
			site.seed = s
			site.erase("ore")
		var sol: String = preload("res://tools/levels.gd").solve(site, rules, "", 300, 60)
		var rates := []
		for kind in ["greedy", "planner", "sloppy"]:
			var wins := 0
			var left := 0
			var stuck := 0
			for r in runs:
				var m := _play(site, rules, 500 + r, kind)
				if m.complete:
					wins += 1
					left += m.energy_left
				elif m.energy_left > 0:
					stuck += 1
			rates.append([wins * 100 / runs, float(left) / maxi(1, wins), stuck])
		var score: float = rates[0][0] + rates[1][0] + rates[2][0] * 2 + (0 if sol == "" else 50)
		print("seed %4d  sol %2d  greedy %3d%% (%4.1f, stuck %d)  planner %3d%% (%4.1f, stuck %d)  sloppy %3d%% (%4.1f, stuck %d)" % [
			s, sol.length() if sol != "" else -1, rates[0][0], rates[0][1], rates[0][2],
			rates[1][0], rates[1][1], rates[1][2], rates[2][0], rates[2][1], rates[2][2]])
		if best.is_empty() or score > best[0]:
			best = [score, s, site, sol]
	if best[1] >= 0:
		print("best seed %d, solution %s" % [best[1], best[3]])
		var b := Board.new()
		b.record = false
		b.setup_site(best[2], 0, rules)
		for y in Board.H:
			var row := []
			for x in Board.W:
				var i := y * Board.W + x
				if i == b.robot:
					row.append("@")
				elif b.terrain[i] == Board.Terrain.GROUND and b.token[i] == Board.Token.ORE:
					row.append(CODES[b.ore[i]])
				else:
					row.append("-")
			print("\t\t\t\"%s\"," % " ".join(row))
	quit(0)


func _play(site: Dictionary, rules: Dictionary, seed_value: int, kind: String) -> Dictionary:
	var b := Board.new()
	b.record = false
	b.setup_site(site, seed_value, rules)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + kind.length()
	var rejected := 0
	for t in 300:
		if b.over:
			break
		if b.first_step_to_match(5) == -1 and b.can_pulse():
			b.pulse()
			continue
		var d: Vector2i
		if kind == "greedy":
			d = Bots.choose(b, Bots.Kind.GREEDY, rng)
		elif kind == "sloppy" and rng.randf() < 0.12:
			d = Bots.choose(b, Bots.Kind.RANDOM, rng)
		else:
			d = Bots.choose(b, Bots.Kind.PLANNER, rng)
		if not b.try_move(d).ok:
			rejected += 1
			if rejected > 20:
				break
	if not b.complete and OS.has_environment("PROBE_LOSS"):
		var rows := []
		for y in Board.H:
			var row := ""
			for x in Board.W:
				var i := y * Board.W + x
				if i == b.robot: row += "@ "
				elif b.terrain[i] == Board.Terrain.BEDROCK: row += "# "
				elif b.terrain[i] == Board.Terrain.ROCK: row += "R "
				elif b.token[i] == Board.Token.ORE: row += CODES[b.ore[i]] + " "
				else: row += ". "
			rows.append(row)
		print("LOSS %s rocks %d/%d\n%s" % [kind, b.stats.rocks_broken, 12, "\n".join(rows)])
	return {"complete": b.complete, "energy_left": b.energy}
