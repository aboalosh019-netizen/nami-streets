extends SceneTree

const BikePhysicsConfigScript = preload("res://src/bike/physics/bike_physics_config.gd")
const BikeBalanceScript = preload("res://src/bike/physics/bike_balance.gd")

var _failed: bool = false


func _initialize() -> void:
    call_deferred("_run_test")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        print("[BIKE BALANCE TEST FAIL] ", message)
        _failed = true


func _run_test() -> void:
    var cfg = BikePhysicsConfigScript.new()
    var balance = BikeBalanceScript.new()
    balance.configure(
        cfg.restoring_torque_strength,
        cfg.balance_angular_damping,
        cfg.air_angular_damping,
        cfg.max_stable_angle_rad
    )

    # 1. Level ground, zero tilt, zero angular velocity -> zero torque
    var t_level: float = balance.compute_torque(0.0, 0.0, true, true, Vector2.UP, Vector2.UP, 0.0)
    _expect(is_equal_approx(t_level, 0.0), "Level balanced bike should produce 0 torque")
    _expect(balance.is_stable, "Level bike must be stable")

    # 2. Tilted forward (+0.3 rad) on level ground -> negative restoring torque pulls back toward 0
    var t_tilt_pos: float = balance.compute_torque(0.3, 0.0, true, true, Vector2.UP, Vector2.UP, 0.0)
    _expect(t_tilt_pos < 0.0, "Positive tilt must produce negative restoring torque")
    _expect(balance.is_stable, "0.3 rad tilt must remain inside stable range")

    # 3. Tilted backward (-0.3 rad) -> positive restoring torque
    var t_tilt_neg: float = balance.compute_torque(-0.3, 0.0, true, true, Vector2.UP, Vector2.UP, 0.0)
    _expect(t_tilt_neg > 0.0, "Negative tilt must produce positive restoring torque")
    _expect(is_equal_approx(t_tilt_neg, -t_tilt_pos), "Restoring torque must be symmetric")

    # 4. Single wheel contact applies gentler restoring torque than two wheels (preserves wheelie feel)
    var t_single: float = balance.compute_torque(-0.3, 0.0, false, true, Vector2.UP, Vector2.UP, 0.0)
    _expect(t_single > 0.0 and t_single < t_tilt_neg, "Single wheel restoring torque must be weaker than two wheels")

    # 5. Airborne applies damping only, no restoring torque
    var t_air: float = balance.compute_torque(0.5, 2.0, false, false, Vector2.UP, Vector2.UP, 100.0)
    _expect(is_equal_approx(balance.last_restoring_torque, 0.0), "Airborne restoring torque must be 0")
    _expect(t_air < 0.0, "Airborne damping must oppose positive angular velocity")

    # 6. Slope alignment (normal rotated +0.25 rad -> target angle ~ +0.25 rad)
    var slope_normal := Vector2.UP.rotated(0.25)
    var t_slope_aligned: float = balance.compute_torque(0.25, 0.0, true, true, slope_normal, slope_normal, 50.0)
    _expect(absf(t_slope_aligned) < 1.0, "Bike aligned with slope should have near-zero restoring torque")

    # 7. Speed stability increases angular damping at higher speed
    var t_damp_slow: float = balance.compute_torque(0.0, 1.0, true, true, Vector2.UP, Vector2.UP, 0.0)
    var t_damp_fast: float = balance.compute_torque(0.0, 1.0, true, true, Vector2.UP, Vector2.UP, 200.0)
    _expect(absf(t_damp_fast) > absf(t_damp_slow), "Higher speed should increase angular damping stability")

    # 8. Over-tilted bike flagged unstable
    balance.compute_torque(1.5, 0.0, true, true, Vector2.UP, Vector2.UP, 0.0)
    _expect(not balance.is_stable, "Tilt beyond max_stable_angle_rad must set is_stable = false")

    if _failed:
        quit(1)
    else:
        print("[BIKE BALANCE TEST OK]")
        print("Tilt torque: ", t_tilt_pos, " | Single-wheel: ", t_single, " | Air damp: ", t_air)
        quit(0)
