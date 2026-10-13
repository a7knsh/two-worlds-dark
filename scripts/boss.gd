class_name Boss
extends Foe
## MORVAITH, THE PALE WARDEN - keeper of the Sundered Gate.
## Phase 1: cleave, sweep, thrust, leap slam.  Phase 2 (below 50%): the Flesh consumes him -
## faster, red, adds a three-hit combo and a blood nova (kneels, chest burns red, then explodes).
## Turns slowly, so getting behind him is rewarded; heavy damage breaks his poise.

signal defeated
signal phase_changed(phase: int)
signal health_changed(hp: float, max_hp: float)

enum State { DORMANT, IDLE, CHASE, ATTACK, STAGGER, PHASE, DEAD }

const GRAVITY := 24.0
const SCALE := 2.2
const ARENA_CENTER := Vector3(0, 2, -63)
const ARENA_RADIUS := 13.5

const ATTACKS := {
    "cleave": {"anim": "w_cleave", "dur": 2.0, "track": 0.62, "hits": [{"t": 0.9, "dmg": 34.0, "range": 4.4, "arc": 0.35, "ring": 3.0, "heavy": true}],
        "moves": [[0.72, 0.95, 4.5]]},
    "sweep": {"anim": "w_sweep", "dur": 1.75, "track": 0.5, "hits": [{"t": 0.78, "dmg": 27.0, "range": 4.8, "arc": -0.3}],
        "moves": [[0.62, 0.85, 3.5]]},
    "thrust": {"anim": "w_thrust", "dur": 1.9, "track": 0.62, "hits": [{"t": 0.84, "dmg": 30.0, "range": 3.4, "arc": 0.6, "heavy": true},
        {"t": 1.0, "dmg": 30.0, "range": 3.4, "arc": 0.6, "heavy": true}], "moves": [[0.74, 1.05, 14.0]]},
    "leap": {"anim": "w_leap", "dur": 2.5, "track": 0.5, "leap": [0.55, 1.3], "hits": [{"t": 1.3, "dmg": 40.0, "aoe": 4.2, "ring": 4.6, "heavy": true}],
        "moves": []},
    "combo": {"anim": "w_combo", "dur": 3.0, "track": 0.5, "hits": [{"t": 0.7, "dmg": 24.0, "range": 4.8, "arc": -0.3},
        {"t": 1.35, "dmg": 24.0, "range": 4.8, "arc": -0.3}, {"t": 2.2, "dmg": 34.0, "range": 4.4, "arc": 0.35, "ring": 3.0, "heavy": true}],
        "moves": [[0.55, 0.8, 3.5], [1.2, 1.4, 3.5], [2.0, 2.25, 4.5]]},
    "nova": {"anim": "w_nova", "dur": 2.9, "track": 0.0, "nova": 1.35, "hits": [{"t": 1.35, "dmg": 42.0, "aoe": 7.0, "ring": 7.5, "heavy": true}],
        "moves": []},
}

var state := State.DORMANT
var state_t := 0.0
var phase := 1
var poise := 160.0
var max_poise := 160.0
var speed_mult := 1.0
var cooldown := 0.0
var facing_yaw := 0.0
var player: Player
var hum: Humanoid
var col: CollisionShape3D
var atk_name := ""
var atk: Dictionary = {}
var atk_t := 0.0
var _hits_done := 0
var _last := ""
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _nova_disc: MeshInstance3D
var _since_nova := 0
var _flinch := false

func _ready() -> void:
    add_to_group("boss")
    max_hp = 650.0
    hp = max_hp
    hit_radius = 1.0
    hit_height = SCALE
    lock_height = 2.9
    collision_layer = 4
    collision_mask = 1 | 2
    floor_snap_length = 0.4
    col = CollisionShape3D.new()
    var sh := CapsuleShape3D.new()
    sh.radius = 0.85
    sh.height = 3.8
    col.shape = sh
    col.position.y = 1.9
    add_child(col)
    _register_anims()
    hum = Humanoid.create("warden", "warden_sword", SCALE)
    hum.trail_color = Color(0.7, 0.82, 1.0, 0.6)
    hum.glow_color = Color(1.0, 0.3, 0.12)
    add_child(hum)
    hum.play("kneel", 1.0, 0.0)
    facing_yaw = 0.0

static func _register_anims() -> void:
    var kneel := {"thigh_r": Vector3(90, 0, 6), "shin_r": Vector3(-90, 0, 0), "thigh_l": Vector3(-8, 0, -6), "shin_l": Vector3(-95, 0, 0),
        "lift": Vector3(0, -0.42, 0), "spine": Vector3(-20, 0, 0)}
    var over := {"arm_r": Vector3(175, 0, 10), "arm_l": Vector3(168, 0, -12), "fore_r": Vector3(15, 0, 0), "fore_l": Vector3(30, 0, 0),
        "hand_r": Vector3(-5, 0, 0), "chest": Vector3(18, 0, 0), "spine": Vector3(8, 0, 0), "head": Vector3(-10, 0, 0)}
    var down := {"arm_r": Vector3(50, 0, 5), "arm_l": Vector3(48, 0, -8), "fore_r": Vector3(5, 0, 0), "fore_l": Vector3(15, 0, 0),
        "hand_r": Vector3(-78, 0, 0), "chest": Vector3(-25, 0, 0), "spine": Vector3(-22, 0, 0), "lift": Vector3(0, -0.2, 0),
        "thigh_l": Vector3(50, 0, 0), "shin_l": Vector3(-55, 0, 0), "thigh_r": Vector3(-25, 0, 0), "shin_r": Vector3(-30, 0, 0)}
    var sw_r := {"arm_r": Vector3(80, -70, 0), "fore_r": Vector3(20, 0, 0), "hand_r": Vector3(-80, 0, 0), "chest": Vector3(0, -50, 0),
        "head": Vector3(0, 35, 0), "arm_l": Vector3(40, 0, -40), "lift": Vector3(0, -0.06, 0)}
    var sw_mid := {"arm_r": Vector3(88, 0, 0), "fore_r": Vector3(5, 0, 0), "hand_r": Vector3(-86, 0, 0), "chest": Vector3(0, 0, 0), "arm_l": Vector3(30, 0, -50)}
    var sw_l := {"arm_r": Vector3(82, 70, 0), "fore_r": Vector3(20, 0, 0), "hand_r": Vector3(-76, 0, 0), "chest": Vector3(0, 50, 0),
        "head": Vector3(0, -35, 0), "arm_l": Vector3(20, 0, -55), "lift": Vector3(0, -0.06, 0)}
    Humanoid.make_attack("w_cleave", [over, {"arm_r": Vector3(100, 0, 5), "arm_l": Vector3(98, 0, -5), "hand_r": Vector3(-60, 0, 0), "chest": Vector3(-10, 0, 0)}, down], 0.45)
    Humanoid.make_attack("w_sweep", [sw_r, sw_mid, sw_l], 0.78 / 1.75)
    Humanoid.make_attack("w_thrust", [{"arm_r": Vector3(10, 0, 25), "fore_r": Vector3(105, 0, 0), "hand_r": Vector3(-80, 0, 0), "chest": Vector3(0, -35, 0),
            "lift": Vector3(0, -0.15, 0), "thigh_l": Vector3(45, 0, 0), "shin_l": Vector3(-60, 0, 0), "thigh_r": Vector3(-20, 0, 0), "arm_l": Vector3(60, 0, -30)},
        {"arm_r": Vector3(90, 0, 0), "fore_r": Vector3(0, 0, 0), "hand_r": Vector3(-90, 0, 0), "chest": Vector3(0, 20, 0), "spine": Vector3(-25, 0, 0),
            "thigh_l": Vector3(55, 0, 0), "shin_l": Vector3(-40, 0, 0), "thigh_r": Vector3(-35, 0, 0), "arm_l": Vector3(20, 0, -50)},
        {"arm_r": Vector3(88, 0, 0), "fore_r": Vector3(0, 0, 0), "hand_r": Vector3(-90, 0, 0), "chest": Vector3(0, 20, 0), "spine": Vector3(-28, 0, 0),
            "thigh_l": Vector3(55, 0, 0), "shin_l": Vector3(-40, 0, 0), "thigh_r": Vector3(-35, 0, 0), "arm_l": Vector3(20, 0, -50), "lift": Vector3(0, -0.12, 0)}], 0.84 / 1.9)
    var crouch := {"lift": Vector3(0, -0.32, 0), "thigh_l": Vector3(65, 0, 0), "shin_l": Vector3(-100, 0, 0), "thigh_r": Vector3(55, 0, 0),
        "shin_r": Vector3(-95, 0, 0), "spine": Vector3(-30, 0, 0), "arm_r": Vector3(-20, 0, 20), "arm_l": Vector3(-20, 0, -20), "hand_r": Vector3(-20, 0, 0)}
    var air := over.merged({"thigh_l": Vector3(60, 0, 0), "shin_l": Vector3(-80, 0, 0), "thigh_r": Vector3(30, 0, 0), "shin_r": Vector3(-70, 0, 0)}, true)
    Humanoid.make_anim("w_leap", [[0.0, {}], [0.18, crouch], [0.24, crouch], [0.33, air], [0.48, air], [0.52, down], [0.75, down], [1.0, {}]])
    var gather := kneel.merged({"arm_r": Vector3(70, 50, 0), "arm_l": Vector3(70, -50, 0), "fore_r": Vector3(60, 0, 0), "fore_l": Vector3(60, 0, 0),
        "hand_r": Vector3(-30, 0, 0), "head": Vector3(-30, 0, 0), "spine": Vector3(-30, 0, 0)}, true)
    var burst := {"arm_r": Vector3(100, 0, 85), "arm_l": Vector3(100, 0, -85), "fore_r": Vector3(5, 0, 0), "fore_l": Vector3(5, 0, 0),
        "chest": Vector3(28, 0, 0), "spine": Vector3(12, 0, 0), "head": Vector3(32, 0, 0), "lift": Vector3(0, 0.02, 0), "hand_r": Vector3(-40, 0, 0)}
    Humanoid.make_anim("w_nova", [[0.0, {}], [0.25, gather], [0.44, gather], [0.47, burst], [0.75, burst], [1.0, {}]])
    Humanoid.make_anim("w_combo", [[0.0, {}], [0.17, sw_r], [0.233, sw_mid], [0.3, sw_l], [0.38, sw_l], [0.45, sw_mid], [0.52, sw_r],
        [0.64, over], [0.733, down], [0.86, down], [1.0, {}]])
    Humanoid.make_anim("w_stand", [[0.0, kneel.merged({"head": Vector3(-25, 0, 0), "arm_r": Vector3(40, 0, 6), "fore_r": Vector3(45, 0, 0),
        "hand_r": Vector3(-170, 0, 0)}, true)], [0.6, {"spine": Vector3(5, 0, 0), "head": Vector3(10, 0, 0)}], [1.0, {}]])

func _set_state(s: State) -> void:
    state = s
    state_t = 0.0

func lockable() -> bool:
    return is_alive() and state != State.DORMANT

## Called by the intro cutscene: the Warden rises from his kneel.
func stand() -> void:
    hum.play("w_stand", 1.8, 0.1)

func activate() -> void:
    if state != State.DORMANT and state != State.IDLE:
        return
    add_to_group("enemies")
    _set_state(State.CHASE)
    cooldown = 0.8
    GameState.add_threat(self)

func _face_dir() -> Vector3:
    return Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))

func _turn_towards(dir: Vector3, rate: float, delta: float) -> void:
    if dir.length() < 0.01:
        return
    var target := atan2(-dir.x, -dir.z)
    var diff := wrapf(target - facing_yaw, -PI, PI)
    facing_yaw += clampf(diff, -rate * delta, rate * delta)

func _physics_process(delta: float) -> void:
    hum.face_yaw = facing_yaw
    if state == State.DORMANT or state == State.DEAD:
        _gravity(delta)
        return
    if player == null or not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player") as Player
        if player == null:
            return
    state_t += delta
    cooldown -= delta * speed_mult
    var to := player.global_position - global_position
    to.y = 0.0
    var dist := to.length()
    var dir := to / maxf(dist, 0.001)
    var move := Vector3.ZERO
    match state:
        State.IDLE:
            pass
        State.CHASE:
            _turn_towards(dir, (2.2 if phase == 1 else 3.0), delta)
            if player.state == Player.State.DEAD:
                pass
            elif cooldown <= 0.0:
                var pick := _choose(dist, dir)
                if pick != "":
                    _start(pick)
                    return
                if dist > 3.0:
                    move = _face_dir() * (3.0 if phase == 1 else 4.0)
            elif dist > 3.5:
                move = _face_dir() * (3.0 if phase == 1 else 4.0)
        State.ATTACK:
            _tick_attack(delta, dir, dist)
            return
        State.STAGGER:
            if state_t >= 2.2:
                _set_state(State.CHASE)
                cooldown = 0.3
        State.PHASE:
            _tick_phase()
    velocity.x = move.x
    velocity.z = move.z
    hum.move_speed = Vector2(move.x, move.z).length() / SCALE * 1.6
    _gravity(delta)

func _gravity(delta: float) -> void:
    if is_on_floor():
        velocity.y = -0.1
    else:
        velocity.y -= GRAVITY * delta
    if state != State.ATTACK or not atk.has("leap") or atk_t < (atk["leap"][0] as float) or atk_t > (atk["leap"][1] as float):
        move_and_slide()
    _clamp_arena()
    hum.velocity = velocity

func _clamp_arena() -> void:
    var off := global_position - ARENA_CENTER
    off.y = 0.0
    if off.length() > ARENA_RADIUS:
        var p := ARENA_CENTER + off.normalized() * ARENA_RADIUS
        global_position = Vector3(p.x, global_position.y, p.z)

func _choose(dist: float, dir: Vector3) -> String:
    var facing_ok := _face_dir().dot(dir) > 0.55
    var opts: Array = []
    if dist > 9.0:
        opts = ["leap"]
    elif dist > 5.0:
        opts = ["thrust", "leap"] if phase == 2 else ["thrust"]
        if not facing_ok:
            return ""
    else:
        if not facing_ok and dist > 2.2:
            return ""
        opts = ["cleave", "sweep", "sweep"]
        if phase == 2:
            opts += ["combo", "combo"]
            if _since_nova >= 3:
                opts = ["nova"]
    opts = opts.filter(func(o: String) -> bool: return o != _last or opts.size() == 1)
    if opts.is_empty():
        return ""
    return opts[randi() % opts.size()]

func _start(aname: String) -> void:
    atk_name = aname
    atk = ATTACKS[aname]
    atk_t = 0.0
    _hits_done = 0
    _last = aname
    _since_nova = 0 if aname == "nova" else _since_nova + 1
    _set_state(State.ATTACK)
    hum.anim_speed = speed_mult
    hum.play(atk["anim"], atk["dur"], 0.15)
    hum.move_speed = 0.0
    if aname == "nova":
        Sfx.play("growl", -2.0, 0.6)
        _nova_disc = Fx.telegraph(self, 7.0, Color(1.0, 0.1, 0.05, 0.45), (atk["nova"] as float) / speed_mult)
    elif aname == "leap":
        Sfx.play("growl", -4.0, 0.8)

func _tick_attack(delta: float, dir: Vector3, dist: float) -> void:
    atk_t += delta * speed_mult
    var hits: Array = atk["hits"]
    if atk_t < (atk["track"] as float):
        _turn_towards(dir, 3.2 if phase == 1 else 4.2, delta)
    # weapon flares before every blow
    var next_hit := 99.0
    if _hits_done < hits.size():
        next_hit = (hits[_hits_done]["t"] as float) - atk_t
    hum.glow_amount = clampf(1.0 - next_hit / 0.6, 0.0, 1.0) if next_hit < 0.6 else 0.0
    hum.trail_on = next_hit < 0.16 and next_hit > -0.1 or (_hits_done > 0 and atk_t - (hits[_hits_done - 1]["t"] as float) < 0.1)
    var move := Vector3.ZERO
    for m: Array in atk["moves"]:
        if atk_t >= (m[0] as float) and atk_t <= (m[1] as float):
            move = _face_dir() * (m[2] as float) * speed_mult
            if dist < 2.0 and atk_name != "thrust":
                move = Vector3.ZERO
    if atk.has("leap"):
        _tick_leap()
    while _hits_done < hits.size() and atk_t >= (hits[_hits_done]["t"] as float):
        _resolve_hit(hits[_hits_done])
        _hits_done += 1
    velocity.x = move.x
    velocity.z = move.z
    _gravity(delta)
    if atk_t >= (atk["dur"] as float):
        hum.trail_on = false
        hum.glow_amount = 0.0
        hum.anim_speed = 1.0
        _set_state(State.CHASE)
        cooldown = randf_range(0.6, 1.3) if phase == 1 else randf_range(0.25, 0.8)

func _tick_leap() -> void:
    var t0: float = atk["leap"][0]
    var t1: float = atk["leap"][1]
    if atk_t < t0:
        _leap_from = global_position
        var target := player.global_position
        var off := target - ARENA_CENTER
        off.y = 0.0
        if off.length() > ARENA_RADIUS:
            target = ARENA_CENTER + off.normalized() * ARENA_RADIUS
        _leap_to = Vector3(target.x, ARENA_CENTER.y + 0.05, target.z)
        return
    if atk_t <= t1:
        var k := (atk_t - t0) / (t1 - t0)
        var p := _leap_from.lerp(_leap_to, k)
        p.y = lerpf(_leap_from.y, _leap_to.y, k) + sin(k * PI) * 5.0
        global_position = p
        collision_mask = 1
        var d := _leap_to - _leap_from
        d.y = 0.0
        if d.length() > 0.2:
            facing_yaw = atan2(-d.x, -d.z)
    else:
        collision_mask = 1 | 2

func _resolve_hit(h: Dictionary) -> void:
    var heavy: bool = h.get("heavy", false)
    Sfx.play("swing_big", -2.0, 0.65)
    var origin := global_position
    if h.has("ring") and not h.has("aoe"):
        origin = global_position + _face_dir() * 3.0
    if h.has("ring"):
        var c := Color(1.0, 0.15, 0.08, 0.9) if phase == 2 or atk_name == "nova" else Color(0.7, 0.8, 1.0, 0.9)
        Fx.ring(origin, h["ring"], c, 0.5)
        Fx.ash(origin + Vector3(0, 0.2, 0), 30, Color(0.45, 0.4, 0.38))
        Sfx.play("slam", 0.0)
        if player.rig:
            player.rig.shake(0.7)
    if atk_name == "nova":
        Fx.burst(global_position + Vector3(0, 2.0, 0), Color(0.9, 0.08, 0.04), 36, 8.0, 0.045, 0.8, -4.0)
        Sfx.play("roar", -2.0, 1.2)
    var to := player.global_position - global_position
    to.y = 0.0
    var d := to.length()
    var hit := false
    if h.has("aoe"):
        var c2 := player.global_position - origin
        c2.y = 0.0
        hit = c2.length() <= (h["aoe"] as float)
    else:
        var arc_ok := d < 1.2 or _face_dir().dot(to / maxf(d, 0.001)) > (h["arc"] as float)
        hit = d <= (h["range"] as float) + 0.35 and arc_ok
    if hit and absf(player.global_position.y - global_position.y) < 2.5:
        player.take_damage(h["dmg"], self, heavy)

func take_damage(amount: float, _from: Node3D = null, poise_dmg := 0.0) -> void:
    if state == State.DEAD or state == State.DORMANT or state == State.PHASE:
        return
    hp = maxf(0.0, hp - amount)
    health_changed.emit(hp, max_hp)
    hum.flash(Color(1.0, 0.3, 0.2), 0.7)
    if hp <= 0.0:
        _die()
        return
    if phase == 1 and hp <= max_hp * 0.5:
        _begin_phase2()
        return
    poise -= poise_dmg
    if poise <= 0.0 and state != State.ATTACK or poise <= -60.0:
        poise = max_poise
        hum.glow_amount = 0.0
        hum.trail_on = false
        hum.anim_speed = 1.0
        if _nova_disc and is_instance_valid(_nova_disc):
            _nova_disc.queue_free()
        _set_state(State.STAGGER)
        hum.play("stagger", 2.2, 0.05)
        Sfx.play("growl", -2.0, 0.7)

func _process(delta: float) -> void:
    if state != State.STAGGER and state != State.DEAD:
        poise = minf(max_poise, poise + 18.0 * delta)

func _begin_phase2() -> void:
    phase = 2
    speed_mult = 1.22
    hum.glow_amount = 0.0
    hum.trail_on = false
    hum.anim_speed = 1.0
    if _nova_disc and is_instance_valid(_nova_disc):
        _nova_disc.queue_free()
    _set_state(State.PHASE)
    _flinch = false
    hum.play("roar", 2.6, 0.15)
    phase_changed.emit(2)

func _tick_phase() -> void:
    if not _flinch and state_t >= 0.9:
        _flinch = true
        Sfx.play("roar", 2.0, 0.8)
        hum.set_eye_color(Color(1.0, 0.12, 0.05))
        hum.trail_color = Color(1.0, 0.2, 0.1, 0.65)
        _set_rune(Color(1.0, 0.15, 0.05))
        Fx.ring(global_position, 7.0, Color(1.0, 0.1, 0.05, 0.9), 0.6)
        Fx.burst(global_position + Vector3(0, 2.4, 0), Color(0.85, 0.05, 0.03), 40, 7.0, 0.045, 0.9, -6.0)
        if player.rig:
            player.rig.shake(1.0)
        var to := player.global_position - global_position
        to.y = 0.0
        if to.length() < 6.5:
            player.take_damage(8.0, self, true)
    if state_t >= 2.6:
        _set_state(State.CHASE)
        cooldown = 0.2
        _since_nova = 3

func _set_rune(c: Color) -> void:
    if hum.weapon_node == null:
        return
    for n: Node in hum.weapon_node.get_children():
        var mi := n as MeshInstance3D
        if mi and mi.material_override and mi.material_override.has_meta("rune"):
            var m := mi.material_override as StandardMaterial3D
            m.emission = c
            m.emission_energy_multiplier = 3.0

func _die() -> void:
    _set_state(State.DEAD)
    remove_from_group("enemies")
    col.set_deferred("disabled", true)
    hum.glow_amount = 0.0
    hum.trail_on = false
    hum.anim_speed = 1.0
    if _nova_disc and is_instance_valid(_nova_disc):
        _nova_disc.queue_free()
    GameState.remove_threat(self)
    hum.play("death", 3.2, 0.1)
    Sfx.play("roar", 0.0, 0.55)
    defeated.emit()

## Dissolve into ash after the death animation (called by Main once the victory banner shows).
func crumble() -> void:
    for i in 6:
        Fx.ash(global_position + Vector3(randf_range(-1.5, 1.5), 0.5 + i * 0.3, randf_range(-1.5, 1.5)), 40, Color(0.8, 0.82, 0.9))
        await get_tree().create_timer(0.35).timeout
    Sfx.play("ash", -2.0, 0.7)
    var tw := create_tween()
    tw.tween_property(hum, "position:y", -3.0, 2.5)
    tw.tween_callback(queue_free)
