class_name Player
extends CharacterBody3D

signal hp_changed(hp: float, max_hp: float)
signal stamina_changed(stamina: float, max_stamina: float)
signal vials_changed(vials: int)
signal died
signal interacted(it: Interactable)

enum State { FREE, ROLL, ATTACK, STAGGER, HEAL, INTERACT, DEAD, LOCKED }

const GRAVITY := 24.0
const ROLL_COST := 18.0
const ROLL_TIME := 0.5
const IFRAME_START := 0.04
const IFRAME_END := 0.34
const HEAL_TIME := 1.15
const HEAL_AMOUNT := 45.0

var max_hp := 100.0
var hp := 100.0
var max_stamina := 100.0
var stamina := 100.0
var vials := 4
var state := State.FREE
var state_t := 0.0
var invulnerable := false
var facing := Vector3(0, 0, -1)
var move_dir := Vector3.ZERO
var roll_dir := Vector3.ZERO
var knock := Vector3.ZERO
var rig: CameraRig
var lock_target: Foe
var hum: Humanoid
var weapon := "fists"
var wstats: Dictionary = {}

var attack_heavy := false
var attack_damage := 0.0
var attack_poise := 0.0
var attack_dur := 0.0
var attack_hit_at := 0.0
var attack_hit_done := false
var _swung := false
var combo := 0
var _buffer := ""
var _buffer_t := 0.0
var _regen_delay := 0.0
var _healed := false
var _stagger_len := 0.35
var _step_t := 0.0
var _lock_marker: Sprite3D
## In cutscenes the story drives the player: walk_to / face.
var script_target := Vector3.INF

func _ready() -> void:
    add_to_group("player")
    collision_layer = 2
    collision_mask = 1 | 4
    floor_snap_length = 0.35
    var cs := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.35
    shape.height = 1.7
    cs.shape = shape
    cs.position.y = 0.85
    add_child(cs)
    vials = get_node("/root/GameState").vials_max
    var gw: String = get_node("/root/GameState").weapon
    hum = Humanoid.create("hunter", "" if gw == "fists" else gw, 1.0, "fang_l" if gw == "twinfangs" else "")
    add_child(hum)
    _set_weapon_stats(gw)
    _lock_marker = Sprite3D.new()
    var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
    for x in 9:
        for y in 9:
            var d := Vector2(x - 4, y - 4).length()
            if d <= 4.2:
                img.set_pixel(x, y, Color(1, 0.95, 0.85, 1.0 if d < 2.4 else 0.55))
    _lock_marker.texture = ImageTexture.create_from_image(img)
    _lock_marker.pixel_size = 0.03
    _lock_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _lock_marker.no_depth_test = true
    _lock_marker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    _lock_marker.top_level = true
    _lock_marker.visible = false
    add_child(_lock_marker)

func equip(id: String) -> void:
    if hum.weapon_id == id or (id == "fists" and hum.weapon_id == ""):
        return
    hum.set_weapon("" if id == "fists" else id, "fang_l" if id == "twinfangs" else "")
    _set_weapon_stats(id)

func _set_weapon_stats(id: String) -> void:
    weapon = id
    wstats = Weapons.stats(id)
    var atk: Dictionary = Weapons.ATTACKS.get(id, Weapons.ATTACKS["fists"])
    Humanoid.make_attack("p_light_a", atk["light_a"], wstats["light_hit"] / wstats["light_dur"])
    Humanoid.make_attack("p_light_b", atk["light_b"], wstats["light_hit"] / wstats["light_dur"])
    Humanoid.make_attack("p_heavy", atk["heavy"], wstats["heavy_hit"] / wstats["heavy_dur"])
    hum.trail_color = wstats["trail"]

func lock_valid() -> bool:
    return lock_target != null and is_instance_valid(lock_target) and lock_target.is_alive()

func acquire_lock() -> void:
    var best: Foe = null
    var best_d := 15.0
    for e: Node in get_tree().get_nodes_in_group("enemies"):
        var en := e as Foe
        if en == null or not en.is_alive() or not en.lockable():
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

func lock_controls(on: bool) -> void:
    if on:
        if state != State.DEAD:
            _set_state(State.LOCKED)
            invulnerable = true
            hum.trail_on = false
    elif state == State.LOCKED:
        invulnerable = false
        script_target = Vector3.INF
        _set_state(State.FREE)
        hum.play("idle", 1.0, 0.2)

func _spend(cost: float) -> void:
    stamina = maxf(0.0, stamina - cost)
    _regen_delay = 0.75
    stamina_changed.emit(stamina, max_stamina)

func _physics_process(delta: float) -> void:
    state_t += delta
    var combat := GameState.mode == GameState.Mode.COMBAT
    if state != State.DEAD:
        _regen(delta)
    if _buffer_t > 0.0:
        _buffer_t -= delta
        if _buffer_t <= 0.0:
            _buffer = ""
    if state in [State.ATTACK, State.ROLL, State.STAGGER, State.HEAL, State.INTERACT]:
        _read_buffer()
    match state:
        State.FREE:
            _tick_free(combat, delta)
        State.ROLL:
            _tick_roll()
        State.ATTACK:
            _tick_attack()
        State.STAGGER:
            var k := maxf(0.0, 1.0 - state_t / _stagger_len)
            velocity.x = knock.x * k
            velocity.z = knock.z * k
            if state_t >= _stagger_len:
                _set_state(State.FREE)
                hum.play("idle", 1.0, 0.15)
        State.HEAL:
            _tick_heal(delta)
        State.INTERACT:
            velocity.x = 0.0
            velocity.z = 0.0
            if state_t >= 0.8:
                _set_state(State.FREE)
        State.LOCKED:
            _tick_scripted(delta)
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
    elif (state == State.FREE or state == State.LOCKED) and stamina < max_stamina:
        stamina = minf(max_stamina, stamina + 34.0 * delta)
        stamina_changed.emit(stamina, max_stamina)

func _read_buffer() -> void:
    if Input.is_action_just_pressed("attack"):
        _buffer = "attack"
        _buffer_t = 0.4
    elif Input.is_action_just_pressed("heavy_attack"):
        _buffer = "heavy"
        _buffer_t = 0.4
    elif Input.is_action_just_pressed("roll"):
        _buffer = "roll"
        _buffer_t = 0.35

func _input_dir() -> Vector3:
    var inp := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var yaw := rig.yaw if rig != null else 0.0
    return Basis(Vector3.UP, yaw) * Vector3(inp.x, 0.0, inp.y)

func _tick_free(combat: bool, delta: float) -> void:
    var dir := _input_dir()
    move_dir = dir
    var spd := 5.0 if combat else 5.4
    velocity.x = dir.x * spd
    velocity.z = dir.z * spd
    if combat and lock_valid():
        var to := lock_target.global_position - global_position
        to.y = 0.0
        if to.length() > 0.01:
            _turn(to, 14.0, delta)
    elif dir.length() > 0.1:
        _turn(dir, 14.0, delta)
    if dir.length() > 0.1:
        _step_t += delta * spd
        if _step_t > 1.4:
            _step_t = 0.0
            Sfx.play("step", -14.0, 1.0, 0.15)
    if Input.is_action_just_pressed("lock_on"):
        toggle_lock()
    var act := _buffer
    _buffer = ""
    if Input.is_action_just_pressed("roll"):
        act = "roll"
    elif Input.is_action_just_pressed("attack"):
        act = "attack"
    elif Input.is_action_just_pressed("heavy_attack"):
        act = "heavy"
    elif Input.is_action_just_pressed("heal"):
        act = "heal"
    elif Input.is_action_just_pressed("interact"):
        act = "interact"
    match act:
        "roll":
            if stamina > 0.0:
                _start_roll()
        "attack":
            if stamina > 0.0:
                _start_attack(false)
        "heavy":
            if stamina > 0.0:
                _start_attack(true)
        "heal":
            _start_heal()
        "interact":
            var it := nearest_interactable()
            if it != null:
                if it.kind in ["altar", "lantern"]:
                    _set_state(State.INTERACT)
                    hum.play("interact", 0.8, 0.1)
                    var to := it.global_position - global_position
                    to.y = 0.0
                    if to.length() > 0.1:
                        facing = to.normalized()
                interacted.emit(it)
                it.activate()

## Smoothly rotate facing toward dir (yaw-based, safe for 180 degree turns).
func _turn(dir: Vector3, rate: float, delta: float) -> void:
    var cur := atan2(-facing.x, -facing.z)
    var target := atan2(-dir.x, -dir.z)
    var y := lerp_angle(cur, target, 1.0 - exp(-rate * delta))
    facing = Vector3(-sin(y), 0.0, -cos(y))

func nearest_interactable() -> Interactable:
    var best: Interactable = null
    var best_d := 99.0
    for n: Node in get_tree().get_nodes_in_group("interactable"):
        var it := n as Interactable
        if it == null or not it.enabled or not it.is_visible_in_tree():
            continue
        var d := Vector2(it.global_position.x - global_position.x, it.global_position.z - global_position.z).length()
        if d < it.radius and d < best_d and absf(it.global_position.y - global_position.y) < 2.0:
            best_d = d
            best = it
    return best

func _start_roll() -> void:
    _spend(ROLL_COST)
    if move_dir.length() > 0.1:
        roll_dir = move_dir.normalized()
        facing = roll_dir
        hum.play("roll", ROLL_TIME, 0.05)
    else:
        roll_dir = -facing
        hum.play("hurt", ROLL_TIME * 0.8, 0.05)
    hum.trail_on = false
    _set_state(State.ROLL)
    Sfx.play("roll", -6.0)

func _tick_roll() -> void:
    var k := 1.0 - state_t / ROLL_TIME
    var spd := 10.0 if roll_dir.dot(facing) > 0.0 else 7.0
    velocity.x = roll_dir.x * spd * (0.3 + 0.7 * k)
    velocity.z = roll_dir.z * spd * (0.3 + 0.7 * k)
    invulnerable = state_t >= IFRAME_START and state_t < IFRAME_END
    if state_t >= ROLL_TIME:
        invulnerable = false
        _set_state(State.FREE)
        if not _try_buffered():
            hum.play("idle", 1.0, 0.12)

func _try_buffered() -> bool:
    if _buffer == "":
        return false
    var b := _buffer
    _buffer = ""
    if stamina <= 0.0:
        return false
    move_dir = _input_dir()
    if move_dir.length() > 0.1 and not lock_valid():
        facing = move_dir.normalized()
    match b:
        "attack":
            _start_attack(false)
        "heavy":
            _start_attack(true)
        "roll":
            _start_roll()
    return true

func _start_attack(heavy: bool) -> void:
    attack_heavy = heavy
    _spend(wstats["heavy_cost"] if heavy else wstats["light_cost"])
    attack_damage = wstats["heavy"] if heavy else wstats["light"]
    attack_poise = wstats["heavy_poise"] if heavy else wstats["poise"]
    attack_dur = wstats["heavy_dur"] if heavy else wstats["light_dur"]
    attack_hit_at = wstats["heavy_hit"] if heavy else wstats["light_hit"]
    attack_hit_done = false
    _swung = false
    var aname := "p_heavy"
    if not heavy:
        aname = "p_light_a" if combo % 2 == 0 else "p_light_b"
        combo += 1
    else:
        combo = 0
    if lock_valid():
        var to := lock_target.global_position - global_position
        to.y = 0.0
        if to.length() > 0.1:
            facing = to.normalized()
    hum.play(aname, attack_dur, 0.06)
    _set_state(State.ATTACK)

func _tick_attack() -> void:
    var lunge := (3.4 if attack_heavy else 2.4) if state_t < attack_hit_at else 0.0
    if state_t < attack_hit_at * 0.6:
        lunge *= 0.4
    velocity.x = facing.x * lunge
    velocity.z = facing.z * lunge
    hum.trail_on = state_t > attack_hit_at - 0.1 and state_t < attack_hit_at + 0.09 and weapon != "fists"
    if not _swung and state_t >= attack_hit_at - 0.08:
        _swung = true
        Sfx.play("swing_big" if attack_heavy or weapon == "greataxe" else "swing", -4.0)
    if not attack_hit_done and state_t >= attack_hit_at:
        attack_hit_done = true
        _do_hit()
    # combo window: chain into the next swing near the end
    if state_t > attack_dur * 0.62 and _buffer != "":
        hum.trail_on = false
        _set_state(State.FREE)
        _try_buffered()
        return
    if state_t >= attack_dur:
        hum.trail_on = false
        combo = 0 if _buffer == "" else combo
        _set_state(State.FREE)
        if not _try_buffered():
            combo = 0
            hum.play("idle", 1.0, 0.15)

func _do_hit() -> void:
    var hit_any := false
    var rng: float = wstats["range"]
    var arc: float = wstats["arc"]
    for e: Node in get_tree().get_nodes_in_group("enemies"):
        var en := e as Foe
        if en == null or not en.is_alive():
            continue
        var to := en.global_position - global_position
        to.y = 0.0
        var d := to.length()
        var reach := rng + en.hit_radius
        if d < reach and (d < 0.5 or facing.dot(to / d) > arc):
            en.take_damage(attack_damage, self, attack_poise)
            hit_any = true
            var hp_pos := en.global_position + Vector3(0, 1.1 * en.hit_height, 0) - to.normalized() * 0.3
            Fx.blood(hp_pos, to.normalized())
            Fx.sparks(hp_pos)
    if hit_any:
        Sfx.play("hit_heavy" if attack_heavy else "hit", -2.0)
        if rig:
            rig.shake(0.35 if attack_heavy else 0.18)
        _hitstop(0.09 if attack_heavy else 0.05)

func _hitstop(dur: float) -> void:
    Engine.time_scale = 0.05
    await get_tree().create_timer(dur, true, false, true).timeout
    if Engine.time_scale < 0.5:
        Engine.time_scale = 1.0

func _start_heal() -> void:
    if vials <= 0 or hp >= max_hp:
        if vials <= 0:
            hum.play("hurt", 0.3, 0.05)
        return
    vials -= 1
    vials_changed.emit(vials)
    _healed = false
    hum.play("heal", HEAL_TIME, 0.1)
    _set_state(State.HEAL)

func _tick_heal(delta: float) -> void:
    var dir := _input_dir()
    velocity.x = dir.x * 1.3
    velocity.z = dir.z * 1.3
    if dir.length() > 0.1 and not lock_valid():
        _turn(dir, 8.0, delta)
    if not _healed and state_t >= HEAL_TIME * 0.55:
        _healed = true
        hp = minf(max_hp, hp + HEAL_AMOUNT)
        hp_changed.emit(hp, max_hp)
        hum.flash(Color(1.0, 0.75, 0.35), 0.9)
        Fx.heal(global_position + Vector3(0, 1.0, 0))
        Sfx.play("heal", -4.0)
    if state_t >= HEAL_TIME:
        _set_state(State.FREE)

func _tick_scripted(delta: float) -> void:
    velocity.x = 0.0
    velocity.z = 0.0
    if script_target != Vector3.INF:
        var to := script_target - global_position
        to.y = 0.0
        if to.length() > 0.15:
            var d := to.normalized()
            velocity.x = d.x * 3.2
            velocity.z = d.z * 3.2
            _turn(d, 10.0, delta)
        else:
            script_target = Vector3.INF

func take_damage(amount: float, from: Node3D = null, heavy := false) -> bool:
    if state == State.DEAD or state == State.LOCKED or invulnerable:
        return false
    hp = maxf(0.0, hp - amount)
    hp_changed.emit(hp, max_hp)
    hum.flash(Color(1.0, 0.1, 0.05), 1.0)
    hum.trail_on = false
    Sfx.play("hurt", -2.0)
    if rig:
        rig.shake(0.5 if heavy else 0.3)
    var away := Vector3.ZERO
    if from != null:
        away = global_position - from.global_position
        away.y = 0.0
        away = away.normalized()
    Fx.blood(global_position + Vector3(0, 1.1, 0), away)
    if hp <= 0.0:
        _set_state(State.DEAD)
        invulnerable = true
        lock_target = null
        hum.play("death", 1.6, 0.08)
        died.emit()
        return true
    knock = away * (7.0 if heavy else 4.5)
    _stagger_len = 0.6 if heavy else 0.35
    hum.play("stagger" if heavy else "hurt", _stagger_len + 0.15, 0.04)
    _set_state(State.STAGGER)
    return true

func refill() -> void:
    hp = max_hp
    stamina = max_stamina
    vials = get_node("/root/GameState").vials_max
    hp_changed.emit(hp, max_hp)
    stamina_changed.emit(stamina, max_stamina)
    vials_changed.emit(vials)

func _update_visuals(delta: float) -> void:
    hum.velocity = velocity
    var hv := Vector2(velocity.x, velocity.z).length()
    hum.move_speed = hv if state == State.FREE or state == State.LOCKED or state == State.HEAL else 0.0
    if state != State.DEAD:
        var target_yaw := atan2(-facing.x, -facing.z)
        hum.face_yaw = lerp_angle(hum.face_yaw, target_yaw, 1.0 - exp(-20.0 * delta))
    if lock_valid() and GameState.visual_combat:
        _lock_marker.visible = true
        _lock_marker.global_position = lock_target.global_position + Vector3(0, lock_target.lock_height, 0)
    else:
        _lock_marker.visible = false
