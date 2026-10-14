class_name Dialog
extends RefCounted

## Mira's two ways of talking.
##   Dialog.Overlay - modal: dims the screen, tap to go through the lines, then calls back.
##   Dialog.Coach   - a line under the board while you keep playing (instructions, notes).


class Overlay extends Control:
	signal done

	var _lines: Array = []
	var _at := 0
	var _text: Label
	var _more: Label
	var _face: Mascot
	var _panel: PanelContainer
	var _typing := 0.0
	var _on_done: Callable

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.5)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		_panel = Ui.panel(Pal.PANEL_HI, 36)
		_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_panel.offset_left = 32
		_panel.offset_right = -32
		_panel.offset_bottom = -40
		_panel.offset_top = -420
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_panel)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 24)
		_panel.add_child(h)
		_face = Mascot.new(190)
		_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(_face)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 10)
		h.add_child(v)
		v.add_child(Ui.label(Story.MASCOT, Pal.FS_SMALL, Pal.ACCENT))
		_text = Ui.label("", Pal.FS, Pal.TEXT)
		_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(_text)
		_more = Ui.label("tap to continue", Pal.FS_TINY, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		v.add_child(_more)

	func is_open() -> bool:
		return visible

	## Show lines one by one; `then` runs after the last tap.
	func say(lines: Array, then := Callable()) -> void:
		if lines.is_empty():
			if then.is_valid():
				then.call()
			return
		_lines = lines
		_at = 0
		_on_done = then
		visible = true
		_show_line()

	func _show_line() -> void:
		_text.text = String(_lines[_at])
		_text.visible_ratio = 0.0
		_typing = 0.0
		_face.talking = true
		_more.modulate.a = 0.0
		Sfx.play("step", 1.4)

	func _process(delta: float) -> void:
		if not visible or _text.visible_ratio >= 1.0:
			return
		_typing += delta
		var n := maxi(1, _text.text.length())
		_text.visible_ratio = minf(1.0, _typing * 55.0 / n)
		if _text.visible_ratio >= 1.0:
			_finish_typing()

	func _finish_typing() -> void:
		_text.visible_ratio = 1.0
		_face.talking = false
		_more.modulate.a = 1.0

	func _gui_input(event: InputEvent) -> void:
		var tap: bool = (event is InputEventScreenTouch and event.pressed) or \
				(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if tap:
			accept_event()
			_advance()

	func _unhandled_input(event: InputEvent) -> void:
		if visible and event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			_advance()

	func _advance() -> void:
		if _text.visible_ratio < 1.0:
			_finish_typing()
			return
		_at += 1
		if _at < _lines.size():
			_show_line()
			return
		visible = false
		done.emit()
		if _on_done.is_valid():
			var cb := _on_done
			_on_done = Callable()
			cb.call()


class Coach extends PanelContainer:
	var _text: Label
	var _face: Mascot
	var _t := 0.0
	var _hold := false

	func _init() -> void:
		add_theme_stylebox_override("panel", Ui.box(Pal.PANEL, 26))
		custom_minimum_size = Vector2(0, 150)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		add_child(h)
		_face = Mascot.new(110)
		h.add_child(_face)
		_text = Ui.label("", Pal.FS_SMALL, Pal.TEXT)
		_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(_text)
		modulate.a = 0.0

	## secs <= 0 keeps the line up until it is replaced or cleared.
	func say(text: String, secs := 0.0) -> void:
		_text.text = text
		_hold = secs <= 0.0
		_t = secs
		modulate.a = 1.0
		_face.talking = true
		get_tree().create_timer(minf(1.2, 0.03 * text.length())).timeout.connect(func(): _face.talking = false)

	func clear() -> void:
		_hold = false
		_t = 0.0

	func _process(delta: float) -> void:
		if _hold:
			return
		_t -= delta
		modulate.a = clampf(_t * 2.0, 0.0, 1.0)


## Spotlight: dims everything except one button, points at it with a bouncing arrow and lets
## Mira say what to do. Only that button can be tapped; the tap runs `on_tap`.
class Spotlight extends Control:
	var target: Control
	var _coach: Coach
	var _t := 0.0
	var _on_tap: Callable

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		_coach = Coach.new()
		_coach.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		add_child(_coach)

	func point(t: Control, text: String, on_tap: Callable) -> void:
		target = t
		_on_tap = on_tap
		visible = true
		_t = 0.0
		var r := _rect()
		# Mira talks from the half of the screen the button is not in
		if r.get_center().y > size.y * 0.5:
			_coach.offset_top = 70
		else:
			_coach.offset_top = size.y - 300
		_coach.offset_left = 32
		_coach.offset_right = -32
		_coach.offset_bottom = _coach.offset_top + 170
		_coach.say(text)

	func close() -> void:
		visible = false
		target = null

	func _rect() -> Rect2:
		if target == null or not is_instance_valid(target):
			return Rect2()
		var g := target.get_global_rect().grow(14)
		return Rect2(g.position - global_position, g.size)

	func _process(delta: float) -> void:
		if visible:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var r := _rect()
		var dim := Color(0, 0, 0, 0.7)
		draw_rect(Rect2(0, 0, size.x, r.position.y), dim)
		draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), dim)
		draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
		draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), dim)
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_rect(r, Color(Pal.WARN, 0.6 + 0.4 * pulse), false, 6.0)
		# arrow pointing at the button, bobbing toward it
		var below := r.get_center().y < size.y * 0.5
		var tip := Vector2(r.get_center().x, r.end.y + 16 if below else r.position.y - 16)
		var dir := -1.0 if below else 1.0  # +1 points down
		var bob := 14.0 * sin(_t * 5.0)
		tip.y -= dir * (bob + 14.0)
		var head := PackedVector2Array([tip, tip + Vector2(-38, -dir * 46), tip + Vector2(38, -dir * 46)])
		draw_colored_polygon(head, Pal.WARN)
		draw_rect(Rect2(tip.x - 14, tip.y - dir * 46 - (66 if dir > 0 else 0), 28, 66), Pal.WARN)

	func _gui_input(event: InputEvent) -> void:
		var pos := Vector2.INF
		if event is InputEventScreenTouch and event.pressed:
			pos = event.position
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
		if pos == Vector2.INF:
			return
		accept_event()
		if _rect().has_point(pos):
			var cb := _on_tap
			close()
			if cb.is_valid():
				cb.call()
