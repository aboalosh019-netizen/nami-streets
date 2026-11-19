class_name TouchControls
extends Control

signal touch_action_pressed(action_name: String)
signal touch_action_released(action_name: String)

const BUTTON_ACTION_MAP: Dictionary = {
    "LeftCluster/LeanBackButton": "bike_lean_back",
    "LeftCluster/LeanForwardButton": "bike_lean_forward",
    "LeftCluster/ShiftUpButton": "bike_shift_up",
    "LeftCluster/ShiftDownButton": "bike_shift_down",
    "LeftCluster/ClutchButton": "bike_clutch",
    "RightCluster/GasButton": "bike_gas",
    "RightCluster/RearBrakeButton": "bike_brake",
    "RightCluster/FrontBrakeButton": "bike_front_brake"
}

@export var controls_enabled: bool = true:
    set(value):
        controls_enabled = value
        if not controls_enabled:
            release_all()

var _button_nodes: Dictionary = {}
var _active_actions: Dictionary = {}
var _touch_index_to_action: Dictionary = {}


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _bind_buttons()


func _exit_tree() -> void:
    release_all()


func _notification(what: int) -> void:
    if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
        release_all()


func _bind_buttons() -> void:
    _button_nodes.clear()
    for rel_path in BUTTON_ACTION_MAP.keys():
        var action_name: String = str(BUTTON_ACTION_MAP[rel_path])
        var btn: Button = get_node_or_null(rel_path) as Button
        if btn == null:
            continue

        btn.focus_mode = Control.FOCUS_NONE
        _button_nodes[action_name] = btn

        btn.button_down.connect(_on_button_down.bind(action_name))
        btn.button_up.connect(_on_button_up.bind(action_name))
        btn.gui_input.connect(_on_button_gui_input.bind(action_name))


func _on_button_down(action_name: String) -> void:
    press_action(action_name)


func _on_button_up(action_name: String) -> void:
    release_action(action_name)


func _on_button_gui_input(event: InputEvent, action_name: String) -> void:
    if not (event is InputEventScreenTouch):
        return

    var touch := event as InputEventScreenTouch
    if touch.pressed:
        _touch_index_to_action[touch.index] = action_name
        press_action(action_name)
    else:
        if _touch_index_to_action.has(touch.index):
            var bound_action: String = str(_touch_index_to_action[touch.index])
            _touch_index_to_action.erase(touch.index)
            release_action(bound_action)
        else:
            release_action(action_name)


func press_action(action_name: String) -> void:
    if not controls_enabled or not visible:
        return
    if action_name.is_empty():
        return
    if _active_actions.get(action_name, false):
        return

    _active_actions[action_name] = true
    Input.action_press(action_name)
    touch_action_pressed.emit(action_name)


func release_action(action_name: String) -> void:
    if action_name.is_empty():
        return
    if not _active_actions.get(action_name, false):
        return

    _active_actions.erase(action_name)
    Input.action_release(action_name)
    touch_action_released.emit(action_name)


func release_all() -> void:
    _touch_index_to_action.clear()
    var keys: Array = _active_actions.keys()
    for action_name in keys:
        release_action(str(action_name))


func get_button_for_action(action_name: String) -> Button:
    return _button_nodes.get(action_name, null) as Button


func get_active_actions() -> Array:
    var list: Array = _active_actions.keys()
    list.sort()
    return list


func get_controls_state() -> Dictionary:
    return {
        "enabled": controls_enabled,
        "visible": visible,
        "button_count": _button_nodes.size(),
        "active_actions": get_active_actions(),
        "active_touch_count": _touch_index_to_action.size()
    }
