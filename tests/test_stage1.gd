extends SceneTree

var fails := 0
var gs: Node

func check(c: bool, msg: String) -> void:
    print(("PASS  " if c else "FAIL  ") + msg)
    if not c:
        fails += 1

func wait_s(s: float) -> void:
    await create_timer(s).timeout

func press(action: String, hold_frames := 2) -> void:
    Input.action_press(action)
    for i in hold_frames:
        await physics_frame
    Input.action_release(action)

func _initialize() -> void:
    _run()

func _run() -> void:
    gs = root.get_node("GameState")
    var main: Node = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    await wait_s(0.4)
    var player: Player = main.player
    var enemies := get_nodes_in_group("enemies")

    check(gs.mode == 0, "starts in EXPLORE mode")
    check(player.sprite.visible and not player.model.visible, "explore: pixel sprite shown, 3D model hidden")
    check(main.rig.cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "explore: orthographic camera")
    check(enemies.size() == 2, "2 enemies spawned (got %d)" % enemies.size())

    # movement
    var z0 := player.global_position.z
    Input.action_press("move_up")
    await wait_s(0.5)
    Input.action_release("move_up")
    check(player.global_position.z < z0 - 1.0, "player moves forward with input (dz=%.2f)" % (player.global_position.z - z0))

    # aggro -> combat switch
    var e1: Enemy = enemies[0]
    e1.global_position = player.global_position + Vector3(0, 0, -6)
    await wait_s(0.25)
    check(gs.mode == 1, "enemy in aggro range triggers COMBAT")
    await wait_s(0.7)
    check(main.rig.cam.projection == Camera3D.PROJECTION_PERSPECTIVE, "combat: perspective camera")
    check(player.model.visible and not player.sprite.visible, "combat: player 3D model shown")
    check(e1.model.visible and not e1.sprite.visible, "combat: enemy 3D model shown")
    check(main.post_mat.get_shader_parameter("strength") == 0.0, "combat: pixel shader disabled")
    check(player.lock_valid(), "auto lock-on acquired")

    # roll costs stamina and grants i-frames
    await wait_s(0.3)
    var st0 := player.stamina
    await press("roll")
    check(player.state == Player.State.ROLL, "roll starts")
    check(player.stamina < st0, "roll costs stamina (%.0f -> %.0f)" % [st0, player.stamina])
    check(player.invulnerable, "roll grants i-frames")
    await wait_s(0.7)
    check(player.state == Player.State.FREE, "roll ends")

    # attack damages enemy
    e1.state = Enemy.State.IDLE   # keep it passive for a deterministic hit test
    e1.global_position = player.global_position + player.facing * 1.4
    e1.aggro_range = 0.0
    var hp0 := e1.hp
    await press("attack")
    await wait_s(0.5)
    check(e1.hp < hp0, "light attack damages enemy (%.0f -> %.0f)" % [hp0, e1.hp])

    # enemy damages player
    e1.aggro_range = 8.0
    player.hp = player.max_hp
    var php := player.hp
    e1.global_position = player.global_position + Vector3(0, 0, -1.2)
    e1.state = Enemy.State.CHASE
    await wait_s(1.6)
    check(player.hp < php or player.invulnerable, "enemy attack can hurt player (%.0f -> %.0f)" % [php, player.hp])

    # kill everything -> back to explore
    for e: Node in get_nodes_in_group("enemies"):
        (e as Enemy).take_damage(999.0, player)
    await wait_s(2.4)
    check(gs.mode == 0, "all enemies dead -> back to EXPLORE")
    check(main.rig.cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "orthographic camera restored")
    check(player.sprite.visible and not player.model.visible, "pixel sprite restored")

    # death
    player.invulnerable = false
    player.take_damage(9999.0)
    check(player.state == Player.State.DEAD, "player can die")
    await wait_s(0.3)
    check(main.death_label.visible, "YOU DIED screen shown")

    print("\nRESULT: %s (%d failures)" % ["ALL PASSED" if fails == 0 else "FAILED", fails])
    quit(fails)
