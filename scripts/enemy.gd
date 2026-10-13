class_name Enemy
extends CharacterBody3D

signal died(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, STRIKE, RECOVER, STAGGER, DEAD }

const GRAVITY := 24.0
const BASE_COLOR := Color(0.42, 0.36, 0.32)
const WARN_COLOR := Color(1.0, 0.25, 0.1)

var max_hp := 60.0
var hp := 60.0
var aggro_range := 8.0
var leash := 16.0
var attack_range := 1.9
var windup_time := 0.65
var recover_time := 0.9
var damage := 18.0
var speed := 2.8
var home := Vector3.ZERO
var state := State.IDLE
var state_t := 0.0

var player: Player
var sprite: Sprite3D
var model: Node3D
var body_mat: StandardMaterial3D
var col: CollisionShape3D

func _ready() -> void:
    add_to_group("enemies")
    collision_layer = 4
    collision_mask = 1 | 2
    col = Visuals.capsule_collision()
    add_child(col)
    sprite = Visuals.make_sprite(Visuals.humanoid_texture(
        Color(0.42, 0.36, 0.32), Color(0.25, 0.2, 0.18), Color(0.7, 0.72, 0.65), Color(0.55, 0.45, 0.3)))
    add_child(sprite)
    var m := Visuals.make_model(BASE_COLOR)
    model = m["node"]
    body_mat = m["mat"]
    add_child(model)
    GameState.visual_mode_changed.connect(_on_visual_mode)
    _on_visual_mode(GameState.visual_combat)

func _on_visual_mode(combat: bool) -> void:
    sprite.visible = not combat
    model.visible = combat

func _set_state(s: State) -> void:
    state = s
    state_t = 0.0

func _tint(c: Color) -> void:
    body_mat.albedo_color = c
    sprite.modulate = Color(1, 1, 1).lerp(c, 0.0 if c == BASE_COLOR else 0.6)

func _face(dir: Vector3) -> void:
    if dir.length() > 0.01:
        model.rotation.y = atan2(-dir.x, -dir.z)

func _physics_process(delta: float) -> void:
    if state == State.DEAD:
        return
    if player == null or not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player") as Player
        if player == null:
            return
    state_t += delta
    var to := player.global_position - global_position
    to.y = 0.0
    var dist := to.length()
    var dir := to / dist if dist > 0.001 else Vector3.ZERO
    var move := Vector3.ZERO
    match state:
        State.IDLE:
            if dist < aggro_range and player.state != Player.State.DEAD:
                _aggro()
        State.CHASE:
            if player.state == Player.State.DEAD or dist > leash:
                _deaggro()
            else:
                _face(dir)
                if dist <= attack_range:
                    _set_state(State.WINDUP)
                else:
                    move = dir * speed
        State.WINDUP:
            _face(dir)
            _tint(BASE_COLOR.lerp(WARN_COLOR, clampf(state_t / windup_time, 0.0, 1.0)))
            if state_t >= windup_time:
                _strike(dist)
        State.STRIKE:
            if state_t >= 0.15:
                _tint(BASE_COLOR)
                _set_state(State.RECOVER)
        State.RECOVER:
            if state_t >= recover_time:
                _set_state(State.CHASE)
        State.STAGGER:
            if state_t >= 0.45:
                _set_state(State.CHASE)
    velocity.x = move.x
    velocity.z = move.z
    if is_on_floor():
        velocity.y = -0.1
    else:
        velocity.y -= GRAVITY * delta
    move_and_slide()

func _aggro() -> void:
    _set_state(State.CHASE)
    GameState.add_threat(self)

func _deaggro() -> void:
    _set_state(State.IDLE)
    GameState.remove_threat(self)

func _strike(dist: float) -> void:
    _set_state(State.STRIKE)
    if dist <= attack_range + 0.5:
        player.take_damage(damage, self)

func take_damage(amount: float, _from: Node3D = null) -> void:
    if state == State.DEAD:
        return
    hp -= amount
    if hp <= 0.0:
        _die()
        return
    if state == State.IDLE:
        _set_state(State.CHASE)
        GameState.add_threat(self)
    if amount >= 25.0:
        _tint(BASE_COLOR)
        _set_state(State.STAGGER)

func _die() -> void:
    hp = 0.0
    _set_state(State.DEAD)
    remove_from_group("enemies")
    col.set_deferred("disabled", true)
    GameState.remove_threat(self)
    died.emit(self)
    var tw := create_tween()
    tw.tween_property(model, "rotation:x", -PI / 2.0, 0.5)
    sprite.scale.y = 0.2
    sprite.position.y = 0.2
    await get_tree().create_timer(2.5).timeout
    queue_free()
