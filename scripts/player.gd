class_name Player
extends CharacterBody3D

signal hp_changed(hp: float, max_hp: float)
signal stamina_changed(stamina: float, max_stamina: float)
signal died

enum State { FREE, ROLL, ATTACK, STAGGER, DEAD }

const GRAVITY := 24.0
const ROLL_COST := 18.0
const LIGHT_COST := 12.0
const HEAVY_COST := 28.0
const ROLL_TIME := 0.45
const IFRAME_TIME := 0.28

var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var state := State.FREE
var state_t := 0.0
var invulnerable := false
var facing := Vector3(0, 0, -1)
var move_dir := Vector3.ZERO
var roll_dir := Vector3.ZERO
var knock := Vector3.ZERO
var rig: CameraRig
var lock_target: Enemy

var attack_damage := 0.0
var attack_dur := 0.0
var attack_hit_at := 0.0
var attack_hit_done := false
var _regen_delay := 0.0

var sprite: Sprite3D
var model: Node3D

func _ready() -> void:
    add_to_group("player")
    collision_layer = 2
    collision_mask = 1 | 4
    add_child(Visuals.capsule_collision())
    sprite = Visuals.make_sprite(Visuals.humanoid_texture(
        Color(0.25, 0.28, 0.42), Color(0.14, 0.14, 0.2), Color(0.8, 0.65, 0.55), Color(0.8, 0.8, 0.85)))
    add_child(sprite)
    var m := Visuals.make_model(Color(0.3, 0.33, 0.45))
    model = m["node"]
    add_child(model)
    GameState.visual_mode_changed.connect(_on_visual_mode)
    _on_visual_mode(GameState.visual_combat)

func _on_visual_mode(combat: bool) -> void:
    sprite.visible = not combat
    model.visible = combat

func lock_valid() -> bool:
    return lock_target != null and is_instance_valid(lock_target) and lock_target.hp > 0.0

func acquire_lock() -> void:
    var best: Enemy = null
    var best_d := 14.0
    for e: Node in get_tree().get_nodes_in_group("enemies"):
        var en := e as Enemy
        if en == null or en.hp <= 0.0:
            continue
        var d := global_position.distance_to(en.global_position)
        if d < best_d:
            best_d = d
            best = en
    lock_target = best

func toggle_lock() -> void:
    if lock_valid():
        lock_target = null
    else:
        acquire_lock()

func _set_state(s: State) -> void:
    state = s
    state_t = 0.0

func _spend(cost: float) -> void:
    stamina = maxf(0.0, stamina - cost)
    _regen_delay = 0.7
    stamina_changed.emit(stamina, max_stamina)

func _physics_process(delta: float) -> void:
    state_t += delta
    var combat := GameState.mode == GameState.Mode.COMBAT
    if state != State.DEAD:
        _regen(delta)
    match state:
        State.FREE:
            _tick_free(combat)
        State.ROLL:
            _tick_roll()
        State.ATTACK:
            _tick_attack()
        State.STAGGER:
            velocity.x = knock.x * (1.0 - state_t / 0.35)
            velocity.z = knock.z * (1.0 - state_t / 0.35)
            if state_t >= 0.35:
                _set_state(State.FREE)
        State.DEAD:
            velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
            velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
    if is_on_floor():
        velocity.y = -0.1
    else:
        velocity.y -= GRAVITY * delta
    move_and_slide()
    _update_visuals(delta)

func _regen(delta: float) -> void:
    if _regen_delay > 0.0:
        _regen_delay -= delta
    elif state == State.FREE and stamina < max_stamina:
        stamina = minf(max_stamina, stamina + 30.0 * delta)
        stamina_changed.emit(stamina, max_stamina)

func _tick_free(combat: bool) -> void:
    var inp := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var yaw := rig.yaw if rig != null else 0.0
    var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(inp.x, 0.0, inp.y)
    move_dir = dir
    var spd := 5.2 if combat else 4.5
    velocity.x = dir.x * spd
    velocity.z = dir.z * spd
    if combat and lock_valid():
        var to := lock_target.global_position - global_position
        to.y = 0.0
        if to.length() > 0.01:
            facing = to.normalized()
    elif dir.length() > 0.1:
        facing = dir.normalized()
    if Input.is_action_just_pressed("lock_on"):
        toggle_lock()
    if Input.is_action_just_pressed("roll") and stamina > 0.0:
        _start_roll()
    elif Input.is_action_just_pressed("attack") and stamina > 0.0:
        _start_attack(false)
    elif Input.is_action_just_pressed("heavy_attack") and stamina > 0.0:
        _start_attack(true)

func _start_roll() -> void:
    _spend(ROLL_COST)
    if move_dir.length() > 0.1:
        roll_dir = move_dir.normalized()
        facing = roll_dir
    else:
        roll_dir = -facing
    invulnerable = true
    _set_state(State.ROLL)

func _tick_roll() -> void:
    var k := 1.0 - state_t / ROLL_TIME
    velocity.x = roll_dir.x * 10.5 * (0.35 + 0.65 * k)
    velocity.z = roll_dir.z * 10.5 * (0.35 + 0.65 * k)
    invulnerable = state_t < IFRAME_TIME
    if state_t >= ROLL_TIME:
        invulnerable = false
        _set_state(State.FREE)

func _start_attack(heavy: bool) -> void:
    _spend(HEAVY_COST if heavy else LIGHT_COST)
    attack_damage = 42.0 if heavy else 22.0
    attack_dur = 0.95 if heavy else 0.55
    attack_hit_at = 0.5 if heavy else 0.22
    attack_hit_done = false
    _set_state(State.ATTACK)

func _tick_attack() -> void:
    var lunge := 2.2 if state_t < attack_hit_at else 0.0
    velocity.x = facing.x * lunge
    velocity.z = facing.z * lunge
    if not attack_hit_done and state_t >= attack_hit_at:
        attack_hit_done = true
        _do_hit()
        _punch()
    if state_t > attack_dur * 0.7 and Input.is_action_just_pressed("roll") and stamina > 0.0:
        _start_roll()
        return
    if state_t >= attack_dur:
        _set_state(State.FREE)

func _do_hit() -> void:
    for e: Node in get_tree().get_nodes_in_group("enemies"):
        var en := e as Enemy
        if en == null:
            continue
        var to := en.global_position - global_position
        to.y = 0.0
        var d := to.length()
        if d < 2.4 and (d < 0.05 or facing.dot(to / d) > 0.2):
            en.take_damage(attack_damage, self)

func take_damage(amount: float, from: Node3D = null) -> bool:
    if state == State.DEAD or invulnerable:
        return false
    hp = maxf(0.0, hp - amount)
    hp_changed.emit(hp, max_hp)
    if hp <= 0.0:
        _set_state(State.DEAD)
        var tw := create_tween()
        tw.tween_property(model, "rotation:x", -PI / 2.0, 0.5)
        sprite.scale.y = 0.25
        died.emit()
        return true
    if from != null:
        var away := global_position - from.global_position
        away.y = 0.0
        knock = away.normalized() * 5.0
    _set_state(State.STAGGER)
    return true

func _punch() -> void:
    var v: Node3D = model if model.visible else sprite
    var tw := create_tween()
    v.scale = Vector3(1.25, 0.85, 1.25)
    tw.tween_property(v, "scale", Vector3.ONE, 0.18)

func _update_visuals(delta: float) -> void:
    if state == State.DEAD:
        return
    var target_yaw := atan2(-facing.x, -facing.z)
    model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 1.0 - exp(-18.0 * delta))
    if rig != null:
        var right := Vector3.RIGHT.rotated(Vector3.UP, rig.yaw)
        var side := facing.dot(right)
        if side < -0.2:
            sprite.flip_h = true
        elif side > 0.2:
            sprite.flip_h = false
