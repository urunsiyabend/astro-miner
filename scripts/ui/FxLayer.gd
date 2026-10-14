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
	_font = ThemeDB.fallback_font


func fly(from: Vector2, res, color: Color, delay := 0.0) -> void:
	_parts.append({"kind": "fly", "p": from - global_position, "from": from - global_position,
			"res": res, "color": color, "t": -delay, "dur": 0.5 + randf() * 0.12,
			"arc": Vector2(randf_range(-160, 160), randf_range(-220, -80))})


func burst(at: Vector2, color: Color, n := 8, speed := 420.0) -> void:
	for i in n:
		var a := randf() * TAU
		_parts.append({"kind": "dot", "p": at - global_position, "v": Vector2(cos(a), sin(a)) * speed * randf_range(0.4, 1.0),
				"color": color, "t": 0.0, "dur": randf_range(0.3, 0.55), "size": randf_range(5, 11)})


func text(at: Vector2, s: String, color: Color, size := 48) -> void:
	_texts.append({"p": at - global_position, "s": s, "color": color, "t": 0.0, "dur": 0.9, "size": size})


func _process(delta: float) -> void:
	for p in _parts:
		p.t += delta
		if p.kind == "dot":
			p.p += p.v * delta
			p.v *= 0.9
			p.v.y += 900.0 * delta
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
			draw_circle(pos, 18.0 * (1.0 - 0.4 * k), p.color)
			draw_circle(pos, 9.0 * (1.0 - 0.4 * k), p.color.lightened(0.5))
		else:
			var col: Color = p.color
			col.a = 1.0 - k
			draw_circle(p.p, p.size * (1.0 - k * 0.5), col)
	for t in _texts:
		var k: float = t.t / t.dur
		var col: Color = t.color
		col.a = 1.0 - k * k
		var pos: Vector2 = t.p + Vector2(0, -90.0 * k)
		var w := _font.get_string_size(t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, t.size).x
		draw_string_outline(_font, pos - Vector2(w * 0.5, 0), t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, t.size, 10, Color(0, 0, 0, col.a * 0.8))
		draw_string(_font, pos - Vector2(w * 0.5, 0), t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, t.size, col)
