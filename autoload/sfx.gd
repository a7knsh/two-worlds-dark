extends Node
## Procedural sound bank. Every sound and both music loops are synthesised in code on a worker
## thread at startup (no audio files in the repo). play() silently ignores sounds not ready yet.

const RATE := 22050

var bank := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var music: AudioStreamPlayer
var _music_name := ""
var _task := -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -80.0
	add_child(music)
	_task = WorkerThreadPool.add_task(_generate_all, false, "sfx")

func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

func ready_now() -> bool:
	return _task == -1 or WorkerThreadPool.is_task_completed(_task)

func play(sname: String, vol_db := 0.0, pitch := 1.0, rand := 0.06) -> void:
	if not bank.has(sname):
		return
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = bank[sname]
	p.volume_db = vol_db
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-rand, rand))
	p.play()

func play_music(mname: String, vol_db := -8.0, fade := 2.0) -> void:
	if mname == _music_name and music.playing:
		return
	_music_name = mname
	var tw := create_tween()
	if music.playing:
		tw.tween_property(music, "volume_db", -60.0, fade * 0.5)
	tw.tween_callback(func() -> void:
		if bank.has(mname):
			music.stream = bank[mname]
			music.play())
	tw.tween_property(music, "volume_db", vol_db, fade)

func stop_music(fade := 2.0) -> void:
	_music_name = ""
	var tw := create_tween()
	tw.tween_property(music, "volume_db", -60.0, fade)
	tw.tween_callback(music.stop)

# ------------------------------------------------------------------ synthesis

func _generate_all() -> void:
	var nb := {}
	var r := RandomNumberGenerator.new()
	r.seed = 99
	nb["swing"] = _wav(_swing(r, 0.28, 900.0))
	nb["swing_big"] = _wav(_swing(r, 0.5, 450.0))
	nb["hit"] = _wav(_hit(r, 0.25, 95.0))
	nb["hit_heavy"] = _wav(_hit(r, 0.4, 70.0))
	nb["hurt"] = _wav(_hurt(r))
	nb["roll"] = _wav(_noise_env(r, 0.35, 0.08, 0.12))
	nb["step"] = _wav(_noise_env(r, 0.07, 0.05, 0.3))
	nb["heal"] = _wav(_heal())
	nb["bell"] = _wav(_bell(4.0, 196.0))
	nb["roar"] = _wav(_roar(r, 1.9, 58.0))
	nb["growl"] = _wav(_roar(r, 1.0, 90.0))
	nb["slam"] = _wav(_slam(r, 1.1))
	nb["gate"] = _wav(_gate(r))
	nb["lantern"] = _wav(_lantern(r))
	nb["banner"] = _wav(_banner(r))
	nb["ash"] = _wav(_noise_env(r, 0.9, 0.5, 0.02))
	nb["ui"] = _wav(_tick())
	nb["fog"] = _wav(_noise_env(r, 1.4, 0.2, 0.05))
	nb["ambient"] = _wav(_ambient(r), true)
	nb["boss"] = _wav(_boss(r), true)
	call_deferred("_install", nb)

func _install(nb: Dictionary) -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	bank = nb
	if _music_name != "" and not music.playing and bank.has(_music_name):
		music.stream = bank[_music_name]
		music.play()

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b

func _swing(r: RandomNumberGenerator, dur: float, peak: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var cut := (200.0 + peak * sin(PI * t)) / RATE
		var a := clampf(TAU * cut, 0.0, 1.0)
		lp += (r.randf_range(-1, 1) - lp) * a
		lp2 += (lp - lp2) * a
		b[i] = lp2 * pow(sin(PI * t), 2.0) * 2.4
	return b

func _hit(r: RandomNumberGenerator, dur: float, f0: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := f0 * exp(-t * 9.0) + 35.0
		ph += TAU * f / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.35
		var thump := sin(ph) * exp(-t * 14.0)
		var crack := lp * exp(-t * 45.0) * 1.2
		b[i] = (thump * 0.9 + crack) * 0.9
	return b

func _hurt(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(0.4)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (160.0 - t * 180.0) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.08
		var tone := (fposmod(ph / TAU, 1.0) * 2.0 - 1.0) * 0.35 * exp(-t * 6.0)
		b[i] = tone + lp * 2.0 * exp(-t * 10.0) + sin(ph * 0.5) * 0.4 * exp(-t * 12.0)
	return b

func _noise_env(r: RandomNumberGenerator, dur: float, attack: float, cut: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(t / attack, 1.0) * clampf((dur - t) / (dur - attack), 0.0, 1.0)
		lp += (r.randf_range(-1, 1) - lp) * cut
		b[i] = lp * env * (1.5 / sqrt(cut))
	return b

func _heal() -> PackedFloat32Array:
	var b := _buf(1.1)
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(t / 0.1, 1.0) * exp(-t * 2.5)
		var v := 0.0
		for k in 4:
			var f := 520.0 * (1.0 + k * 0.5) * (1.0 + t * 0.35)
			v += sin(TAU * f * t + sin(TAU * 6.0 * t) * 0.6) / (k + 1.5)
		b[i] = v * env * 0.45
	return b

func _bell(dur: float, f0: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var partials := [[0.5, 1.0, 0.9], [1.0, 0.8, 1.4], [1.19, 0.5, 2.0], [1.5, 0.45, 2.4], [2.0, 0.35, 3.0], [2.74, 0.22, 4.5], [3.76, 0.12, 6.0]]
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for p: Array in partials:
			v += sin(TAU * f0 * (p[0] as float) * t) * (p[1] as float) * exp(-t * (p[2] as float) * 0.6)
		b[i] = v * 0.32 * minf(t / 0.004, 1.0)
	return b

func _roar(r: RandomNumberGenerator, dur: float, f0: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph := 0.0
	var lp := 0.0
	var am := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(t / 0.25, 1.0) * clampf((dur - t) / (dur * 0.5), 0.0, 1.0)
		ph += TAU * (f0 + 18.0 * sin(t * 3.0) + 10.0 * t) / RATE
		am += (r.randf_range(-1, 1) - am) * 0.02
		var saw := fposmod(ph / TAU, 1.0) * 2.0 - 1.0
		lp += (saw * (0.6 + am * 3.0) - lp) * 0.12
		b[i] = (lp * 1.6 + r.randf_range(-1, 1) * 0.08) * env
	return b

func _slam(r: RandomNumberGenerator, dur: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += TAU * (70.0 * exp(-t * 4.0) + 28.0) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.05
		b[i] = (sin(ph) * exp(-t * 4.0) + lp * 3.0 * exp(-t * 5.0)) * 0.9
	return b

func _gate(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buf(2.4)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.03
		var clank := 0.0
		for k in 6:
			var tk := t - k * 0.35
			if tk > 0.0:
				clank += sin(TAU * 410.0 * tk) * exp(-tk * 30.0) * 0.4
		b[i] = lp * 4.0 * minf(t * 3.0, 1.0) * clampf(2.4 - t, 0.0, 1.0) + clank
	return b

func _lantern(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _noise_env(r, 1.4, 0.3, 0.04)
	var chime := _bell(1.4, 523.0)
	for i in b.size():
		b[i] = b[i] * 0.6 + chime[i] * 0.4
	return b

func _banner(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _slam(r, 3.5)
	var chord := [110.0, 164.8, 220.0, 261.6]
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for f: float in chord:
			v += sin(TAU * f * t + sin(TAU * 5.0 * t) * 0.3) + 0.5 * sin(TAU * f * 1.003 * t)
		b[i] = b[i] * 0.7 + v * 0.07 * minf(t / 0.6, 1.0) * clampf((3.5 - t) / 2.0, 0.0, 1.0)
	return b

func _tick() -> PackedFloat32Array:
	var b := _buf(0.05)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * 1200.0 * t) * exp(-t * 90.0) * 0.4
	return b

## 12 s seamless drone: low fifths with slow beating, wind and a distant choir swell.
func _ambient(r: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 12.0
	var b := _buf(dur)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var swell := 0.5 + 0.5 * sin(TAU * t / dur)
		var v := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 82.5 * t) * 0.3 + sin(TAU * 55.25 * t) * 0.3
		v += (sin(TAU * 220.0 * t) + sin(TAU * 261.75 * t) * 0.7 + sin(TAU * 329.5 * t) * 0.5) * 0.06 * swell
		lp += (r.randf_range(-1, 1) - lp) * (0.01 + 0.02 * (0.5 + 0.5 * sin(TAU * t / 6.0)))
		lp2 += (lp - lp2) * 0.05
		b[i] = v * 0.3 + lp2 * 6.0
	_crossfade_loop(b, 0.5)
	return b

## 8 s boss loop: pounding low drums, dissonant string pad and a bell every bar.
func _boss(r: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 8.0
	var b := _buf(dur)
	var pad := [73.4, 77.8, 110.0, 146.8, 155.6]
	var lp := 0.0
	var phs := PackedFloat32Array()
	phs.resize(pad.size() * 2)
	for i in b.size():
		var t := float(i) / RATE
		var beat := fposmod(t, 0.5)
		var bar := fposmod(t, 2.0)
		var kick := sin(TAU * (55.0 * exp(-beat * 18.0) + 38.0) * beat) * exp(-beat * 9.0)
		if fposmod(t, 4.0) > 3.5:
			kick *= 1.4
		var v := 0.0
		for k in pad.size():
			for d in 2:
				var idx := k * 2 + d
				phs[idx] = fposmod(phs[idx] + (pad[k] as float) * (1.0 + 0.004 * d) / RATE, 1.0)
				v += phs[idx] * 2.0 - 1.0
		lp += (v * 0.2 - lp) * (0.04 + 0.03 * sin(TAU * t / 8.0))
		var bell := sin(TAU * 293.7 * bar) * exp(-bar * 3.0) * 0.18 + sin(TAU * 440.0 * bar) * exp(-bar * 5.0) * 0.08
		b[i] = kick * 0.7 + lp * 1.3 + bell + r.randf_range(-1, 1) * 0.01
	return b

func _crossfade_loop(b: PackedFloat32Array, secs: float) -> void:
	var n := int(secs * RATE)
	var size := b.size()
	for i in n:
		var w := float(i) / n
		b[i] = b[i] * w + b[size - n + i] * (1.0 - w)
	b.resize(size - n)
