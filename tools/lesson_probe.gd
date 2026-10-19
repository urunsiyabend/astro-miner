extends SceneTree

## Plays a lesson's moves and prints the board after each, to design guided levels.
##   godot --headless --path . -s res://tools/lesson_probe.gd -- <site id> <moves...>
## A move is a path of U D L R letters ("U", "RRD"). Prints what each move did (matches,
## cascades, specials made and fired) and the goals. Board: @ robot, F C L R gems
## (Ferrite Cryo Lumen Ruby), * a special (D drill, Q quake, P prism), # bedrock, 1-3 rock,
## c crystal, o core, [x] a caged gem.

const MAP := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := Sites.index_of(args[0])
	var site := Sites.get_site(i)
	var rules := Economy.rules([1, 1, 1, 1])
	rules.path_max = int(site.get("path_max", 4))
	var b := Board.new()
	b.setup_site(site, 0, rules)
	print("%s: %d moves, goals %s" % [site.id, b.energy, site.goals])
	_print(b)
	for k in range(1, args.size()):
		var dirs: Array = Array(args[k].split("", false)).map(func(ch): return MAP[ch])
		var r := b.try_path(dirs)
		var kinds := {}
		var groups := 0
		var cascades := 0
		for s in r.steps:
			kinds[s.type] = int(kinds.get(s.type, 0)) + 1
			if s.type == "match":
				groups += s.groups.size()
				if s.cascade:
					cascades += 1
		print("\n> %s: %s; %d lines, %d cascade passes; steps %s; goals %s; moves left %d%s" % [
				args[k], "ok" if r.ok else "REJECTED (%s)" % r.reason, groups, cascades, kinds,
				b.goals.map(func(g): return b.goal_progress(g)), b.energy, " COMPLETE" if b.complete else ""])
		_print(b)
	quit(0)


func _print(b: Board) -> void:
	for y in Board.H:
		var line := ""
		for x in Board.W:
			var c := Board.idx(Vector2i(x, y))
			var ch := "."
			if c == b.robot:
				ch = "@"
			elif b.terrain[c] == Board.Terrain.BEDROCK:
				ch = "#"
			elif b.terrain[c] == Board.Terrain.ROCK:
				ch = str(b.hp[c])
			elif b.terrain[c] == Board.Terrain.BLOCK:
				ch = "G"
			else:
				match b.token[c]:
					Board.Token.ORE: ch = "FCLR"[b.ore[c]]
					Board.Token.CHARGE: ch = "BDPGQ"[b.spec[c]].to_lower()
					Board.Token.CRYSTAL: ch = "c"
					Board.Token.CELL: ch = "e"
					Board.Token.CORE: ch = "o"
			line += ("[%s]" % ch) if b.obs.locked(c) else (" %s " % ch)
		print(line)
