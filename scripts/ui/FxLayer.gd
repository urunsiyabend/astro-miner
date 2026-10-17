class_name FxLayer
extends Control

## Screen-space feedback: ore chunks flying into the haul counters, debris, floating text.

signal arrived(res: int)

var targets := {}  # res index (0..3, "energy") -> global position getter (Callable)
var _parts := []
var _texts := []
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Widgets.game_font(700)


func fly(from: Vector2, res, color: Color, delay := 0.0, dur := -1.0, arc := Vector2.INF) -> void:
	_parts.append({"kind": "fly", "p": from - global_position, "from": from - global_position,
			"res": res, "color": color, "t": -delay, "dur": dur if dur > 0.0 else 0.5 + randf() * 0.12,
			"arc": arc if arc != Vector2.INF else Vector2(randf_range(-160, 160), randf_range(-220, -80))})


## A picture (a booster icon) flies from `from` to target `res`, growing on the way, `size` px.
func fly_icon(from: Vector2, res, tex: Texture2D, size := 110.0, delay := 0.0) -> void:
	fly(from, res, Color.WHITE, delay, 0.7, Vector2(randf_range(-60, 60), -260))
	_parts[-1]["tex"] = tex
	_parts[-1]["size"] = size


func burst(at: Vector2, color: Color, n := 8, speed := 420.0) -> void:
	for i in n:
		var a := randf() * TAU
		_parts.append({"kind": "dot", "p": at - global_position, "v": Vector2(cos(a), sin(a)) * speed * randf_range(0.4, 1.0),
				"color": color, "t": 0.0, "dur": randf_range(0.3, 0.55), "size": randf_range(5, 11)})


## Sparkles: four-point stars with a soft glow, spinning out from `at` and fading (match pops).
func sparks(at: Vector2, color: Color, n := 8, speed := 520.0, size := 22.0) -> void:
	for i in n:
		var a := randf() * TAU
		_parts.append({"kind": "spark", "p": at - global_position, "v": Vector2(cos(a), sin(a)) * speed * randf_range(0.35, 1.0),
				"color": color, "t": 0.0, "dur": randf_range(0.35, 0.6), "size": size * randf_range(0.6, 1.2),
				"rot": randf() * TAU, "spin": randf_range(-8, 8)})


## A big word over the board when a cascade climbs (Nice! Stellar! Cosmic! Supernova!): it pops
## in large with an overshoot and a tilt, holds, rises and fades.
func callout(at: Vector2, s: String, color: Color, size := 110) -> void:
	_texts.append({"p": at - global_position, "s": s, "color": color, "t": 0.0, "dur": 1.25, "size": size,
			"tilt": randf_range(-0.18, 0.18)})


## Celebration: paper bits shot up from `at`, spinning and fluttering down.
func confetti(at: Vector2, n := 60) -> void:
	var cols := [Pal.COIN, Pal.GOOD, Pal.ACCENT, Color("ff6fb5"), Color("c88bff"), Color.WHITE]
	for i in n:
		var a := randf_range(-PI * 0.92, -PI * 0.08)
		_parts.append({"kind": "conf", "p": at - global_position, "v": Vector2(cos(a), sin(a)) * randf_range(500, 1250),
				"color": cols[i % cols.size()], "t": 0.0, "dur": randf_range(1.3, 1.9),
				"size": Vector2(randf_range(22, 34), randf_range(12, 18)), "rot": randf() * TAU,
				"spin": randf_range(-9, 9), "ph": randf() * TAU})


func text(at: Vector2, s: String, color: Color, size := 48) -> void:
	_texts.append({"p": at - global_position, "s": s, "color": color, "t": 0.0, "dur": 1.05, "size": size,
			"tilt": randf_range(-0.12, 0.12)})


func _process(delta: float) -> void:
	for p in _parts:
		p.t += delta
		if p.kind == "dot":
			p.p += p.v * delta
			p.v *= 0.9
			p.v.y += 900.0 * delta
		elif p.kind == "spark":
			p.p += p.v * delta
			p.v *= 0.88
			p.rot += p.spin * delta
		elif p.kind == "conf":
			p.p += p.v * delta
			p.v *= 0.965
			p.v.y += 1100.0 * delta * 0.6
			p.v.x += sin(p.t * 6.0 + p.ph) * 40.0
			p.rot += p.spin * delta
	var keep := []
	for p in _parts:
		if p.kind == "fly" and p.t >= p.dur:
			arrived.emit(p.res)
			continue
		if p.t < p.dur:
			keep.append(p)
	_parts = keep
	for t in _texts:
		t.t += delta
	_texts = _texts.filter(func(t): return t.t < t.dur)
	queue_redraw()


func _target(res) -> Vector2:
	if targets.has(res):
		return (targets[res] as Callable).call() - global_position
	return Vector2(size.x * 0.5, 0)


func _draw() -> void:
	for p in _parts:
		if p.t < 0.0:
			continue
		var k: float = clampf(p.t / p.dur, 0.0, 1.0)
		if p.kind == "fly":
			var e := k * k * (3.0 - 2.0 * k)
			var to := _target(p.res)
			var mid: Vector2 = (p.from + to) * 0.5 + p.arc
			var a: Vector2 = p.from.lerp(mid, e)
			var b: Vector2 = mid.lerp(to, e)
			var pos := a.lerp(b, e)
			if p.has("tex"):
				var w: float = p.size * (1.0 + 0.35 * sin(PI * k)) * (1.0 - 0.35 * k * k)
				draw_texture_rect(p.tex, Rect2(pos - Vector2(w, w) * 0.5, Vector2(w, w)), false)
				continue
			# a goal piece flies as itself (the gem, the crystal, a chip of rock): big as it
			# leaves, shrinking into the icon
			var art: Texture2D = null
			if p.res is int:
				art = Art.ore(p.res)
			elif p.res is String and p.res == "rock":
				art = Art.rock(1, 1)
			if art != null:
				var w2 := 96.0 * (1.0 + 0.25 * sin(PI * k)) * (1.0 - 0.5 * k)
				draw_circle(pos, w2 * 0.55, Color(p.color, 0.18 * (1.0 - k)))
				draw_texture_rect(art, Rect2(pos - Vector2(w2, w2) * 0.5, Vector2(w2, w2)), false)
				continue
			if p.res is String and p.res == "coin":
				Widgets.draw_currency_icon(self, pos, 30.0 * (1.0 + 0.25 * sin(PI * k)), false)
				continue
			draw_circle(pos, 18.0 * (1.0 - 0.4 * k), p.color)
			draw_circle(pos, 9.0 * (1.0 - 0.4 * k), p.color.lightened(0.5))
		elif p.kind == "spark":
			var a2 := 1.0 - k * k
			var r: float = p.size * (1.0 - 0.5 * k)
			draw_circle(p.p, r * 0.9, Color(p.color, 0.22 * a2))
			draw_set_transform(p.p, p.rot)
			var star := PackedVector2Array()
			for j in 8:
				var rr: float = r if j % 2 == 0 else r * 0.3
				var an := j * PI / 4.0
				star.append(Vector2(cos(an), sin(an)) * rr)
			draw_colored_polygon(star, Color(p.color.lightened(0.45), a2))
			draw_set_transform(Vector2.ZERO)
		elif p.kind == "conf":
			var col: Color = p.color
			col.a = 1.0 - smoothstep(0.7, 1.0, k)
			# the flip: the strip narrows as it turns over
			var sz: Vector2 = p.size * Vector2(1.0, absf(cos(p.t * 7.0 + p.ph)) * 0.8 + 0.2)
			draw_set_transform(p.p, p.rot)
			draw_rect(Rect2(-sz * 0.5, sz), col)
			draw_set_transform(Vector2.ZERO)
		else:
			var col: Color = p.color
			col.a = 1.0 - k
			draw_circle(p.p, p.size * (1.0 - k * 0.5), col)
	for t in _texts:
		_draw_pop_text(t)


## Juicy floating text: pops in with an overshoot and a squash, settles its tilt, drifts up
## easing out, then shrinks and fades. Light fill, ore-dark outline, crisp drop shadow.
func _draw_pop_text(t: Dictionary) -> void:
	var tt: float = t.t
	var k: float = tt / t.dur
	# scale: back-out from 0 with a ~25% overshoot over the first 0.28 s, shrink in the last 25%
	var sp := clampf(tt / 0.28, 0.0, 1.0) - 1.0
	var c1 := 3.2
	var sc := 1.0 + (c1 + 1.0) * sp * sp * sp + c1 * sp * sp
	sc *= 1.0 - 0.35 * smoothstep(0.75, 1.0, k)
	# squash and stretch on the pop: wide then tall
	var sq := sin(clampf(tt / 0.32, 0.0, 1.0) * TAU) * 0.14 * (1.0 - clampf(tt / 0.32, 0.0, 1.0))
	var scl := Vector2(sc * (1.0 + sq), sc * (1.0 - sq))
	var rot: float = t.tilt * (1.0 - clampf(tt / 0.35, 0.0, 1.0))
	var rise := 1.0 - pow(1.0 - clampf((tt - 0.12) / (t.dur - 0.12), 0.0, 1.0), 3.0)
	var pos: Vector2 = t.p + Vector2(0, -26.0 - 84.0 * rise)
	var a := 1.0 - smoothstep(0.7, 1.0, k)
	if sc <= 0.01 or a <= 0.0:
		return
	var fs: int = t.size
	var w := _font.get_string_size(t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(-w * 0.5, fs * 0.36)
	var base: Color = t.color
	var fill := base.lightened(0.12)
	var edge := base.darkened(0.62)
	var ink := Color("12041f")
	var ol := int(fs * 0.2)
	var drop := Vector2(0, maxf(2.0, fs * 0.07))
	draw_set_transform(pos, rot, scl)
	draw_string_outline(_font, at + drop, t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol + 2, Color(ink, a * 0.85))
	draw_string_outline(_font, at, t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol + 2, Color(ink, a))
	draw_string_outline(_font, at, t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol - 2, Color(edge, a))
	draw_string(_font, at, t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fill, a))
	# white flash right on the pop
	var flash := 1.0 - clampf(tt / 0.16, 0.0, 1.0)
	if flash > 0.0:
		draw_string(_font, at, t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a * flash * 0.85))
	draw_set_transform(Vector2.ZERO)
