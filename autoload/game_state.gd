extends Node
## Global game state: which "mode" we are in (2D-look exploration vs realistic 3D combat).

enum Mode { EXPLORE, COMBAT }

signal mode_changed(mode: Mode)          ## logical change (threat appeared / gone)
signal visual_mode_changed(combat: bool) ## emitted at the middle of the screen transition

const RETURN_DELAY := 1.5

var mode: Mode = Mode.EXPLORE
var visual_combat := false
var threats: Array = []
var _token := 0

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"roll": [KEY_SPACE],
	"attack": [KEY_J],
	"heavy_attack": [KEY_K],
	"lock_on": [KEY_Q],
	"interact": [KEY_E],
}

func _ready() -> void:
	_setup_input()

func _setup_input() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key: int in ACTIONS[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = key as Key
				InputMap.action_add_event(action, ev)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", lmb)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("heavy_attack", rmb)
	_add_joy_button("attack", JOY_BUTTON_X)
	_add_joy_button("heavy_attack", JOY_BUTTON_Y)
	_add_joy_button("roll", JOY_BUTTON_B)
	_add_joy_button("lock_on", JOY_BUTTON_RIGHT_STICK)
	_add_joy_button("interact", JOY_BUTTON_A)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)

func _add_joy_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _add_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

func reset() -> void:
	_token += 1
	threats.clear()
	mode = Mode.EXPLORE
	visual_combat = false

func add_threat(e: Node) -> void:
	if not threats.has(e):
		threats.append(e)
	_update()

func remove_threat(e: Node) -> void:
	threats.erase(e)
	_update()

func _update() -> void:
	threats = threats.filter(func(t: Variant) -> bool: return is_instance_valid(t))
	_token += 1
	if threats.size() > 0:
		_set_mode(Mode.COMBAT)
	else:
		var tok := _token
		await get_tree().create_timer(RETURN_DELAY).timeout
		if tok == _token and threats.is_empty():
			_set_mode(Mode.EXPLORE)

func _set_mode(m: Mode) -> void:
	if m != mode:
		mode = m
		mode_changed.emit(m)

func apply_visual(combat: bool) -> void:
	visual_combat = combat
	visual_mode_changed.emit(combat)
