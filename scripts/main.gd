extends Node3D
## Game flow: title -> opening cutscene -> tutorial / Hall of Arms -> graveyard -> boss -> ending.
## Death and resting at a lantern reload the scene; progress lives in GameState.

signal any_key

const POST_SHADER := preload("res://shaders/pixel_explore.gdshader")

enum Flow { TITLE, PLAY, CUTSCENE, DEAD, ENDING }

const KEEPER_LINES := [
    "The Hall of Arms lies north. Take what steel you can carry...\nthe dead there are hungry for it.",
    "Lanterns burn with the pale flame of the Veil.\nRest by them, and you will wake there when you fall.",
    "The Warden... Morvaith. Once a knight of the Pale Sun.\nNow he guards a door that should never have been made.",
    "Go on. I'll be here. I am always here.",
]

var flow := Flow.PLAY
var level: Level
var player: Player
var rig: CameraRig
var hud: Hud
var cinema: Cinema
var keeper: Humanoid
var boss: Boss
var post_mat: ShaderMaterial
var fade_rect: ColorRect
var hall_enemies: Array = []
var ash_particles: CPUParticles3D
var _transitioning := false
var _pending := false
var _zone := ""
var _zones_seen := {}
var _msg_open: Interactable
var _keeper_line := 0
var _sub_token := 0
var _paused := false
## Tests replace scene reloads (death, resting, ending) with this callback.
var on_reload: Callable

func _ready() -> void:
    # the world pauses; the HUD (always processing) handles the pause key and menu
    process_mode = Node.PROCESS_MODE_PAUSABLE
    GameState.reset()
    Engine.time_scale = 1.0
    level = Level.new()
    level.name = "Level"
    add_child(level)
    level.build()
    for it: Interactable in level.interactables:
        it.activated.connect(_on_interact)

    rig = CameraRig.new()
    rig.name = "CameraRig"
    add_child(rig)

    player = Player.new()
    player.name = "Player"
    add_child(player)
    var cp: Dictionary = Level.CHECKPOINTS.get(GameState.checkpoint, Level.CHECKPOINTS["chapel"])
    player.global_position = cp["pos"]
    player.rig = rig
    rig.target = player
    rig.player = player
    rig.snap()

    _spawn_npcs()
    _spawn_enemies()
    _restore_world_state()

    hud = Hud.new()
    add_child(hud)
    cinema = Cinema.new()
    cinema.hud = hud
    add_child(cinema)
    hud.pause_choice.connect(_on_pause_choice)
    hud.pause_pressed.connect(_on_pause_pressed)
    _build_post()
    _build_ambience()

    hud.set_hp(player.hp, player.max_hp)
    hud.set_stamina(player.stamina, player.max_stamina)
    hud.set_vials(player.vials)
    hud.set_weapon(player.wstats["name"])
    player.hp_changed.connect(hud.set_hp)
    player.stamina_changed.connect(hud.set_stamina)
    player.vials_changed.connect(hud.set_vials)
    player.died.connect(_on_player_died)
    GameState.mode_changed.connect(_on_mode_changed)
    _apply_visual()

    if GameState.show_title:
        _title()
    elif not GameState.flag("intro_seen"):
        _run_intro()
    else:
        _zone = _zone_id()
        _zones_seen[_zone] = true
        wake_player(player.global_position)

# ------------------------------------------------------------------ world setup

func _spawn_npcs() -> void:
    keeper = Humanoid.create("keeper", "cane", 1.0)
    add_child(keeper)
    keeper.global_position = Vector3(2.4, 0.0, 65.2)
    keeper.face_yaw = PI * 0.5
    keeper.play("sit", 1.0, 0.0)
    var talk := Interactable.make("talk", "Speak with the Veilkeeper", {}, 2.0)
    add_child(talk)
    talk.global_position = Vector3(1.4, 0.0, 65.0)
    talk.activated.connect(_on_interact)

func _spawn_enemies() -> void:
    hall_enemies.clear()
    for e: Array in Level.ENEMIES:
        var tag: String = e[3]
        if tag == "hall" and GameState.flag("hall_cleared"):
            continue
        var en := Enemy.spawn(e[0], e[2])
        en.tag = tag
        add_child(en)
        en.global_position = e[1]
        en.home = e[1]
        if tag == "hall":
            en.facing_yaw = randf() * TAU
            hall_enemies.append(en)
            en.died.connect(_on_hall_enemy_died)
    if not GameState.flag("boss_dead"):
        boss = Boss.new()
        boss.name = "Boss"
        add_child(boss)
        boss.global_position = Vector3(0, 2.1, -63.0)
        boss.facing_yaw = PI
        boss.health_changed.connect(func(v: float, m: float) -> void: hud.set_boss("Morvaith, the Pale Warden", v, m))
        boss.phase_changed.connect(_on_boss_phase)
        boss.defeated.connect(_on_boss_defeated)

func _restore_world_state() -> void:
    if GameState.flag("hall_cleared"):
        level.open_gate("hall", true)
    if GameState.flag("boss_dead"):
        level.open_gate("arena", true)
        level.set_fog(false)
        level.set_portal(true)
        for it: Interactable in level.interactables:
            if it.kind == "portal":
                it.enabled = true
    for it: Interactable in level.interactables:
        if it.kind == "lantern":
            _set_lantern_lit(it, GameState.flag("lantern_" + String(it.data["id"])))

func _set_lantern_lit(it: Interactable, lit: bool) -> void:
    var l: OmniLight3D = it.get_meta("light")
    var f: MeshInstance3D = it.get_meta("flame")
    f.visible = lit
    l.visible = lit
    it.prompt = "Rest at lantern" if lit else "Light lantern"

func _build_ambience() -> void:
    ash_particles = CPUParticles3D.new()
    ash_particles.amount = 90
    ash_particles.lifetime = 6.0
    ash_particles.preprocess = 6.0
    ash_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    ash_particles.emission_box_extents = Vector3(14, 4, 12)
    ash_particles.direction = Vector3(0.3, -1, 0.1)
    ash_particles.spread = 25.0
    ash_particles.gravity = Vector3(0, -0.15, 0)
    ash_particles.initial_velocity_min = 0.2
    ash_particles.initial_velocity_max = 0.6
    var qm := QuadMesh.new()
    qm.size = Vector2(0.05, 0.05)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.albedo_color = Color(0.7, 0.7, 0.72, 0.6)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    qm.material = m
    ash_particles.mesh = qm
    ash_particles.position = Vector3(0, 4, 0)
    rig.add_child(ash_particles)

# ------------------------------------------------------------------ flow

func _title() -> void:
    flow = Flow.TITLE
    player.lock_controls(true)
    hud.show_title(true)
    cinema.cam.make_current()
    cinema.shot(Vector3(-6, 12, 22), Vector3(0, 0, -6))
    cinema.drift(Vector3(6, 10, 14), Vector3(0, 0, -12), 40.0)
    hud.fade_to(0.0, 2.5)
    Sfx.play_music("ambient", -10.0, 3.0)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    await any_key
    Sfx.play("bell", -6.0)
    hud.show_title(false)
    GameState.show_title = false
    await hud.fade_to(1.0, 1.2).finished
    if not GameState.flag("intro_seen"):
        _run_intro()
    else:
        rig.cam.make_current()
        wake_player(player.global_position)

func _run_intro() -> void:
    flow = Flow.CUTSCENE
    hud.show_title(false)
    await Story.intro(self)

## Fade in from black with the Pale One rising from the floor.
func wake_player(pos: Vector3) -> void:
    flow = Flow.CUTSCENE
    rig.cam.make_current()
    player.lock_controls(true)
    player.global_position = pos
    rig.snap()
    player.hum.play("rise", 2.0, 0.0)
    hud.show_gameplay(true)
    hud.fade_to(0.0, 1.6)
    Sfx.play_music("ambient", -10.0, 3.0)
    await get_tree().create_timer(2.0).timeout
    player.lock_controls(false)
    flow = Flow.PLAY
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _zone = ""
    if GameState.checkpoint == "chapel" and not GameState.flag("tutorial_hint"):
        GameState.set_flag("tutorial_hint")
        hud.hint("Read the glowing messages on the ground with  [E]", 5.0)

func set_world_look(combat: bool) -> void:
    post_mat.set_shader_parameter("strength", 0.0 if combat else 1.0)
    GameState.apply_visual(combat)

func _input(event: InputEvent) -> void:
    if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
        any_key.emit()

func _on_pause_pressed() -> void:
    if (flow == Flow.PLAY or _paused) and not cinema.active:
        _toggle_pause()

func _process(_delta: float) -> void:
    if flow == Flow.PLAY:
        var it := player.nearest_interactable() if player.state == Player.State.FREE else null
        hud.set_prompt(it.prompt if it else "")
        if _msg_open and (it != _msg_open or not is_instance_valid(_msg_open)):
            hud.hide_message()
            _msg_open = null
        _track_zone()
    else:
        hud.set_prompt("")
    hud.mode_label.text = "THE FLESH  (3D combat)" if GameState.visual_combat else "THE VEIL  (exploration)"
    if ash_particles:
        (ash_particles.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = \
            Color(1.0, 0.35, 0.15, 0.7) if GameState.visual_combat else Color(0.7, 0.7, 0.72, 0.5)

func _zone_id() -> String:
    var z := level.zone_at(player.global_position)
    return z[0] if z.size() > 0 else ""

func _track_zone() -> void:
    var z := level.zone_at(player.global_position)
    var id: String = z[0] if z.size() > 0 else _zone
    if id == _zone:
        return
    _zone = id
    if not _zones_seen.has(id) and z.size() > 0:
        _zones_seen[id] = true
        hud.area_title(z[1])
    if id == "hall" and GameState.flag("hall_triggered") and not GameState.flag("hall_cleared"):
        _wake_hall()

# ------------------------------------------------------------------ interactions

func _on_interact(it: Interactable) -> void:
    if flow != Flow.PLAY:
        return
    match it.kind:
        "message":
            if _msg_open == it:
                hud.hide_message()
                _msg_open = null
            else:
                hud.show_message(it.data["text"])
                _msg_open = it
                Sfx.play("ui", -8.0)
        "talk":
            keeper.play("talk", 3.0, 0.3)
            _timed_subtitle("The Veilkeeper", KEEPER_LINES[_keeper_line % KEEPER_LINES.size()], 5.0)
            _keeper_line += 1
        "altar":
            _take_weapon(it.data["weapon"])
        "lantern":
            _rest(it)
        "fog":
            if boss and boss.state == Boss.State.DORMANT:
                flow = Flow.CUTSCENE
                hud.set_prompt("")
                await Story.boss_intro(self)
                flow = Flow.PLAY
        "portal":
            flow = Flow.ENDING
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            Sfx.stop_music(2.0)
            await Story.ending(self)

func _timed_subtitle(speaker: String, text: String, dur: float) -> void:
    _sub_token += 1
    var tok := _sub_token
    hud.subtitle(speaker, text)
    await get_tree().create_timer(dur).timeout
    if tok == _sub_token:
        hud.subtitle("", "")

func _take_weapon(id: String) -> void:
    if player.weapon == id:
        hud.hint("You already wield the " + String(Weapons.stats(id)["name"]), 2.5)
        return
    await get_tree().create_timer(0.35).timeout
    player.equip(id)
    GameState.weapon = id
    var st := Weapons.stats(id)
    hud.set_weapon(st["name"])
    hud.hint("%s  -  %s" % [st["name"], st["desc"]], 4.0)
    Sfx.play("lantern", -6.0, 1.3)
    Fx.heal(player.global_position + Vector3(0, 1.2, 0))
    if not GameState.flag("hall_triggered"):
        GameState.set_flag("hall_triggered")
        await get_tree().create_timer(1.2).timeout
        hud.hint("The dead stir...", 3.0)
        Sfx.play("bell", -6.0, 0.6)
        _wake_hall()

func _wake_hall() -> void:
    var d := 0.3
    for e: Enemy in hall_enemies:
        if is_instance_valid(e) and e.state == Enemy.State.DORMANT:
            e.wake(d)
            d += 0.7

func _on_hall_enemy_died(_e: Enemy) -> void:
    for e: Enemy in hall_enemies:
        if is_instance_valid(e) and e.is_alive():
            return
    if GameState.flag("hall_cleared"):
        return
    GameState.set_flag("hall_cleared")
    await get_tree().create_timer(1.5).timeout
    level.open_gate("hall")
    hud.hint("The gate of the Hall of Arms grinds open.", 3.5)

func _rest(it: Interactable) -> void:
    if GameState.mode == GameState.Mode.COMBAT:
        hud.hint("You cannot rest while foes are near.", 2.5)
        return
    var id: String = it.data["id"]
    flow = Flow.CUTSCENE
    player.lock_controls(true)
    var first := not GameState.flag("lantern_" + id)
    if first:
        GameState.set_flag("lantern_" + id)
        _set_lantern_lit(it, true)
        Sfx.play("lantern", -2.0)
        hud.show_banner("LANTERN LIT", Color(0.75, 0.85, 1.0), 1.8, 64)
        await get_tree().create_timer(2.6).timeout
    GameState.checkpoint = id
    player.refill()
    Sfx.play("heal", -6.0, 0.8)
    hud.hint("Resting... the dead return to their posts.", 1.6)
    await hud.fade_to(1.0, 1.2).finished
    _reload()

func _reload() -> void:
    Engine.time_scale = 1.0
    if on_reload.is_valid():
        on_reload.call()
        return
    GameState.reset()
    get_tree().reload_current_scene()

# ------------------------------------------------------------------ boss

func start_boss_fight() -> void:
    boss.activate()
    hud.set_boss("Morvaith, the Pale Warden", boss.hp, boss.max_hp)
    Sfx.play_music("boss", -6.0, 1.5)
    player.lock_target = boss

func _on_boss_phase(_p: int) -> void:
    hud.flash(Color(0.7, 0.0, 0.0, 0.5), 1.0)
    _timed_subtitle("Morvaith", "The Flesh... it BURNS...!", 3.0)

func _on_boss_defeated() -> void:
    hud.set_boss("", 0, 1)
    Sfx.stop_music(1.0)
    Engine.time_scale = 0.3
    await get_tree().create_timer(1.4, true, false, true).timeout
    Engine.time_scale = 1.0
    GameState.set_flag("boss_dead")
    hud.show_banner("WARDEN FELLED", Color(0.95, 0.8, 0.45), 3.0)
    Sfx.play("banner", 0.0)
    await get_tree().create_timer(2.0).timeout
    _timed_subtitle("Morvaith", "...the gate... was never meant... to open...", 4.0)
    if is_instance_valid(boss):
        boss.crumble()
    await get_tree().create_timer(3.5).timeout
    level.set_fog(false)
    level.open_gate("arena")
    level.set_portal(true)
    for it: Interactable in level.interactables:
        if it.kind == "portal":
            it.enabled = true
    hud.hint("The Sundered Gate stands open.", 4.0)
    Sfx.play_music("ambient", -10.0, 4.0)

# ------------------------------------------------------------------ death

func _on_player_died() -> void:
    flow = Flow.DEAD
    hud.hide_message()
    await get_tree().create_timer(1.0).timeout
    Sfx.play("banner", -4.0, 0.6)
    hud.show_banner("YOU DIED", Color(0.62, 0.04, 0.03), 2.6, 96)
    await get_tree().create_timer(3.8).timeout
    await hud.fade_to(1.0, 1.0).finished
    _reload()

# ------------------------------------------------------------------ pause

func _toggle_pause() -> void:
    _paused = not _paused
    get_tree().paused = _paused
    hud.show_pause(_paused)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _paused else Input.MOUSE_MODE_CAPTURED

func _on_pause_choice(choice: String) -> void:
    match choice:
        "resume":
            _toggle_pause()
        "title":
            _toggle_pause()
            GameState.show_title = true
            _reload()
        "quit":
            get_tree().quit()

# ------------------------------------------------------------------ the two worlds

func _build_post() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    var rect := ColorRect.new()
    rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    post_mat = ShaderMaterial.new()
    post_mat.shader = POST_SHADER
    rect.material = post_mat
    layer.add_child(rect)

    var fade_layer := CanvasLayer.new()
    fade_layer.layer = 20
    add_child(fade_layer)
    fade_rect = ColorRect.new()
    fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fade_rect.color = Color(0, 0, 0, 0)
    fade_layer.add_child(fade_rect)

func _on_mode_changed(_m: GameState.Mode) -> void:
    if _transitioning:
        _pending = true
        return
    _run_transition()

func _run_transition() -> void:
    _transitioning = true
    var tw := create_tween()
    var combat := GameState.mode == GameState.Mode.COMBAT
    fade_rect.color = Color(0.35, 0.0, 0.0, 0.0) if combat else Color(0.0, 0.0, 0.0, 0.0)
    tw.tween_property(fade_rect, "color:a", 1.0, 0.15)
    tw.tween_callback(_apply_visual)
    tw.tween_property(fade_rect, "color:a", 0.0, 0.35)
    tw.tween_callback(_end_transition)
    if combat:
        Sfx.play("growl", -14.0, 1.6)

func _end_transition() -> void:
    _transitioning = false
    if _pending:
        _pending = false
        _run_transition()

func _apply_visual() -> void:
    var combat := GameState.mode == GameState.Mode.COMBAT
    rig.apply_mode(GameState.mode)
    if not cinema or not cinema.active:
        set_world_look(combat)
    if combat:
        if not player.lock_valid():
            player.acquire_lock()
    else:
        player.lock_target = null
