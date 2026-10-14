class_name CameraRig
extends Node3D
## One camera, two personalities - both of them now player controlled.
## EXPLORE: orthographic "2D" view of the Veil. Rotate, tilt and zoom freely; walls between
##          the camera and the player are cut down by Level.update_cutaway().
## COMBAT : perspective, behind the player on a spring arm (never clips into walls).
##          With a lock-on the camera swings to keep the target in view and frames tall foes.
## Controls: mouse (captured) / right stick / arrow keys to rotate and tilt, wheel or +/- to zoom.

const MOUSE_SENS := 0.0035
const KEY_YAW_SPEED := 2.4
const KEY_PITCH_SPEED := 70.0

var cam: Camera3D
var pivot: Node3D
var arm: SpringArm3D
var target: Node3D
var player: Player
var yaw := 0.0
var mode: GameState.Mode = GameState.Mode.EXPLORE
## user-controlled tilt (degrees) and zoom, remembered separately per world
var explore_pitch := -48.0
var combat_pitch := -17.0
var explore_zoom := 1.0
var combat_zoom := 1.0
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
        cam.size = 12.5 * explore_zoom
        arm.collision_mask = 0
        arm.spring_length = 30.0
        arm.position = Vector3.ZERO
        pivot.rotation.x = deg_to_rad(explore_pitch)
        pivot.position.y = 0.5
    else:
        cam.projection = Camera3D.PROJECTION_PERSPECTIVE
        cam.fov = 68.0
        arm.collision_mask = 1
        _len = 5.4 * combat_zoom
        _pitch = combat_pitch
        _pivot_y = 1.75
        arm.spring_length = _len
        arm.position = Vector3(0.55, 0, 0)
        pivot.rotation.x = deg_to_rad(_pitch)
        pivot.position.y = _pivot_y
    rotation.y = yaw

func shake(amount: float) -> void:
    _shake = maxf(_shake, amount)

func snap() -> void:
    if target:
        global_position = target.global_position

## Horizontal direction from the player toward the camera (used to cut away walls).
func back_dir() -> Vector3:
    var b := cam.global_transform.basis.z
    b.y = 0.0
    return b.normalized() if b.length() > 0.01 else Vector3.BACK

func _locked() -> bool:
    return mode == GameState.Mode.COMBAT and player != null and player.lock_valid()

func _rotate(dyaw: float, dpitch: float) -> void:
    if not _locked():
        yaw += dyaw
    if mode == GameState.Mode.EXPLORE:
        explore_pitch = clampf(explore_pitch + dpitch, -80.0, -22.0)
    else:
        combat_pitch = clampf(combat_pitch + dpitch, -60.0, 25.0)

func _zoom(f: float) -> void:
    if mode == GameState.Mode.EXPLORE:
        explore_zoom = clampf(explore_zoom * f, 0.55, 1.8)
    else:
        combat_zoom = clampf(combat_zoom * f, 0.55, 1.7)

func _unhandled_input(event: InputEvent) -> void:
    if target == null or not cam.current:
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var rel := (event as InputEventMouseMotion).relative
        _rotate(-rel.x * MOUSE_SENS, -rel.y * MOUSE_SENS * 57.0)
    elif event is InputEventMouseButton and event.is_pressed():
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(0.9)
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(1.1)

func _process(delta: float) -> void:
    if target == null:
        return
    global_position = global_position.lerp(target.global_position, 1.0 - exp(-10.0 * delta))
    # keyboard + right stick camera control
    if cam.current:
        var kx := Input.get_axis("cam_left", "cam_right")
        var ky := Input.get_axis("cam_down", "cam_up")
        var sx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
        var sy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
        if absf(sx) < 0.15:
            sx = 0.0
        if absf(sy) < 0.15:
            sy = 0.0
        if kx != 0.0 or ky != 0.0 or sx != 0.0 or sy != 0.0:
            _rotate(-(kx + sx) * KEY_YAW_SPEED * delta, (ky - sy) * KEY_PITCH_SPEED * delta)
        if Input.is_action_pressed("zoom_in"):
            _zoom(1.0 - 1.2 * delta)
        elif Input.is_action_pressed("zoom_out"):
            _zoom(1.0 + 1.2 * delta)
    if mode == GameState.Mode.COMBAT:
        var want_pitch := combat_pitch
        var want_len := 5.4 * combat_zoom
        var want_y := 1.75
        if _locked():
            var to := player.lock_target.global_position - target.global_position
            to.y = 0.0
            if to.length() > 0.1:
                var f := to.normalized()
                yaw = lerp_angle(yaw, atan2(-f.x, -f.z), 1.0 - exp(-7.0 * delta))
            # frame tall foes: pull back, raise and tilt up as they get close
            if player.lock_target.lock_height > 2.0:
                want_len = 7.6 * combat_zoom
                want_y = 2.3
                want_pitch = -8.0 + clampf((6.0 - to.length()) * 2.6, 0.0, 16.0)
        var k := 1.0 - exp(-6.0 * delta)
        _pitch = lerpf(_pitch, want_pitch, k)
        _len = lerpf(_len, want_len, k)
        _pivot_y = lerpf(_pivot_y, want_y, k)
        pivot.rotation.x = deg_to_rad(_pitch)
        pivot.position.y = _pivot_y
        arm.spring_length = _len
    else:
        var k2 := 1.0 - exp(-10.0 * delta)
        pivot.rotation.x = lerp_angle(pivot.rotation.x, deg_to_rad(explore_pitch), k2)
        cam.size = lerpf(cam.size, 12.5 * explore_zoom, k2)
    rotation.y = yaw
    if _shake > 0.0:
        _shake = maxf(0.0, _shake - delta * 2.5)
        cam.h_offset = _rng.randf_range(-1, 1) * _shake * 0.25
        cam.v_offset = _rng.randf_range(-1, 1) * _shake * 0.25
    else:
        cam.h_offset = 0.0
        cam.v_offset = 0.0
