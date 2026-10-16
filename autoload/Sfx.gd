extends Node

## Procedural sound effects: every sound is synthesised at startup (no audio assets).

const RATE := 22050
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams.step = _tone([[520.0, 0.035]], 0.18, "square", 0.25)
	_streams.swap = _tone([[440.0, 0.03], [660.0, 0.04]], 0.2, "square", 0.25)
	_streams.match = _tone([[784.0, 0.05], [1046.0, 0.09]], 0.32, "tri", 0.6)
	_streams.crack = _noise(0.12, 0.35, 1800.0)
	_streams.reveal = _tone([[880.0, 0.04], [1175.0, 0.04], [1568.0, 0.08]], 0.3, "tri", 0.5)
	_streams.pickup = _tone([[660.0, 0.04], [990.0, 0.04], [1320.0, 0.1]], 0.35, "sine", 0.4)
	_streams.blast = _noise(0.45, 0.6, 500.0)
	_streams.bump = _tone([[150.0, 0.08]], 0.35, "sine", 0.9)
	_streams.drill = _noise(0.16, 0.35, 900.0)
	_streams.buy = _tone([[523.0, 0.07], [659.0, 0.07], [784.0, 0.07], [1046.0, 0.16]], 0.35, "tri", 0.4)
	_streams.win = _tone([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1046.0, 0.3]], 0.38, "square", 0.5)
	_streams.lose = _tone([[440.0, 0.12], [349.0, 0.12], [262.0, 0.3]], 0.3, "tri", 0.5)
	_streams.pulse = _tone([[220.0, 0.25]], 0.35, "sine", 0.2)
	_streams.coin = _tone([[1318.0, 0.03], [1760.0, 0.07]], 0.22, "sine", 0.35)


func play(name: String, pitch := 1.0) -> void:
	if not Game.sfx_on or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.play()


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## notes: [[freq, seconds], ...] played back to back with a shared decay envelope.
func _tone(notes: Array, vol: float, wave: String, decay: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	for n in notes:
		var f: float = n[0]
		var count := int(RATE * float(n[1]))
		for i in count:
			var t := float(i) / RATE
			var ph := fmod(t * f, 1.0)
			var s := 0.0
			match wave:
				"square": s = 1.0 if ph < 0.5 else -1.0
				"tri": s = 4.0 * absf(ph - 0.5) - 1.0
				_: s = sin(TAU * ph)
			var env := exp(-t / maxf(0.01, float(n[1]) * decay * 3.0))
			var attack := minf(1.0, i / 60.0)
			out.append(s * vol * env * attack)
	return _wav(out)


func _noise(seconds: float, vol: float, cutoff: float) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cutoff)
	var count := int(RATE * seconds)
	var y := 0.0
	var a := clampf(cutoff / RATE * TAU, 0.01, 1.0)
	for i in count:
		var t := float(i) / RATE
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		out.append(y * vol * 3.0 * exp(-t / (seconds * 0.35)))
	return _wav(out)
