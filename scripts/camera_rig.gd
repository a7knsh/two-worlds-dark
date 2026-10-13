class_name CameraRig
extends Node3D
## One camera, two personalities.
## EXPLORE: orthographic, fixed angle, fixed yaw (the "2D" view).
## COMBAT : perspective, behind the player, yaw follows the lock-on target.

var cam: Camera3D
var pivot: Node3D
var target: Node3D
var player: Player
var yaw := 0.0
var mode: GameState.Mode = GameState.Mode.EXPLORE

func _init() -> void:
    pivot = Node3D.new()
    add_child(pivot)
    cam = Camera3D.new()
    cam.far = 200.0
    pivot.add_child(cam)

func _ready() -> void:
    cam.make_current()
    apply_mode(GameState.Mode.EXPLORE)

func apply_mode(m: GameState.Mode) -> void:
    mode = m
    if m == GameState.Mode.EXPLORE:
        cam.projection = Camera3D.PROJECTION_ORTHOGONAL
        cam.size = 11.0
        cam.position = Vector3(0, 0, 25)
        pivot.rotation.x = deg_to_rad(-48.0)
        pivot.position.y = 0.5
    else:
        cam.projection = Camera3D.PROJECTION_PERSPECTIVE
        cam.fov = 70.0
        cam.position = Vector3(0.6, 0, 5.2)
        pivot.rotation.x = deg_to_rad(-16.0)
        pivot.position.y = 1.7

func snap() -> void:
    if target:
        global_position = target.global_position

func _process(delta: float) -> void:
    if target == null:
        return
    global_position = global_position.lerp(target.global_position, 1.0 - exp(-10.0 * delta))
    var desired := 0.0
    var follow_speed := 5.0
    if mode == GameState.Mode.COMBAT:
        if player != null and player.lock_valid():
            var to := player.lock_target.global_position - target.global_position
            to.y = 0.0
            if to.length() > 0.1:
                var f := to.normalized()
                desired = atan2(-f.x, -f.z)
                follow_speed = 7.0
        else:
            desired = yaw
    yaw = lerp_angle(yaw, desired, 1.0 - exp(-follow_speed * delta))
    rotation.y = yaw
