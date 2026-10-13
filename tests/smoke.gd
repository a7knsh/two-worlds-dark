extends Node
## Dev tool: boots the game straight into play (skipping title + intro) and takes screenshots.
## godot res://tests/smoke.tscn -- <out_dir> [checkpoint]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shots"
	var gs: Node = get_node("/root/GameState")
	gs.show_title = false
	gs.set_flag("intro_seen")
	if args.size() > 1:
		gs.checkpoint = args[1]
	var t0 := Time.get_ticks_msec()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	await get_tree().process_frame
	t0 = Time.get_ticks_msec()
	get_tree().root.add_child(main)
	print("main _ready in %d ms" % (Time.get_ticks_msec() - t0))
	await get_tree().process_frame
	await get_tree().process_frame
	print("first frames in %d ms" % (Time.get_ticks_msec() - t0))
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(out + "/smoke_explore.png")
	print("saved")
	get_tree().quit()
