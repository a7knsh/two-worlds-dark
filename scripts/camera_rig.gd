class_name CameraRig
extends Node3D
## One camera, two personalities.
## EXPLORE: orthographic, fixed angle, fixed yaw (the "2D" view of the Veil).
## COMBAT : perspective, behind the player on a spring arm (never clips into walls).
##          Mouse / right stick turn it; with a lock-on it swings to keep the target in view.

var cam: Camera3D
var pivot: Node3D
var arm: SpringArm3D
var target: Node3D
var player: Player
var yaw := 0.0
var mode: GameState.Mode = GameState.Mode.EXPLORE
var _shake := 0.0
var _pitch := -17.0
var _len := 5.4
var _pivot_y := 1.75
var _rng := RandomNumberGenerator.new()

func _init() -> void:
    pivot = Node3D.new()
    add_child(pivot)
    arm = SpringArm3D.new()
    arm.margin = 0.25
    pivot.add_child(arm)
    var probe := SphereShape3D.new()
    probe.radius = 0.25
    arm.shape = probe
    cam = Camera3D.new()
    cam.far = 400.0
    arm.add_child(cam)

func _ready() -> void:
    cam.make_current()
    apply_mode(GameState.Mode.EXPLORE)

func apply_mode(m: GameState.Mode) -> void:
    mode = m
    if m == GameState.Mode.EXPLORE:
        cam.projection = Camera3D.PROJECTION_ORTHOGONAL
        cam.size = 12.5
        arm.collision_mask = 0
        arm.spring_length = 30.0
        arm.position = Vector3.ZERO
        pivot.rotation.x = deg_to_rad(-48.0)
        pivot.position.y = 0.5
        yaw = 0.0
        rotation.y = 0.0
    else:
        cam.projection = Camera3D.PROJECTION_PERSPECTIVE
        cam.fov = 68.0
        arm.collision_mask = 1
        _len = 5.4
        _pitch = -17.0
        _pivot_y = 1.75
        arm.spring_length = _len
        arm.position = Vector3(0.55, 0, 0)
        pivot.rotation.x = deg_to_rad(_pitch)
        pivot.position.y = _pivot_y
        if player != null:
            yaw = atan2(-player.facing.x, -player.facing.z)
            rotation.y = yaw

func shake(amount: float) -> void:
    _shake = maxf(_shake, amount)

func snap() -> void:
    if target:
        global_position = target.global_position

func _unhandled_input(event: InputEvent) -> void:
    if mode == GameState.Mode.COMBAT and event is InputEventMouseMotion \
            and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        if player == null or not player.lock_valid():
            yaw -= (event as InputEventMouseMotion).relative.x * 0.0035

func _process(delta: float) -> void:
    if target == null:
        return
    global_position = global_position.lerp(target.global_position, 1.0 - exp(-10.0 * delta))
    if mode == GameState.Mode.COMBAT:
        var want_pitch := -17.0
        var want_len := 5.4
        var want_y := 1.75
        if player != null and player.lock_valid():
            var to := player.lock_target.global_position - target.global_position
            to.y = 0.0
            if to.length() > 0.1:
                var f := to.normalized()
                yaw = lerp_angle(yaw, atan2(-f.x, -f.z), 1.0 - exp(-7.0 * delta))
            # frame tall foes: pull back, raise and tilt up as they get close
            if player.lock_target.lock_height > 2.0:
                want_len = 7.6
                want_y = 2.3
                want_pitch = -8.0 + clampf((6.0 - to.length()) * 2.6, 0.0, 16.0)
        var k := 1.0 - exp(-4.0 * delta)
        _pitch = lerpf(_pitch, want_pitch, k)
        _len = lerpf(_len, want_len, k)
        _pivot_y = lerpf(_pivot_y, want_y, k)
        pivot.rotation.x = deg_to_rad(_pitch)
        pivot.position.y = _pivot_y
        arm.spring_length = _len
        if player == null or not player.lock_valid():
            var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
            if absf(stick) > 0.15:
                yaw -= stick * 2.6 * delta
    else:
        yaw = lerp_angle(yaw, 0.0, 1.0 - exp(-6.0 * delta))
    rotation.y = yaw
    if _shake > 0.0:
        _shake = maxf(0.0, _shake - delta * 2.5)
        cam.h_offset = _rng.randf_range(-1, 1) * _shake * 0.25
        cam.v_offset = _rng.randf_range(-1, 1) * _shake * 0.25
    else:
        cam.h_offset = 0.0
        cam.v_offset = 0.0
