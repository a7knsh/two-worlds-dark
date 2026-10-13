extends Node
## End-to-end gameplay test. Plays the whole level start to finish with scripted input.
## Run:  godot --headless res://tests/test_game.tscn

var fails := 0
var main: Node
var gs: Node
var reloads := 0

func check(c: bool, msg: String) -> void:
	print(("PASS  " if c else "FAIL  ") + msg)
	if not c:
		fails += 1

func wait_s(s: float) -> void:
	await get_tree().create_timer(s).timeout

func press(action: String, hold_frames := 2) -> void:
	Input.action_press(action)
	for i in hold_frames:
		await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame

## Send a real input event through the pipeline (for event-driven actions like pause).
func tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func until(cond: Callable, timeout: float) -> bool:
	var e := 0.0
	while e < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		e += get_physics_process_delta_time()
	return cond.call()

func tp(p: Vector3) -> void:
	main.player.global_position = p
	main.rig.snap()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	gs = get_node("/root/GameState")
	await _title_and_intro()
	gs.reset_progress()
	gs.show_title = false
	gs.set_flag("intro_seen")
	main = load("res://scenes/main.tscn").instantiate()
	main.on_reload = func() -> void: reloads += 1
	add_child(main)
	await _run()
	print("\nRESULT: %s (%d failures)" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
	get_tree().quit(fails)

## New game: title screen -> any key -> opening cutscene (skipped) -> control.
func _title_and_intro() -> void:
	gs.reset_progress()
	main = load("res://scenes/main.tscn").instantiate()
	main.on_reload = func() -> void: pass
	add_child(main)
	await wait_s(0.5)
	check(main.flow == main.Flow.TITLE and main.hud.title_root.visible, "title screen shown on a new game")
	main.any_key.emit()
	await until(func() -> bool: return main.cinema.active, 4.0)
	check(main.cinema.active, "opening cutscene starts after the title")
	check(main.player.state == Player.State.LOCKED, "player is locked during the cutscene")
	await wait_s(1.0)
	await tap("interact")
	check(not main.cinema.skipped and main.hud.skip_label.text.contains("again"), "first press asks to confirm the skip")
	await tap("interact")
	check(main.cinema.skipped, "second press skips the cutscene")
	await until(func() -> bool: return main.flow == main.Flow.PLAY, 8.0)
	check(main.flow == main.Flow.PLAY, "skipping the opening hands control to the player")
	check(gs.flag("intro_seen"), "intro remembered")
	check(main.player.global_position.distance_to(Vector3(0, 0.1, 63.4)) < 1.0, "wakes beside the slab")
	check(get_tree().get_nodes_in_group("player").size() == 1, "exactly one player")
	main.queue_free()
	await wait_s(0.3)
	gs.reset()

func _run() -> void:
	var player: Player = main.player
	await until(func() -> bool: return main.flow == main.Flow.PLAY, 5.0)
	check(main.flow == main.Flow.PLAY, "wakes up and gains control")
	check(gs.mode == 0, "starts in EXPLORE (the Veil)")
	check(player.hum.sprite.visible and not player.hum.rig.visible, "explore: pixel sprite shown, 3D model hidden")
	check(main.rig.cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "explore: orthographic camera")
	check(main.post_mat.get_shader_parameter("strength") == 1.0, "explore: pixel post shader on")
	check(player.weapon == "fists", "starts unarmed")
	check(main.boss != null, "boss spawned")
	check(get_tree().get_nodes_in_group("enemies").size() == 6, "6 active enemies in the graveyard (got %d)" % get_tree().get_nodes_in_group("enemies").size())

	# --- movement
	var z0 := player.global_position.z
	Input.action_press("move_up")
	await wait_s(0.6)
	Input.action_release("move_up")
	check(player.global_position.z < z0 - 1.5, "player walks forward (dz=%.2f)" % (player.global_position.z - z0))
	check(player.hum.anim == "idle" or player.hum.anim == "walk", "locomotion animation plays")

	# --- pause freezes the world
	await tap("pause")
	await wait_s(0.1)
	check(get_tree().paused and main.hud.pause_panel.visible, "ESC pauses the game")
	var zp := player.global_position.z
	Input.action_press("move_up")
	await wait_s(0.3)
	Input.action_release("move_up")
	check(absf(player.global_position.z - zp) < 0.01, "the world is frozen while paused")
	await tap("pause")
	await wait_s(0.1)
	check(not get_tree().paused and not main.hud.pause_panel.visible, "ESC resumes")

	# --- ground message
	tp(Vector3(0, 0.1, 60.6))
	await wait_s(0.2)
	var it := player.nearest_interactable()
	check(it != null and it.kind == "message", "standing on a message shows a prompt")
	await press("interact")
	await wait_s(0.1)
	check(main.hud.message_open(), "message panel opens")
	await press("interact")
	await wait_s(0.1)
	check(not main.hud.message_open(), "message panel closes")

	# --- the Veilkeeper talks
	tp(Vector3(1.4, 0.1, 64.2))
	await wait_s(0.15)
	await press("interact")
	await wait_s(0.2)
	check(main.hud.sub_text.text.contains("Hall of Arms"), "the Veilkeeper speaks")

	# --- Hall of Arms: take the longsword, the dead rise
	check(main.level.gates["hall"].position.y < 1.0, "hall gate starts closed")
	tp(Vector3(0, 0.1, 27.4))
	await wait_s(0.2)
	it = player.nearest_interactable()
	check(it != null and it.kind == "altar", "altar prompt near the longsword")
	await press("interact")
	await wait_s(0.8)
	check(player.weapon == "longsword", "longsword equipped")
	check(player.hum.weapon_node != null, "longsword model in hand")
	check(gs.flag("hall_triggered"), "taking a weapon triggers the hall ambush")
	await wait_s(3.5)
	var risen := 0
	for e: Enemy in main.hall_enemies:
		if e.state != Enemy.State.DORMANT:
			risen += 1
	check(risen == 3, "3 husks rise in the Hall of Arms (got %d)" % risen)
	await until(func() -> bool: return gs.visual_combat, 4.0)
	check(gs.mode == 1, "risen husks trigger COMBAT (the Flesh)")
	check(main.rig.cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "combat: perspective camera")
	check(player.hum.rig.visible and not player.hum.sprite.visible, "combat: player 3D model shown")
	check(main.post_mat.get_shader_parameter("strength") == 0.0, "combat: pixel shader off")
	check(player.lock_valid(), "auto lock-on acquired")

	# --- roll i-frames
	player.stamina = player.max_stamina
	player.hp = player.max_hp
	var st0 := player.stamina
	Input.action_press("move_left")
	await press("roll")
	Input.action_release("move_left")
	await wait_s(0.08)
	check(player.state == Player.State.ROLL, "roll starts")
	check(player.stamina < st0, "roll costs stamina")
	check(player.invulnerable, "roll grants i-frames")
	check(player.hum.anim == "roll", "roll animation plays")
	await wait_s(0.6)
	check(player.state == Player.State.FREE, "roll ends")

	# --- attack + combo
	var e1: Enemy = main.hall_enemies[0]
	for e: Enemy in main.hall_enemies:
		e.set_physics_process(false)
	e1.global_position = player.global_position + player.facing * 1.6
	var hp0 := e1.hp
	await press("attack")
	await wait_s(0.1)
	check(player.hum.anim == "p_light_a", "light attack animation (got %s)" % player.hum.anim)
	await press("attack")
	await wait_s(0.6)
	check(e1.hp < hp0, "light attack damages enemy (%.0f -> %.0f)" % [hp0, e1.hp])
	check(player.combo >= 1, "attack chains into a combo")
	for e: Enemy in main.hall_enemies:
		e.set_physics_process(true)

	# --- an enemy attack hurts the player
	player.hp = player.max_hp
	e1.global_position = player.global_position + Vector3(0, 0, -1.4)
	e1.facing_yaw = 0.0
	e1._start_attack(e1.t["attacks"][0])
	var hurt := await until(func() -> bool: return player.hp < player.max_hp, 2.5)
	check(hurt, "husk swing hurts the player (%.0f)" % player.hp)

	# --- heal
	await until(func() -> bool: return player.state == Player.State.FREE, 2.0)
	for e: Enemy in main.hall_enemies:
		e.set_physics_process(false)
	player.hp = 30.0
	var v0 := player.vials
	await press("heal")
	await wait_s(1.4)
	for e: Enemy in main.hall_enemies:
		e.set_physics_process(true)
	check(player.vials == v0 - 1, "drinking uses a Blood Vial")
	check(player.hp > 30.0, "Blood Vial heals (%.0f)" % player.hp)

	# --- clear the hall -> gate opens -> back to explore
	for e: Enemy in main.hall_enemies:
		if e.is_alive():
			e.take_damage(999.0, player)
	await wait_s(5.0)
	check(gs.flag("hall_cleared"), "hall cleared")
	check(main.level.gates["hall"].position.y > 3.0, "hall gate opened")
	check(gs.mode == 0, "back to EXPLORE after the fight")
	check(main.rig.cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "orthographic camera restored")

	# --- lantern: light + rest
	tp(Vector3(-1.6, 0.1, 16.2))
	await wait_s(0.2)
	it = player.nearest_interactable()
	check(it != null and it.kind == "lantern", "lantern prompt")
	await press("interact")
	await until(func() -> bool: return reloads > 0, 7.0)
	check(gs.flag("lantern_vestibule"), "lantern lit")
	check(gs.checkpoint == "vestibule", "checkpoint set to the vestibule")
	check(reloads == 1, "resting reloads the world")
	player.lock_controls(false)
	main.flow = main.Flow.PLAY
	main.hud.fade.color.a = 0.0

	# --- the brute in the graveyard
	var brute: Enemy = null
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if n is Enemy and (n as Enemy).kind == "brute":
			brute = n
	check(brute != null, "a brute guards the graveyard")
	tp(Vector3(0, 0.1, -16.0))
	await until(func() -> bool: return gs.mode == 1, 3.0)
	check(gs.mode == 1, "approaching the brute starts combat")
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if n is Enemy:
			(n as Enemy).take_damage(9999.0, player)
	await wait_s(2.5)

	# --- climb the cathedral steps
	tp(Vector3(0, 0.1, -29.0))
	player.lock_controls(true)
	player.script_target = Vector3(0, 2.1, -39.0)
	await wait_s(3.5)
	check(player.global_position.y > 1.7 and player.global_position.z < -36.0, "stairs climbable (y=%.2f z=%.2f)" % [player.global_position.y, player.global_position.z])
	player.lock_controls(false)

	# --- the white fog and the Warden
	tp(Vector3(0, 2.1, -44.6))
	await wait_s(0.2)
	it = player.nearest_interactable()
	check(it != null and it.kind == "fog", "fog wall prompt")
	await press("interact")
	await until(func() -> bool: return main.cinema.active, 4.0)
	main.cinema.skipped = true
	var boss: Boss = main.boss
	await until(func() -> bool: return boss.state == Boss.State.CHASE, 8.0)
	check(boss.state == Boss.State.CHASE, "boss fight begins after the fog")
	check(player.global_position.z < -47.5, "player walked through the fog")
	check(main.hud.boss_box.visible, "boss health bar shown")
	await until(func() -> bool: return gs.visual_combat, 2.0)
	check(gs.mode == 1 and gs.visual_combat, "boss fight is in the Flesh (3D)")

	# boss can hurt the player
	player.hp = 1000.0
	player.max_hp = 1000.0
	tp(boss.global_position + Vector3(0, 0, 3.0))
	boss.facing_yaw = PI
	boss.cooldown = 0.0
	var bhp := player.hp
	await until(func() -> bool: return player.hp < bhp, 6.0)
	check(player.hp < bhp, "the Warden's attacks land (%.0f)" % player.hp)

	# phase 2
	await until(func() -> bool: return boss.state == Boss.State.CHASE, 4.0)
	boss.take_damage(boss.max_hp * 0.55, player, 0.0)
	check(boss.phase == 2 and boss.state == Boss.State.PHASE, "phase 2 at half health")
	await wait_s(3.0)
	check(boss.speed_mult > 1.0, "phase 2 is faster")
	await until(func() -> bool: return boss.state == Boss.State.CHASE, 4.0)

	# kill
	boss.take_damage(9999.0, player, 0.0)
	check(boss.state == Boss.State.DEAD, "the Warden falls")
	await wait_s(9.0)
	check(gs.flag("boss_dead"), "boss defeat recorded")
	check(main.level.gates["arena"].position.y > 4.0, "the Sundered Gate's portcullis opened")
	var portal: Interactable = null
	for i: Interactable in main.level.interactables:
		if i.kind == "portal":
			portal = i
	check(portal != null and portal.enabled, "portal enabled")
	check(gs.mode == 0, "back to the Veil after the boss")

	# --- the ending
	player.max_hp = 100.0
	player.hp = 100.0
	tp(Vector3(0, 2.1, -82.5))
	await wait_s(0.2)
	it = player.nearest_interactable()
	check(it != null and it.kind == "portal", "portal prompt")
	await press("interact")
	await wait_s(0.3)
	check(main.flow == main.Flow.ENDING, "ending starts")
	main.cinema.skipped = true
	for i in 40:
		if reloads >= 2:
			break
		main.any_key.emit()
		await wait_s(0.1)
	check(reloads == 2, "ending returns to the title")
	check(gs.show_title and not gs.flag("boss_dead"), "progress reset for a new game")

	# --- death
	main.flow = main.Flow.PLAY
	player.lock_controls(false)
	player.invulnerable = false
	player.take_damage(9999.0)
	check(player.state == Player.State.DEAD, "player can die")
	await wait_s(2.0)
	check(main.hud.banner.text == "YOU DIED", "YOU DIED banner")
	await until(func() -> bool: return reloads == 3, 6.0)
	check(reloads == 3, "death reloads at the last lantern")
