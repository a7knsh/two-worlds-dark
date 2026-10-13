class_name Story
extends RefCounted
## The story beats: opening (Dark Souls prologue + a Bloodborne-style awakening),
## the Warden's entrance, and the ending.

const PROLOGUE := [
    "In the Age of Ash, there was but one world...\nwhole, and dreaming.",
    "Then the Pale Sun cracked,\nand its light bled in two.",
    "One half became the Veil -\na world of shadow and memory, faded as old parchment.",
    "The other became the Flesh -\ncold and sharp, where steel cuts and blood is spilled.",
    "Between them stands the Sundered Gate...\nand the Warden who keeps it.",
    "You are a Pale One.\nNeither living, nor dead.\nBound to walk both worlds.",
]

static func intro(m: Node) -> void:
    var c: Cinema = m.cinema
    var hud: Hud = m.hud
    var p: Player = m.player
    p.lock_controls(true)
    p.global_position = Vector3(0, 0.85, 65.3)
    p.facing = Vector3(0, 0, -1)
    p.hum.face_yaw = 0.0
    p.hum.play("lie", 1.0, 0.0)
    m.set_world_look(false)
    c.begin()
    hud.fade.color.a = 1.0
    Sfx.stop_music(1.0)
    # --- Part one: the prologue, over black
    for line: String in PROLOGUE:
        await c.narrate(line, 5.2)
    await c.wait(0.6)
    # --- Part two: the chapel. The Veil, pixelated and cold.
    c.shot(Vector3(-3.8, 3.6, 70.0), Vector3(0, 0.9, 65.4))
    hud.fade_to(0.0, 2.5)
    Sfx.play("bell", -4.0)
    c.drift(Vector3(-2.2, 2.3, 68.4), Vector3(0, 0.9, 65.2), 9.0)
    var keeper: Humanoid = m.keeper
    await c.wait(2.0)
    keeper.play("talk", 3.5, 0.3)
    await c.say("The Veilkeeper", "Ahh... so the bell has called another one.", 4.0)
    await c.say("The Veilkeeper", "Rest easy, Pale One. You'll not remember much... you never do.", 4.6)
    c.shot(Vector3(-0.6, 2.6, 60.8), Vector3(2.0, 0.9, 65.0))
    c.drift(Vector3(0.2, 2.3, 61.2), Vector3(2.0, 0.9, 65.0), 9.0)
    keeper.play("talk", 4.0, 0.3)
    await c.say("The Veilkeeper", "Your blood is thin. Pale. Neither world will claim it...\nso both of them will hunt you.", 5.2)
    keeper.play("talk", 3.0, 0.3)
    await c.say("The Veilkeeper", "Now then... let us begin the binding.", 3.6)
    # --- Part three: the Flesh bleeds through. Something crawls out of the blood.
    Sfx.play("bell", 0.0, 0.8)
    hud.flash(Color(0.6, 0.02, 0.02, 0.9), 1.2)
    m.set_world_look(true)
    var beast: Humanoid = null
    if not c.skipped:
        beast = Humanoid.create("beast", "", 1.45)
        m.add_child(beast)
        beast.global_position = Vector3(-2.3, -2.4, 63.8)
        beast.face_yaw = deg_to_rad(-60.0)
        beast.play("crawl", 1.6, 0.0)
        Fx.burst(Vector3(-2.3, 0.1, 63.8), Color(0.4, 0.0, 0.0), 40, 3.0, 0.07, 1.2, -6.0, 40.0)
        Sfx.play("growl", -2.0, 0.7)
        var tw := beast.create_tween()
        tw.tween_property(beast, "global_position:y", 0.0, 3.2).set_ease(Tween.EASE_OUT)
    c.shot(Vector3(-0.2, 0.55, 61.2), Vector3(-2.3, 1.0, 64.0))
    c.drift(Vector3(0.3, 0.7, 61.6), Vector3(-2.0, 1.3, 64.0), 4.0)
    await c.wait(3.6)
    if beast and not c.skipped:
        var tw2 := beast.create_tween()
        tw2.tween_property(beast, "global_position", Vector3(-1.0, 0.0, 64.7), 2.6)
        Sfx.play("growl", 0.0, 0.55)
    c.shot(Vector3(1.9, 1.5, 61.9), Vector3(-0.8, 0.9, 64.8))
    await c.wait(2.6)
    if beast and not c.skipped:
        beast.play("reach", 1.4, 0.15)
        beast.face_yaw = deg_to_rad(-80.0)
    c.drift(Vector3(1.4, 1.3, 62.5), Vector3(-0.5, 1.1, 64.9), 1.6)
    await c.wait(1.6)
    # the Veil rejects it: it burns away in pale light
    hud.flash(Color(0.85, 0.9, 1.0, 1.0), 1.6)
    Sfx.play("ash", 0.0, 0.8)
    Sfx.play("bell", -2.0, 1.2)
    if beast:
        Fx.ash(beast.global_position + Vector3(0, 0.8, 0), 70, Color(0.85, 0.88, 1.0))
        beast.queue_free()
    m.set_world_look(false)
    c.shot(Vector3(-0.6, 2.6, 60.8), Vector3(2.0, 0.9, 65.0))
    keeper.play("talk", 3.0, 0.3)
    await c.say("The Veilkeeper", "Hah... It seems the Veil has taken a liking to you.", 4.0)
    if not c.skipped:
        await hud.fade_to(1.0, 1.2).finished
    await c.say("The Veilkeeper", "Go now. Take up steel in the Hall of Arms...\nand find the Warden who keeps the Sundered Gate.", 5.2)
    await c.say("The Veilkeeper", "End this long night, Pale One.", 3.2)
    # --- wake up
    if beast and is_instance_valid(beast):
        beast.queue_free()
    keeper.play("sit", 1.0, 0.2)
    hud.fade.color.a = 1.0
    c.end(m.rig.cam)
    GameState.set_flag("intro_seen")
    m.set_world_look(false)
    await m.wake_player(Vector3(0, 0.1, 63.4))

static func boss_intro(m: Node) -> void:
    var c: Cinema = m.cinema
    var p: Player = m.player
    var boss: Boss = m.boss
    var level: Level = m.level
    var first := not GameState.flag("boss_seen")
    p.lock_controls(true)
    Sfx.play("fog", -2.0)
    level.set_fog(false)
    p.script_target = Vector3(0, 2.1, -49.0)
    var e := 0.0
    while p.script_target != Vector3.INF and e < 2.5:
        await m.get_tree().process_frame
        e += m.get_process_delta_time()
    p.global_position = Vector3(p.global_position.x, p.global_position.y, minf(p.global_position.z, -48.6))
    level.set_fog(true)
    level.fog_mat.set_shader_parameter("tint", Color(0.9, 0.3, 0.25, 0.75))
    Sfx.stop_music(1.0)
    # beyond the fog lies only the Flesh
    m.set_world_look(true)
    if first:
        c.begin()
        c.shot(Vector3(3.2, 4.4, -47.0), Vector3(0, 3.0, -63.0))
        c.drift(Vector3(2.4, 3.1, -55.0), Vector3(0, 3.0, -63.0), 4.5)
        await c.wait(3.0)
        await c.say("", "...", 1.5)
        boss.stand()
        Sfx.play("growl", 0.0, 0.5)
        c.shot(Vector3(-2.2, 2.8, -57.0), Vector3(0, 5.2, -63.0))
        c.drift(Vector3(-1.6, 2.6, -57.8), Vector3(0, 5.6, -63.0), 3.5)
        await c.wait(1.9)
        boss.hum.play("roar", 2.6, 0.2)
        await c.wait(0.8)
        Sfx.play("roar", 2.0, 0.75)
        m.hud.flash(Color(0.5, 0.6, 1.0, 0.35), 0.8)
        m.hud.show_banner("Morvaith, the Pale Warden", Color(0.85, 0.82, 0.72), 2.0, 44)
        await c.wait(2.6)
        c.end(m.rig.cam)
        GameState.set_flag("boss_seen")
    else:
        boss.stand()
        await m.get_tree().create_timer(1.2).timeout
    if boss.state == Boss.State.DORMANT:
        boss.hum.play("idle", 1.0, 0.3)
    p.lock_controls(false)
    m.start_boss_fight()

const EPILOGUE := [
    "And so the Warden fell,\nand the Sundered Gate stood open.",
    "Beyond it, the Veil and the Flesh bled into one another...\nand something far older than the Warden began to wake.",
    "The long night is not over, Pale One.\nIt has only begun.",
]

static func ending(m: Node) -> void:
    var c: Cinema = m.cinema
    var hud: Hud = m.hud
    m.player.lock_controls(true)
    m.player.script_target = Vector3(0, 2.1, -85.5)
    c.begin(false)
    c.shot(Vector3(2.5, 3.2, -76.0), Vector3(0, 4.0, -85.0))
    c.drift(Vector3(0.8, 4.4, -79.5), Vector3(0, 4.4, -85.0), 4.0)
    Sfx.play("fog", 0.0, 0.6)
    await c.wait(2.6)
    hud.flash(Color(1.0, 0.35, 0.3, 1.0), 2.0)
    await hud.fade_to(1.0, 1.6).finished
    Sfx.play("bell", -3.0, 0.7)
    for line: String in EPILOGUE:
        await c.narrate(line, 5.5)
    hud.narration("TWO WORLDS DARK\n\nEnd of Prototype v1.1\n\nThank you for playing.", 6.0)
    await c.wait(5.0)
    hud.ending_label.text = "TWO WORLDS DARK\n\nEnd of Prototype v1.1\n\nThank you for playing.\n\n\n[ press any key ]"
    hud.ending_label.modulate.a = 1.0
    Sfx.play("banner", -4.0)
    await m.any_key
    GameState.reset_progress()
    m.call("_reload")
