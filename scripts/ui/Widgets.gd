class_name Widgets
extends RefCounted

## Tiny custom-drawn HUD widgets.


## Resource icon + count. Pops when the value changes.
class Chip extends Control:
	var res := 0
	var value := 0
	var _pop := 0.0
	var _font: Font

	func _init(r: int) -> void:
		res = r
		custom_minimum_size = Vector2(180, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_value(v: int) -> void:
		if v != value:
			_pop = 1.0
		value = v
		queue_redraw()

	func icon_global() -> Vector2:
		return get_global_transform_with_canvas() * Vector2(38, size.y * 0.5)

	func _process(delta: float) -> void:
		if _pop > 0.0:
			_pop = maxf(0.0, _pop - delta * 4.0)
			queue_redraw()

	func _draw() -> void:
		var c := Vector2(38, size.y * 0.5)
		var s := 30.0 * (1.0 + 0.35 * _pop)
		Widgets.draw_res_icon(self, c, s, res)
		var fs := Pal.FS
		var p := Vector2(82, size.y * 0.5 + fs * 0.36)
		draw_string_outline(_font, p, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
		draw_string(_font, p, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT.lerp(Pal.RES[res], _pop))


## Currency icon + count (Coin or Star). Pops when the value changes. Colony bank / results.
class CurrencyChip extends Control:
	var star := false
	var value := 0
	var _pop := 0.0
	var _font: Font

	func _init(is_star := false) -> void:
		star = is_star
		custom_minimum_size = Vector2(180, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_value(v: int) -> void:
		if v != value:
			_pop = 1.0
		value = v
		queue_redraw()

	func icon_global() -> Vector2:
		return get_global_transform_with_canvas() * Vector2(38, size.y * 0.5)

	func _process(delta: float) -> void:
		if _pop > 0.0:
			_pop = maxf(0.0, _pop - delta * 4.0)
			queue_redraw()

	func _draw() -> void:
		var c := Vector2(38, size.y * 0.5)
		var s := 26.0 * (1.0 + 0.35 * _pop)
		Widgets.draw_currency_icon(self, c, s, star)
		var fs := Pal.FS
		var p := Vector2(82, size.y * 0.5 + fs * 0.36)
		var col: Color = Pal.STAR if star else Pal.COIN
		draw_string_outline(_font, p, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
		draw_string(_font, p, str(value), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT.lerp(col, _pop))


## A glossy "jelly" rounded frame drawn by scripts/ui/jelly.gdshader (rim, gloss, dark inset
## face, drop shadow). Colours and sizes are shader parameters; lengths in pixels.
class Jelly extends Control:
	const SHADER := preload("res://scripts/ui/jelly.gdshader")
	var mat := ShaderMaterial.new()

	func _init(rim_color := Color("a27be0"), face := Color("2f1660"), face_bottom := Color("3d1d78")) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat.shader = SHADER
		material = mat
		set_param("rim_color", rim_color)
		set_param("face_color", face)
		set_param("face_color_bottom", face_bottom)
		resized.connect(func(): set_param("size", size); queue_redraw())

	func set_param(k: String, v: Variant) -> void:
		mat.set_shader_parameter(k, v)

	## The visible shape inside the node (the node keeps `pad` px around it for the shadow).
	func setup(r: Rect2, pad: float, radius: float, rim: float) -> void:
		position = r.position - Vector2(pad, pad)
		size = r.size + Vector2(pad, pad) * 2.0
		set_param("pad", pad)
		set_param("radius", radius)
		set_param("rim", rim)
		set_param("outline", maxf(2.0, rim * 0.18))
		set_param("drop_offset", Vector2(0, pad * 0.45))
		set_param("size", size)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


## The game's display font: Fredoka Bold (SIL OFL), a FontVariation resource so the engine owns
## and frees it (one made with FontVariation.new() keeps a text cache that points back at it and
## is reported leaked at exit).
static func game_font(_weight := 700) -> Font:
	var path := "res://assets/fonts/fredoka_bold.tres"
	return load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font


## The dig's top HUD, after the hero: one compact jelly plate (~73% of the board's width) with
## the moves left (energy) as a big number over "Moves", a thin divider, then one jelly slot
## per goal (rim coloured after the goal's gem) with "have/need" under it, and this dig's haul
## at the right end. Sizes follow `unit` (the board's cell size), so the HUD scales with it.
class DigHud extends Control:
	signal haul_tapped
	const LOW_MOVES := 5   # from here the count is red and every move hits (last-moves tension)
	const RIM := Color("a27be0")
	var unit := 120.0
	var coin := 0
	var coin_shown := 0
	var _coin_pop := 0.0
	var shown: Array = []   # counts on screen: they catch up when the flying ore lands
	var _wait := 0.0         # fallback: catch up anyway if nothing lands
	var energy := 0
	var goals: Array = []
	var have: Array = []
	var _pop: Array = []
	var _flash := 0.0
	var _hit := 0.0           # 1..0 after a move is spent on the last moves (squash-pop)
	var _shake := 0.0         # 1..0 plate shake with it
	var _shake_t := 0.0
	var _plate_at := Vector2.ZERO
	var calm := false         # the end-of-dig move conversion: hits pop but don't shake
	var coin_preview := false # dims the coin amount (unused for now)
	var _font: Font
	var _plate: Jelly
	var _top: Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		custom_minimum_size = Vector2(600, 170)
		_font = Widgets.game_font(700)
		_plate = Jelly.new()
		add_child(_plate)
		_top = Control.new()
		_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_top.draw.connect(_draw_top)
		add_child(_top)
		resized.connect(_layout)

	## Size the HUD from the board's cell size and width.
	func fit(cell: float, board_w: float) -> void:
		unit = cell * 1.25
		custom_minimum_size = Vector2(minf(board_w * 0.8, board_w), unit * 1.42)
		_layout()

	## Before the clear: the Coin this dig pays for clearing it, shown dimmed.
	func set_coin_preview(n: int) -> void:
		coin = n
		coin_shown = n
		coin_preview = true
		_top.queue_redraw()

	## One Coin landed during the end-of-dig conversion (a move left turned into Coin).
	func coin_tick() -> void:
		coin_preview = false
		coin_shown += 1
		coin = coin_shown
		_coin_pop = 1.0
		_top.queue_redraw()

	## Coin on the slot (no animation).
	func set_coin(c: int) -> void:
		coin = c
		if c < coin_shown:
			coin_shown = c
		_wait = 1.2
		_top.queue_redraw()

	## An ore/crystal particle landed on the HUD: its counter catches up and pops now.
	func landed(res) -> void:
		for i in goals.size():
			var g: Dictionary = goals[i]
			var hit := false
			if res is int:
				hit = (g.type == "ore" and g.ore == res) or (g.type == "crystal" and res == Board.RES_CRYSTAL) \
						or (g.type == "chunks" and res < Board.RES_CRYSTAL)
			else:
				hit = g.type == res
			if hit:
				if shown[i] != have[i]:
					shown[i] = have[i]
					_pop[i] = 1.0
				_top.queue_redraw()
				return

	func _flies(g: Dictionary) -> bool:
		return g.type in ["ore", "crystal", "chunks", "rock"]

	func haul_global() -> Vector2:
		return get_global_transform_with_canvas() * _haul_center()

	## Centre of the coin icon: the coin and its amount stack centred in the plate's height.
	func _haul_center() -> Vector2:
		var p := _shape()
		return Vector2(p.end.x - _rim() - unit * 0.48, p.get_center().y - unit * 0.13)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
			if e.position.distance_to(_haul_center()) < unit * 0.55:
				haul_tapped.emit()
				accept_event()

	func set_energy(e: int, _cap: int) -> void:
		if e > energy:
			_flash = 1.0
		elif e < energy and (e <= LOW_MOVES or calm):
			_hit = 1.0
			if not calm:
				_shake = 1.0
		energy = e
		_top.queue_redraw()

	func set_goals(g: Array) -> void:
		goals = g
		have = []
		shown = []
		_pop = []
		for i in g.size():
			have.append(0)
			shown.append(0)
			_pop.append(0.0)
		coin = 0
		coin_shown = 0
		_layout()

	func set_have(i: int, v: int) -> void:
		v = mini(v, goals[i].n)
		have[i] = v
		if not _flies(goals[i]) or v < shown[i]:
			# nothing flies here (rock, chunks...): show it straight away
			if v != shown[i]:
				_pop[i] = 1.0
			shown[i] = v
		elif _wait <= 0.0:
			_wait = 0.9  # catch up anyway if no particle lands (counted from the first miss)
		_top.queue_redraw()

	## Every counter to its real value at once (the dig is over: nothing may still read 1/2).
	func sync() -> void:
		for i in shown.size():
			if shown[i] != have[i]:
				shown[i] = have[i]
				_pop[i] = 1.0
		_wait = 0.0
		_top.queue_redraw()

	func target_global() -> Vector2:
		return get_global_transform_with_canvas() * _moves_center()

	func icon_global(i: int) -> Vector2:
		return get_global_transform_with_canvas() * _slot(i).get_center()

	func _shape() -> Rect2:
		return Rect2(Vector2.ZERO, size).grow(-unit * 0.06)

	func _rim() -> float:
		return unit * 0.1   # same weight as the board frame

	func _moves_center() -> Vector2:
		var p := _shape()
		return Vector2(p.position.x + unit * 0.78, p.get_center().y)

	func _divider_x() -> float:
		return _shape().position.x + unit * 1.48

	func _slot(i: int) -> Rect2:
		var p := _shape()
		var x0 := _divider_x() + unit * 0.15
		var x1 := p.end.x - _rim() - unit * 0.95
		var step := (x1 - x0) / maxf(1.0, goals.size())
		var s := minf(unit * 0.76, step - unit * 0.16)   # a little air between frames
		var cx := x0 + step * (i + 0.5)
		return Rect2(Vector2(cx - s * 0.5, p.position.y - s * 0.16), Vector2(s, s))

	func _layout() -> void:
		var p := _shape()
		_plate.setup(p, unit * 0.06, unit * 0.3, _rim())
		_plate_at = _plate.position
		_plate.set_param("rim_color", Color("7d52bf"))
		_plate.set_param("gloss", 0.35)
		_plate.set_param("face_color", Color("2b1258"))
		_plate.set_param("face_color_bottom", Color("3a1a74"))
		_top.position = Vector2.ZERO
		_top.size = size
		_top.queue_redraw()

	func _process(delta: float) -> void:
		if _wait > 0.0:
			_wait -= delta
			if _wait <= 0.0:
				for i in shown.size():
					if shown[i] != have[i]:
						shown[i] = have[i]
						_pop[i] = 1.0
				if coin_shown != coin:
					coin_shown = coin
					_coin_pop = 1.0
		var any := _flash > 0.0 or _coin_pop > 0.0
		if _hit > 0.0 or _shake > 0.0:
			_hit = maxf(0.0, _hit - delta / 0.32)
			_shake = maxf(0.0, _shake - delta / 0.2)
			_shake_t += delta
			var off := Vector2(sin(_shake_t * 70.0), 0.0) * unit * 0.035 * _shake
			_top.position = off
			_plate.position = _plate_at + off
			any = true
		_flash = maxf(0.0, _flash - delta * 3.0)
		_coin_pop = maxf(0.0, _coin_pop - delta * 3.0)
		for i in _pop.size():
			if _pop[i] > 0.0:
				_pop[i] = maxf(0.0, _pop[i] - delta * 3.0)
				any = true
		if any:
			_top.queue_redraw()

	func _text(c: Vector2, t: String, fs: int, col: Color, ol := 8) -> void:
		var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2(c.x - tw * 0.5, c.y + fs * 0.36)
		# crisp elevation: a hard dark copy just below the outlined text
		var drop := Vector2(0, maxf(1.5, fs * 0.045))
		_top.draw_string_outline(_font, at + drop, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color("12041f"))
		_top.draw_string(_font, at + drop, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("12041f"))
		_top.draw_string_outline(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color("1e0a3a"))
		_top.draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _frame(g: Dictionary) -> Texture2D:
		return Widgets.goal_frame(g)



	func _goal_color(g: Dictionary) -> Color:
		match g.type:
			"ore": return [Color("ff8a2a"), Color("2fd6e0"), Color("ffc928")][g.ore]
			"crystal": return Color("a66bff")
			"rock": return Color("a9b2c4")
			"blast": return Color("ff5aa0")
		return Color("ff5aa0")

	func _draw_top() -> void:
		var p := _shape()
		var mc := _moves_center()
		var col := Color.WHITE.lerp(Pal.GOOD, _flash)
		# a spent move pops the count once: wide and flat, then tall, then back
		var h := sin(PI * (1.0 - _hit)) * _hit
		var sq := Vector2(1.0 + 0.3 * h, 1.0 + 0.3 * h - 0.18 * sin(TAU * (1.0 - _hit)) * _hit)
		if energy <= LOW_MOVES and not calm:
			col = Pal.BAD.lerp(Color.WHITE, 0.2 + 0.5 * h)
		var nc := mc + Vector2(0, -unit * 0.14)
		_top.draw_set_transform(nc, 0.0, sq)
		_text(Vector2.ZERO, str(energy), int(unit * 0.56), col, int(unit * 0.11))
		_top.draw_set_transform(Vector2.ZERO)
		_text(mc + Vector2(0, unit * 0.3), "Moves", int(unit * 0.25), Color("f3c9ff"), int(unit * 0.08))
		var dx := _divider_x()
		_top.draw_line(Vector2(dx, p.position.y + p.size.y * 0.24), Vector2(dx, p.end.y - p.size.y * 0.24), Color(RIM, 0.35), 3.0, true)
		for i in goals.size():
			var g: Dictionary = goals[i]
			var r := _slot(i)
			var k: float = 1.0 + 0.22 * sin(PI * (1.0 - _pop[i])) * _pop[i]
			var fr := _frame(g)
			if fr != null:
				_top.draw_texture_rect(fr, r.grow(r.size.x * 0.06 * k), false)
			Widgets.draw_goal_icon(_top, r.get_center() + Vector2(0, r.size.y * 0.02), r.size.x * 0.4 * k, g)
			var done: bool = shown[i] >= g.n
			_text(Vector2(r.get_center().x, r.end.y + unit * 0.17), "%d/%d" % [shown[i], g.n], int(unit * 0.22), Pal.GOOD if done else Color.WHITE, int(unit * 0.08))
			if done:
				var c := r.end - Vector2(r.size.x * 0.12, r.size.y * 0.12)
				_top.draw_circle(c, r.size.x * 0.17, Pal.GOOD, true, -1.0, true)
				_top.draw_polyline(PackedVector2Array([c + Vector2(-r.size.x * 0.08, 0), c + Vector2(-r.size.x * 0.02, r.size.x * 0.06), c + Vector2(r.size.x * 0.09, -r.size.x * 0.06)]), Pal.BG, 4.0, true)
		# this dig's haul as Coin: a coin over the amount, lined up with the goal counts
		var hc := _haul_center()
		Widgets.draw_currency_icon(_top, hc, unit * 0.2 * (1.0 + 0.35 * sin(PI * (1.0 - _coin_pop)) * _coin_pop), false)
		var ny := hc.y + unit * 0.4
		var cc := Color.WHITE.lerp(Pal.COIN, _coin_pop)
		if coin_preview:
			cc = Color(1, 1, 1, 0.55)
		_text(Vector2(hc.x, ny), str(coin_shown), int(unit * 0.22), cc, int(unit * 0.08))


## Progress toward the colony's next star milestone: a star, a filling bar, "have / need".
class MilestoneBar extends Control:
	var frac := 0.0
	var text := ""
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_progress(f: float, t: String) -> void:
		frac = clampf(f, 0.0, 1.0)
		text = t
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var star_c := Vector2(h * 0.5, h * 0.5)
		var bar := Rect2(Vector2(h * 0.75, h * 0.25), Vector2(size.x - h * 0.85, h * 0.5))
		var sb := StyleBoxFlat.new()
		sb.anti_aliasing = true
		sb.set_corner_radius_all(int(bar.size.y * 0.5))
		sb.bg_color = Pal.OUTLINE
		draw_style_box(sb, bar.grow(3))
		sb.bg_color = Pal.PANEL_HI
		draw_style_box(sb, bar)
		if frac > 0.0:
			sb.bg_color = Pal.COIN
			draw_style_box(sb, Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * frac), bar.size.y)))
		Widgets.draw_currency_icon(self, star_c, h * 0.42, true)
		var fs := Pal.FS_SMALL
		var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(bar.get_center().x - tw * 0.5, bar.get_center().y + fs * 0.36)
		draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
		draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT)


## This dig's haul in one small slot: the four gems and the total. Ore that is not a goal flies
## here; the slot then shows the gem that came in for a moment. Tap it for the breakdown.
## (Mobile puzzle HUDs keep the top bar for goals and moves; extras get one compact slot.)
class HaulChip extends Control:
	signal tapped
	var values := [0, 0, 0, 0, 0]
	var _pop := 0.0
	var _last := -1
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(190, 76)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = ThemeDB.fallback_font

	func set_values(v: Array) -> void:
		for r in values.size():
			if v[r] > values[r]:
				_last = r
				_pop = 1.0
		values = v.duplicate()
		queue_redraw()

	func total() -> int:
		var t := 0
		for x in values:
			t += x
		return t

	func icon_global() -> Vector2:
		return get_global_transform_with_canvas() * _icon_c()

	func _icon_c() -> Vector2:
		return Vector2(44, size.y * 0.5)

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			tapped.emit()
			accept_event()

	func _process(delta: float) -> void:
		if _pop > 0.0:
			_pop = maxf(0.0, _pop - delta * 1.2)
			queue_redraw()

	func _draw() -> void:
		var c := _icon_c()
		if _pop > 0.0 and _last >= 0:
			# the gem that just came in, popping
			Widgets.draw_res_icon(self, c, 26.0 * (1.0 + 0.3 * minf(1.0, _pop * 2.0)), _last)
		else:
			for r in values.size():
				var o := Vector2(-17 if r % 2 == 0 else 17, -16 if r < 2 else 16)
				Widgets.draw_res_icon(self, c + o, 15.0, r)
		var fs := Pal.FS
		var p := Vector2(88, size.y * 0.5 + fs * 0.36)
		var txt := str(total())
		draw_string_outline(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
		draw_string(_font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.TEXT.lerp(Pal.RES[maxi(_last, 0)], minf(1.0, _pop * 2.0)))


## Battery bar whose length grows with capacity, so Power Station upgrades are visible.
class EnergyBar extends Control:
	var energy := 20
	var capacity := 20
	var max_capacity := 40
	var _flash := 0.0
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0, 70)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_energy(e: int, cap: int) -> void:
		if e > energy:
			_flash = 1.0
		energy = e
		capacity = cap
		queue_redraw()

	func target_global() -> Vector2:
		return get_global_transform_with_canvas() * Vector2(40, size.y * 0.5)

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 3.0)
			queue_redraw()

	func _draw() -> void:
		var h := size.y - 16
		var full_w := size.x - 210
		# starts at 60% of the room and grows to full with Power Station upgrades
		var w := full_w * (0.6 + 0.4 * float(capacity - 20) / (max_capacity - 20))
		var r := Rect2(Vector2(80, 8), Vector2(w, h))
		var frac := clampf(float(energy) / maxf(1.0, capacity), 0.0, 1.0)
		var col := Pal.GOOD if frac > 0.4 else (Pal.WARN if frac > 0.2 else Pal.BAD)
		col = col.lerp(Color.WHITE, _flash * 0.6)
		const K := 0.6  # battery art scale for a 54 px bar
		var inner := r.grow(-6)
		if Art.draw(self, "battery", r, Color.WHITE, K):
			inner = Art.face("battery", r, K).grow(-3)
		else:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(14)
			sb.bg_color = Pal.PANEL_HI
			sb.border_color = Pal.LINE
			sb.set_border_width_all(3)
			draw_style_box(sb, r)
		if energy > 0:
			var fr := Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * frac), inner.size.y))
			if not Art.draw(self, "bar_fill_base", fr, col, inner.size.y / 61.0):
				var f := StyleBoxFlat.new()
				f.set_corner_radius_all(11)
				f.bg_color = col
				draw_style_box(f, fr)
		# one tick per energy unit
		for i in range(1, capacity):
			var x := inner.position.x + inner.size.x * i / capacity
			draw_line(Vector2(x, inner.position.y + 4), Vector2(x, inner.end.y - 4), Color(0, 0, 0, 0.18), 2.0)
		Widgets.draw_bolt(self, Vector2(38, size.y * 0.5), 24, col)
		var txt := "%d/%d" % [energy, capacity]
		var tp := Vector2(r.end.x + 16, size.y * 0.5 + Pal.FS * 0.36)
		draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS, 8, Color("2a1830"))
		draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS, Pal.TEXT)


## One objective with a progress bar.
class GoalRow extends Control:
	var text := ""
	var have := 0
	var need := 1
	var color := Pal.ACCENT
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func setup(t: String, n: int, c: Color) -> void:
		text = t
		need = n
		color = c
		queue_redraw()

	func set_have(v: int) -> void:
		have = mini(v, need)
		queue_redraw()

	func _draw() -> void:
		var done := have >= need
		var fs := Pal.FS_SMALL
		draw_string_outline(_font, Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Pal.OUTLINE)
		draw_string(_font, Vector2(0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.GOOD if done else Pal.TEXT)
		var count := "%d / %d" % [have, need]
		var cw := _font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(_font, Vector2(size.x - cw, fs), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Pal.OUTLINE)
		draw_string(_font, Vector2(size.x - cw, fs), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Pal.GOOD if done else Pal.DIM)
		var r := Rect2(Vector2(0, fs + 12), Vector2(size.x, 12))
		draw_rect(r, Pal.PANEL_HI)
		draw_rect(Rect2(r.position, Vector2(r.size.x * float(have) / need, r.size.y)), Pal.GOOD if done else color)


## Objectives as big icons with counters, right above the board where the eyes are.
## Collected ore flies into the matching icon (see icon_global).
class GoalStrip extends Control:
	var goals: Array = []
	var have: Array = []
	var _pop: Array = []
	var big := false
	var _font: Font

	func _init(large := false) -> void:
		big = large
		custom_minimum_size = Vector2(0, 230 if large else 160)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func set_goals(g: Array) -> void:
		goals = g
		have = []
		_pop = []
		for i in g.size():
			have.append(0)
			_pop.append(0.0)
		queue_redraw()

	func set_have(i: int, v: int) -> void:
		v = mini(v, goals[i].n)
		if v != have[i]:
			_pop[i] = 1.0
		have[i] = v
		queue_redraw()

	func icon_global(i: int) -> Vector2:
		return get_global_transform_with_canvas() * _icon_pos(i)

	func _slot_w() -> float:
		return size.x / maxf(1.0, goals.size())

	func _icon_pos(i: int) -> Vector2:
		var w := _slot_w()
		if big:
			return Vector2(w * (i + 0.5), size.y * 0.36)
		# icon + count are centred as one group in the face above the bar
		var top := _top_area(i)
		var txt := "%d/%d" % [goals[i].n, goals[i].n]
		var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS).x
		var group := _icon_size() * 2.0 + 14.0 + tw
		return Vector2(top.get_center().x - group * 0.5 + _icon_size(), top.get_center().y)

	func _slot(i: int) -> Rect2:
		var w := _slot_w()
		return Rect2(Vector2(w * i + 8, 4), Vector2(w - 16, size.y - 8))

	func _bar(i: int) -> Rect2:
		var face := Art.face("plate", _slot(i))
		return Rect2(Vector2(face.position.x + 16, face.end.y - 26), Vector2(face.size.x - 32, 20))

	## The part of the slot's face above its progress bar.
	func _top_area(i: int) -> Rect2:
		var face := Art.face("plate", _slot(i))
		return Rect2(face.position, Vector2(face.size.x, _bar(i).position.y - 6 - face.position.y))

	func _icon_size() -> float:
		if big:
			return 62.0
		# the icon art is ~1.9 s tall: keep it inside the area above the bar
		return minf(46.0, (_top_area(0).size.y - 4.0) / 1.9) if goals.size() > 0 else 46.0

	func _process(delta: float) -> void:
		var any := false
		for i in _pop.size():
			if _pop[i] > 0.0:
				_pop[i] = maxf(0.0, _pop[i] - delta * 3.0)
				any = true
		if any:
			queue_redraw()

	func _draw() -> void:
		var w := _slot_w()
		var s := _icon_size()
		for i in goals.size():
			var g: Dictionary = goals[i]
			var done: bool = have[i] >= g.n
			var c := _icon_pos(i)
			var col := Pal.GOOD if done else Pal.TEXT
			var slot := _slot(i)
			var tint := Color.WHITE.lerp(Pal.GOOD, 0.35) if done else Color.WHITE.lerp(Color(1.3, 1.3, 1.3), _pop[i])
			if not Art.draw(self, "plate", slot, tint):
				var sb := StyleBoxFlat.new()
				sb.set_corner_radius_all(26)
				sb.bg_color = Pal.PANEL.lerp(Pal.GOOD, 0.18) if done else Pal.PANEL
				sb.border_color = Pal.GOOD if done else Pal.LINE.lerp(Color.WHITE, _pop[i] * 0.6)
				sb.set_border_width_all(3)
				draw_style_box(sb, slot)
			Widgets.draw_goal_icon(self, c, s * (1.0 + 0.3 * _pop[i]), g)
			var fs := Pal.FS_BIG if big else Pal.FS
			var txt := ("x %d" % g.n) if big else ("%d/%d" % [have[i], g.n])
			var tw := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tp := Vector2(c.x - tw * 0.5, size.y * 0.82) if big else Vector2(c.x + s + 14.0, c.y + fs * 0.36)
			draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Pal.OUTLINE)
			draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			if not big:
				var bar := _bar(i)
				const K := 0.29  # bar art scale for a 20 px bar
				var frac: float = float(have[i]) / g.n
				if Art.draw(self, "bar_track", bar, Color.WHITE, K):
					var inner := Art.face("bar_track", bar, K)
					if frac > 0.0:
						var fr := Rect2(inner.position, Vector2(maxf(inner.size.y * 1.5, inner.size.x * frac), inner.size.y))
						Art.draw(self, "bar_fill_base", fr, Pal.GOOD if done else Pal.ACCENT, inner.size.y / 61.0)
				else:
					draw_rect(bar, Pal.PANEL_HI)
					draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Pal.GOOD if done else Pal.ACCENT)
			if done:
				var k := c + Vector2(s * 0.75, -s * 0.75)
				draw_circle(k, s * 0.38, Pal.GOOD)
				draw_polyline(PackedVector2Array([k + Vector2(-s * 0.18, 0), k + Vector2(-s * 0.04, s * 0.14), k + Vector2(s * 0.2, -s * 0.14)]), Pal.BG, 5.0, true)


## A Coin cost as a coin icon + number; red when you cannot afford it.
class CostRow extends Control:
	var coin_cost := 0
	var coin_have := 0
	var _font: Font

	func _init() -> void:
		custom_minimum_size = Vector2(0, 52)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = ThemeDB.fallback_font

	func setup(cost: int, have: int) -> void:
		coin_cost = cost
		coin_have = have
		queue_redraw()

	func _draw() -> void:
		if coin_cost <= 0:
			return
		var x := 18.0
		Widgets.draw_currency_icon(self, Vector2(x, size.y * 0.5), 15, false)
		var enough: bool = coin_have >= coin_cost
		draw_string(_font, Vector2(x + 26, size.y * 0.5 + Pal.FS_SMALL * 0.36), str(coin_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, Pal.FS_SMALL, Pal.TEXT if enough else Pal.BAD)


## Building badge: the tool it gives the robot.
class BuildingIcon extends Control:
	var building := 0
	var level := 0

	func _init(b: int, px := 110.0) -> void:
		building = b
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.5
		draw_circle(c, s, Pal.PANEL_HI)
		draw_arc(c, s - 3, 0, TAU, 40, Pal.GOOD if level > 0 else Pal.LINE, 5.0, true)
		Widgets.draw_building_icon(self, c, s * 0.55, building, Pal.TEXT if level > 0 else Pal.DIM)


static func draw_goal_icon(ci: CanvasItem, c: Vector2, s: float, g: Dictionary) -> void:
	match g.type:
		"treasure":
			var t := Art.tex("res://assets/ui/treasure.png")
			if t != null:
				ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 1.1, Vector2(s, s) * 2.2), false)
				return
		"ore":
			draw_res_icon(ci, c, s * 0.8, g.ore)
		"crystal":
			draw_res_icon(ci, c, s * 0.85, Board.RES_CRYSTAL)
		"rock":
			var rk := Art.rock(1, 1)
			if rk != null:
				ci.draw_texture_rect(rk, Rect2(c - Vector2(s, s) * 1.05, Vector2(s, s) * 2.1), false)
				return
			var pts := PackedVector2Array()
			for k in 8:
				var a := TAU * (k + 0.5) / 8.0
				pts.append(c + Vector2(cos(a), sin(a)) * s * (0.85 + 0.08 * sin(k * 2.3)))
			ci.draw_colored_polygon(pts, Pal.ROCK[1])
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.6), c + Vector2(s * 0.1, -s * 0.05), c + Vector2(-s * 0.15, s * 0.3), c + Vector2(s * 0.05, s * 0.7)]), Pal.ROCK[3], 5.0, true)
		"generator", "core", "cage", "web":
			# obstacle goals show the obstacle itself (a generator switched on)
			var name: String = {"generator": "generator_on", "core": "core", "cage": "cage", "web": "web_icon"}[g.type]
			var ot := Art.tex("res://assets/obstacles/%s.png" % name)
			if ot != null:
				ci.draw_texture_rect(ot, Rect2(c - Vector2(s, s) * 1.1, Vector2(s, s) * 2.2), false)
				return
			ci.draw_circle(c, s * 0.8, Color("5ff2c8"))
		"blast":
			ci.draw_arc(c, s * 0.62, 0, TAU, 24, Pal.CHARGE, s * 0.22, true)
			ci.draw_circle(c, s * 0.24, Pal.CHARGE)
			for k in 8:
				var d := Vector2.from_angle(TAU * k / 8.0)
				ci.draw_line(c + d * s * 0.8, c + d * s * 1.0, Pal.CHARGE, 5.0, true)
		_:  # any ore
			draw_res_icon(ci, c + Vector2(0, -s * 0.32), s * 0.42, 2)
			draw_res_icon(ci, c + Vector2(-s * 0.42, s * 0.3), s * 0.42, 0)
			draw_res_icon(ci, c + Vector2(s * 0.42, s * 0.3), s * 0.42, 1)


static func draw_building_icon(ci: CanvasItem, c: Vector2, s: float, b: int, col: Color) -> void:
	match b:
		0:  # power station: battery with a bolt
			ci.draw_rect(Rect2(c - Vector2(s * 0.55, s * 0.85), Vector2(s * 1.1, s * 1.7)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 1.05), Vector2(s * 0.5, s * 0.2)), col)
			draw_bolt(ci, c, s * 0.6, Pal.BG)
		1:  # workshop: drill bit
			ci.draw_rect(Rect2(c + Vector2(-s * 0.9, -s * 0.35), Vector2(s * 0.8, s * 0.7)), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.5), c + Vector2(s * 1.0, 0), c + Vector2(-s * 0.1, s * 0.5)]), col)
			for k in 3:
				var x := -s * 0.05 + k * s * 0.3
				ci.draw_line(c + Vector2(x, -s * 0.42 + k * s * 0.13), c + Vector2(x + s * 0.18, s * 0.42 - k * s * 0.13), Pal.BG, 4.0)
		_:  # lab: scanner dish
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.8, PI * 0.15, PI * 0.85, 16, col, 7.0, true)
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.45, PI * 0.2, PI * 0.8, 12, col, 6.0, true)
			ci.draw_circle(c + Vector2(0, -s * 0.1), s * 0.16, col)
			ci.draw_line(c + Vector2(0, s * 0.3), c + Vector2(0, s * 0.95), col, 6.0)


## Currency icon: a gold coin, or a violet star (GDD v3 two-currency economy).
static func draw_currency_icon(ci: CanvasItem, c: Vector2, s: float, star: bool) -> void:
	var t := Art.tex("res://assets/ui/%s.png" % ("star" if star else "coin"))
	if t != null:
		ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 1.15, Vector2(s, s) * 2.3), false)
		return
	if star:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + TAU * k / 10.0
			var r := s if k % 2 == 0 else s * 0.44
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(pts, Pal.STAR)
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Pal.CRYSTAL_DARK, maxf(2.0, s * 0.1), true)
	else:
		ci.draw_circle(c, s, Pal.COIN)
		ci.draw_arc(c, s * 0.96, 0, TAU, 28, Pal.COIN_DARK, maxf(2.0, s * 0.14), true)
		ci.draw_circle(c, s * 0.45, Pal.COIN_DARK)


static func draw_res_icon(ci: CanvasItem, c: Vector2, s: float, res: int) -> void:
	var t := Art.ore(res)
	if t != null:
		# ore sprites share one canvas with the gem centred on its box, so every kind lands
		# on the same point and looks the same size (see tools/art/build_assets.py)
		ci.draw_texture_rect(t, Rect2(c - Vector2(s, s) * 1.15, Vector2(s, s) * 2.3), false)
		return
	var col: Color = Pal.RES[res]
	match res:
		0:
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7), col)
		1:
			ci.draw_circle(c, s, col)
		2:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s, s * 0.8), c + Vector2(-s, s * 0.8)]), col)
		_:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 0.8, -s * 0.2), c + Vector2(0, s * 1.1), c + Vector2(-s * 0.8, -s * 0.2)]), col)


static func draw_bolt(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.55, s * 0.1), c + Vector2(-s * 0.05, s * 0.1),
		c + Vector2(-s * 0.2, s), c + Vector2(s * 0.55, -s * 0.1), c + Vector2(s * 0.05, -s * 0.1)]), col)


## The painted slot frame for a goal, coloured after its gem.
static func goal_frame(g: Dictionary) -> Texture2D:
	var n := "pink"
	match g.type:
		"ore": n = ["orange", "cyan", "yellow", "pink"][g.ore]
		"crystal": n = "violet"
		"rock", "cage": n = "grey"
		"web": n = "violet"
		"treasure": n = "yellow"
		"generator", "core": n = "cyan"
	return Art.tex("res://assets/ui/slot_%s.png" % n)


## Text in the HUD's style: centred on `c`, dark outline and a crisp dark copy just below it.
static func shadow_text(ci: CanvasItem, font: Font, c: Vector2, t: String, fs: int, col: Color, ol := -1) -> void:
	if ol < 0:
		ol = int(fs * 0.16)
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(c.x - tw * 0.5, c.y + fs * 0.36)
	var drop := Vector2(0, maxf(2.0, fs * 0.06))
	var a := col.a
	ci.draw_string_outline(font, at + drop, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color("12041f", a))
	ci.draw_string(font, at + drop, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("12041f", a))
	ci.draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color("1e0a3a", a))
	ci.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Text centred on `c` by its ink (the glyphs' measured outline, not the font's line box), so
## a short number sits dead centre in a badge; the drop shadow and outline are balanced around
## it. Same look as shadow_text.
static func ink_text(ci: CanvasItem, font: Font, c: Vector2, t: String, fs: int, col: Color, ol := -1) -> void:
	if ol < 0:
		ol = int(fs * 0.16)
	var ts := TextServerManager.get_primary_interface()
	var rid: RID = font.get_rids()[0]
	var pen := 0.0
	var x0 := INF
	var x1 := -INF
	var y0 := INF
	var y1 := -INF
	for i in t.length():
		var g := ts.font_get_glyph_index(rid, fs, t.unicode_at(i), 0)
		var off := ts.font_get_glyph_offset(rid, Vector2i(fs, 0), g)
		var sz := ts.font_get_glyph_size(rid, Vector2i(fs, 0), g)
		x0 = minf(x0, pen + off.x)
		x1 = maxf(x1, pen + off.x + sz.x)
		y0 = minf(y0, off.y)
		y1 = maxf(y1, off.y + sz.y)
		pen += ts.font_get_glyph_advance(rid, fs, g).x
	var drop := maxf(2.0, fs * 0.06)
	# baseline origin that puts the ink box's centre on c (the shadow below lifts it a hair)
	var at := Vector2(c.x - (x0 + x1) * 0.5, c.y - (y0 + y1) * 0.5 - drop * 0.4)
	var a := col.a
	ci.draw_string_outline(font, at + Vector2(0, drop), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color("12041f", a))
	ci.draw_string(font, at + Vector2(0, drop), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("12041f", a))
	ci.draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color("1e0a3a", a))
	ci.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Back-out ease (0..1 -> 0..1 with an overshoot of about `over`), for pops.
static func back_out(x: float, over := 3.0) -> float:
	var s := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + (over + 1.0) * s * s * s + over * s * s


## A jelly plate (the HUD's look) behind one content child, `margin` px inside the rim.
class JellyCard extends Container:
	var margin := 56.0
	var rim := Color("7d52bf")  # a hard dig's card wears its tier's colour
	var _plate: Jelly

	func _init(m := 56.0) -> void:
		margin = m
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_plate = Jelly.new()
		add_child(_plate)
		resized.connect(func(): pivot_offset = size * 0.5)

	func _get_minimum_size() -> Vector2:
		var m := Vector2.ZERO
		for c in get_children():
			if c != _plate and c is Control and c.visible:
				m = m.max((c as Control).get_combined_minimum_size())
		return m + Vector2(margin, margin) * 2.0

	func _notification(what: int) -> void:
		if what != NOTIFICATION_SORT_CHILDREN:
			return
		var pad := 18.0
		_plate.setup(Rect2(Vector2.ZERO, size), pad, 64.0, 22.0)
		_plate.set_param("rim_color", rim)
		_plate.set_param("gloss", 0.35)
		_plate.set_param("face_color", Color("2b1258"))
		_plate.set_param("face_color_bottom", Color("3a1a74"))
		for c in get_children():
			if c != _plate and c is Control:
				fit_child_in_rect(c, Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0))


## A jelly button: a bright jelly plate in `rim`/`face` colours, Fredoka label, squashes when held.
class JellyButton extends Button:
	var _plate: Jelly

	func _init(t: String, rim: Color, face: Color, h := 132.0, fs := 52) -> void:
		text = t
		custom_minimum_size = Vector2(0, h)
		focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(s, empty)
		add_theme_font_override("font", Widgets.game_font())
		add_theme_font_size_override("font_size", fs)
		add_theme_constant_override("outline_size", int(fs * 0.22))
		add_theme_color_override("font_outline_color", face.darkened(0.6))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			add_theme_color_override(c, Color.WHITE)
		_plate = Jelly.new(rim, face.lightened(0.08), face.darkened(0.12))
		_plate.show_behind_parent = true
		_plate.set_param("gloss", 0.7)
		_plate.set_param("inner_shadow", 0.25)
		_plate.set_param("outline_color", face.darkened(0.7))
		add_child(_plate)
		resized.connect(_layout)
		button_down.connect(func(): _squash(Vector2(1.05, 0.9)))
		button_up.connect(func(): _squash(Vector2.ONE))

	func _layout() -> void:
		pivot_offset = size * 0.5
		_plate.setup(Rect2(Vector2.ZERO, size), 14.0, size.y * 0.42, size.y * 0.13)

	## Recolour the plate (e.g. the colony's DIG button turning into SUPPLY RUN).
	func paint(rim: Color, face: Color) -> void:
		_plate.set_param("rim_color", rim)
		_plate.set_param("face_color", face.lightened(0.08))
		_plate.set_param("face_color_bottom", face.darkened(0.12))
		_plate.set_param("outline_color", face.darkened(0.7))
		add_theme_color_override("font_outline_color", face.darkened(0.6))

	func _squash(to: Vector2) -> void:
		create_tween().tween_property(self, "scale", to, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Juicy text: pops in with an overshoot and a white flash after `delay`; with `breathe` it
## then keeps pulsing gently (an invitation, e.g. "Tap to start").
class JuicyText extends Control:
	var text := ""
	var fs := 64
	var color := Color.WHITE
	var delay := 0.0
	var breathe := false
	var _t := 0.0
	var _font: Font

	func _init(t: String, size_px := 64, col := Color.WHITE, wait := 0.0, pulse := false) -> void:
		text = t
		fs = size_px
		color = col
		delay = wait
		breathe = pulse
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = Widgets.game_font()
		custom_minimum_size = Vector2(_font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.6, fs * 1.4)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var t := _t - delay
		if t <= 0.0:
			return
		var sc := Widgets.back_out(t / 0.32)
		var a := clampf(t / 0.12, 0.0, 1.0)
		if breathe:
			sc *= 1.0 + 0.06 * sin(maxf(0.0, t - 0.32) * 4.2)
			a *= 0.8 + 0.2 * sin(maxf(0.0, t - 0.32) * 4.2 + 1.0)
		var c := size * 0.5
		draw_set_transform(c, 0.0, Vector2(sc, sc))
		Widgets.shadow_text(self, _font, Vector2.ZERO, text, fs, Color(color, a))
		var flash := 1.0 - clampf(t / 0.18, 0.0, 1.0)
		if flash > 0.0:
			Widgets.shadow_text(self, _font, Vector2.ZERO, text, fs, Color(1, 1, 1, flash * 0.8), 0)
		draw_set_transform(Vector2.ZERO)


## The dig's goals as big framed slots, each with the amount under it; the slots pop in one
## after another. No words: the gem in the frame says what to collect.
class GoalCard extends Control:
	const SLOT := 210.0
	const GAP := 48.0
	var goals: Array = []
	var _t := 0.0
	var _font: Font

	func _init(g: Array) -> void:
		goals = g
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = Widgets.game_font()
		custom_minimum_size = Vector2(g.size() * SLOT + (g.size() - 1) * GAP, SLOT + 110.0)

	func _process(delta: float) -> void:
		_t += delta
		if _t < 2.0:
			queue_redraw()

	func _draw() -> void:
		var x0 := (size.x - (goals.size() * SLOT + (goals.size() - 1) * GAP)) * 0.5
		for i in goals.size():
			var g: Dictionary = goals[i]
			var t := _t - 0.15 - i * 0.12
			if t <= 0.0:
				continue
			var k := Widgets.back_out(t / 0.38)
			var c := Vector2(x0 + i * (SLOT + GAP) + SLOT * 0.5, SLOT * 0.5)
			draw_set_transform(c, 0.0, Vector2(k, k))
			var fr := Widgets.goal_frame(g)
			if fr != null:
				draw_texture_rect(fr, Rect2(-Vector2(SLOT, SLOT) * 0.53, Vector2(SLOT, SLOT) * 1.06), false)
			Widgets.draw_goal_icon(self, Vector2(0, SLOT * 0.02), SLOT * 0.4, g)
			draw_set_transform(Vector2.ZERO)
			var tk := Widgets.back_out((t - 0.1) / 0.32)
			if tk > 0.0:
				draw_set_transform(c + Vector2(0, SLOT * 0.5 + 58.0), 0.0, Vector2(tk, tk))
				Widgets.shadow_text(self, _font, Vector2.ZERO, str(g.n), 76, Color.WHITE)
				draw_set_transform(Vector2.ZERO)


## The dig's reward: Coin (and Star, if any) counting up from 0 after `delay`, each icon
## popping when its count lands.
class RewardRow extends Control:
	var coin := 0
	var star := 0
	var delay := 0.3
	var note := ""   # where the Coin came from, small under the row
	var _t := 0.0
	var _font: Font

	func _init(c: int, s: int, wait := 0.3, why := "") -> void:
		coin = c
		star = s
		delay = wait
		note = why
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = Widgets.game_font()
		custom_minimum_size = Vector2(0, 150 if why == "" else 210)

	func _process(delta: float) -> void:
		_t += delta
		if _t < delay + 3.0:
			queue_redraw()

	func _count_dur(n: int) -> float:
		return clampf(0.25 + n * 0.03, 0.3, 0.9)

	func _draw() -> void:
		var items := [[false, coin]]
		if star > 0:
			items.append([true, star])
		var w := 300.0
		var x0 := (size.x - w * items.size()) * 0.5
		var start := delay
		for i in items.size():
			var is_star: bool = items[i][0]
			var n: int = items[i][1]
			var t := _t - start
			var dur := _count_dur(n)
			start += dur + 0.15
			if t <= 0.0:
				continue
			var shown := int(round(n * clampf(t / dur, 0.0, 1.0)))
			var land := t - dur   # > 0 once the count is done: the icon pops
			var k := Widgets.back_out(t / 0.3)
			if land > 0.0 and land < 0.35:
				k *= 1.0 + 0.3 * sin(PI * land / 0.35)
			var c := Vector2(x0 + w * (i + 0.5), 75.0)
			Widgets.draw_currency_icon(self, c + Vector2(-70, 0), 46.0 * k, is_star)
			var col: Color = Pal.STAR if is_star else Pal.COIN
			Widgets.shadow_text(self, _font, c + Vector2(50, 0), str(shown), 80, Color.WHITE.lerp(col, 0.55))
		if note != "":
			var a := clampf((_t - delay) / 0.3, 0.0, 1.0)
			Widgets.shadow_text(self, _font, Vector2(size.x * 0.5, 172), note, 38, Color(Color("f3c9ff"), a))


## A jelly ribbon that slides in from the left, holds, and leaves to the right, then frees
## itself (e.g. "5 moves left!"). Centred vertically on `y` of its parent.
class Banner extends Control:
	var text := ""
	var _t := 0.0
	var _plate: Jelly
	var _font: Font
	const IN := 0.3
	const OUT := 0.22
	var hold := 0.45
	var fs := 72

	func _init(t: String, rim := Color("ffb36b"), face := Color("e2563f"), hold_s := 0.45, font_px := 72) -> void:
		text = t
		hold = hold_s
		fs = font_px
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = Widgets.game_font()
		_plate = Jelly.new(rim, face.lightened(0.06), face.darkened(0.15))
		_plate.set_param("gloss", 0.7)
		_plate.set_param("inner_shadow", 0.25)
		_plate.set_param("outline_color", face.darkened(0.7))
		_plate.show_behind_parent = true
		add_child(_plate)

	func show_at(y: float, w: float) -> void:
		size = Vector2(w * 0.8, fs * 2.1)
		position = Vector2(-size.x, y - size.y * 0.5)
		_plate.setup(Rect2(Vector2.ZERO, size), 16.0, 60.0, 18.0)
		pivot_offset = size * 0.5
		set_meta("w", w)

	func _process(delta: float) -> void:
		_t += delta
		var w: float = get_meta("w", 1080.0)
		var mid := (w - size.x) * 0.5
		if _t < IN:
			var k := Widgets.back_out(_t / IN, 1.6)
			position.x = lerpf(-size.x, mid, k)
			rotation = -0.06 * (1.0 - k)
		elif _t < IN + hold:
			position.x = mid
			rotation = 0.0
			var h := _t - IN
			scale = Vector2.ONE * (1.0 + 0.06 * sin(minf(h / 0.25, 1.0) * PI))
		elif _t < IN + hold + OUT:
			var k := (_t - IN - hold) / OUT
			position.x = lerpf(mid, w + 20.0, k * k)
			rotation = 0.05 * k
		else:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		Widgets.shadow_text(self, _font, size * 0.5, text, fs, Color.WHITE)


## A coin and an amount, popping in after `delay` (the goal card's clear reward).
class CoinTag extends Control:
	var amount := 0
	var delay := 0.0
	var _t := 0.0
	var _font: Font

	func _init(n: int, wait := 0.0) -> void:
		amount = n
		delay = wait
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = Widgets.game_font()
		custom_minimum_size = Vector2(240, 100)

	func _process(delta: float) -> void:
		_t += delta
		if _t < delay + 1.0:
			queue_redraw()

	func _draw() -> void:
		var k := Widgets.back_out((_t - delay) / 0.32)
		if k <= 0.0:
			return
		var c := size * 0.5
		draw_set_transform(c, 0.0, Vector2(k, k))
		Widgets.draw_currency_icon(self, Vector2(-42, 0), 34.0, false)
		Widgets.shadow_text(self, _font, Vector2(34, 0), str(amount), 64, Color.WHITE.lerp(Pal.COIN, 0.55))
		draw_set_transform(Vector2.ZERO)


## A painted picture that pops in after `delay` (e.g. the gold rush emblem on its card).
class Picture extends Control:
	var tex: Texture2D
	var delay := 0.0
	var _t := 0.0

	func _init(path: String, px: float, wait := 0.0) -> void:
		tex = Art.tex(path)
		delay = wait
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(px, px)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := Widgets.back_out((_t - delay) / 0.4)
		if k <= 0.0 or tex == null:
			return
		var c := size * 0.5
		var wob := sin(maxf(0.0, _t - delay - 0.4) * 2.2) * 0.03
		draw_set_transform(c, wob, Vector2(k, k) * (1.0 + 0.03 * sin(_t * 3.0)))
		draw_texture_rect(tex, Rect2(-size * 0.5, size), false)
		draw_set_transform(Vector2.ZERO)


## The colony's top bar, no plate (the art behind has the contrast): the Coin amount on the
## left, then a short chunky bar toward the next star milestone with the star sitting on its
## end. The right side stays free for a future lives/energy counter.
class ColonyTop extends Control:
	var coin := 0
	var frac := 0.0
	var text := ""
	var _font: Font
	var _coin_pop := 0.0
	const BAR_W := 330.0
	const BAR_H := 62.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 110)
		_font = Widgets.game_font()

	func set_values(c: int, f: float, t: String) -> void:
		if c != coin:
			_coin_pop = 1.0
		coin = c
		frac = clampf(f, 0.0, 1.0)
		text = t
		queue_redraw()

	func _coin_center() -> Vector2:
		return Vector2(46, size.y * 0.5)

	func coin_global() -> Vector2:
		return get_global_transform_with_canvas() * _coin_center()

	func _process(delta: float) -> void:
		if _coin_pop > 0.0:
			_coin_pop = maxf(0.0, _coin_pop - delta * 3.0)
			queue_redraw()

	func _draw() -> void:
		var cy := size.y * 0.5
		var k := 1.0 + 0.3 * sin(PI * (1.0 - _coin_pop)) * _coin_pop
		Widgets.draw_currency_icon(self, _coin_center(), 36.0 * k, false)
		var amount := Widgets.short_number(coin)
		var aw := _font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 58).x
		Widgets.shadow_text(self, _font, Vector2(98 + aw * 0.5, cy), amount, 58, Color.WHITE)
		# milestone bar: dark rim, deep track, orange fill with a gloss streak, count on it
		var x0 := 98.0 + maxf(aw, 110.0) + 44.0
		var bar := Rect2(Vector2(x0, cy - BAR_H * 0.5), Vector2(BAR_W, BAR_H))
		var sb := StyleBoxFlat.new()
		sb.anti_aliasing = true
		sb.set_corner_radius_all(int(BAR_H * 0.5))
		sb.bg_color = Color("150830")
		draw_style_box(sb, bar.grow(5))
		sb.bg_color = Color("3d2470")
		draw_style_box(sb, bar)
		if frac > 0.0:
			sb.bg_color = Color("ffae2b")
			var fill := Rect2(bar.position, Vector2(maxf(bar.size.y, bar.size.x * frac), bar.size.y))
			draw_style_box(sb, fill)
			sb.set_corner_radius_all(int(BAR_H * 0.2))
			sb.bg_color = Color(1, 1, 1, 0.3)
			draw_style_box(sb, Rect2(fill.position + Vector2(14, 7), Vector2(maxf(0.0, fill.size.x - 28), fill.size.y * 0.26)))
		Widgets.shadow_text(self, _font, bar.get_center() - Vector2(18, 0), text, 40, Color.WHITE)
		# the star sits on the bar's end, overlapping it
		Widgets.draw_currency_icon(self, Vector2(bar.end.x - 4, cy), 44.0, true)


## Short Coin amounts for tight spots: 950, 1.2K, 25K, 1.5M.
static func short_number(n: int) -> String:
	if n < 1000:
		return str(n)
	if n < 10000:
		return "%.1fK" % (n / 1000.0)
	if n < 1000000:
		return "%dK" % (n / 1000)
	return "%.1fM" % (n / 1000000.0)


## The bottom tab bar: a jelly plate across the screen with five tabs (icon over a label).
## The selected tab sits on a raised, lighter tile and its icon is bigger.
class NavBar extends Control:
	signal tab_pressed(i: int)
	const TABS := [["market", "Market"], ["ranks", "Ranks"], ["colony", "Colony"],
			["soon", "Soon"], ["settings", "Settings"]]
	var selected := 2
	var _plate: Jelly
	var _tile: Jelly
	var _font: Font
	var _press := -1
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(0, 200)
		_font = Widgets.game_font()
		_plate = Jelly.new()
		_plate.show_behind_parent = true
		add_child(_plate)
		_tile = Jelly.new(Color("d9c6ff"), Color("8a63d2"), Color("6a44b4"))
		_tile.show_behind_parent = true
		add_child(_tile)
		resized.connect(_layout)

	func _bar_rect() -> Rect2:
		return Rect2(Vector2(0, 46), Vector2(size.x, size.y - 46))

	func _cell(i: int) -> Rect2:
		var r := _bar_rect()
		var w := r.size.x / TABS.size()
		return Rect2(Vector2(r.position.x + w * i, r.position.y), Vector2(w, r.size.y))

	func _layout() -> void:
		var r := _bar_rect()
		_plate.setup(Rect2(r.position + Vector2(-20, 0), r.size + Vector2(40, 40)), 14.0, 48.0, 14.0)
		_plate.set_param("rim_color", Color("8a62cf"))
		_plate.set_param("gloss", 0.35)
		_plate.set_param("face_color", Color("2b1258"))
		_plate.set_param("face_color_bottom", Color("3a1a74"))
		var c := _cell(selected)
		_tile.setup(Rect2(c.position + Vector2(10, -40), Vector2(c.size.x - 20, c.size.y + 30)), 12.0, 40.0, 12.0)
		_tile.set_param("gloss", 0.6)
		queue_redraw()

	func select(i: int) -> void:
		selected = i
		_layout()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT) or e is InputEventScreenTouch:
			var i := clampi(int(e.position.x / (size.x / TABS.size())), 0, TABS.size() - 1)
			if e.pressed:
				_press = i
			elif _press == i:
				_press = -1
				tab_pressed.emit(i)
			else:
				_press = -1
			accept_event()

	func _draw() -> void:
		for i in TABS.size():
			var c := _cell(i)
			var sel := i == selected
			var tex := Art.tex("res://assets/ui/tabs/%s.png" % TABS[i][0])
			var isz := c.size.x * (0.72 if sel else 0.56)
			var ic := Vector2(c.get_center().x, c.position.y + (c.size.y * 0.30 if not sel else c.size.y * 0.16))
			if sel:
				ic.y += sin(_t * 2.4) * 3.0
			if _press == i:
				isz *= 0.9
			if tex != null:
				var col := Color.WHITE if sel else Color(0.86, 0.82, 0.95)
				draw_texture_rect(tex, Rect2(ic - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, col)
			var ly := c.position.y + c.size.y * 0.78
			Widgets.shadow_text(self, _font, Vector2(c.get_center().x, ly), TABS[i][1], 36 if sel else 32,
					Color.WHITE if sel else Color("d9ccf2"))


## A building's level as three stars, filled up to `level` (the upgrade card).
class LevelStars extends Control:
	var level := 0
	var max_level := 3

	func _init(lv: int, mx := 3) -> void:
		level = lv
		max_level = mx
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(mx * 78, 74)

	func _draw() -> void:
		for k in max_level:
			var c := Vector2(39 + k * 78, size.y * 0.5)
			if k < level:
				Widgets.draw_currency_icon(self, c, 30.0, true)
			else:
				Widgets.draw_currency_icon(self, c, 30.0, true)
				draw_circle(c, 34.0, Color(0.1, 0.04, 0.2, 0.0))
		# dim the stars not reached yet
		for k in range(level, max_level):
			var c := Vector2(39 + k * 78, size.y * 0.5)
			draw_circle(c, 31.0, Color("2b1258", 0.72), true, -1.0, true)


## One effect line on the upgrade card: a small rounded plate with a tag ("Now", "Next") and
## the effect text, wrapping onto a second line if needed.
class EffectPlate extends PanelContainer:
	func _init(tag: String, text: String, accent: Color) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("1d0b40")
		sb.border_color = Color(accent, 0.55)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(26)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14
		add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		add_child(h)
		var t := Label.new()
		t.text = tag
		t.add_theme_font_override("font", Widgets.game_font())
		t.add_theme_font_size_override("font_size", 34)
		t.add_theme_color_override("font_color", accent)
		t.custom_minimum_size.x = 96
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(t)
		var l := Label.new()
		l.text = text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", Widgets.game_font())
		l.add_theme_font_size_override("font_size", 38)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_constant_override("outline_size", 8)
		l.add_theme_color_override("font_outline_color", Color("12041f"))
		h.add_child(l)


## The upgrade button: a green jelly button with "Upgrade" and the Coin cost on it; greyed out
## with the cost in red when the colony can't afford it.
class CostButton extends JellyButton:
	var cost := 0
	var label := ""
	var short := false
	var _font: Font

	func _init(t: String, c: int, can_pay: bool) -> void:
		super._init("", Color("8ff0a4") if can_pay else Color("b9b0cc"), Color("37b65a") if can_pay else Color("6e6488"), 140.0, 54)
		label = t
		cost = c
		short = not can_pay
		disabled = not can_pay
		_font = Widgets.game_font()
		var over := Control.new()
		over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		over.draw.connect(func():
			var cy := over.size.y * 0.5
			if cost <= 0:
				Widgets.shadow_text(over, _font, Vector2(over.size.x * 0.5, cy), label, 56, Color.WHITE)
				return
			Widgets.shadow_text(over, _font, Vector2(over.size.x * 0.36, cy), label, 54, Color.WHITE)
			Widgets.draw_currency_icon(over, Vector2(over.size.x * 0.68, cy), 26.0, false)
			Widgets.shadow_text(over, _font, Vector2(over.size.x * 0.81, cy), str(cost), 52,
					Color("ff8f8f") if short else Color("fff2b0")))
		add_child(over)


## The dig's booster bar (after the C1-C3 hero mockups): a dark jelly tray under the board
## with one glossy blue jelly slot per booster, its icon inside and a red count badge on the
## corner. A locked booster's slot is grey with only a padlock (what it holds stays a surprise); tapping it shakes
## and says "Locked". The armed booster's slot glows gold and bobs until it is used or tapped
## again. All four always show, so the player sees what is still to come.
class BoosterBar extends Control:
	signal picked(k: int)
	const ICONS := ["bomb", "warp", "laser", "magnet"]
	var counts := [0, 0, 0, 0]
	var unlocked := [false, false, false, false]
	var armed := -1
	var _tray: Jelly
	var _slots: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(0, 236)
		_tray = Jelly.new(Color("8d6cc9"), Color("2a1550"), Color("341a63"))
		_tray.show_behind_parent = true
		_tray.set_param("gloss", 0.35)
		add_child(_tray)
		for k in 4:
			var s := BoosterSlot.new(k)
			s.tapped.connect(_on_slot)
			add_child(s)
			_slots.append(s)
		resized.connect(_layout)

	func set_state(c: Array, u: Array, a: int) -> void:
		for k in 4:
			var s: BoosterSlot = _slots[k]
			if s.count != c[k] and s.unlocked:
				s.pop()
			s.count = c[k]
			s.unlocked = u[k]
			s.armed = a == k
			s.restyle()
		counts = c.duplicate()
		unlocked = u.duplicate()
		armed = a

	func slot_global(k: int) -> Vector2:
		var s: Control = _slots[k]
		return s.get_global_rect().get_center()

	func _on_slot(k: int) -> void:
		if not unlocked[k]:
			(_slots[k] as BoosterSlot).deny()
			Sfx.play("bump")
			return
		picked.emit(k)

	func _layout() -> void:
		var h := size.y
		var s := minf(h * 0.78, size.x / 5.2)
		var gap := s * 0.2
		var tw := s * 4.0 + gap * 5.0
		var th := s + gap * 1.6
		var tr := Rect2(Vector2((size.x - tw) * 0.5, (h - th) * 0.5), Vector2(tw, th))
		_tray.setup(tr, 16.0, th * 0.34, th * 0.08)
		for k in 4:
			var sl: Control = _slots[k]
			sl.size = Vector2(s, s)
			sl.position = Vector2(tr.position.x + gap + k * (s + gap), tr.position.y + (th - s) * 0.5)
			sl.pivot_offset = sl.size * 0.5


class BoosterSlot extends Control:
	signal tapped(k: int)
	var k := 0
	var count := 0
	var unlocked := false
	var armed := false
	var _plate: Jelly
	var _font: Font
	var _t := 0.0
	var _deny := 0.0     # 1..0 shake + "Locked" after a tap on a locked slot
	var _pop := 0.0      # 1..0 count badge pop
	var _press := false

	func _init(index: int) -> void:
		k = index
		mouse_filter = Control.MOUSE_FILTER_STOP
		_font = Widgets.game_font()
		_plate = Jelly.new()
		_plate.show_behind_parent = true
		_plate.set_param("gloss", 0.8)
		_plate.set_param("inner_shadow", 0.2)
		add_child(_plate)
		resized.connect(func(): _plate.setup(Rect2(Vector2.ZERO, size), 12.0, size.x * 0.26, size.x * 0.09))
		restyle()

	func restyle() -> void:
		var rim := Color("7ee0ff")
		var face := Color("2f97ea")
		if not unlocked:
			rim = Color("b4aec6")
			face = Color("6d6788")
		elif armed:
			rim = Color("ffe27a")
			face = Color("3aa8f2")
		_plate.set_param("rim_color", rim)
		_plate.set_param("face_color", face.lightened(0.1))
		_plate.set_param("face_color_bottom", face.darkened(0.2))
		_plate.set_param("outline_color", face.darkened(0.72))
		queue_redraw()

	func pop() -> void:
		_pop = 1.0

	func deny() -> void:
		_deny = 1.0

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch or (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
			if e.pressed:
				_press = true
			elif _press:
				_press = false
				tapped.emit(k)
			accept_event()

	func _process(delta: float) -> void:
		_t += delta
		_deny = maxf(0.0, _deny - delta / 0.6)
		_pop = maxf(0.0, _pop - delta / 0.35)
		var sc := 0.92 if _press else 1.0
		if armed:
			sc *= 1.06 + 0.04 * sin(_t * 8.0)
		sc *= 1.0 + 0.12 * _pop
		scale = Vector2(sc, sc)
		rotation = sin(_deny * 30.0) * 0.12 * _deny
		queue_redraw()

	func _draw() -> void:
		var s := size.x
		var c := size * 0.5
		if armed:
			var g := 0.5 + 0.5 * sin(_t * 8.0)
			for r in 3:
				draw_circle(c, s * (0.62 + 0.08 * r), Color(1.0, 0.86, 0.4, (0.10 - r * 0.03) * (0.6 + 0.4 * g)), true, -1.0, true)
		var tex := Art.tex("res://assets/ui/boosters/%s.png" % BoosterBar.ICONS[k])
		var iw := s * 0.74
		var bob := -s * 0.04 * sin(_t * 8.0) if armed else 0.0
		if not unlocked:
			# a locked booster stays a mystery until its building goes up: only the padlock shows
			var lw := s * 0.62
			draw_texture_rect(Art.tex("res://assets/ui/boosters/lock.png"), Rect2(c - Vector2(lw, lw) * 0.5, Vector2(lw, lw)), false)
			if _deny > 0.0:
				var a := minf(1.0, _deny * 2.0)
				Widgets.shadow_text(self, _font, Vector2(c.x, -s * 0.18 - (1.0 - _deny) * s * 0.3), "Locked", int(s * 0.3), Color(1, 1, 1, a))
			return
		draw_texture_rect(tex, Rect2(c - Vector2(iw, iw) * 0.5 + Vector2(0, bob), Vector2(iw, iw)), false,
				Color(1, 1, 1, 0.55) if count <= 0 else Color.WHITE)
		# count badge on the bottom-right corner
		var bc := Vector2(s * 0.86, s * 0.86)
		var br := s * 0.21 * (1.0 + 0.3 * _pop)
		var bw := br * 2.4
		var tex2 := Art.tex("res://assets/ui/badge_red.png" if count > 0 else "res://assets/ui/badge_grey.png")
		draw_texture_rect(tex2, Rect2(bc - Vector2(bw, bw) * 0.5, Vector2(bw, bw)), false)
		Widgets.ink_text(self, _font, bc, str(count), int(br * 1.2), Color.WHITE)
