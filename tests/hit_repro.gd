extends Node
## Dev tool: reproduce "hitting an enemy at the start". Runs the real main scene.

var t := 0.0
var step := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gs: Node = get_node("/root/GameState")
	gs.reset_progress()
	gs.show_title = false
	gs.set_flag("intro_seen")
	if get_tree().current_scene == self:
		var bot: Node = (get_script() as GDScript).new()
		get_tree().root.add_child.call_deferred(bot)
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
		set_process(false)

func tap(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var u := InputEventAction.new()
	u.action = action
	u.pressed = false
	Input.parse_input_event(u)

func _process(delta: float) -> void:
	t += delta
	var main := get_tree().current_scene
	if main == null or not main.has_method("start_boss_fight") or main.flow != 1:
		return
	var p: Player = main.player
	# walk at the nearest awake enemy
	var best: Foe = null
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var f := n as Foe
		if f and f.is_alive() and (best == null or f.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
			best = f
	if best and step >= 2:
		var to := best.global_position - p.global_position
		to.y = 0.0
		if to.length() > 0.1:
			p.facing = to.normalized()
		if to.length() > 1.4 and p.state == Player.State.FREE:
			p.global_position += to.normalized() * delta * 4.0
	if int(t * 2.0) != int((t - delta) * 2.0):
		var hps := []
		for n: Node in get_tree().get_nodes_in_group("enemies"):
			hps.append(int((n as Foe).hp))
		print("t=%.1f mode=%d php=%d enemies=%s state=%d" % [t, get_node("/root/GameState").mode, int(p.hp), str(hps), p.state])
	if step == 0:
		step = 1
		print("REPRO: fists vs graveyard husk")
		p.global_position = Vector3(-7, 0.1, 5.5)
		main.rig.snap()
	elif step == 1 and t > 4.0:
		step = 2
	if step == 2 and int(t * 4.0) % 2 == 0:
		tap("attack")
	if step == 2 and t > 14.0:
		step = 3
		print("REPRO: longsword vs hall husks")
		p.hp = p.max_hp
		for n: Node in get_tree().get_nodes_in_group("enemies"):
			(n as Foe).take_damage(999.0, p)
		p.global_position = Vector3(0, 0.1, 27.4)
		main.rig.snap()
	if step == 3 and t > 15.5 and t < 16.0:
		tap("interact")
	if step == 3 and t > 16.5 and int(t * 4.0) % 2 == 0:
		tap("attack" if randf() < 0.7 else "heavy_attack")
		p.hp = p.max_hp
	if step >= 2:
		p.hp = maxf(p.hp, 50.0)
	if t > 40.0:
		print("REPRO DONE alive")
		get_tree().quit()
