extends Node
## Procedurally synthesized sound effects. No audio files needed.

const RATE := 22050
const MAX_ACTIVE := 28

var streams := {}
var _active := 0


func _ready() -> void:
	streams["mg"] = _wav(_shot(0.09, 0.9, 140.0))
	streams["cannon"] = _wav(_boom(0.7, 55.0, 0.8))
	streams["explosion"] = _wav(_boom(1.6, 38.0, 1.0))
	streams["rocket"] = _wav(_whoosh(0.7))
	streams["laser"] = _wav(_laser(), true)
	streams["flame"] = _wav(_noise_loop(0.6, 0.35), true)
	streams["engine"] = _wav(_engine(), true)
	streams["jet"] = _wav(_noise_loop(0.8, 0.12), true)
	streams["place"] = _wav(_tone(0.07, 880.0, 0.5, 40.0))
	streams["remove"] = _wav(_sweep(0.12, 520.0, 140.0, 0.5))
	streams["click"] = _wav(_tone(0.04, 1300.0, 0.35, 70.0))
	streams["ring"] = _wav(_chime())
	streams["horn"] = _wav(_horn())
	streams["jump"] = _wav(_sweep(0.35, 160.0, 620.0, 0.6))
	streams["hit"] = _wav(_shot(0.06, 0.5, 900.0))
	streams["splash"] = _wav(_splash())
	streams["pop"] = _wav(_sweep(0.15, 900.0, 200.0, 0.7))
	streams["score"] = _wav(_arp())


func _wav(data: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w


func _shot(dur: float, vol: float, tone: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 45.0)
		lp = lerpf(lp, randf_range(-1, 1), 0.5)
		out[i] = (lp * 0.8 + sin(TAU * tone * t * (1.0 - t * 4.0)) * 0.5) * env * vol
	return out


func _boom(dur: float, tone: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 4.0 / dur) * minf(1.0, t * 400.0)
		lp = lerpf(lp, randf_range(-1, 1), 0.12)
		lp2 = lerpf(lp2, lp, 0.3)
		var thump := sin(TAU * tone * t * (1.0 - t * 0.3)) * exp(-t * 6.0)
		out[i] = clampf((lp2 * 3.2 + thump * 0.9) * env * vol, -1, 1)
	return out


func _whoosh(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := sin(PI * t / dur)
		lp = lerpf(lp, randf_range(-1, 1), 0.08 + 0.3 * t / dur)
		out[i] = lp * env * 1.6
	return out


func _laser() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 620.0 + sin(TAU * 8.0 * t) * 40.0
		var ph := fmod(t * f, 1.0)
		out[i] = (ph * 2.0 - 1.0) * 0.18 + sin(TAU * 1240.0 * t) * 0.08
	return out


func _noise_loop(dur: float, smooth: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp = lerpf(lp, randf_range(-1, 1), smooth)
		out[i] = lp * 0.9
	# crossfade loop seam
	var fade := 600
	for i in fade:
		var a := float(i) / fade
		out[i] = out[i] * a + out[n - fade + i] * (1.0 - a)
	return out


func _engine() -> PackedFloat32Array:
	var n := int(0.5 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 60.0
		var saw := fmod(t * f, 1.0) * 2.0 - 1.0
		var saw2 := fmod(t * f * 2.0, 1.0) * 2.0 - 1.0
		lp = lerpf(lp, randf_range(-1, 1), 0.2)
		var pulse := 0.6 + 0.4 * sin(TAU * 30.0 * t)
		out[i] = (saw * 0.35 + saw2 * 0.15 + lp * 0.2) * pulse
	return out


func _tone(dur: float, f: float, vol: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * f * t) * exp(-t * decay) * vol
	return out


func _sweep(dur: float, f0: float, f1: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		ph += f / RATE
		out[i] = sin(TAU * ph) * (1.0 - t / dur) * vol
	return out


func _chime() -> PackedFloat32Array:
	var n := int(0.8 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var a := sin(TAU * 1046.0 * t) * exp(-t * 5.0)
		var b := sin(TAU * 1568.0 * t) * exp(-maxf(0.0, t - 0.08) * 5.0) * (1.0 if t > 0.08 else 0.0)
		out[i] = (a + b) * 0.35
	return out


func _arp() -> PackedFloat32Array:
	var n := int(0.45 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [523.0, 659.0, 784.0, 1046.0]
	for i in n:
		var t := float(i) / RATE
		var k := mini(int(t / 0.08), 3)
		var lt := t - k * 0.08
		out[i] = sin(TAU * notes[k] * t) * exp(-lt * 9.0) * 0.35
	return out


func _horn() -> PackedFloat32Array:
	var n := int(0.55 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 60.0) * minf(1.0, (0.55 - t) * 20.0)
		var a := 1.0 if fmod(t * 349.0, 1.0) < 0.5 else -1.0
		var b := 1.0 if fmod(t * 440.0, 1.0) < 0.5 else -1.0
		out[i] = (a + b) * 0.16 * env
	return out


func _splash() -> PackedFloat32Array:
	var n := int(0.6 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1, 1), 0.45)
		out[i] = lp * exp(-t * 6.0) * minf(1.0, t * 200.0) * 0.9
	return out


## Plays a one-shot. `pos` = null for UI/2D sounds.
func play(nm: String, pos: Variant = null, vol := 0.0, pitch := 1.0) -> void:
	if not streams.has(nm) or _active >= MAX_ACTIVE:
		return
	var p
	if pos == null:
		var a := AudioStreamPlayer.new()
		a.stream = streams[nm]
		a.volume_db = vol
		a.pitch_scale = pitch * randf_range(0.96, 1.04)
		p = a
	else:
		var a3 := AudioStreamPlayer3D.new()
		a3.stream = streams[nm]
		a3.volume_db = vol
		a3.unit_size = 14.0
		a3.max_distance = 500.0
		a3.pitch_scale = pitch * randf_range(0.93, 1.07)
		a3.position = pos
		p = a3
	add_child(p)
	_active += 1
	p.finished.connect(_done.bind(p))
	p.play()


func _done(p: Node) -> void:
	_active -= 1
	p.queue_free()


## Creates a looping 3D player attached to `parent` (engine hum, laser buzz...).
func loop_player(nm: String, parent: Node3D) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = streams[nm]
	a.unit_size = 10.0
	a.max_distance = 300.0
	a.volume_db = -80.0
	parent.add_child(a)
	a.play()
	return a
