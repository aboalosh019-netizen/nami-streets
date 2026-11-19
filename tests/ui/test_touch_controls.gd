extends Node2D

var _ticks: int = 0
var _finished: bool = false

var _all_buttons_mapped: bool = false
var _gas_pressed_seen: bool = false
var _multi_touch_both_active: bool = false
var _gear_after_shift: int = 0
var _min_rot_during_multitouch: float = 0.0
var _max_vx_seen: float = 0.0
var _active_after_disable: int = -1
var _input_gas_after_disable: bool = true

@onready var controls: Control = $CanvasLayer/TouchControls
@onready var bike: RigidBody2D = $Bike


func _ready() -> void:
    process_physics_priority = -20
    if not controls.has_method("get_controls_state"):
        print("[TOUCH CONTROLS TEST FAIL] TouchControls script missing")
        _finished = true
        get_tree().quit(1)
        return

    var st: Dictionary = controls.get_controls_state()
    _all_buttons_mapped = (
        int(st["button_count"]) == 8
        and controls.get_button_for_action("bike_gas") != null
        and controls.get_button_for_action("bike_lean_back") != null
        and controls.get_button_for_action("bike_shift_up") != null
    )


func _send_touch(action_name: String, index: int, pressed: bool) -> void:
    var btn: Button = controls.get_button_for_action(action_name)
    if btn == null:
        return
    var ev := InputEventScreenTouch.new()
    ev.index = index
    ev.pressed = pressed
    ev.position = Vector2(10.0, 10.0)
    btn.gui_input.emit(ev)


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1
    _max_vx_seen = maxf(_max_vx_seen, bike.linear_velocity.x)

    # Tick 20: Press Gas button via button_down
    if _ticks == 20:
        var gas_btn: Button = controls.get_button_for_action("bike_gas")
        gas_btn.button_down.emit()
        _gas_pressed_seen = Input.is_action_pressed("bike_gas")

    # Tick 45: Release Gas via button_up, then start Multi-Touch (finger 0 = Gas, finger 1 = Lean Back)
    if _ticks == 45:
        controls.get_button_for_action("bike_gas").button_up.emit()
        _send_touch("bike_gas", 0, true)
        _send_touch("bike_lean_back", 1, true)
        var active: Array = controls.get_active_actions()
        _multi_touch_both_active = (
            active.has("bike_gas")
            and active.has("bike_lean_back")
            and Input.is_action_pressed("bike_gas")
            and Input.is_action_pressed("bike_lean_back")
        )

    if _ticks >= 45 and _ticks <= 95:
        _min_rot_during_multitouch = minf(_min_rot_during_multitouch, bike.rotation)

    # Tick 75: Tap Shift Up with finger 2 while keeping Gas + Lean Back held
    if _ticks == 75:
        _send_touch("bike_shift_up", 2, true)
    if _ticks == 77:
        _send_touch("bike_shift_up", 2, false)
        var ctrl: Node = bike.get_node("BikeController")
        _gear_after_shift = int(ctrl.get("drivetrain").get("current_gear"))

    # Tick 96: Disable controls while fingers are still down -> must release everything cleanly
    if _ticks == 96:
        controls.controls_enabled = false
        _active_after_disable = controls.get_active_actions().size()
        _input_gas_after_disable = Input.is_action_pressed("bike_gas")

    if _ticks >= 110:
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    controls.release_all()

    var checks := {
        "all_8_buttons_mapped": _all_buttons_mapped,
        "button_down_triggered_gas": _gas_pressed_seen,
        "multitouch_held_two_actions": _multi_touch_both_active,
        "bike_accelerated_via_touch": _max_vx_seen > 150.0,
        "bike_pitched_back_via_multitouch": _min_rot_during_multitouch < -0.10,
        "shift_up_button_changed_gear": _gear_after_shift == 2,
        "disable_released_all_actions": _active_after_disable == 0 and not _input_gas_after_disable
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[TOUCH CONTROLS TEST FAIL] ", key)
            all_ok = false

    print(
        "Touch controls -> max_vx: ", snappedf(_max_vx_seen, 0.1),
        " | min_rot: ", snappedf(_min_rot_during_multitouch, 0.001),
        " | gear: ", _gear_after_shift,
        " | active_after_disable: ", _active_after_disable
    )

    if all_ok:
        print("[TOUCH CONTROLS TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
