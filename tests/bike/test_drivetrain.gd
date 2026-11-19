extends SceneTree

const BikeDrivetrainConfigScript = preload("res://src/bike/systems/bike_drivetrain_config.gd")
const BikeDrivetrainScript = preload("res://src/bike/systems/bike_drivetrain.gd")

var _failed: bool = false


func _initialize() -> void:
    call_deferred("_run_test")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        print("[DRIVETRAIN TEST FAIL] ", message)
        _failed = true


func _run_test() -> void:
    var cfg = BikeDrivetrainConfigScript.new()
    var dt: float = 1.0 / 60.0
    var drive = BikeDrivetrainScript.new(cfg)

    # 1. Throttle response ramps smoothly instead of instant jump
    drive.set_gear(1)
    drive.update(1.0, false, false, false, 0.0, true, dt)
    _expect(drive.throttle > 0.0 and drive.throttle < 1.0, "Throttle must ramp smoothly on first frame")
    for _i in range(30):
        drive.update(1.0, false, false, false, 0.0, true, dt)
    _expect(is_equal_approx(drive.throttle, 1.0), "Throttle should reach 1.0 after ramp")

    # 2. Neutral gear (0) revs engine but produces zero drive force
    drive.set_gear(0)
    var neutral_force: float = 0.0
    for _i in range(40):
        neutral_force = drive.update(1.0, false, false, false, 0.0, true, dt)
    _expect(is_equal_approx(neutral_force, 0.0), "Neutral gear must produce 0 drive force")
    _expect(drive.rpm > cfg.idle_rpm + 2000.0, "Neutral gear must allow free revving")

    # 3. Shifting bounds (0 -> max_gear -> 0)
    var max_g: int = drive.get_max_gear()
    for _i in range(max_g + 3):
        drive.update(0.0, false, true, false, 0.0, true, dt)
    _expect(drive.current_gear == max_g, "Gear must clamp at max gear")

    for _i in range(max_g + 3):
        drive.update(0.0, false, false, true, 0.0, true, dt)
    _expect(drive.current_gear == 0, "Gear must clamp at 0 (Neutral)")

    # 4. Lower gear produces stronger drive force than higher gear
    drive.set_gear(1)
    var f_gear1: float = 0.0
    for _i in range(25):
        f_gear1 = drive.update(1.0, false, false, false, 80.0, true, dt)

    drive.set_gear(3)
    var f_gear3: float = 0.0
    for _i in range(25):
        f_gear3 = drive.update(1.0, false, false, false, 80.0, true, dt)

    _expect(f_gear1 > f_gear3 and f_gear3 > 0.0, "Gear 1 force must exceed Gear 3 force")

    # 5. Clutch disengages drive force while allowing RPM to rise
    drive.set_gear(1)
    var f_clutch: float = 0.0
    for _i in range(25):
        f_clutch = drive.update(1.0, true, false, false, 50.0, true, dt)
    _expect(is_equal_approx(f_clutch, 0.0), "Pulled clutch must cut drive force to 0")
    _expect(drive.clutch_engagement <= 0.05, "Clutch engagement must reach 0 when pulled")

    # 6. Rev limiter cuts drive force at over-rev
    drive.set_gear(1)
    var f_limiter: float = 1.0
    for _i in range(45):
        f_limiter = drive.update(1.0, false, false, false, 260.0, true, dt)
    _expect(drive.is_rev_limiter_active, "Rev limiter must activate when speed overshoots gear 1")
    _expect(is_equal_approx(f_limiter, 0.0), "Rev limiter must cut drive force to 0")

    # 7. Engine braking applies negative force when coasting in gear with zero throttle
    drive.set_gear(2)
    var f_ebrake: float = 0.0
    for _i in range(30):
        f_ebrake = drive.update(0.0, false, false, false, 160.0, true, dt)
    _expect(f_ebrake < 0.0, "Coasting in gear with 0 throttle must apply engine braking")

    if _failed:
        quit(1)
    else:
        print("[DRIVETRAIN TEST OK]")
        print("Gear1 force: ", snappedf(f_gear1, 0.1), " | Gear3 force: ", snappedf(f_gear3, 0.1), " | EBrake: ", snappedf(f_ebrake, 0.1))
        quit(0)
