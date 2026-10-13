class_name Enemy
extends Foe
## Data-driven regular enemy (husk, brute). Telegraphs every attack: the weapon flares red
## during the windup, tracking stops shortly before the swing so a well-timed roll beats it.

signal died(enemy: Enemy)

enum State { DORMANT, RISE, IDLE, CHASE, ATTACK, STAGGER, DEAD }

const GRAVITY := 24.0

const TYPES := {
    "husk": {
        "build": "husk", "weapon": "rusty_blade", "scale": 1.0, "hp": 60.0, "speed": 2.7, "aggro": 9.0,
        "leash": 20.0, "poise": 22.0, "radius": 0.35, "hit_radius": 0.35,
        "attacks": [
            {"anim": "husk_swing", "windup": 0.72, "dur": 1.55, "dmg": 17.0, "range": 2.1, "arc": 0.35, "lunge": 2.5, "trigger": 2.0,
                "poses": [{"arm_r": Vector3(165, 0, 20), "fore_r": Vector3(30, 0, 0), "hand_r": Vector3(0, 0, 0), "chest": Vector3(14, 0, 0), "spine": Vector3(-5, 0, 0)},
                    {"arm_r": Vector3(80, 0, 10), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-60, 0, 0), "chest": Vector3(-15, 0, 0), "spine": Vector3(-20, 0, 0), "lift": Vector3(0, -0.06, 0)},
                    {"arm_r": Vector3(40, 0, 10), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-70, 0, 0), "chest": Vector3(-25, 0, 0), "spine": Vector3(-25, 0, 0), "lift": Vector3(0, -0.1, 0)}]},
            {"anim": "husk_lunge", "windup": 0.6, "dur": 1.45, "dmg": 14.0, "range": 1.9, "arc": 0.5, "lunge": 7.5, "trigger": 3.6,
                "poses": [{"arm_r": Vector3(15, 0, 20), "fore_r": Vector3(110, 0, 0), "hand_r": Vector3(-70, 0, 0), "chest": Vector3(0, -30, 0), "lift": Vector3(0, -0.1, 0), "thigh_l": Vector3(40, 0, 0), "shin_l": Vector3(-50, 0, 0)},
                    {"arm_r": Vector3(90, 0, 0), "fore_r": Vector3(5, 0, 0), "hand_r": Vector3(-90, 0, 0), "chest": Vector3(0, 15, 0), "spine": Vector3(-25, 0, 0), "thigh_l": Vector3(50, 0, 0), "thigh_r": Vector3(-30, 0, 0)},
                    {"arm_r": Vector3(85, 0, 0), "fore_r": Vector3(0, 0, 0), "hand_r": Vector3(-90, 0, 0), "spine": Vector3(-30, 0, 0), "lift": Vector3(0, -0.12, 0), "thigh_l": Vector3(50, 0, 0), "thigh_r": Vector3(-30, 0, 0)}]},
        ],
    },
    "brute": {
        "build": "brute", "weapon": "great_club", "scale": 1.3, "hp": 190.0, "speed": 2.1, "aggro": 10.0,
        "leash": 22.0, "poise": 70.0, "radius": 0.55, "hit_radius": 0.6,
        "attacks": [
            {"anim": "brute_smash", "windup": 1.15, "dur": 2.2, "dmg": 34.0, "range": 3.0, "arc": 0.45, "lunge": 2.0, "trigger": 2.9, "heavy": true, "ring": 2.6,
                "poses": [{"arm_r": Vector3(172, 0, 12), "arm_l": Vector3(168, 0, -12), "fore_r": Vector3(25, 0, 0), "fore_l": Vector3(35, 0, 0), "hand_r": Vector3(0, 0, 0), "chest": Vector3(20, 0, 0), "spine": Vector3(8, 0, 0), "lift": Vector3(0, 0.04, 0)},
                    {"arm_r": Vector3(90, 0, 5), "arm_l": Vector3(90, 0, -5), "fore_r": Vector3(10, 0, 0), "fore_l": Vector3(15, 0, 0), "hand_r": Vector3(-60, 0, 0), "chest": Vector3(-20, 0, 0), "spine": Vector3(-15, 0, 0)},
                    {"arm_r": Vector3(42, 0, 5), "arm_l": Vector3(42, 0, -5), "fore_r": Vector3(5, 0, 0), "fore_l": Vector3(10, 0, 0), "hand_r": Vector3(-75, 0, 0), "chest": Vector3(-30, 0, 0), "spine": Vector3(-25, 0, 0), "lift": Vector3(0, -0.18, 0), "thigh_l": Vector3(40, 0, 0), "shin_l": Vector3(-40, 0, 0)}]},
            {"anim": "brute_sweep", "windup": 0.85, "dur": 1.8, "dmg": 26.0, "range": 3.2, "arc": -0.25, "lunge": 1.5, "trigger": 3.0, "heavy": true,
                "poses": [{"arm_r": Vector3(80, -70, 0), "arm_l": Vector3(80, -45, 0), "fore_r": Vector3(20, 0, 0), "hand_r": Vector3(-80, 0, 0), "chest": Vector3(0, -50, 0), "lift": Vector3(0, -0.05, 0)},
                    {"arm_r": Vector3(85, 0, 0), "arm_l": Vector3(85, 20, 0), "fore_r": Vector3(5, 0, 0), "hand_r": Vector3(-85, 0, 0), "chest": Vector3(0, 0, 0)},
                    {"arm_r": Vector3(80, 70, 0), "arm_l": Vector3(80, 85, 0), "fore_r": Vector3(15, 0, 0), "hand_r": Vector3(-75, 0, 0), "chest": Vector3(0, 50, 0), "lift": Vector3(0, -0.05, 0)}]},
        ],
    },
}

var kind := "husk"
var t: Dictionary
var speed := 2.7
var aggro_range := 9.0
var leash := 20.0
var max_poise := 22.0
var poise := 22.0
var home := Vector3.ZERO
var state := State.IDLE
var state_t := 0.0
var cooldown := 0.0
var atk: Dictionary = {}
var _hit_done := false
var _strafe := 1.0
var player: Player
var hum: Humanoid
var col: CollisionShape3D
var dormant := false
var facing_yaw := 0.0
var tag := ""

static func spawn(p_kind: String, p_dormant := false) -> Enemy:
    var e := Enemy.new()
    e.kind = p_kind
    e.dormant = p_dormant
    return e

func _ready() -> void:
    add_to_group("enemies")
    t = TYPES[kind]
    collision_layer = 4
    collision_mask = 1 | 2 | 4
    floor_snap_length = 0.35
    max_hp = t["hp"]
    hp = max_hp
    speed = t["speed"]
    aggro_range = t["aggro"]
    leash = t["leash"]
    max_poise = t["poise"]
    poise = max_poise
    hit_radius = t["hit_radius"]
    var sc: float = t["scale"]
    hit_height = sc
    lock_height = 1.25 * sc
    col = CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = t["radius"]
    shape.height = 1.7 * sc
    col.shape = shape
    col.position.y = 0.85 * sc
    add_child(col)
    for a: Dictionary in t["attacks"]:
        Humanoid.make_attack(a["anim"], a["poses"], (a["windup"] as float) / (a["dur"] as float))
    hum = Humanoid.create(t["build"], t["weapon"], sc)
    hum.trail_color = Color(1.0, 0.35, 0.2, 0.45)
    add_child(hum)
    _strafe = 1.0 if randf() < 0.5 else -1.0
    facing_yaw = randf() * TAU
    if dormant:
        state = State.DORMANT
        hum.play("lie", 1.0, 0.0)
        col.disabled = true
        remove_from_group("enemies")

func lockable() -> bool:
    return is_alive() and state != State.DORMANT and state != State.RISE

func wake(delay := 0.0) -> void:
    if state != State.DORMANT:
        return
    if delay > 0.0:
        await get_tree().create_timer(delay).timeout
    _set_state(State.RISE)
    add_to_group("enemies")
    col.disabled = false
    hum.play("rise", 1.8, 0.0)
    Sfx.play("growl", -6.0, 1.3)
    Fx.ash(global_position + Vector3(0, 0.3, 0), 20, Color(0.5, 0.48, 0.45))

func _set_state(s: State) -> void:
    state = s
    state_t = 0.0

func _face_dir() -> Vector3:
    return Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))

func _turn_towards(dir: Vector3, rate: float, delta: float) -> void:
    if dir.length() < 0.01:
        return
    var target := atan2(-dir.x, -dir.z)
    var diff := wrapf(target - facing_yaw, -PI, PI)
    facing_yaw += clampf(diff, -rate * delta, rate * delta)

func _physics_process(delta: float) -> void:
    if state == State.DEAD or state == State.DORMANT:
        if state == State.DORMANT:
            hum.face_yaw = facing_yaw
        return
    if player == null or not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player") as Player
        if player == null:
            return
    state_t += delta
    cooldown -= delta
    var to := player.global_position - global_position
    to.y = 0.0
    var dist := to.length()
    var dir := to / dist if dist > 0.001 else Vector3.ZERO
    var move := Vector3.ZERO
    var player_ok := player.state != Player.State.DEAD and player.state != Player.State.LOCKED
    match state:
        State.RISE:
            if state_t >= 1.8:
                _aggro()
        State.IDLE:
            if dist < aggro_range and player_ok and absf(player.global_position.y - global_position.y) < 2.5:
                _aggro()
        State.CHASE:
            if not player_ok or dist > leash or global_position.distance_to(home) > leash:
                _deaggro()
            else:
                _turn_towards(dir, 4.5, delta)
                var pick := _pick_attack(dist)
                if not pick.is_empty() and cooldown <= 0.0:
                    _start_attack(pick)
                elif dist > 1.7:
                    move = _face_dir() * speed if _face_dir().dot(dir) > 0.5 else Vector3.ZERO
                elif cooldown > 0.0:
                    # circle while waiting for an opening
                    move = dir.cross(Vector3.UP) * _strafe * speed * 0.45
        State.ATTACK:
            _tick_attack(dir, dist, delta)
            return
        State.STAGGER:
            var k := maxf(0.0, 1.0 - state_t / 0.3)
            velocity.x = -_face_dir().x * 2.0 * k
            velocity.z = -_face_dir().z * 2.0 * k
            if state_t >= (0.9 if kind == "brute" else 0.6):
                _set_state(State.CHASE)
                cooldown = 0.2
            _finish_move(delta, true)
            return
    if state == State.IDLE and global_position.distance_to(home) > 0.6:
        var back := home - global_position
        back.y = 0.0
        _turn_towards(back, 3.0, delta)
        move = back.normalized() * speed * 0.6
    # keep enemies from stacking on top of each other
    for o: Node in get_tree().get_nodes_in_group("enemies"):
        if o != self and o is Enemy:
            var away := global_position - (o as Enemy).global_position
            away.y = 0.0
            if away.length() < 1.3 and away.length() > 0.01:
                move += away.normalized() * (1.3 - away.length()) * 2.5
    velocity.x = move.x
    velocity.z = move.z
    _finish_move(delta, false)

func _finish_move(delta: float, keep_xz: bool) -> void:
    if not keep_xz:
        pass
    if is_on_floor():
        velocity.y = -0.1
    else:
        velocity.y -= GRAVITY * delta
    move_and_slide()
    hum.velocity = velocity
    hum.move_speed = Vector2(velocity.x, velocity.z).length() if state == State.CHASE or state == State.IDLE else 0.0
    hum.face_yaw = facing_yaw

func _pick_attack(dist: float) -> Dictionary:
    var options: Array = []
    for a: Dictionary in t["attacks"]:
        if dist <= (a["trigger"] as float):
            options.append(a)
    if options.is_empty():
        return {}
    # prefer the lunge when slightly out of swing range
    if kind == "husk" and dist > 2.1:
        return t["attacks"][1]
    return options[randi() % options.size()]

func _start_attack(a: Dictionary) -> void:
    atk = a
    _hit_done = false
    _set_state(State.ATTACK)
    hum.play(a["anim"], a["dur"], 0.12)
    if kind == "brute":
        Sfx.play("growl", -8.0, 0.9)

func _tick_attack(dir: Vector3, dist: float, delta: float) -> void:
    var windup: float = atk["windup"]
    var dur: float = atk["dur"]
    # track the player until shortly before the swing
    if state_t < windup * 0.75:
        _turn_towards(dir, 5.0, delta)
    hum.glow_amount = clampf(state_t / windup, 0.0, 1.0) if state_t < windup + 0.05 else 0.0
    var move := Vector3.ZERO
    if state_t > windup - 0.12 and state_t < windup + 0.12:
        move = _face_dir() * (atk["lunge"] as float)
        if dist < 1.0:
            move = Vector3.ZERO
    hum.trail_on = state_t > windup - 0.1 and state_t < windup + 0.12
    if not _hit_done and state_t >= windup:
        _hit_done = true
        Sfx.play("swing_big" if kind == "brute" else "swing", -6.0, 0.8)
        var to := player.global_position - global_position
        to.y = 0.0
        var d := to.length()
        var arc_ok := d < 0.6 or _face_dir().dot(to / maxf(d, 0.001)) > (atk["arc"] as float)
        if d <= (atk["range"] as float) + 0.35 and arc_ok and absf(player.global_position.y - global_position.y) < 1.5:
            player.take_damage(atk["dmg"], self, atk.get("heavy", false))
        if atk.has("ring"):
            var p := global_position + _face_dir() * 2.0
            Fx.ring(p, atk["ring"], Color(1.0, 0.55, 0.3, 0.8), 0.4)
            Fx.ash(p, 14, Color(0.4, 0.35, 0.3))
            Sfx.play("slam", -6.0)
            if player.rig:
                player.rig.shake(0.25)
    velocity.x = move.x
    velocity.z = move.z
    if state_t >= dur:
        hum.trail_on = false
        _set_state(State.CHASE)
        cooldown = randf_range(0.5, 1.4)
        _strafe = -_strafe
    _finish_move(delta, true)

func _aggro() -> void:
    _set_state(State.CHASE)
    GameState.add_threat(self)
    cooldown = randf_range(0.2, 0.8)

func _deaggro() -> void:
    _set_state(State.IDLE)
    hum.glow_amount = 0.0
    GameState.remove_threat(self)

func take_damage(amount: float, from: Node3D = null, poise_dmg := 0.0) -> void:
    if state == State.DEAD or state == State.DORMANT:
        return
    hp -= amount
    hum.flash(Color(1.0, 0.25, 0.15), 0.9)
    if hp <= 0.0:
        _die()
        return
    if state == State.IDLE or state == State.RISE:
        if state == State.IDLE:
            _aggro()
    poise -= poise_dmg
    if poise <= 0.0 and state != State.RISE:
        poise = max_poise
        hum.glow_amount = 0.0
        hum.trail_on = false
        _set_state(State.STAGGER)
        hum.play("stagger" if kind == "brute" else "hurt", 0.9 if kind == "brute" else 0.6, 0.04)
        if from != null:
            var to := from.global_position - global_position
            to.y = 0.0
            if to.length() > 0.01:
                facing_yaw = atan2(-to.x, -to.z)

func _process(delta: float) -> void:
    if state != State.DEAD and state != State.STAGGER:
        poise = minf(max_poise, poise + max_poise * 0.25 * delta)

func _die() -> void:
    hp = 0.0
    _set_state(State.DEAD)
    remove_from_group("enemies")
    col.set_deferred("disabled", true)
    hum.glow_amount = 0.0
    hum.trail_on = false
    GameState.remove_threat(self)
    died.emit(self)
    hum.play("death", 1.3, 0.05)
    Sfx.play("growl", -10.0, 0.7)
    await get_tree().create_timer(2.2).timeout
    if not is_inside_tree():
        return
    Fx.ash(global_position + Vector3(0, 0.4, 0), 36)
    Sfx.play("ash", -10.0)
    var tw := create_tween()
    tw.tween_property(hum, "position:y", -1.2, 1.4)
    tw.tween_callback(queue_free)
