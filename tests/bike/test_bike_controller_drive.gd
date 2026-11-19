extends Node2D

var _ticks: int = 0
var _finished: bool = false

var _speed_after_gear1: float = 0.0
var _gear_after_shift_up: int = -1
var _speed_after_gear2: float = 0.0
var _drive_force_during_clutch: float = -1.0
var _gear_after_shift_down: int = -1
var _speed_before_rear_brake: float = 0.0
var _speed_after_rear_brake: float = 0.0
var _speed_before_front_brake: float = 0.0
var _speed_after_front_brake: float = 0.0
var _front_comp_during_front_brake: float = 0.0
var _rear_comp_during_front_brake: float = 0.0
var _max_abs_rot: float = 0.0

@onready var bike: RigidBody2D = $Bike
@onready var controller: Node = $Bike/BikeController


func _ready() -> void:
    process_physics_priority = -20
    if not bike.has_method("get_telemetry") or not controller.has_method("get_controller_state"):
        print("[CONTROLLER DRIVE TEST FAIL] Missing BikePhysicsBody or BikeController methods")
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
    _max_abs_rot = maxf(_max_abs_rot, absf(bike.rotation))

    # Ticks 1..50: settle on ground
    if _ticks == 51:
        Input.action_press("bike_gas")

    # Tick 111: record gear 1 speed and press shift up
    if _ticks == 111:
        _speed_after_gear1 = bike.linear_velocity.x
        Input.action_press("bike_shift_up")

    if _ticks == 112:
        Input.action_release("bike_shift_up")

    if _ticks == 113:
        var state_up: Dictionary = controller.get_controller_state()
        _gear_after_shift_up = int(state_up["gear"])

    # Tick 171: record gear 2 speed and pull clutch
    if _ticks == 171:
        _speed_after_gear2 = bike.linear_velocity.x
        Input.action_press("bike_clutch")

    if _ticks == 195:
        var state_clutch: Dictionary = controller.get_controller_state()
        _drive_force_during_clutch = float(state_clutch["drive_force"])

    # Tick 196: release gas & clutch, press shift down, start rear brake
    if _ticks == 196:
        Input.action_release("bike_clutch")
        Input.action_release("bike_gas")
        Input.action_press("bike_shift_down")
        _speed_before_rear_brake = bike.linear_velocity.x
        Input.action_press("bike_brake")

    if _ticks == 197:
        Input.action_release("bike_shift_down")

    if _ticks == 198:
        var state_down: Dictionary = controller.get_controller_state()
        _gear_after_shift_down = int(state_down["gear"])

    # Tick 221: finish rear brake, start front brake
    if _ticks == 221:
        _speed_after_rear_brake = bike.linear_velocity.x
        Input.action_release("bike_brake")
        _speed_before_front_brake = bike.linear_velocity.x
        Input.action_press("bike_front_brake")

    if _ticks == 235:
        var tel_brake: Dictionary = bike.get_telemetry()
        _front_comp_during_front_brake = float(tel_brake["front_compression"])
        _rear_comp_during_front_brake = float(tel_brake["rear_compression"])

    # Tick 251: finish front brake and evaluate
    if _ticks == 251:
        _speed_after_front_brake = bike.linear_velocity.x
        _release_all_inputs()
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var t: Dictionary = bike.get_telemetry()
    var rear_brake_drop: float = _speed_before_rear_brake - _speed_after_rear_brake
    var front_brake_drop: float = _speed_before_front_brake - _speed_after_front_brake

    var checks := {
        "accelerated_in_gear1": _speed_after_gear1 > 120.0,
        "shifted_up_to_gear2": _gear_after_shift_up == 2,
        "accelerated_faster_in_gear2": _speed_after_gear2 > _speed_after_gear1 + 30.0,
        "clutch_cut_drive_force": is_equal_approx(_drive_force_during_clutch, 0.0),
        "shifted_down_to_gear1": _gear_after_shift_down == 1,
        "rear_brake_slowed_bike": rear_brake_drop > 40.0,
        "front_brake_slowed_bike": front_brake_drop > 40.0,
        "front_brake_fork_dive": _front_comp_during_front_brake > _rear_comp_during_front_brake,
        "remained_stable": t["is_stable"] == true and _max_abs_rot < 0.7,
        "both_wheels_grounded": t["front_grounded"] == true and t["rear_grounded"] == true,
        "no_nan": not is_nan(bike.global_position.x) and not is_nan(bike.global_position.y)
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[CONTROLLER DRIVE TEST FAIL] ", key)
            all_ok = false

    print(
        "Drive telemetry -> g1_v: ", snappedf(_speed_after_gear1, 0.1),
        " | g2_v: ", snappedf(_speed_after_gear2, 0.1),
        " | rear_drop: ", snappedf(rear_brake_drop, 0.1),
        " | front_drop: ", snappedf(front_brake_drop, 0.1),
        " | dive_f/r: ", snappedf(_front_comp_during_front_brake, 0.01), "/", snappedf(_rear_comp_during_front_brake, 0.01),
        " | max_rot: ", snappedf(_max_abs_rot, 0.001)
    )

    if all_ok:
        print("[BIKE CONTROLLER DRIVE TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
