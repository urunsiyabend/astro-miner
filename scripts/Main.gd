extends Control

## Root: switches between the colony hub and a dig, with a short fade.

var colony: ColonyScreen
var dig: DigScreen
var _fade: ColorRect
var _fps: Label  # Settings > "FPS": frame rate and the worst frame of the last half second




func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# painted icons and frames are drawn well below their source size: sample the mipmaps
	# (inherited by every screen), or their edges shimmer and stair-step
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	colony = ColonyScreen.new()
	add_child(colony)
	dig = DigScreen.new()
	dig.visible = false
	add_child(dig)
	_fade = ColorRect.new()
	_fade.color = Pal.BG
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	_fps = Label.new()
	_fps.position = Vector2(16, 6)
	_fps.add_theme_font_size_override("font_size", 30)
	_fps.add_theme_color_override("font_color", Color("b8ff9a"))
	_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps.add_theme_constant_override("outline_size", 8)
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps)
	Sfx.music("colony")
	colony.launch.connect(_go_dig)
	dig.finished.connect(_go_colony)
	get_tree().set_auto_accept_quit(false)
	if OS.has_environment("ASTRO_SHOT"):
		var shot := preload("res://scripts/DevShot.gd").new()
		add_child(shot)


func _go_dig(i: int, supply: bool) -> void:
	_transition(func():
		colony.visible = false
		dig.visible = true
		Sfx.music("dig")
		dig.start(i, supply))


func _go_colony() -> void:
	_transition(func():
		dig.visible = false
		colony.visible = true
		Sfx.music("colony")
		colony.refresh())


func _transition(swap: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.12)
	tw.tween_callback(swap)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.18)


## The texture cache is static and outlives the scene tree; drop it before the engine shuts down.
func _exit_tree() -> void:
	Art.clear_cache()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			Game.save()
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if dig.visible:
				if dig.board == null or dig.board.over:
					_go_colony()
				else:
					dig._on_recall()
			else:
				Game.save()
				get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED:
			Game.save()


var _fps_t := 0.0
var _fps_n := 0
var _fps_worst := 0.0


func _process(delta: float) -> void:
	_fps.visible = Game.show_fps
	if not Game.show_fps:
		return
	_fps_t += delta
	_fps_n += 1
	_fps_worst = maxf(_fps_worst, delta)
	if _fps_t >= 0.5:
		_fps.text = "%d fps · worst %.0f ms" % [roundi(_fps_n / _fps_t), _fps_worst * 1000.0]
		_fps_t = 0.0
		_fps_n = 0
		_fps_worst = 0.0
