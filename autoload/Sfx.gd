extends Node

## Sound effects and music. Every effect is a set of recorded takes (assets/sfx/<name>_<k>.wav,
## generated on Layer with Mirelo SFX 2, trimmed and loudness-matched by the scratch tools); a
## play picks a random take with a little pitch and volume jitter so repeats never sound
## mechanical. The combo ladder is one tuned marimba note (note.wav, C5) pitched in-engine on
## chord tones. Music is one looping track per screen, crossfaded.

const DIR := "res://assets/sfx/"
const MUSIC := {"colony": "res://assets/music/colony.ogg", "dig": "res://assets/music/dig.ogg"}
const MUSIC_DB := -9.0
const FADE := 1.2

## name: [volume dB, pitch jitter in semitones, minimum gap between two plays in seconds]
const MIX := {
	"pop": [-5.0, 1.0, 0.03], "note": [-7.0, 0.0, 0.0], "swap": [-4.0, 0.8, 0.05],
	"step": [-9.0, 1.0, 0.05], "land": [-11.0, 1.5, 0.06], "crack": [-4.0, 1.0, 0.05],
	"drill": [-4.0, 0.7, 0.05], "reveal": [-5.0, 0.5, 0.05], "pickup": [-4.0, 0.5, 0.04],
	"cell": [-5.0, 0.5, 0.04], "blast": [-1.0, 0.8, 0.05], "zap": [-2.0, 0.6, 0.05],
	"quake": [-1.0, 0.6, 0.05], "prism": [-2.0, 0.3, 0.05], "forge": [-4.0, 0.5, 0.05],
	"warp": [-3.0, 0.5, 0.05], "laser": [-2.0, 0.4, 0.05], "magnet": [-3.0, 0.4, 0.05],
	"bombdrop": [-4.0, 0.5, 0.05], "pulse": [-7.0, 0.5, 0.05], "bump": [-7.0, 0.6, 0.08],
	"tap": [-7.0, 1.0, 0.04], "buy": [-3.0, 0.4, 0.05], "coin": [-9.0, 0.3, 0.02],
	"collect": [-3.0, 0.6, 0.05], "fanfare": [-2.0, 0.0, 0.5], "lose": [-3.0, 0.0, 0.5],
	"teleport": [-2.0, 0.3, 0.1], "telearm": [-6.0, 0.3, 0.1],
	"rockbreak": [-3.0, 0.8, 0.04], "rockcrack": [-5.0, 1.0, 0.04],
}
## the old synthesised names the game still calls, mapped onto recorded sounds
const ALIAS := {"match": "pop", "win": "fanfare", "tick": "tap"}
const WIN_NOTES := [0, 4, 7, 12]   # C E G C, the win arpeggio over the fanfare

var _takes := {}   # name -> Array[AudioStream]
var _last := {}    # name -> msec of its last play
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = []
var _track := ""
var _duck := 0.0   # dB the music is pulled down by, recovering over time
var _fade_tw: Tween


func _ready() -> void:
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	for name in MIX:
		var list: Array[AudioStream] = []
		if name == "note":
			list.append(load(DIR + "note.wav"))
		else:
			for k in 6:
				var path := "%s%s_%d.wav" % [DIR, name, k]
				if ResourceLoader.exists(path):
					list.append(load(path))
		_takes[name] = list


## pitch multiplies the take's own jitter: the combo ladder passes its note here.
func play(name: String, pitch := 1.0) -> void:
	if not Game.sfx_on:
		return
	match name:
		"match":
			# a gem pop with the ladder's marimba note on top: the pop varies, the note climbs
			_play("pop", 1.0)
			_play("note", pitch)
			return
		"win":
			_play("fanfare", 1.0)
			duck(8.0)
			for i in WIN_NOTES.size():
				get_tree().create_timer(0.1 + i * 0.11).timeout.connect(
						func(): _play("note", pow(2.0, WIN_NOTES[i] / 12.0), -3.0 if i == 3 else 0.0))
			return
		"blast", "quake", "prism", "laser":
			duck(4.0)
	_play(ALIAS.get(name, name), pitch, -6.0 if name == "tick" else 0.0)


func _play(name: String, pitch: float, extra_db := 0.0) -> void:
	var list: Array = _takes.get(name, [])
	if list.is_empty():
		return
	var mix: Array = MIX[name]
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -100000)) < int(mix[2] * 1000.0):
		return
	_last[name] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[randi() % list.size()]
	p.pitch_scale = pitch * pow(2.0, randf_range(-mix[1], mix[1]) / 12.0)
	p.volume_db = mix[0] + extra_db + randf_range(-1.0, 0.0)
	p.play()


## Crossfade to a screen's track ("colony" / "dig"); the same track keeps playing.
func music(track: String) -> void:
	if track == _track:
		return
	_track = track
	if _fade_tw and _fade_tw.is_running():
		_fade_tw.kill()
		_music[0].stop()   # the track still fading out from the last switch
	var old := _music[1]
	var new := _music[0]
	_music.reverse()
	var tw := create_tween().set_parallel()
	_fade_tw = tw
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, FADE)
		tw.chain().tween_callback(old.stop)
	if not MUSIC.has(track):
		return
	var s: AudioStream = load(MUSIC[track])
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	new.stream = s
	new.volume_db = -60.0
	new.play()
	tw.tween_property(new, "volume_db", _music_db(), FADE)


## Pull the music down for a big moment (a blast, the win), recovering by itself.
func duck(db: float) -> void:
	_duck = maxf(_duck, db)


func _music_db() -> float:
	return MUSIC_DB - _duck if Game.music_on else -80.0


func _process(delta: float) -> void:
	_duck = maxf(0.0, _duck - delta * 6.0)
	var cur := _music[1]
	if cur.playing and not (_fade_tw and _fade_tw.is_running()):
		cur.volume_db = _music_db()


func _exit_tree() -> void:
	_takes.clear()
	for m in _music:
		m.stream = null
