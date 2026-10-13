extends SceneTree

func _initialize() -> void:
    _run()

func _shot(name: String) -> void:
    await process_frame
    await process_frame
    var img := root.get_texture().get_image()
    img.save_png("/home/claude/shots/%s.png" % name)
    print("saved ", name, " ", img.get_size())

func _run() -> void:
    DirAccess.make_dir_recursive_absolute("/home/claude/shots")
    var main: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await create_timer(1.0).timeout
    await _shot("1_explore")
    var enemies := get_nodes_in_group("enemies")
    var p: Node3D = main.player
    (enemies[0] as Node3D).global_position = p.global_position + Vector3(0, 0, -5.5)
    await create_timer(1.6).timeout
    await _shot("2_combat")
    quit(0)
