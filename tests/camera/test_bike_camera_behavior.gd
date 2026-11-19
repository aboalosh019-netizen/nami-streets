extends Node2D

class MockTarget extends Node2D:
    var linear_velocity: Vector2 = Vector2.ZERO

var _target: MockTarget
var _ticks: int = 0
var _finished: bool = false

var _pos_after_snap: Vector2 = Vector2.ZERO
var _pos_after_deadzone: Vector2 = Vector2.ZERO
var _pos_after_step_1_follow: Vector2 = Vector2.ZERO
var _pos_after_settle_follow: Vector2 = Vector2.ZERO
var _look_ahead_at_speed: Vector2 = Vector2.ZERO
var _framing_at_speed: Vector2 = Vector2.ZERO
var _zoom_at_speed: float = 1.0
var _zoom_after_stop: float = 0.0
var _max_shake_x: float = 0.0
var _max_shake_y: float = 0.0
var _saw_nonzero_shake: bool = false
var _shake_trauma_final: float = -1.0
var _shake_offset_final: Vector2 = Vector2.INF

@onready var cam: Camera2D = $BikeCamera


func _ready() -> void:
    _target = MockTarget.new()
    _target.position = Vector2.ZERO
    add_child(_target)

    if not cam.has_method("set_target") or not cam.has_method("get_camera_state"):
        print("[CAMERA BEHAVIOR TEST FAIL] BikeCamera methods missing")
        _finished = true
        get_tree().quit(1)
        return

    cam.set_target(_target, true)
    _pos_after_snap = cam.global_position


func _physics_process(delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    # Ticks 1..20: small movement strictly inside dead zone (14x10)
    if _ticks == 1:
        _target.global_position = Vector2(8.0, 5.0)
        _target.linear_velocity = Vector2.ZERO

    if _ticks == 20:
        _pos_after_deadzone = cam.global_position
        # Jump target outside dead zone to test smooth follow
        _target.global_position = Vector2(120.0, -40.0)
        _target.linear_velocity = Vector2.ZERO

    if _ticks == 22:
        _pos_after_step_1_follow = cam.global_position

    if _ticks == 110:
        _pos_after_settle_follow = cam.global_position
        # Accelerate to high speed (500 px/s)
        _target.linear_velocity = Vector2(500.0, 0.0)

    if _ticks > 110 and _ticks <= 210:
        _target.global_position += _target.linear_velocity * delta

    if _ticks == 210:
        var st_fast: Dictionary = cam.get_camera_state()
        _look_ahead_at_speed = st_fast["look_ahead"]
        _framing_at_speed = st_fast["speed_framing"]
        _zoom_at_speed = float(st_fast["zoom"])
        # Stop target to test zoom return
        _target.linear_velocity = Vector2.ZERO

    if _ticks == 330:
        var st_stop: Dictionary = cam.get_camera_state()
        _zoom_after_stop = float(st_stop["zoom"])
        # Trigger over-clamped shake
        cam.add_shake(2.0)

    if _ticks > 330 and _ticks <= 390:
        var off: Vector2 = cam.offset
        if off.length() > 0.05:
            _saw_nonzero_shake = true
        _max_shake_x = maxf(_max_shake_x, absf(off.x))
        _max_shake_y = maxf(_max_shake_y, absf(off.y))

    if _ticks == 390:
        var st_end: Dictionary = cam.get_camera_state()
        _shake_trauma_final = float(st_end["shake_trauma"])
        _shake_offset_final = cam.offset
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var cfg: Resource = cam.config
    var base_off: Vector2 = cfg.base_offset
    var dead_zone: Vector2 = cfg.dead_zone_half_size
    var max_shake: Vector2 = cfg.max_shake_offset
    var expected_settle := Vector2(120.0 - dead_zone.x, -40.0 + dead_zone.y) + base_off

    var checks := {
        "snap_applies_base_offset": _pos_after_snap.distance_to(base_off) < 0.01,
        "deadzone_holds_camera_still": _pos_after_deadzone.distance_to(_pos_after_snap) < 0.01,
        "smooth_follow_is_gradual": _pos_after_step_1_follow.x > _pos_after_deadzone.x + 2.0 and _pos_after_step_1_follow.x < expected_settle.x - 10.0,
        "smooth_follow_converges": _pos_after_settle_follow.distance_to(expected_settle) < 1.5,
        "look_ahead_leads_at_speed": _look_ahead_at_speed.x > 80.0,
        "speed_framing_expands_ahead": _framing_at_speed.x > 20.0,
        "zoom_pulls_out_at_speed": _zoom_at_speed < float(cfg.base_zoom) - 0.12 and _zoom_at_speed >= float(cfg.min_zoom),
        "zoom_returns_when_stopped": absf(_zoom_after_stop - float(cfg.base_zoom)) < 0.02,
        "shake_was_applied": _saw_nonzero_shake,
        "shake_strictly_bounded": _max_shake_x <= max_shake.x + 0.01 and _max_shake_y <= max_shake.y + 0.01,
        "shake_decays_to_zero": is_equal_approx(_shake_trauma_final, 0.0) and _shake_offset_final.length() < 0.001
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[CAMERA BEHAVIOR TEST FAIL] ", key)
            all_ok = false

    print(
        "Camera behavior -> snap: ", _pos_after_snap,
        " | settle: ", _pos_after_settle_follow.snapped(Vector2(0.1, 0.1)),
        " | look_ahead_x: ", snappedf(_look_ahead_at_speed.x, 0.1),
        " | zoom_fast/stop: ", snappedf(_zoom_at_speed, 0.001), "/", snappedf(_zoom_after_stop, 0.001),
        " | max_shake: (", snappedf(_max_shake_x, 0.01), ", ", snappedf(_max_shake_y, 0.01), ")"
    )

    if all_ok:
        print("[BIKE CAMERA BEHAVIOR TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
