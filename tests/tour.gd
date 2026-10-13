extends Node
## Dev tool: visual tour. Needs a display (or xvfb):
##   godot res://tests/tour.tscn -- <out_dir> [part]
## Saves screenshots of every zone in both worlds, the fights, and the cutscenes.

var out := "user://shots"
var main: Node
var gs: Node

func shot(sname: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, sname])
	print("shot ", sname)

func wait_s(s: float) -> void:
	await get_tree().create_timer(s).timeout

func tp(p: Vector3) -> void:
	main.player.global_position = p
	main.rig.snap()

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var part := args[1] if args.size() > 1 else "play"
	gs = get_node("/root/GameState")
	gs.reset_progress()
	if part == "title" or part == "intro":
		gs.show_title = part == "title"
	else:
		gs.show_title = false
		gs.set_flag("intro_seen")
	main = load("res://scenes/main.tscn").instantiate()
	main.on_reload = func() -> void: pass
	add_child(main)
	match part:
		"title":
			await wait_s(4.0)
			await shot("t_title")
		"intro":
			await _intro()
		"play":
			await _play()
		"boss":
			await _boss()
	get_tree().quit()

func _intro() -> void:
	await wait_s(3.0)
	await shot("i_prologue")
	await wait_s(33.0)
	await shot("i_chapel_veil")
	await wait_s(9.0)
	await shot("i_keeper")
	await wait_s(9.5)
	await shot("i_beast_rises")
	await wait_s(4.0)
	await shot("i_beast_reach")
	await wait_s(2.0)
	await shot("i_flash")

func _play() -> void:
	await wait_s(3.0)
	await shot("p_chapel")
	tp(Vector3(0, 0.1, 50))
	await wait_s(0.6)
	await shot("p_corridor")
	tp(Vector3(0, 0.1, 30))
	await wait_s(0.6)
	await shot("p_hall_veil")
	gs.weapon = "greataxe"
	main.player.equip("greataxe")
	main._wake_hall()
	await wait_s(3.5)
	await shot("p_hall_flesh")
	main.player.hum.play("p_heavy", 1.35, 0.05)
	await wait_s(0.95)
	await shot("p_axe_heavy")
	for e: Enemy in main.hall_enemies:
		e.take_damage(999.0, main.player)
	await wait_s(5.0)
	tp(Vector3(0, 0.1, 16))
	await wait_s(0.6)
	await shot("p_vestibule")
	main.player.equip("longsword")
	tp(Vector3(0, 0.1, 6))
	await wait_s(0.8)
	await shot("p_graveyard_veil")
	tp(Vector3(-4, 0.1, -10))
	await wait_s(0.8)
	await shot("p_graveyard_mid")
	tp(Vector3(0, 0.1, -19))
	await wait_s(3.0)
	await shot("p_brute_flesh")
	await wait_s(1.0)
	await shot("p_brute_flesh2")
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		(n as Foe).take_damage(9999.0, main.player)
	await wait_s(4.0)
	tp(Vector3(0, 2.1, -41))
	await wait_s(0.8)
	await shot("p_steps_fog")

func _boss() -> void:
	await wait_s(2.0)
	main.player.equip("longsword")
	tp(Vector3(0, 2.1, -44.6))
	await wait_s(0.5)
	main.player.nearest_interactable().activate()
	await wait_s(4.5)
	await shot("b_intro_1")
	await wait_s(3.0)
	await shot("b_intro_2")
	await wait_s(2.6)
	await shot("b_intro_name")
	await wait_s(4.0)
	main.player.max_hp = 5000.0
	main.player.hp = 5000.0
	main.boss.cooldown = 3.0
	tp(main.boss.global_position + Vector3(1.5, 0, 6.5))
	await wait_s(1.2)
	await shot("b_fight_0")
	await shot("b_fight_1")
	await wait_s(1.6)
	await shot("b_fight_2")
	await wait_s(1.6)
	await shot("b_fight_3")
	main.boss.take_damage(400.0, main.player, 0.0)
	await wait_s(1.2)
	await shot("b_phase2")
	await wait_s(2.0)
	main.boss._start("nova")
	await wait_s(1.1)
	await shot("b_nova_windup")
	await wait_s(0.5)
	await shot("b_nova_burst")
	await wait_s(2.5)
	main.boss.take_damage(9999.0, main.player, 0.0)
	await wait_s(2.6)
	await shot("b_felled")
	await wait_s(9.0)
	tp(Vector3(0, 2.1, -78))
	await wait_s(1.0)
	await shot("b_portal")
