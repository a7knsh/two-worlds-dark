class_name Cinema
extends Node
## Tiny cutscene runner. Story scripts await these helpers; pressing E / ESC twice skips,
## after which every helper returns immediately so the script still reaches its end state.

var cam: Camera3D
var hud: Hud
var active := false
var skipped := false
var _armed := false
var _look := Vector3.ZERO
var _move_id := 0

func _init() -> void:
    cam = Camera3D.new()
    cam.far = 400.0
    cam.fov = 55.0

func _ready() -> void:
    add_child(cam)

func begin(skippable := true) -> void:
    active = true
    skipped = false
    _armed = false
    cam.make_current()
    hud.letterbox(true)
    hud.skip_label.text = "[E] skip" if skippable else ""
    set_meta("skippable", skippable)

func end(back_to: Camera3D) -> void:
    active = false
    if back_to:
        back_to.make_current()
    hud.letterbox(false)
    hud.clear_narration()
    hud.subtitle("", "")

func _input(event: InputEvent) -> void:
    if not active or not get_meta("skippable", true) or event.is_echo():
        return
    if event.is_action_pressed("interact") or event.is_action_pressed("pause"):
        if _armed:
            skipped = true
            hud.skip_label.text = ""
        else:
            _armed = true
            hud.skip_label.text = "Press again to skip"

func wait(t: float) -> void:
    var e := 0.0
    while e < t and not skipped:
        await get_tree().process_frame
        e += get_process_delta_time()

func say(speaker: String, text: String, t: float) -> void:
    if skipped:
        return
    hud.subtitle(speaker, text)
    await wait(t)
    hud.subtitle("", "")

func narrate(text: String, t: float) -> void:
    if skipped:
        return
    hud.narration(text, t)
    await wait(t)

func shot(pos: Vector3, look: Vector3) -> void:
    _move_id += 1
    _place(pos, look)

func _place(pos: Vector3, look: Vector3) -> void:
    cam.global_position = pos
    _look = look
    cam.look_at(look)

func move(pos: Vector3, look: Vector3, t: float) -> void:
    var p0 := cam.global_position
    var l0 := _look
    _move_id += 1
    var my_id := _move_id
    if skipped:
        _place(pos, look)
        return
    var e := 0.0
    while e < t and not skipped:
        await get_tree().process_frame
        if my_id != _move_id:
            return
        e += get_process_delta_time()
        var k := clampf(e / t, 0.0, 1.0)
        k = k * k * (3.0 - 2.0 * k)
        cam.global_position = p0.lerp(pos, k)
        _look = l0.lerp(look, k)
        cam.look_at(_look)
    if my_id == _move_id:
        _place(pos, look)

## Fire-and-forget camera move (does not block the script).
func drift(pos: Vector3, look: Vector3, t: float) -> void:
    move(pos, look, t)
