extends SceneTree

const BikePhysicsConfigScript = preload("res://src/bike/physics/bike_physics_config.gd")
const WheelSuspensionScript = preload("res://src/bike/physics/wheel_suspension.gd")

var _failed: bool = false


func _initialize() -> void:
    call_deferred("_run_test")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        print("[SUSPENSION TEST FAIL] ", message)
        _failed = true


func _run_test() -> void:
    var cfg = BikePhysicsConfigScript.new()
    var wheel = WheelSuspensionScript.new()
    wheel.configure(
        "front",
        cfg.front_wheel_offset,
        cfg.front_wheel_radius,
        cfg.front_rest_length,
        cfg.front_stiffness,
        cfg.front_compression_damping,
        cfg.front_rebound_damping
    )

    var dt := 1.0 / 60.0

    # 1. Airborne state
    var air_force: float = wheel.update_from_hit(false, wheel.get_max_ray_length(), Vector2.ZERO, Vector2.UP, 0.0, dt)
    _expect(not wheel.is_grounded, "Wheel should not be grounded in air")
    _expect(is_equal_approx(air_force, 0.0), "Air force must be 0")
    _expect(is_equal_approx(wheel.compression, 0.0), "Air compression must be 0")

    # 2. Static equilibrium (compression = 5.0 px over 2 ticks -> zero compression velocity)
    var dist_5px: float = wheel.wheel_radius + (wheel.rest_length - 5.0)
    wheel.update_from_hit(true, dist_5px, Vector2(0.0, dist_5px), Vector2.UP, 140.0, dt)
    var static_force: float = wheel.update_from_hit(true, dist_5px, Vector2(0.0, dist_5px), Vector2.UP, 140.0, dt)
    var expected_static: float = 5.0 * cfg.front_stiffness
    _expect(wheel.is_grounded, "Wheel should be grounded")
    _expect(is_equal_approx(wheel.compression, 5.0), "Compression should be 5.0")
    _expect(is_equal_approx(wheel.compression_velocity, 0.0), "Static compression velocity should be 0")
    _expect(is_equal_approx(static_force, expected_static), "Static force must equal k * x")

    # 3. Active compression (5.0 -> 7.0 px)
    var dist_7px: float = wheel.wheel_radius + (wheel.rest_length - 7.0)
    var comp_force: float = wheel.update_from_hit(true, dist_7px, Vector2(0.0, dist_7px), Vector2.UP, 140.0, dt)
    _expect(wheel.compression_velocity > 0.0, "Compression velocity must be positive")
    _expect(wheel.damping_force > 0.0, "Compression damping force must resist compression")
    _expect(comp_force > wheel.spring_force, "Total force during compression must exceed spring force")

    # 4. Rebound (7.0 -> 5.0 px)
    var reb_force: float = wheel.update_from_hit(true, dist_5px, Vector2(0.0, dist_5px), Vector2.UP, 140.0, dt)
    _expect(wheel.compression_velocity < 0.0, "Rebound velocity must be negative")
    _expect(wheel.damping_force < 0.0, "Rebound damping must oppose extension")
    _expect(reb_force < wheel.spring_force and reb_force >= 0.0, "Rebound force must be damped and non-negative")

    # 5. Extreme rebound must never pull bike into ground (total_force >= 0)
    var dist_1px: float = wheel.wheel_radius + (wheel.rest_length - 1.0)
    var fast_reb_force: float = wheel.update_from_hit(true, dist_1px, Vector2(0.0, dist_1px), Vector2.UP, 140.0, dt)
    _expect(fast_reb_force >= 0.0, "Suspension force must never be negative")

    # 6. Wheel angular velocity check (v = 140 px/s, r = 14 px -> w = 10 rad/s)
    _expect(is_equal_approx(wheel.wheel_angular_velocity, 10.0), "Wheel angular velocity must equal v / r")

    if _failed:
        quit(1)
    else:
        print("[SUSPENSION MATH TEST OK]")
        print("Static force: ", static_force, " | Comp force: ", comp_force, " | Rebound force: ", reb_force)
        quit(0)
