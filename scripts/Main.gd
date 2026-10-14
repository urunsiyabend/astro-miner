extends Control

## Root: switches between the colony hub and a dig, with a short fade.

var colony: ColonyScreen
var dig: DigScreen
var _fade: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	colony.launch.connect(_go_dig)
	dig.finished.connect(_go_colony)
	get_tree().set_auto_accept_quit(false)
	if OS.has_environment("ASTRO_SHOT"):
		var shot := preload("res://scripts/DevShot.gd").new()
		add_child(shot)


func _go_dig(i: int) -> void:
	_transition(func():
		colony.visible = false
		dig.visible = true
		dig.start(i))


func _go_colony() -> void:
	_transition(func():
		dig.visible = false
		colony.visible = true
		colony.refresh())


func _transition(swap: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.12)
	tw.tween_callback(swap)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.18)


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
