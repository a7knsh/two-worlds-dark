extends Node3D
## Dev tool: renders every character build in several animation poses and dumps the
## generated pixel sprite sheets. Run under a display:  godot res://tests/pose_gallery.tscn -- <out_dir>

var out_dir := "user://shots"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_node("/root/GameState").apply_visual(true)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	for w in ["longsword", "greataxe", "twinfangs"]:
		Humanoid.make_attack("p_light_a", Weapons.ATTACKS[w]["light_a"], 0.4)
	var t0 := Time.get_ticks_msec()
	var cast := [
		["hunter", "longsword", 1.0, "", ["idle", "p_light_a", "p_heavy", "roll", "death"]],
		["hunter", "greataxe", 1.0, "", ["idle"]],
		["hunter", "twinfangs", 1.0, "fang_l", ["idle"]],
		["husk", "rusty_blade", 1.0, "", ["idle", "walk"]],
		["brute", "great_club", 1.3, "", ["idle"]],
		["warden", "warden_sword", 2.2, "", ["idle", "kneel"]],
		["keeper", "cane", 1.0, "", ["sit"]],
		["beast", "", 1.5, "", ["crawl_hold"]],
	]
	Humanoid.make_attack("p_light_a", Weapons.ATTACKS["longsword"]["light_a"], 0.4)
	Humanoid.make_attack("p_heavy", Weapons.ATTACKS["longsword"]["heavy"], 0.53)
	var x := -9.0
	for c: Array in cast:
		for a: String in c[4]:
			var h := Humanoid.create(c[0], c[1], c[2], c[3])
			add_child(h)
			h.position = Vector3(x, 0, 0)
			h.face_yaw = deg_to_rad(-60)
			var t := 0.0
			if a.begins_with("p_"):
				t = 0.4
			elif a == "roll":
				t = 0.45
			h.play(a, 1.0, 0.0)
			h.anim_t = t
			h.anim_speed = 0.0
			x += 1.6 if c[2] < 1.5 else 3.0
	print("built cast in %d ms" % (Time.get_ticks_msec() - t0))
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(5, 2.6, 13)
	cam.look_at(Vector3(5, 1.2, 0))
	cam.fov = 60
	cam.make_current()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(out_dir + "/gallery3d.png")
	var gs: Node = get_node("/root/GameState")
	for k: String in gs.cache:
		if k.begins_with("sheet_"):
			var img: Image = (gs.cache[k] as ImageTexture).get_image()
			img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
			img.save_png(out_dir + "/" + k + ".png")
	get_tree().quit()
