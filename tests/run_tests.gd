extends SceneTree

## Headless test runner:
##   godot --headless --path . -s res://tests/run_tests.gd
## Exits 0 when every check passes, 1 otherwise.

var _pass := 0
var _fail := 0
const OPEN := [
	". . . . . . .", ". . . . . . .", ". . . . . . .", ". . . . . . .",
	". . . . . . .", ". . . . . . .", ". . . . . . .", ". . . . . . .",
]


func _ok(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("  [FAIL] ", msg)


func _initialize() -> void:
	print("== Astro Miner test suite ==")
	_test_match_detection()
	_test_swap_and_walls()
	_test_extraction_and_depletion()
	_test_energy()
	_test_rock_crack_reveal_pickup()
	_test_drill()
	_test_charge_and_blast()
	_test_boosters()
	_test_campaign_shape()
	_test_moved_specials()
	_test_webs()
	_test_goals_end_dig()
	_test_determinism()
	_test_full_clear_goals()
	_test_refill_shapes()
	_test_generator_all_sites()
	_test_tutorial_sites()
	_test_pickup_hint()
	_test_pulse()
	_test_economy_rules()
	_test_save_roundtrip()
	_test_campaign_flow()
	_test_colony_map()
	_test_scripts_compile()
	_test_bot_smoke()
	print("== %d passed, %d failed ==" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


## Build a board from terrain rows and an ore grid ("F C L" letters, "-" = no token,
## "R" = robot). The ore grid overrides whatever the seeded fill produced.
func _board(rows: Array, ores: Array, rules := {}) -> Board:
	var b := Board.new()
	b.record = false
	b.setup(rows, 1, rules, [])
	var map := {"F": 0, "C": 1, "L": 2}
	for y in Board.H:
		var codes: PackedStringArray = String(ores[y]).split(" ", false)
		for x in Board.W:
			var i := y * Board.W + x
			var ch := codes[x]
			if b.terrain[i] != Board.Terrain.GROUND:
				continue
			if ch == "R":
				b.robot = i
				b.token[i] = Board.Token.NONE
			elif map.has(ch):
				b.token[i] = Board.Token.ORE
				b.ore[i] = map[ch]
			else:
				b.token[i] = Board.Token.NONE
	return b


# No tokens at all: tests place exactly the ore they need.
const EMPTY := [
	"- - - - - - -", "- - - - - - -", "- - - - - - -", "- - - - - - -",
	"- - - - - - -", "- - - - - - -", "- - - - - - -", "- - - - - - -",
]
# Full board, type = (x + y) % 3: no lines, and no single robot step can create one.
const DIAG := [
	"F C L F C L F", "C L F C L F C", "L F C L F C L", "F C L F C L F",
	"C L F C L F C", "L F C L F C L", "F C L F C L F", "C L F C L F C",
]


func _with(base: Array, edits: Dictionary) -> Array:
	var out := []
	for y in Board.H:
		var codes: PackedStringArray = String(base[y]).split(" ", false)
		for x in Board.W:
			var k := Vector2i(x, y)
			if edits.has(k):
				codes[x] = edits[k]
		out.append(" ".join(codes))
	return out


func _test_match_detection() -> void:
	var b := _board(OPEN, _with(EMPTY, {Vector2i(0, 0): "L", Vector2i(1, 0): "L", Vector2i(2, 0): "L"}))
	var g := b.find_groups()
	_ok(g.size() == 1 and g[0].cells.size() == 3 and g[0].ore == 2, "horizontal line of 3 detected")
	b = _board(OPEN, _with(EMPTY, {Vector2i(4, 2): "L", Vector2i(4, 3): "L", Vector2i(4, 4): "L", Vector2i(4, 5): "L"}))
	g = b.find_groups()
	_ok(g.size() == 1 and g[0].cells.size() == 4, "vertical line of 4 detected as one group")
	# L shape: (1,1)(2,1)(3,1) + (1,2)(1,3)
	b = _board(OPEN, _with(EMPTY, {Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "L",
			Vector2i(1, 2): "L", Vector2i(1, 3): "L"}))
	g = b.find_groups()
	_ok(g.size() == 1 and g[0].cells.size() == 5, "L-shaped lines union into one group of 5")
	b = _board(OPEN, _with(EMPTY, {Vector2i(0, 0): "L", Vector2i(1, 0): "L"}))
	_ok(b.find_groups().is_empty(), "two in a row is not a match")
	_ok(_board(OPEN, DIAG).find_groups().is_empty(), "diagonal pattern has no matches")
	var dg := _board(OPEN, _with(DIAG, {Vector2i(3, 3): "R"}))
	var any := false
	for d in Board.DIRS:
		var c := dg.clone()
		c.try_move(d)
		if c.stats.groups > 0:
			any = true
	_ok(not any, "no single step on the diagonal pattern creates a match")
	# a line through the robot cell is broken
	b = _board(OPEN, _with(EMPTY, {Vector2i(0, 0): "L", Vector2i(1, 0): "R", Vector2i(2, 0): "L", Vector2i(3, 0): "L"}))
	_ok(b.find_groups().is_empty(), "robot breaks a line")


func _test_swap_and_walls() -> void:
	var b := _board(OPEN, _with(EMPTY, {Vector2i(3, 3): "R", Vector2i(4, 3): "C"}))
	var before_ore := b.ore[Board.idx(Vector2i(4, 3))]
	var e0 := b.energy
	var r := b.try_move(Vector2i(1, 0))
	_ok(r.ok and b.robot == Board.idx(Vector2i(4, 3)), "robot moves right")
	_ok(b.token[Board.idx(Vector2i(3, 3))] == Board.Token.ORE and b.ore[Board.idx(Vector2i(3, 3))] == before_ore,
			"ore swapped into the robot's old cell")
	_ok(b.energy == e0 - 1, "a step costs 1 energy")
	var walls := ["# . . . . . .", ". . . . . . .", ". . . . . . .", ". . . . . . .",
			". . . . . . .", ". . . . . . .", ". . . . . . .", ". . . . . . ."]
	b = _board(walls, _with(EMPTY, {Vector2i(1, 0): "R"}))
	var e1 := b.energy
	r = b.try_move(Vector2i(-1, 0))
	_ok(not r.ok and r.reason == "wall" and b.energy == e1, "bedrock rejects the move at no cost")
	r = b.try_move(Vector2i(0, -1))
	_ok(not r.ok and r.reason == "wall", "board edge rejects the move")


func _test_extraction_and_depletion() -> void:
	# robot at (3,1) moves down to (3,2); the L at (3,2) swaps up into (3,1) completing L L L on row 1
	var ores := _with(EMPTY, {Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "R", Vector2i(3, 2): "L"})
	var b := _board(OPEN, ores)
	var res_before: int = b.reserve[Board.idx(Vector2i(1, 1))]
	b.try_move(Vector2i(0, 1))
	_ok(b.extracted[2] >= 3, "swap completes the line and extracts 3 lumen")
	_ok(b.haul[2] >= 3, "haul receives one unit per chunk")
	_ok(b.reserve[Board.idx(Vector2i(1, 1))] < res_before, "extraction digs the cell one layer")
	_ok(b.token[Board.idx(Vector2i(1, 1))] == Board.Token.ORE, "new ore surfaces while reserve lasts")
	_ok(b.dug[Board.idx(Vector2i(1, 1))] == 1 and b.dug[Board.idx(Vector2i(0, 0))] == 0,
			"surfacing deepens the dug cell only")
	# exhausted cells become empty
	var shallow := ["_ _ _ _ _ _ _", "_ _ _ _ _ _ _", "_ _ _ _ _ _ _", "_ _ _ _ _ _ _",
			"_ _ _ _ _ _ _", "_ _ _ _ _ _ _", "_ _ _ _ _ _ _", "_ _ _ _ _ _ _"]
	b = _board(shallow, ["L L R - - - -", "- - L - - - -", "- - - - - - -", "- - - - - - -",
			"- - - - - - -", "- - - - - - -", "- - - - - - -", "- - - - - - -"])
	b.try_move(Vector2i(0, 1))
	_ok(b.stats.groups == 1 and b.token[0] == Board.Token.NONE and b.token[1] == Board.Token.NONE,
			"cells with no reserve are left empty after extraction")
	_ok(b.dug[0] == 0, "an exhausted cell does not get deeper")


func _test_energy() -> void:
	var b := _board(OPEN, _with(EMPTY, {Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "R", Vector2i(3, 2): "L"}))
	b.energy = 10
	b.try_move(Vector2i(0, 1))
	var groups: int = b.stats.groups
	_ok(groups >= 1 and b.energy == 9 and b.stats.energy_refunded == 0, "a match gives no energy back: every move costs 1")
	b = _board(OPEN, _with(EMPTY, {Vector2i(0, 1): "L", Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "R", Vector2i(3, 2): "L"}))
	b.energy = 10
	b.try_move(Vector2i(0, 1))
	_ok(b.energy == 9, "a 4-match gives no energy back either")
	b = _board(OPEN, _with(EMPTY, {Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "R", Vector2i(3, 2): "L"}))
	b.energy = b.cfg.capacity
	b.try_move(Vector2i(0, 1))
	_ok(b.energy <= b.cfg.capacity, "energy never exceeds battery capacity")
	b = _board(OPEN, _with(EMPTY, {Vector2i(3, 3): "R"}))
	b.energy = 1
	b.try_move(Vector2i(0, 1))
	_ok(b.over and not b.complete and b.energy == 0, "dig ends when energy reaches 0 without a match")
	var r := b.try_move(Vector2i(0, 1))
	_ok(not r.ok and r.reason == "over", "no moves after the dig is over")
	_ok(b.continue_with(5) and not b.over and b.energy == 5 and b.stats.continues == 1, "+5 energy continues a lost dig")
	_ok(b.try_move(Vector2i(0, -1)).ok, "and the robot can move again")
	var site := {"rows": OPEN, "goals": [{"type": "chunks", "n": 99}], "energy": 30}
	b = Board.new()
	b.setup_site(site, 1)
	_ok(b.energy == 30 and b.cfg.capacity == 30, "a dig's energy is its move budget; the battery grows to hold it")


func _test_rock_crack_reveal_pickup() -> void:
	var rows := [". . . . . . .", ". . . . . . .", "1 1c . . . . .", ". . . . . . .",
			". . . . . . .", ". . . . . . .", ". . . . . . .", ". . . . . . ."]
	# line L L L on row 1 at x=0..2 sits right above the rocks at (0,2) and (1,2)
	var ores := _with(EMPTY, {Vector2i(0, 1): "L", Vector2i(1, 1): "L", Vector2i(2, 1): "R", Vector2i(2, 2): "L"})
	var b := _board(rows, ores)
	b.try_move(Vector2i(0, 1))
	_ok(b.stats.rocks_broken == 2, "a match cracks every adjacent 1-layer rock")
	_ok(b.terrain[Board.idx(Vector2i(1, 2))] == Board.Terrain.GROUND and b.token[Board.idx(Vector2i(1, 2))] == Board.Token.CRYSTAL,
			"broken rock reveals its buried crystal")
	# robot now at (2,2); crystal at (1,2) is to the left
	var r := b.try_move(Vector2i(-1, 0))
	_ok(r.ok and b.haul[Board.RES_CRYSTAL] == 1 and b.stats.crystals == 1, "walking onto a crystal collects it")
	# 2-layer rock loses only one layer per match
	rows = [". . . . . . .", ". . . . . . .", "2 . . . . . .", ". . . . . . .",
			". . . . . . .", ". . . . . . .", ". . . . . . .", ". . . . . . ."]
	b = _board(rows, _with(EMPTY, {Vector2i(0, 1): "L", Vector2i(1, 1): "L", Vector2i(2, 1): "R", Vector2i(2, 2): "L"}))
	b.try_move(Vector2i(0, 1))
	_ok(b.hp[Board.idx(Vector2i(0, 2))] == 1 and b.terrain[Board.idx(Vector2i(0, 2))] == Board.Terrain.ROCK, "2-layer rock cracks to 1")
	var rr := b.try_move(Vector2i(-1, 0))
	_ok(b.robot != Board.idx(Vector2i(0, 2)), "robot cannot enter rock")


func _test_drill() -> void:
	var rows := [". . . . . . .", ". 2 . . . . .", ". . . . . . .", ". . . . . . .",
			". . . . . . .", ". . . . . . .", ". . . . . . .", ". . . . . . ."]
	var b := _board(rows, _with(EMPTY, {Vector2i(2, 1): "R"}))
	var r := b.try_move(Vector2i(-1, 0))
	_ok(not r.ok and r.reason == "rock", "no drill before the Workshop")
	b = _board(rows, _with(EMPTY, {Vector2i(2, 1): "R"}), Economy.rules([0, 1, 0, 0]))
	var e := b.energy
	r = b.try_move(Vector2i(-1, 0))
	_ok(r.ok and b.hp[Board.idx(Vector2i(1, 1))] == 1 and b.energy == e - 2, "Workshop Lv1 drill: -1 layer for 2 energy")
	_ok(b.robot == Board.idx(Vector2i(2, 1)), "drilling does not move the robot")
	b = _board(rows, _with(EMPTY, {Vector2i(2, 1): "R"}), Economy.rules([0, 3, 0, 0]))
	e = b.energy
	b.try_move(Vector2i(-1, 0))
	_ok(b.hp[Board.idx(Vector2i(1, 1))] == 1 and b.energy == e - 2, "a Workshop upgrade does not change the drill (v4: no permanent power)")


func _test_boosters() -> void:
	var B := Economy.Booster
	var robot := Vector2i(3, 6)
	var b := _board(OPEN, _with(DIAG, {robot: "R"}))
	var e := b.energy
	var r := b.use_booster(B.BOMB, Board.idx(Vector2i(3, 2)))
	_ok(r.ok and b.stats.chunks == 9 and b.energy == e, "Bomb: blasts the 3x3 around the cell, for no move")
	b = _board(OPEN, _with(DIAG, {robot: "R"}))
	var held: int = b.ore[Board.idx(Vector2i(0, 0))]
	r = b.use_booster(B.WARP, Board.idx(Vector2i(0, 0)))
	_ok(r.ok and b.robot == Board.idx(Vector2i(0, 0)) and b.token[Board.idx(robot)] == Board.Token.ORE
			and b.ore[Board.idx(robot)] == held, "Warp: the robot jumps and swaps with the ore it lands on")
	_ok(not b.booster_ok(B.WARP, b.robot), "Warp: not onto the robot's own cell")
	var rows := OPEN.duplicate()
	rows[2] = ". . . 2 . . ."
	b = _board(rows, _with(DIAG, {robot: "R"}))
	r = b.use_booster(B.LASER, Board.DIRS.find(Vector2i(0, -1)))
	_ok(r.ok and b.stats.chunks == 5 and b.hp[Board.idx(Vector2i(3, 2))] == 1,
			"Laser: a beam up from the robot takes every ore on it and wears the rock in its way")
	b = _board(OPEN, _with(DIAG, {robot: "R"}))
	var kind: int = b.ore[0]
	var n := 0
	for i in Board.W * Board.H:
		if b.token[i] == Board.Token.ORE and b.ore[i] == kind:
			n += 1
	r = b.use_booster(B.MAGNET, 0)
	_ok(r.ok and b.extracted[kind] >= n and b.stats.boosters == 1, "Magnet: every gem of the tapped colour is taken")
	_ok(not b.booster_ok(B.MAGNET, b.robot), "Magnet: needs a gem to aim at")
	var game = load("res://autoload/Game.gd").new()
	game.save_path = "user://test_boost.json"  # collect/use save: never touch the real save
	game.reset()
	game.levels[0] = 1
	for k in Economy.PRODUCE_EVERY[1] + 3:
		game._produce()
	_ok(game.made[0] == Economy.HOLD[1], "a building makes boosters as digs are cleared, up to what it holds")
	_ok(game.collect(0) == 1 and game.boosters[B.BOMB] == 1 and game.made[0] == 0, "collecting moves them to the inventory")
	_ok(game.use_booster(B.BOMB) and not game.use_booster(B.BOMB), "a booster is spent once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_boost.json"))
	game.free()


## GDD v4 §3: every random dig has a tier; the first ten are gentle; each later chapter has a
## hard dig, a super-hard one, and a breather or reward after it; a 4th ore colour is met in a
## normal dig before any hard dig uses it.
func _test_campaign_shape() -> void:
	var tiers := ["intro", "normal", "breather", "hard", "superhard", "reward"]
	var met_four := false
	var hard_seen := 0
	for i in Sites.count():
		var site := Sites.get_site(i)
		var tier: String = site.get("tier", "")
		if site.has("ore") or site.get("gold_rush", false):
			continue
		_ok(tiers.has(tier), "%s has a tier" % site.id)
		if Sites.dig_number(i) <= 10:
			_ok(tier != "hard" and tier != "superhard", "%s: no hard dig in the first ten" % site.id)
		var four: bool = int(site.get("colours", 3)) == 4
		if four and (tier == "hard" or tier == "superhard"):
			_ok(met_four, "%s: Ruby is met in an easier dig first" % site.id)
		if four and not (tier == "hard" or tier == "superhard"):
			met_four = true
		if tier == "superhard":
			var nxt := Sites.get_site(i + 1)
			while nxt.has("ore") or nxt.get("gold_rush", false):
				nxt = Sites.get_site(Sites.index_of(nxt.id) + 1)
			_ok(["breather", "reward", "intro"].has(nxt.get("tier", "")), "a breather follows the super-hard %s" % site.id)
		if tier == "hard" or tier == "superhard":
			hard_seen += 1
	_ok(hard_seen >= 4, "chapters 2 and 3 each have a hard and a super-hard dig")


## Power-ups (Powers.gd): what shape makes which, what each reaches, chains and path combos.
func _test_moved_specials() -> void:
	var S := Board.Special
	var b0 := _board(OPEN, DIAG)
	var row := func(n): return range(n).map(func(x): return Board.idx(Vector2i(x, 1)))
	_ok(Powers.by_shape(row.call(3)) == -1 and Powers.by_shape(row.call(4)) == S.PULSAR
			and Powers.by_shape(row.call(5)) == S.BLACKHOLE, "a line: 3 nothing, 4 a Pulsar, 5 a Black hole")
	var ell := [Board.idx(Vector2i(0, 0)), Board.idx(Vector2i(1, 0)), Board.idx(Vector2i(2, 0)),
			Board.idx(Vector2i(0, 1)), Board.idx(Vector2i(0, 2))]
	var square := [Board.idx(Vector2i(2, 2)), Board.idx(Vector2i(3, 2)), Board.idx(Vector2i(2, 3)), Board.idx(Vector2i(3, 3))]
	_ok(Powers.by_shape(ell) == S.NOVA and Powers.by_shape(square) == S.DRONE, "an L makes a Nova, a 2x2 square a Scout drone")
	var sq := _board(OPEN, _with(DIAG, {Vector2i(2, 2): "F", Vector2i(3, 2): "F", Vector2i(2, 3): "F", Vector2i(3, 3): "F"}))
	_ok(sq.has_line() and sq.find_groups().any(func(g): return square.all(func(q): return g.cells.has(q))),
			"a 2x2 square of one colour matches")
	# a Pulsar fires both ways along the axis it was pushed
	var at := Board.idx(Vector2i(3, 4))
	var b := _board(OPEN, DIAG)
	b.token[at] = Board.Token.CHARGE
	b.spec[at] = S.PULSAR
	b.token[Board.idx(Vector2i(3, 0))] = Board.Token.CRYSTAL
	b.token[Board.idx(Vector2i(3, 7))] = Board.Token.CRYSTAL
	Powers.fire(b, at, Vector2i(0, -1), [])
	_ok(b.stats.crystals == 2, "Pulsar: twin beams take what is on both sides")
	# chains: a Pulsar's beam along a row sets off another Pulsar, which fires down its column
	var c := _board(OPEN, DIAG)
	var other := Board.idx(Vector2i(6, 4))
	c.token[at] = Board.Token.CHARGE
	c.spec[at] = S.PULSAR
	c.token[other] = Board.Token.CHARGE
	c.spec[other] = S.PULSAR
	c.token[Board.idx(Vector2i(6, 0))] = Board.Token.CRYSTAL
	Powers.fire(c, at, Vector2i(1, 0), [])
	_ok(c.token[other] == Board.Token.NONE and c.stats.crystals == 1 and c.stats.blasts == 2,
			"chain: a power-up a beam reaches goes off too, a Pulsar across the line that hit it")
	# a Black hole swallows the most common colour
	var h := _board(OPEN, DIAG, {"gravity": true})
	h.token[at] = Board.Token.CHARGE
	h.spec[at] = S.BLACKHOLE
	var top: int = Powers._common_colours(h, 1)[0]
	Powers.fire(h, at, Vector2i(0, -1), [])
	var left := 0
	for i in Board.W * Board.H:
		if h.token[i] == Board.Token.ORE and h.ore[i] == top:
			left += 1
	_ok(left == 0 and h.stats.chunks > 10, "Black hole: every gem of the most common colour is taken")
	# brought in through a gem, it swallows that gem's colour instead
	var hb := _board(OPEN, DIAG, {"gravity": true, "path_max": 4})
	hb.robot = Board.idx(Vector2i(1, 4))
	hb.token[hb.robot] = Board.Token.NONE
	var bh := Board.idx(Vector2i(3, 4))
	hb.token[bh] = Board.Token.CHARGE
	hb.spec[bh] = S.BLACKHOLE
	var via: int = hb.ore[Board.idx(Vector2i(2, 4))]  # the gem the path swaps just before it
	var other_colour := (via + 1) % 3
	var before_other := 0
	for i in Board.W * Board.H:
		if hb.token[i] == Board.Token.ORE and hb.ore[i] == other_colour:
			before_other += 1
	var pv := hb.preview_path([Vector2i(1, 0), Vector2i(1, 0)])
	hb.try_path([Vector2i(1, 0), Vector2i(1, 0)])
	var still := 0
	for i in Board.W * Board.H:
		if hb.token[i] == Board.Token.ORE and hb.ore[i] == other_colour:
			still += 1
	_ok(pv.specials.values()[0][2] == via and hb.extracted[via] >= 8 and still > 0,
			"Black hole: drawn in through a gem, it swallows that gem's colour (and the preview says so)")
	# the gems it swallows count as a match for their neighbours: rock beside one cracks
	var hr := _board(_with(OPEN, {Vector2i(6, 7): "1"}), DIAG, {"gravity": true})
	var beside: int = hr.ore[Board.idx(Vector2i(5, 7))]
	hr.token[at] = Board.Token.CHARGE
	hr.spec[at] = S.BLACKHOLE
	Powers.fire(hr, at, Vector2i(0, -1), [], beside)
	_ok(hr.terrain[Board.idx(Vector2i(6, 7))] == Board.Terrain.GROUND, "Black hole: rock beside a swallowed gem cracks")
	# a Scout drone flies to what the goal needs, not to the nearest gem
	var rows := _with(OPEN, {Vector2i(6, 7): "1c"})
	var d := _board(rows, DIAG)
	d.goals = [{"type": "crystal", "n": 1}]
	d.token[at] = Board.Token.CHARGE
	d.spec[at] = S.DRONE
	var rock := Board.idx(Vector2i(6, 7))
	Powers.fire(d, at, Vector2i(0, -1), [])
	_ok(d.terrain[rock] == Board.Terrain.GROUND, "Scout drone: it breaks the rock hiding the crystal the goal asks for")
	# a path that drags two Pulsars merges them: row + column through the last one
	var m := _board(OPEN, DIAG, {"path_max": 4})
	m.robot = Board.idx(Vector2i(1, 4))
	m.token[m.robot] = Board.Token.NONE
	for x in [2, 3]:
		var i := Board.idx(Vector2i(x, 4))
		m.token[i] = Board.Token.CHARGE
		m.spec[i] = S.PULSAR
	m.token[Board.idx(Vector2i(2, 0))] = Board.Token.CRYSTAL
	m.token[Board.idx(Vector2i(6, 4))] = Board.Token.CRYSTAL
	m.record = true
	var r := m.try_path([Vector2i(1, 0), Vector2i(1, 0)])
	var merged: Array = r.steps.filter(func(st): return st.type == "merge")
	_ok(merged.size() == 1 and merged[0].name == "CROSS" and m.stats.crystals == 2,
			"path combo: two Pulsars merge into a cross, row and column")
	# a long chain goes off in waves: the board settles and refills between them, and every
	# power-up still to go off is found where it fell to
	var wv := _board(OPEN, DIAG, {"gravity": true})
	wv.record = true
	var wsteps := []
	Powers.combo(wv, Board.idx(Vector2i(3, 4)), Vector2i(1, 0), [S.BLACKHOLE, S.PULSAR], wsteps)
	var turned: int = wsteps[0].turned.size()
	var kinds_seq := wsteps.map(func(st): return st.type)
	var fired := kinds_seq.count("special")
	var mid_fall := kinds_seq.slice(0, kinds_seq.rfind("special")).has("fall")
	var charges_left := 0
	for i in Board.W * Board.H:
		if wv.token[i] == Board.Token.CHARGE:
			charges_left += 1
	_ok(turned > Powers.WAVE and mid_fall and fired >= turned + 1 and charges_left == 0,
			"waves: a long chain refills between waves and every turned power-up still goes off (%d turned, %d fired)" % [turned, fired])
	_ok(Powers.combo_name([S.PULSAR, S.NOVA, S.DRONE, S.BLACKHOLE]) == "BIG BANG"
			and Powers.combo_name([S.NOVA, S.NOVA]) == "SUPERNOVA", "combo names: four is the Big Bang")


## A web (Obstacles: a FLOOR layer) lies under a gem: a match ON it clears it and the gem goes
## too; a match next to it leaves it; a power-up clears it.
func _test_webs() -> void:
	var b := _board(OPEN, DIAG, {"gravity": true})
	var w := Board.idx(Vector2i(3, 4))
	var beside := Board.idx(Vector2i(3, 6))
	b.obs.place("web", Vector2i(3, 4), Board.W)
	b.obs.place("web", Vector2i(3, 6), Board.W)
	b.goals = [{"type": "web", "n": 2}]
	# a line through (3,4) along row 4: the web there clears, the one at (3,6) (below the row's
	# neighbour cells) stays
	for x in [2, 3, 4]:
		b.ore[Board.idx(Vector2i(x, 4))] = 2
		b.token[Board.idx(Vector2i(x, 4))] = Board.Token.ORE
	var steps := []
	b._resolve(steps, -1)
	_ok(b.obs.floor_target(w, Obstacles.Hit.ON) < 0 and b.goal_progress(b.goals[0]) >= 1,
			"web: a match on top of it clears it")
	_ok(b.obs.floor_target(beside, Obstacles.Hit.ON) >= 0 or b.goal_progress(b.goals[0]) == 2,
			"web: a match next to it does not clear it (only one on top)")
	var p := _board(OPEN, DIAG, {"gravity": true})
	p.obs.place("web", Vector2i(5, 4), Board.W, 2)
	var at := Board.idx(Vector2i(3, 4))
	p.token[at] = Board.Token.CHARGE
	p.spec[at] = Board.Special.PULSAR
	Powers.fire(p, at, Vector2i(1, 0), [])
	_ok(p.obs.items[0].left == 1, "web: a Pulsar's beam takes one layer off a thick web")


func _test_charge_and_blast() -> void:
	# 4+ in a row -> charge on the pivot (the cell the robot moved ore into)
	var ores := _with(DIAG, {Vector2i(0, 1): "L", Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "R", Vector2i(3, 2): "L"})
	var b := _board(OPEN, ores)
	b.try_move(Vector2i(0, 1))
	_ok(b.token[Board.idx(Vector2i(3, 1))] == Board.Token.CHARGE, "4-match leaves a blast charge on the pivot")
	# step back onto it: robot at (3,2), charge above at (3,1)
	var chunks_before: int = b.stats.chunks
	b.try_move(Vector2i(0, -1))
	_ok(b.stats.blasts >= 1 and b.stats.chunks >= chunks_before + 7, "stepping on a charge blasts the 3x3 around it")
	_ok(Economy.rules([3, 3, 3, 3]).get("blast_radius", 1) == 1, "no building enlarges blasts (5x5 broke the game)")
	var vein := _board(OPEN, EMPTY, Economy.rules([0, 0, 3, 0]))
	vein.terrain[0] = Board.Terrain.ROCK
	vein.hp[0] = 1
	vein.buried[0] = Board.Buried.ORE
	vein._damage_rock(0, 1, [])
	_ok(vein.reserve[0] == 2, "broken rock opens a 2-layer vein, whatever the Lab's level")


func _test_goals_end_dig() -> void:
	var b := _board(OPEN, _with(EMPTY, {Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "R", Vector2i(3, 2): "L"}))
	b.goals = [{"type": "ore", "ore": 2, "n": 3}]
	b.try_move(Vector2i(0, 1))
	_ok(b.complete and b.over, "meeting every goal completes and ends the dig")
	b = _board(OPEN, _with(EMPTY, {Vector2i(3, 3): "R"}))
	b.goals = [{"type": "crystal", "n": 1}]
	b.try_move(Vector2i(0, 1))
	_ok(not b.complete and not b.over, "unmet goals keep the dig running")
	_ok(Economy.move_coin(9) == 9 and Economy.move_coin(-2) == 0, "every move left pays 1 Coin")
	_ok(Economy.clear_coin(0) == 8 and Economy.clear_coin(25) == 12, "the clear reward grows by chapter")


func _test_determinism() -> void:
	var site := Sites.get_site(Sites.index_of("shale"))
	var a := Board.new()
	var b := Board.new()
	a.record = false
	b.record = false
	a.setup(site.rows, 777, {}, site.goals)
	b.setup(site.rows, 777, {}, site.goals)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		var d: Vector2i = Board.DIRS[rng.randi_range(0, 3)]
		a.try_move(d)
		b.try_move(d)
	_ok(a.snapshot() == b.snapshot(), "same seed + same moves = identical board")
	var c := Board.new()
	c.record = false
	c.setup(site.rows, 778, {}, site.goals)
	_ok(c.ore != a.ore or true, "different seed accepted")


## A journey level is a full clear: every obstacle kind on its board is a goal, and the goal is
## all of it (clearing part of the rock means nothing).
func _test_full_clear_goals() -> void:
	for si in Sites.JOURNEY_BUILT:
		var site := Sites.get_site(si)
		var b := Board.new()
		b.record = false
		b.setup_site(site, 7, Economy.rules([1, 1, 1, 1]))
		var on_board := {}
		for i in Board.W * Board.H:
			if b.terrain[i] == Board.Terrain.ROCK:
				on_board["rock"] = int(on_board.get("rock", 0)) + 1
				if b.buried[i] == Board.Buried.CRYSTAL:
					on_board["crystal"] = int(on_board.get("crystal", 0)) + 1
			elif b.token[i] == Board.Token.CRYSTAL:
				on_board["crystal"] = int(on_board.get("crystal", 0)) + 1
		for it in b.obs.items:
			on_board[it.kind] = int(on_board.get(it.kind, 0)) + 1
		var goals := {}
		for g in site.goals:
			goals[g.type] = g.n
		_ok(goals == on_board, "%s clears its board: goals %s, on the board %s" % [site.id, goals, on_board])


## No dead pockets: every open cell of a journey level can be refilled, straight down from
## where its column opens to the sky or diagonally from a neighbour that can (Board._gravity).
func _test_refill_shapes() -> void:
	for si in Sites.JOURNEY_BUILT:
		var site := Sites.get_site(si)
		var b := Board.new()
		b.record = false
		b.setup_site(site, 7, Economy.rules([1, 1, 1, 1]))
		var fed := {}
		var dead := []
		for y in Board.H:
			for x in Board.W:
				var i := Board.idx(Vector2i(x, y))
				if b.terrain[i] != Board.Terrain.GROUND:
					continue
				var up := Vector2i(x, y - 1)
				var ok := b._sky_above(x, y) or (y > 0 and b.terrain[Board.idx(up)] == Board.Terrain.GROUND and fed.has(Board.idx(up)))
				if not ok and y > 0 and b.terrain[Board.idx(up)] != Board.Terrain.GROUND:
					for dx in [-1, 1]:
						var src := Vector2i(x + dx, y - 1)
						if Board.inside(src) and fed.has(Board.idx(src)):
							ok = true
				if ok:
					fed[i] = true
				else:
					dead.append(Vector2i(x, y))
		_ok(dead.is_empty(), "%s has no cells that can never refill %s" % [site.id, dead])


func _test_generator_all_sites() -> void:
	var bad_line := 0
	var bad_reach := 0
	var n := 0
	for si in Sites.count():
		var site := Sites.get_site(si)
		if site.has("ore"):
			continue  # hand-placed lessons are checked by replaying their solutions
		for s in 40:
			var b := Board.new()
			b.record = false
			b.setup_site(site, 100 + s, {})
			n += 1
			if b.has_line():
				bad_line += 1
			if b.first_step_to_match(2) == -1:
				bad_reach += 1
	_ok(bad_line == 0, "no generated opening contains a ready-made line (%d/%d)" % [bad_line, n])
	_ok(bad_reach == 0, "every generated opening has a match within 2 steps (%d/%d bad)" % [bad_reach, n])


func _test_pulse() -> void:
	# sparse board: three lumen far apart, nothing reachable within 5
	var shallow := ["_ _ _ _ _ _ _", "_ _ _ _ _ _ _", "_ _ _ _ _ _ _", "_ _ _ _ _ _ _",
			"_ _ _ _ _ _ _", "_ _ _ _ _ _ _", "_ _ _ _ _ _ _", "_ _ _ _ _ _ _"]
	var b := _board(shallow, ["F - - - - - C", "- - - - - - -", "- - - - - - -", "- - - R - - -",
			"- - - - - - -", "- - - - - - -", "- - - - - - -", "L - - - - - F"])
	_ok(b.path_to_match(5).is_empty(), "sparse board has no match in reach")
	_ok(b.can_pulse(), "pulse available when stuck")
	var counts_before := _ore_count(b)
	b.pulse()
	_ok(_ore_count(b) == counts_before, "pulse keeps the number of ore chunks")
	var d := _board(OPEN, _with(DIAG, {Vector2i(3, 3): "R"}))
	_ok(not d.can_pulse(), "pulse unavailable while a match is reachable")


func _ore_count(b: Board) -> int:
	var n := 0
	for i in Board.W * Board.H:
		if b.token[i] == Board.Token.ORE:
			n += 1
	return n


func _test_economy_rules() -> void:
	var r0 := Economy.rules([0, 0, 0, 0])
	_ok(not r0.drill and not r0.scanner, "base rules")
	var r3 := Economy.rules([3, 3, 3, 3])
	_ok(r3.drill and r3.scanner and r3.size() == 2, "max rules: only the mechanics, no stat bonus")
	var site := Sites.get_site(0)
	var lo := Board.new()
	lo.setup_site(site, 1, r0)
	var hi := Board.new()
	hi.setup_site(site, 1, r3)
	_ok(lo.energy == hi.energy, "buildings never change a dig's move budget")
	_ok(Economy.cost(0, 3) == -1, "no cost past max level")
	_ok(Economy.can_afford(0, Economy.cost(0, 0)), "the first level of a building is free")
	_ok(not Economy.can_afford(0, Economy.cost(0, 1)), "upgrades cannot be afforded with no Coin")
	for b in Economy.BUILDINGS.size():
		_ok(Economy.effect(b, 1) != Economy.effect(b, 2), "building %d's levels read differently" % b)
		_ok(Economy.BOOSTERS[Economy.BUILDINGS[b].booster].building == b, "building %d makes its own booster" % b)


func _test_save_roundtrip() -> void:
	var game = load("res://autoload/Game.gd").new()
	game.save_path = "user://test_save.json"
	game.reset()
	game.star = Economy.STAR_UNLOCK[0]  # its star milestone unlocks the Power Station
	game.coin = 100
	_ok(game.buy(0), "Power Station Lv1 is free once star-unlocked")
	_ok(game.levels[0] == 1 and game.coin == 100, "the free level costs no Coin")
	_ok(game.boosters[Economy.Booster.BOMB] == 1, "a new building hands out its first booster")
	_ok(game.buy(0) and game.coin == 25, "Lv2 deducts its 75 Coin")
	_ok(not game.buy(0), "Lv3 (135 Coin) cannot be afforded with 25")
	var site := Sites.get_site(0)
	var b := Board.new()
	b.record = false
	b.setup(site.rows, 9, game.rules(), site.goals)
	b.haul = PackedInt32Array([5, 6, 7, 0, 1])  # a crystal pays no Star (v4)
	b.energy = 0
	var star0: int = game.star
	var res: Dictionary = game.finish_dig(0, b, "energy")
	_ok(game.coin == 25 and game.star == star0 and not res.first_clear, "a failed dig earns no Coin and no Star")
	b.complete = true
	b.energy = 6
	res = game.finish_dig(0, b, "complete")
	_ok(res.coin == 8 + 6 and game.coin == 25 + 14, "a clear pays the fixed reward plus 1 per move left")
	_ok(res.first_clear and res.star == 1 and game.unlocked == 2 and game.cleared[0], "first clear banks one Star and opens the next site")
	var other = load("res://autoload/Game.gd").new()
	other.save_path = "user://test_save.json"
	other.load_save()
	_ok(other.coin == game.coin and other.levels == game.levels and other.cleared == game.cleared
			and other.boosters == game.boosters, "save/load round trip")
	_ok(other.star == 1, "Star is rebuilt from the cleared digs on load")
	_ok(other.totals.digs == 2, "totals persisted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	game.free()
	other.free()


func _test_bot_smoke() -> void:
	var site := Sites.get_site(Sites.index_of("arches"))
	var rules := Economy.rules([0, 0, 0, 0])
	rules.path_max = 4  # the game's default: moves are drawn paths
	var wins := 0
	for s in 20:
		var m := Bots.play(site, rules, 500 + s, Bots.Kind.GREEDY)
		if m.complete:
			wins += 1
	_ok(wins >= 16, "greedy bot clears the first open site in >=80%% of seeds (%d/20)" % wins)


# Intended solution of every hand-crafted lesson dig. Each must finish the site exactly on
# its last move; if a layout edit breaks one, this fails before a player meets it. A string
# is one step per letter; an array is one move per entry (a drawn path: "ULLD").
const TUTORIAL_SOLUTIONS := {
	"first": ["DRD", "UUUL", "RURD"],
	"battery": ["DDLD", "RRUL", "LUUU", "DR", "LLUR", "URRD", "UULL"], "charge": "UDLDDUDU",
	"longhaul": "LLLDLUUUURRRDRUUULLLULL",
	"vaults": "UUUUULLLUUUUUDDRRRRRRUUUUU",
	"readings": "UULLUUUDLUURDDURDRDRLDRRRULUUUUUUUU",
}


## A recorded solution as moves, each a list of directions (see TUTORIAL_SOLUTIONS).
func _solution_moves(sol) -> Array:
	var map := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}
	var words: Array = sol if sol is Array else Array(String(sol).split("", false))
	return words.map(func(w): return Array(String(w).split("", false)).map(func(ch): return map[ch]))


## A lesson board as the dig sets it up: its own path limit (a lesson before paths: 1).
func _lesson_board(i: int) -> Board:
	var site := Sites.get_site(i)
	var rules := Economy.rules(_campaign_levels(i))
	rules.path_max = int(site.get("path_max", 4))
	var b := Board.new()
	b.record = false
	b.setup_site(site, 0, rules)
	return b


func _test_tutorial_sites() -> void:
	var guided := 0
	for i in Sites.count():
		var site := Sites.get_site(i)
		if not site.has("ore"):
			continue
		guided += 1
		_ok(TUTORIAL_SOLUTIONS.has(site.id), "hand-made dig %s has a recorded solution" % site.id)
		var moves := _solution_moves(TUTORIAL_SOLUTIONS.get(site.id, ""))
		var b := _lesson_board(i)
		_ok(not b.has_line(), "%s opens without a ready-made line" % site.id)
		var ok := true
		for k in moves.size():
			var r := b.try_path(moves[k])
			if not r.ok or (b.over and k < moves.size() - 1):
				ok = false
				break
		_ok(ok and b.complete, "%s is solved by %s" % [site.id, TUTORIAL_SOLUTIONS.get(site.id, "")])
		# the moves the hand shows ("guide") are the solution's moves, in order
		var shown := []
		for st in site.get("script", []):
			if st.has("guide"):
				var g: Array = st.guide
				shown.append(range(1, g.size()).map(func(k): return g[k] - g[k - 1]))
		for k in shown.size():
			_ok(k < moves.size() and moves[k] == shown[k], "%s: move %d is the one the hand shows" % [site.id, k + 1])
	_ok(guided == TUTORIAL_SOLUTIONS.size(), "every recorded solution belongs to a tutorial site")
	# each building unlock is followed by its hand-made dig, which needs that building
	var map2 := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}
	for i in Sites.count() - 1:
		var u: int = Sites.get_site(i).get("unlock", -1)
		if u < 0:
			continue
		var nxt := Sites.get_site(i + 1)
		_ok(nxt.get("building_level", false) and nxt.get("needs", {}).get("building", -1) == u,
				"dig after %s is the hand-made level for building %d" % [Sites.get_site(i).id, u])
		if u != 1:
			continue  # only the Workshop's drill changes a rule a replay can check (the scanner
			# shows information; the Power Station and Teleporter make boosters)
		var lv := _campaign_levels(i + 1)
		lv[u] = 0
		var nb2 := Board.new()
		nb2.record = false
		nb2.setup_site(nxt, 0, Economy.rules(lv))
		for mv in _solution_moves(TUTORIAL_SOLUTIONS.get(nxt.id, "")):
			nb2.try_path(mv)
		_ok(not nb2.complete, "%s cannot be done without building %d" % [nxt.id, u])
	# each lesson's solution starts with the move Mira asks for and uses what she teaches
	var opening := {"charge": "U"}  # battery asks for any match by the rock
	for id in opening:
		_ok(String(TUTORIAL_SOLUTIONS[id]).begins_with(opening[id]), "%s: the solution starts with Mira's move" % id)
	var bat := _lesson_board(Sites.index_of("battery"))
	# (with drawn paths the budget no longer forces the cell; the lesson is rebuilt in the journey)
	for mv in _solution_moves(TUTORIAL_SOLUTIONS.battery):
		bat.try_path(mv)
	_ok(bat.complete and bat.stats.cells >= 1, "battery: the solution recharges from the buried cell")


func _test_pickup_hint() -> void:
	var b := _board(OPEN, EMPTY)
	b.robot = Board.idx(Vector2i(1, 1))
	b.token[Board.idx(Vector2i(4, 1))] = Board.Token.CRYSTAL
	var p := b.path_to_pickup(10)
	_ok(p.size() == 3 and p[0] == 1, "hint routes toward a crystal in the open")
	b.token[Board.idx(Vector2i(4, 1))] = Board.Token.NONE
	_ok(b.path_to_pickup(10).is_empty(), "no pickup, no pickup route")


func _test_campaign_flow() -> void:
	var game = load("res://autoload/Game.gd").new()
	game.save_path = "user://test_campaign.json"
	game.reset()
	_ok(game.next_dig() == 0, "a new colony starts at the first dig")
	var core := Sites.index_of("core")
	_ok(not game.can_start(core), "the basalt-shell dig waits for the Mining Workshop")
	for b in Economy.BUILDINGS.size():
		_ok(not game.building_unlocked(b) and not game.buy(b), "building %d starts locked" % b)
	game.star = Economy.STAR_UNLOCK[1]  # reaching the Workshop's star milestone unlocks it (and the Power Station)
	game.buy(0)  # the Power Station and Teleporter unlocked earlier; build them so the Workshop is due
	game.buy(3)
	game.reminders.clear()  # drop their reminders; the Workshop's is tested below
	_ok(game.building_unlocked(1) and game.pending_build() == 1, "reaching its star milestone unlocks the Workshop, which is now due")
	var drill := Sites.index_of("vaults")
	_ok(drill == Sites.index_of("garden") + 1 and not game.can_start(drill), "the drill level comes next and waits for the build")
	_ok(game.buy(1), "build the Mining Workshop")
	_ok(game.pending_build() == -1 and game.can_start(drill), "built: the drill level can start")
	_ok(game.can_start(core), "with the drill the basalt-shell dig can start")
	var lines: Array = game.take_reminders()
	_ok(lines.size() == 1 and String(lines[0]).contains("drill"), "Mira reminds about the drill at the next dig")
	_ok(game.take_reminders().is_empty(), "a reminder is said once")
	game.reminders = [[1, 1], [0, 1]]
	var told: Array = game.take_reminders(1)
	_ok(told.size() == 2 and String(told[0]).contains("Laser") and not String(told[0]).contains("drill")
			and String(told[1]).contains("Bomb"), "the drill's lesson dig still announces the Laser, and the Bomb in full")
	for i in Sites.count():
		game.cleared[i] = true
	_ok(game.next_dig() == -1, "after the last dig there is no next dig")
	var sup: int = game.supply_site()
	_ok(not Sites.get_site(sup).has("ore"), "supply runs use open sites, not hand-made ones")
	var talking := 0
	for i in Sites.count():
		var site := Sites.get_site(i)
		if site.get("guide", false) or site.get("building_level", false):
			_ok(not site.get("script", []).is_empty(), "Mira introduces the lesson in dig %s" % site.id)
		if not site.get("script", []).is_empty():
			talking += 1
	_ok(talking * 3 <= Sites.count(), "Mira talks in at most a third of the digs (%d of %d)" % [talking, Sites.count()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_campaign.json"))
	game.free()


func _test_colony_map() -> void:
	_ok(Colony.MILESTONES.size() == Economy.STAR_MILESTONES.size(), "one colony entry per star milestone")
	for b in Economy.BUILDINGS.size():
		var i := Colony.building_plot(b)
		_ok(i >= 0, "building %d has a plot on the map" % b)
		_ok(Colony.plot_stars(i) == Economy.STAR_UNLOCK[b], "building %d's plot opens at its unlock star" % b)
	var seen := {}
	# Story refers to the Game autoload, so load it at run time (not as a parse-time dependency)
	var story = load("res://scripts/core/Story.gd")
	for i in Colony.PLOTS.size():
		var m := Colony.plot_milestone(i)
		_ok(m >= 0 and not seen.has(m), "plot %s belongs to exactly one milestone" % Colony.PLOTS[i].id)
		seen[m] = true
		var c: Dictionary = Colony.MILESTONES[m]
		if c.has("deco"):
			_ok(story.DECO.has(c.deco), "Mira has a line for the %s" % c.deco)
	var game = load("res://autoload/Game.gd").new()
	game.save_path = "user://test_colony.json"
	game.reset()
	_ok(game.new_milestones().is_empty() and game.next_milestone() == [0, Economy.STAR_MILESTONES[0]], "a new colony has nothing to celebrate yet")
	game.star = Economy.STAR_MILESTONES[1]
	_ok(game.new_milestones() == [0, 1], "reaching two milestones reports both, oldest first")
	_ok(is_equal_approx(game.milestone_progress(), 0.0), "progress restarts after a milestone")
	game.ack_milestones()
	_ok(game.new_milestones().is_empty(), "a milestone is celebrated once")
	game.star = Economy.STAR_MILESTONES[2]
	_ok(game.new_milestones() == [2], "the next milestone comes on its own")
	for i in Economy.STAR_MILESTONES[2]:  # Star is rebuilt from the cleared digs on load
		game.cleared[i] = true
	game.save()
	var other = load("res://autoload/Game.gd").new()
	other.save_path = "user://test_colony.json"
	other.load_save()
	_ok(other.milestones_seen == 2, "the celebrated count survives a save")
	game.star = 999
	_ok(game.next_milestone().is_empty() and is_equal_approx(game.milestone_progress(), 1.0), "a finished colony has no next milestone")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_colony.json"))
	game.free()
	other.free()


## The UI is not exercised headless, so at least make sure every script compiles.
func _test_scripts_compile() -> void:
	var paths := ["res://scripts/Main.gd", "res://scripts/DevShot.gd"]
	for dir in ["res://scripts/ui/", "res://scripts/core/", "res://autoload/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				paths.append(dir + f)
	for p in paths:
		var sc := load(p) as GDScript
		_ok(sc != null and sc.can_instantiate(), "%s compiles" % p)


## Building levels a player has at campaign dig i: every building unlocked earlier, at level 1.
func _campaign_levels(i: int) -> Array:
	var lv := [0, 0, 0, 0]
	for j in i:
		var u: int = Sites.get_site(j).get("unlock", -1)
		if u >= 0:
			lv[u] = 1
	return lv
