extends Node3D

const POST_SHADER := preload("res://shaders/pixel_explore.gdshader")

var player: Player
var rig: CameraRig
var post_mat: ShaderMaterial
var fade_rect: ColorRect
var hp_bar: ProgressBar
var st_bar: ProgressBar
var mode_label: Label
var death_label: Label
var _transitioning := false
var _pending := false

func _ready() -> void:
    GameState.reset()
    var info := Level.build(self)

    rig = CameraRig.new()
    rig.name = "CameraRig"
    add_child(rig)

    player = Player.new()
    player.name = "Player"
    add_child(player)
    var start: Vector3 = info["player_start"]
    player.global_position = start
    player.rig = rig
    rig.target = player
    rig.player = player
    rig.snap()

    var spawns: Array = info["enemy_spawns"]
    for p: Vector3 in spawns:
        var e := Enemy.new()
        add_child(e)
        e.global_position = p
        e.home = p

    _build_post()
    _build_hud()
    player.hp_changed.connect(_on_hp)
    player.stamina_changed.connect(_on_stamina)
    player.died.connect(_on_player_died)
    GameState.mode_changed.connect(_on_mode_changed)
    _apply_visual()

# ---------- screen look + transition ----------

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
    tw.tween_property(fade_rect, "color:a", 1.0, 0.15)
    tw.tween_callback(_apply_visual)
    tw.tween_property(fade_rect, "color:a", 0.0, 0.35)
    tw.tween_callback(_end_transition)

func _end_transition() -> void:
    _transitioning = false
    if _pending:
        _pending = false
        _run_transition()

func _apply_visual() -> void:
    var combat := GameState.mode == GameState.Mode.COMBAT
    rig.apply_mode(GameState.mode)
    post_mat.set_shader_parameter("strength", 0.0 if combat else 1.0)
    GameState.apply_visual(combat)
    if combat:
        player.acquire_lock()
    else:
        player.lock_target = null
    if mode_label:
        mode_label.text = "COMBAT  (3D)" if combat else "EXPLORING  (pixel)"

# ---------- HUD ----------

func _bar(color: Color, y: float, w: float) -> ProgressBar:
    var b := ProgressBar.new()
    b.position = Vector2(24, y)
    b.custom_minimum_size = Vector2(w, 14)
    b.size = Vector2(w, 14)
    b.show_percentage = false
    var fg := StyleBoxFlat.new()
    fg.bg_color = color
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.05, 0.05, 0.05, 0.8)
    b.add_theme_stylebox_override("fill", fg)
    b.add_theme_stylebox_override("background", bg)
    return b

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 30
    add_child(layer)
    hp_bar = _bar(Color(0.7, 0.1, 0.1), 20, 320)
    hp_bar.max_value = player.max_hp
    hp_bar.value = player.hp
    layer.add_child(hp_bar)
    st_bar = _bar(Color(0.25, 0.65, 0.3), 40, 240)
    st_bar.max_value = player.max_stamina
    st_bar.value = player.stamina
    layer.add_child(st_bar)
    mode_label = Label.new()
    mode_label.position = Vector2(24, 62)
    layer.add_child(mode_label)
    var help := Label.new()
    help.text = "WASD move  |  Space roll  |  J / LMB light  |  K / RMB heavy  |  Q lock-on"
    help.position = Vector2(24, 690)
    help.modulate = Color(1, 1, 1, 0.6)
    layer.add_child(help)
    death_label = Label.new()
    death_label.text = "YOU DIED"
    death_label.add_theme_font_size_override("font_size", 96)
    death_label.add_theme_color_override("font_color", Color(0.65, 0.05, 0.05))
    death_label.set_anchors_preset(Control.PRESET_CENTER)
    death_label.position = Vector2(440, 300)
    death_label.visible = false
    layer.add_child(death_label)

func _on_hp(v: float, m: float) -> void:
    hp_bar.max_value = m
    hp_bar.value = v

func _on_stamina(v: float, m: float) -> void:
    st_bar.max_value = m
    st_bar.value = v

func _on_player_died() -> void:
    death_label.visible = true
    death_label.modulate.a = 0.0
    var tw := create_tween()
    tw.tween_property(death_label, "modulate:a", 1.0, 1.2)
    tw.tween_interval(2.5)
    tw.tween_callback(func() -> void: get_tree().reload_current_scene())
