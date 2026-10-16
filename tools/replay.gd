extends SceneTree

## Replays a move string on a dig and prints the board after every move.
##   godot --headless --path . -s res://tools/replay.gd -- <id> <MOVES>
## Board: @ robot, # bedrock, R rock (Rc hides a crystal), F/C/L ore, c crystal, . empty.

const CODES := ["F", "C", "L"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := Sites.index_of(args[0])
	var site := Sites.get_site(i)
	var b := Board.new()
	b.record = false
	b.setup_site(site, 0, Economy.rules(preload("res://tools/levels.gd").campaign_levels(i)))
	var dirs := {"U": Vector2i(0, -1), "R": Vector2i(1, 0), "D": Vector2i(0, 1), "L": Vector2i(-1, 0)}
	print("start  energy %d" % b.energy)
	_show(b)
	var k := 0
	for ch in (args[1] if args.size() > 1 else ""):
		k += 1
		var g: int = b.stats.groups
		var r := b.try_move(dirs[ch])
		print("%2d %s  %s  energy %d  groups +%d  rocks %d%s" % [k, ch, "ok" if r.ok else "REJECTED " + r.reason,
				b.energy, b.stats.groups - g, b.stats.rocks_broken, "  COMPLETE" if b.complete else ""])
		_show(b)
		if b.over:
			break
	quit(0)


func _show(b: Board) -> void:
	for y in Board.H:
		var row := "   "
		for x in Board.W:
			var i := y * Board.W + x
			if i == b.robot: row += "@  "
			elif b.terrain[i] == Board.Terrain.BEDROCK: row += "#  "
			elif b.terrain[i] == Board.Terrain.ROCK: row += ("Rc " if b.buried[i] == Board.Buried.CRYSTAL else "R  ")
			elif b.token[i] == Board.Token.ORE: row += CODES[b.ore[i]] + "  "
			elif b.token[i] == Board.Token.CRYSTAL: row += "c  "
			else: row += ".  "
		print(row)
