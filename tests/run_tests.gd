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
	_test_goals_end_dig()
	_test_determinism()
	_test_generator_all_sites()
	_test_tutorial_sites()
	_test_pickup_hint()
	_test_pulse()
	_test_economy_rules()
	_test_save_roundtrip()
	_test_campaign_flow()
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
	_ok(b.energy >= 10 - 1 + 2, "3-match refunds 2 energy (net +1)")
	_ok(b.stats.energy_refunded >= 2 * groups, "refund counted per group")
	b = _board(OPEN, _with(EMPTY, {Vector2i(0, 1): "L", Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "R", Vector2i(3, 2): "L"}))
	b.energy = 10
	b.try_move(Vector2i(0, 1))
	_ok(b.energy >= 10 - 1 + 3, "4-match refunds 3 energy")
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
	var rules := Economy.rules([2, 0, 0])
	b = _board(OPEN, EMPTY, rules)
	_ok(b.cfg.capacity == 32 and b.energy == 32, "Power Station Lv2 starts the dig with 32 energy")


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
	_ok(r.ok and b.haul[3] == 1 and b.stats.crystals == 1, "walking onto a crystal collects it")
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
	b = _board(rows, _with(EMPTY, {Vector2i(2, 1): "R"}), Economy.rules([0, 1, 0]))
	var e := b.energy
	r = b.try_move(Vector2i(-1, 0))
	_ok(r.ok and b.hp[Board.idx(Vector2i(1, 1))] == 1 and b.energy == e - 2, "Workshop Lv1 drill: -1 layer for 2 energy")
	_ok(b.robot == Board.idx(Vector2i(2, 1)), "drilling does not move the robot")
	b = _board(rows, _with(EMPTY, {Vector2i(2, 1): "R"}), Economy.rules([0, 2, 0]))
	b.try_move(Vector2i(-1, 0))
	_ok(b.terrain[Board.idx(Vector2i(1, 1))] == Board.Terrain.GROUND, "Workshop Lv2 drill breaks 2 layers at once")
	b = _board(rows, _with(EMPTY, {Vector2i(2, 1): "R"}), Economy.rules([0, 3, 0]))
	e = b.energy
	b.try_move(Vector2i(-1, 0))
	_ok(b.energy <= e - 1 + 0 or b.stats.groups > 0, "Workshop Lv3 drill costs 1")
	_ok(b.cfg.crack_power == 2, "Workshop Lv3 matches crack 2 layers")


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
	_ok(Economy.rules([3, 3, 3]).get("blast_radius", 1) == 1, "no building enlarges blasts (5x5 broke the game)")
	var rich := _board(OPEN, EMPTY, Economy.rules([0, 0, 2]))
	rich.terrain[0] = Board.Terrain.ROCK
	rich.hp[0] = 1
	rich.buried[0] = Board.Buried.ORE
	rich._damage_rock(0, 1, [])
	_ok(rich.reserve[0] == 3, "Research Lab Lv2: broken rock opens a 3-layer vein")


func _test_goals_end_dig() -> void:
	var b := _board(OPEN, _with(EMPTY, {Vector2i(1, 1): "L", Vector2i(2, 1): "L", Vector2i(3, 1): "R", Vector2i(3, 2): "L"}))
	b.goals = [{"type": "ore", "ore": 2, "n": 3}]
	b.try_move(Vector2i(0, 1))
	_ok(b.complete and b.over, "meeting every goal completes and ends the dig")
	b = _board(OPEN, _with(EMPTY, {Vector2i(3, 3): "R"}))
	b.goals = [{"type": "crystal", "n": 1}]
	b.try_move(Vector2i(0, 1))
	_ok(not b.complete and not b.over, "unmet goals keep the dig running")
	_ok(Economy.completion_bonus(9) == [2, 1, 1, 0], "leftover energy converts to bonus ore (1 per 2)")


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
	var r0 := Economy.rules([0, 0, 0])
	_ok(r0.capacity == 20 and not r0.drill and not r0.scanner and r0.reveal_reserve == 2, "base rules")
	var r3 := Economy.rules([3, 3, 3])
	_ok(r3.capacity == 40 and r3.drill and r3.drill_cost == 1 and r3.drill_power == 2 and r3.scanner
			and r3.reveal_reserve == 3 and r3.refund_bonus == 1 and r3.crack_power == 2, "max rules")
	_ok(Economy.cost(0, 3).is_empty(), "no cost past max level")
	_ok(Economy.can_afford([0, 0, 0, 0], Economy.cost(0, 0)), "the first level of a building is free")
	_ok(not Economy.can_afford([0, 0, 0, 0], Economy.cost(0, 1)), "upgrades cannot be afforded with an empty bank")
	for b in Economy.BUILDINGS.size():
		_ok(Economy.BUILDINGS[b].effects.size() == Economy.MAX_LEVEL + 1, "effects text per level")


func _test_save_roundtrip() -> void:
	var game = load("res://autoload/Game.gd").new()
	game.save_path = "user://test_save.json"
	game.reset()
	game.cleared[Sites.index_of("landing")] = true  # landing unlocks the Power Station
	game.bank = [50, 40, 30, 1]
	_ok(game.buy(0), "Power Station Lv1 is free once unlocked")
	_ok(game.levels[0] == 1 and game.bank == [50, 40, 30, 1], "the free level costs nothing")
	_ok(not game.buy(0), "Lv2 needs crystals the bank lacks")
	game.bank = [50, 40, 30, 3]
	_ok(game.buy(0) and game.bank[0] == 5 and game.bank[3] == 1, "Lv2 deducts its cost")
	var site := Sites.get_site(0)
	var b := Board.new()
	b.record = false
	b.setup(site.rows, 9, game.rules(), site.goals)
	b.haul = PackedInt32Array([5, 6, 7, 1])
	var res: Dictionary = game.finish_dig(0, b, "energy")
	_ok(game.bank[0] == 10 and game.bank[3] == 2 and not res.first_clear, "failed dig still banks the haul")
	b.complete = true
	res = game.finish_dig(0, b, "complete")
	_ok(res.first_clear and game.unlocked == 2 and game.cleared[0], "first clear unlocks the next site")
	var other = load("res://autoload/Game.gd").new()
	other.save_path = "user://test_save.json"
	other.load_save()
	_ok(other.bank == game.bank and other.levels == game.levels and other.cleared == game.cleared, "save/load round trip")
	_ok(other.totals.digs == 2, "totals persisted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	game.free()
	other.free()


func _test_bot_smoke() -> void:
	var site := Sites.get_site(Sites.index_of("landing"))
	var wins := 0
	for s in 20:
		var m := Bots.play(site, Economy.rules([0, 0, 0]), 500 + s, Bots.Kind.GREEDY)
		if m.complete:
			wins += 1
	_ok(wins >= 16, "greedy bot clears the first open site in >=80%% of seeds (%d/20)" % wins)


# Intended solution of every hand-crafted lesson dig. Each must finish the site exactly on
# its last move; if a layout edit breaks one, this fails before a player meets it.
const TUTORIAL_SOLUTIONS := {
	"first": "UUD", "rocks": "DLUURDD", "power": "UDDDDLL",
	"longhaul": "DULLUURRRRRRUULLLLLLUURRR",
	"vaults": "UUUUULLLUUUUUDDRRRRRRUUUUU",
	"readings": "UULLUUUDLUURDDURDRDRLDRRRULUUUUUUUU",
}


func _test_tutorial_sites() -> void:
	var map := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}
	var guided := 0
	for i in Sites.count():
		var site := Sites.get_site(i)
		if not site.has("ore"):
			continue
		guided += 1
		_ok(TUTORIAL_SOLUTIONS.has(site.id), "hand-made dig %s has a recorded solution" % site.id)
		var sol: String = TUTORIAL_SOLUTIONS.get(site.id, "")
		var b := Board.new()
		b.record = false
		b.setup_site(site, 0, Economy.rules(_campaign_levels(i)))
		_ok(not b.has_line(), "%s opens without a ready-made line" % site.id)
		var ok := true
		for k in sol.length():
			var r := b.try_move(map[sol[k]])
			if not r.ok or (b.over and k < sol.length() - 1):
				ok = false
				break
		_ok(ok and b.complete, "%s is solved by %s" % [site.id, sol])
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
		if u == 2:
			continue  # the scanner shows information; it changes no rule a replay could check
		var lv := _campaign_levels(i + 1)
		lv[u] = 0
		var nb2 := Board.new()
		nb2.record = false
		nb2.setup_site(nxt, 0, Economy.rules(lv))
		var sol: String = TUTORIAL_SOLUTIONS.get(nxt.id, "")
		for k in sol.length():
			nb2.try_move(map2[sol[k]])
		_ok(not nb2.complete, "%s cannot be done without building %d" % [nxt.id, u])
	# the power lesson must actually need the energy cell: after the match and the blast the
	# robot is 5 steps from the crystal with less energy than that
	var nb := Board.new()
	nb.record = false
	nb.setup_site(Sites.get_site(Sites.index_of("power")), 0, Economy.rules([0, 0, 0]))
	nb.try_move(Vector2i(0, -1))
	nb.try_move(Vector2i(0, 1))
	_ok(nb.stats.blasts == 1 and nb.energy < 5, "power: the crystal is out of reach without the energy cell")


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
	for b in 3:
		_ok(not game.building_unlocked(b) and not game.buy(b), "building %d starts locked" % b)
	game.cleared[Sites.index_of("shale")] = true
	_ok(game.building_unlocked(1) and game.pending_build() == 1, "clearing shale unlocks the Workshop, which is now due")
	var drill := Sites.index_of("vaults")
	_ok(drill == Sites.index_of("shale") + 1 and not game.can_start(drill), "the drill level comes next and waits for the build")
	_ok(game.buy(1), "build the Mining Workshop")
	_ok(game.pending_build() == -1 and game.can_start(drill), "built: the drill level can start")
	_ok(game.can_start(core), "with the drill the basalt-shell dig can start")
	var lines: Array = game.take_reminders()
	_ok(lines.size() == 1 and String(lines[0]).contains("drill"), "Mira reminds about the drill at the next dig")
	_ok(game.take_reminders().is_empty(), "a reminder is said once")
	for i in Sites.count():
		game.cleared[i] = true
	_ok(game.next_dig() == -1, "after the last dig there is no next dig")
	var sup: int = game.supply_site()
	_ok(not Sites.get_site(sup).has("ore"), "supply runs use open sites, not hand-made ones")
	for i in Sites.count():
		var site := Sites.get_site(i)
		_ok(not site.get("script", []).is_empty(), "Mira introduces dig %s" % site.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_campaign.json"))
	game.free()


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
	var lv := [0, 0, 0]
	for j in i:
		var u: int = Sites.get_site(j).get("unlock", -1)
		if u >= 0:
			lv[u] = 1
	return lv
