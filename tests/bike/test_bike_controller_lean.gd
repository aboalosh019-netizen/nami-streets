extends Node2D

var _ticks: int = 0
var _finished: bool = false

var _rot_lean_back: float = 0.0
var _front_comp_back: float = 0.0
var _rear_comp_back: float = 0.0

var _rot_recovered_after_back: float = 0.0

var _rot_lean_forward: float = 0.0
var _front_comp_fwd: float = 0.0
var _rear_comp_fwd: float = 0.0

var _rot_recovered_after_fwd: float = 0.0

var _min_rot_launch: float = 0.0
var _min_front_comp_launch: float = INF
var _max_rear_comp_launch: float = 0.0

@onready var bike: RigidBody2D = $Bike
@onready var controller: Node = $Bike/BikeController


func _ready() -> void:
    process_physics_priority = -20
    if not bike.has_method("get_telemetry") or not controller.has_method("get_controller_state"):
        print("[CONTROLLER LEAN TEST FAIL] Missing BikePhysicsBody or BikeController methods")
        _finished = true
        get_tree().quit(1)


func _release_all_inputs() -> void:
    Input.action_release("bike_gas")
    Input.action_release("bike_brake")
    Input.action_release("bike_front_brake")
    Input.action_release("bike_lean_back")
    Input.action_release("bike_lean_forward")
    Input.action_release("bike_clutch")
    Input.action_release("bike_shift_up")
    Input.action_release("bike_shift_down")


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    # Ticks 1..40: settle on ground
    if _ticks == 41:
        Input.action_press("bike_lean_back")

    if _ticks == 80:
        var t_back: Dictionary = bike.get_telemetry()
        _rot_lean_back = float(t_back["rotation"])
        _front_comp_back = float(t_back["front_compression"])
        _rear_comp_back = float(t_back["rear_compression"])
        Input.action_release("bike_lean_back")

    # Ticks 81..120: recover to level
    if _ticks == 120:
        _rot_recovered_after_back = bike.rotation
        Input.action_press("bike_lean_forward")

    # Ticks 121..160: lean forward
    if _ticks == 160:
        var t_fwd: Dictionary = bike.get_telemetry()
        _rot_lean_forward = float(t_fwd["rotation"])
        _front_comp_fwd = float(t_fwd["front_compression"])
        _rear_comp_fwd = float(t_fwd["rear_compression"])
        Input.action_release("bike_lean_forward")

    # Ticks 161..200: recover to level
    if _ticks == 200:
        _rot_recovered_after_fwd = bike.rotation
        Input.action_press("bike_gas")
        Input.action_press("bike_lean_back")

    # Ticks 201..245: combined gas + lean_back (dynamic pitch / wheelie shift)
    if _ticks >= 201 and _ticks <= 245:
        var t_launch: Dictionary = bike.get_telemetry()
        _min_rot_launch = minf(_min_rot_launch, float(t_launch["rotation"]))
        _min_front_comp_launch = minf(_min_front_comp_launch, float(t_launch["front_compression"]))
        _max_rear_comp_launch = maxf(_max_rear_comp_launch, float(t_launch["rear_compression"]))

    if _ticks == 246:
        Input.action_release("bike_gas")
        Input.action_release("bike_lean_back")

    # Ticks 246..310: settle back down while coasting
    if _ticks >= 310:
        _release_all_inputs()
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var t_final: Dictionary = bike.get_telemetry()
    var final_rot: float = float(t_final["rotation"])

    var checks := {
        "lean_back_tilts_negative": _rot_lean_back < -0.04,
        "lean_back_shifts_weight_rear": _rear_comp_back > _front_comp_back + 1.5,
        "recovered_after_lean_back": absf(_rot_recovered_after_back) < 0.03,
        "lean_forward_tilts_positive": _rot_lean_forward > 0.04,
        "lean_forward_shifts_weight_front": _front_comp_fwd > _rear_comp_fwd + 1.5,
        "recovered_after_lean_forward": absf(_rot_recovered_after_fwd) < 0.03,
        "gas_plus_lean_pitches_deeper": _min_rot_launch < _rot_lean_back - 0.04,
        "gas_plus_lean_unloads_front": _min_front_comp_launch < _front_comp_back - 1.0,
        "gas_plus_lean_loads_rear": _max_rear_comp_launch > _rear_comp_back + 0.5,
        "did_not_flip_over": _min_rot_launch > -1.2,
        "recovered_after_launch": absf(final_rot) < 0.08,
        "both_wheels_grounded_final": t_final["front_grounded"] == true and t_final["rear_grounded"] == true,
        "is_stable_final": t_final["is_stable"] == true,
        "no_nan": not is_nan(bike.global_position.x) and not is_nan(bike.global_position.y) and not is_nan(bike.rotation)
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[CONTROLLER LEAN TEST FAIL] ", key)
            all_ok = false

    print(
        "Lean telemetry -> back_rot: ", snappedf(_rot_lean_back, 0.001),
        " (f/r: ", snappedf(_front_comp_back, 0.01), "/", snappedf(_rear_comp_back, 0.01), ")",
        " | fwd_rot: ", snappedf(_rot_lean_forward, 0.001),
        " (f/r: ", snappedf(_front_comp_fwd, 0.01), "/", snappedf(_rear_comp_fwd, 0.01), ")",
        " | launch_min_rot: ", snappedf(_min_rot_launch, 0.001),
        " | final_rot: ", snappedf(final_rot, 0.001)
    )

    if all_ok:
        print("[BIKE CONTROLLER LEAN TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
