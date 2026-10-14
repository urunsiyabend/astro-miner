class_name Mascot
extends Control

## Mira, the colony chief: a drawn portrait in a helmet. She blinks, and her mouth moves
## while `talking` is on.

var talking := false
var _time := 0.0


func _init(px := 150.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(size.x * 0.5, size.y * 0.55)
	var r := s * 0.38
	# antenna
	draw_line(c + Vector2(r * 0.45, -r * 0.8), c + Vector2(r * 0.75, -r * 1.25), Pal.ROBOT_DARK, s * 0.03)
	draw_circle(c + Vector2(r * 0.75, -r * 1.25), s * 0.045, Pal.WARN.lerp(Color.WHITE, 0.4 + 0.4 * sin(_time * 4.0)))
	# helmet and face
	draw_circle(c, r * 1.08, Pal.ACCENT.darkened(0.35))
	draw_circle(c, r, Pal.ACCENT)
	draw_circle(c + Vector2(0, r * 0.12), r * 0.74, Color("f6d2b4"))
	# hair fringe
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.74, -r * 0.05), c + Vector2(-r * 0.5, -r * 0.55),
			c + Vector2(r * 0.2, -r * 0.62), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(r * 0.1, -r * 0.3)]), Color("7a3b2e"))
	# eyes (blink every few seconds)
	var blink := fmod(_time, 3.7) < 0.12
	for sx in [-1.0, 1.0]:
		var e := c + Vector2(sx * r * 0.3, r * 0.08)
		if blink:
			draw_line(e - Vector2(r * 0.1, 0), e + Vector2(r * 0.1, 0), Color("2b1d2e"), s * 0.025)
		else:
			draw_circle(e, r * 0.1, Color("2b1d2e"))
			draw_circle(e + Vector2(-r * 0.03, -r * 0.04), r * 0.035, Color.WHITE)
	# cheeks
	draw_circle(c + Vector2(-r * 0.48, r * 0.32), r * 0.09, Color(1, 0.5, 0.5, 0.35))
	draw_circle(c + Vector2(r * 0.48, r * 0.32), r * 0.09, Color(1, 0.5, 0.5, 0.35))
	# mouth: opens and closes while talking, a smile otherwise
	var m := c + Vector2(0, r * 0.45)
	if talking:
		var open := 0.5 + 0.5 * absf(sin(_time * 16.0))
		draw_circle(m, r * 0.12 * open + r * 0.04, Color("6b2737"))
	else:
		draw_arc(m + Vector2(0, -r * 0.08), r * 0.16, 0.3, PI - 0.3, 12, Color("6b2737"), s * 0.025, true)
