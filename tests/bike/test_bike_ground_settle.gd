extends Node2D

var _ticks: int = 0
var _finished: bool = false
var _sample_min_y: float = INF
var _sample_max_y: float = -INF
var _sample_max_abs_vy: float = 0.0
var _sample_max_abs_ang_vel: float = 0.0

@onready var bike: RigidBody2D = $Bike


func _ready() -> void:
    if not bike.has_method("get_telemetry"):
        print("[GROUND SETTLE TEST FAIL] BikePhysicsBody script failed to attach")
        _finished = true
        get_tree().quit(1)


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    if _ticks >= 150 and _ticks <= 180:
        var y: float = bike.global_position.y
        _sample_min_y = minf(_sample_min_y, y)
        _sample_max_y = maxf(_sample_max_y, y)
        _sample_max_abs_vy = maxf(_sample_max_abs_vy, absf(bike.linear_velocity.y))
        _sample_max_abs_ang_vel = maxf(_sample_max_abs_ang_vel, absf(bike.angular_velocity))

    if _ticks >= 180:
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var t: Dictionary = bike.get_telemetry()
    var y_jitter: float = _sample_max_y - _sample_min_y

    var checks := {
        "front_grounded": t["front_grounded"] == true,
        "rear_grounded": t["rear_grounded"] == true,
        "front_compression_valid": t["front_compression"] > 1.0 and t["front_compression"] < 13.0,
        "rear_compression_valid": t["rear_compression"] > 1.0 and t["rear_compression"] < 13.0,
        "low_y_jitter": y_jitter < 0.5,
        "low_vertical_speed": _sample_max_abs_vy < 5.0,
        "low_angular_speed": _sample_max_abs_ang_vel < 0.05,
        "near_level_angle": absf(t["rotation"]) < 0.05,
        "is_stable": t["is_stable"] == true,
        "no_nan": not is_nan(bike.global_position.x) and not is_nan(bike.global_position.y) and not is_nan(bike.rotation)
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[GROUND SETTLE TEST FAIL] ", key)
            all_ok = false

    print(
        "Settle telemetry -> pos: ", bike.global_position,
        " | rot: ", snappedf(bike.rotation, 0.0001),
        " | front_comp: ", snappedf(t["front_compression"], 0.01),
        " | rear_comp: ", snappedf(t["rear_compression"], 0.01),
        " | y_jitter: ", snappedf(y_jitter, 0.0001),
        " | max_vy: ", snappedf(_sample_max_abs_vy, 0.001)
    )

    if all_ok:
        print("[BIKE GROUND SETTLE TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
