extends Node2D

const EXPECTED_SLOPE_RAD: float = 0.20

var _ticks: int = 0
var _finished: bool = false

@onready var bike: RigidBody2D = $Bike


func _ready() -> void:
    if not bike.has_method("get_telemetry"):
        print("[SLOPE TEST FAIL] BikePhysicsBody script failed to attach")
        _finished = true
        get_tree().quit(1)


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1
    if _ticks >= 150:
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var t: Dictionary = bike.get_telemetry()
    var expected_normal: Vector2 = Vector2.UP.rotated(EXPECTED_SLOPE_RAD).normalized()
    var front_normal_dot: float = bike.front_wheel.contact_normal.dot(expected_normal)
    var rear_normal_dot: float = bike.rear_wheel.contact_normal.dot(expected_normal)
    var angle_diff: float = absf(bike.rotation - EXPECTED_SLOPE_RAD)

    var checks := {
        "front_grounded": t["front_grounded"] == true,
        "rear_grounded": t["rear_grounded"] == true,
        "front_normal_matches_slope": front_normal_dot > 0.99,
        "rear_normal_matches_slope": rear_normal_dot > 0.99,
        "chassis_aligned_with_slope": angle_diff < 0.08,
        "front_compression_valid": t["front_compression"] > 1.0 and t["front_compression"] < 13.5,
        "rear_compression_valid": t["rear_compression"] > 1.0 and t["rear_compression"] < 13.5,
        "rolled_downhill": bike.global_position.x > 100.0,
        "downhill_velocity": bike.linear_velocity.x > 100.0,
        "front_wheel_spinning": bike.front_wheel.wheel_angular_velocity > 5.0,
        "rear_wheel_spinning": bike.rear_wheel.wheel_angular_velocity > 5.0,
        "is_stable": t["is_stable"] == true,
        "no_nan": not is_nan(bike.global_position.x) and not is_nan(bike.global_position.y) and not is_nan(bike.rotation)
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[SLOPE TEST FAIL] ", key)
            all_ok = false

    print(
        "Slope telemetry -> pos: ", bike.global_position.snapped(Vector2(0.1, 0.1)),
        " | rot: ", snappedf(bike.rotation, 0.001),
        " | vx: ", snappedf(bike.linear_velocity.x, 0.1),
        " | front_comp: ", snappedf(t["front_compression"], 0.01),
        " | rear_comp: ", snappedf(t["rear_compression"], 0.01),
        " | wheel_w: ", snappedf(bike.rear_wheel.wheel_angular_velocity, 0.1)
    )

    if all_ok:
        print("[BIKE SLOPE CONTACT TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
