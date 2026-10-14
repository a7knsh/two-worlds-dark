extends Node
## Dev tool: chaos/soak test. Runs the REAL game (real scene reloads on death/rest/ending)
## with a bot that mashes random inputs and wanders every zone. Watch the log for errors.
##   godot --headless res://tests/soak.tscn -- [seconds]

var bot_time := 240.0
var t := 0.0
var rng := RandomNumberGenerator.new()
var _act_t := 0.0
var _tp_t := 0.0
var _held: Array = []
var reloads := 0
var _last_scene: Node

const SPOTS := [
	Vector3(0, 0.1, 62), Vector3(0, 0.1, 50), Vector3(0, 0.1, 27.4), Vector3(-5, 0.1, 29), Vector3(5, 0.1, 29),
	Vector3(-1.6, 0.1, 16.2), Vector3(0, 0.1, 5), Vector3(-8, 0.1, -6), Vector3(10, 0.1, -12), Vector3(0, 0.1, -20),
	Vector3(0, 0.1, -28), Vector3(3.5, 2.1, -40), Vector3(0, 2.1, -44.6),
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 1234
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		bot_time = float(args[0])
	var gs: Node = get_node("/root/GameState")
	gs.reset_progress()
	if get_tree().current_scene == self:
		# hand over to a copy of this bot living beside the scene, so it survives reloads
		var bot: Node = (get_script() as GDScript).new()
		bot.name = "SoakBot"
		get_tree().root.add_child.call_deferred(bot)
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		set_process(false)

func ev(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)

func tap(action: String) -> void:
	ev(action, true)
	await get_tree().process_frame
	await get_tree().process_frame
	ev(action, false)

func _process(delta: float) -> void:
	t += delta
	if t > bot_time:
		print("SOAK DONE  reloads=%d" % reloads)
		get_tree().quit()
		return
	var main := get_tree().current_scene
	if main == null or not main.has_method("start_boss_fight"):
		return
	if main != _last_scene:
		_last_scene = main
		reloads += 1
		print("SOAK scene loaded #%d  t=%.1f checkpoint=%s" % [reloads, t, get_node("/root/GameState").checkpoint])
	var flow: int = main.flow
	_act_t -= delta
	_tp_t -= delta
	if flow == 0 or flow == 4:
		# title / ending: press something now and then
		if _act_t <= 0.0:
			_act_t = 2.0
			var k := InputEventKey.new()
			k.keycode = KEY_SPACE
			k.physical_keycode = KEY_SPACE
			k.pressed = true
			Input.parse_input_event(k)
			if main.cinema.active:
				tap("interact")
		return
	if flow == 2:
		# cutscene: sometimes watch, sometimes skip
		if _act_t <= 0.0:
			_act_t = rng.randf_range(1.0, 6.0)
			tap("interact")
		return
	if flow != 1:
		return
	var p: Player = main.player
	if _act_t <= 0.0:
		_act_t = rng.randf_range(0.08, 0.45)
		for a: String in _held:
			ev(a, false)
		_held.clear()
		for a: String in ["move_up", "move_down", "move_left", "move_right"]:
			if rng.randf() < 0.3:
				ev(a, true)
				_held.append(a)
		var roll := rng.randf()
		if roll < 0.25:
			tap("attack")
		elif roll < 0.35:
			tap("heavy_attack")
		elif roll < 0.48:
			tap("roll")
		elif roll < 0.52:
			tap("heal")
		elif roll < 0.58:
			tap("lock_on")
		elif roll < 0.7:
			tap("interact")
		elif roll < 0.72:
			tap("pause")
			await get_tree().create_timer(0.3, true, false, true).timeout
			tap("pause")
		if rng.randf() < 0.3:
			var m := InputEventMouseMotion.new()
			m.relative = Vector2(rng.randf_range(-80, 80), rng.randf_range(-30, 30))
			Input.parse_input_event(m)
	if _tp_t <= 0.0 and p.state == Player.State.FREE:
		_tp_t = rng.randf_range(4.0, 10.0)
		var spot: Vector3 = SPOTS[rng.randi() % SPOTS.size()]
		var gs: Node = get_node("/root/GameState")
		if spot.z < -30.0 and not gs.flag("hall_cleared"):
			spot = SPOTS[rng.randi() % 6]
		p.global_position = spot
		main.rig.snap()
		# keep the run going: sometimes make the hero tough so the boss can be reached and beaten
		if rng.randf() < 0.3:
			p.hp = p.max_hp
		if main.boss and is_instance_valid(main.boss) and main.boss.state != Boss.State.DORMANT and rng.randf() < 0.3:
			main.boss.take_damage(150.0, p, 50.0)
