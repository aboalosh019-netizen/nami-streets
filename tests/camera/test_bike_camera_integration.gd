extends Node2D

var _ticks: int = 0
var _finished: bool = false

var _idle_cam_x_offset: float = 0.0
var _idle_zoom: float = 1.0

var _fast_bike_speed: float = 0.0
var _fast_cam_x_offset: float = 0.0
var _fast_look_ahead_x: float = 0.0
var _fast_zoom: float = 1.0

@onready var bike: RigidBody2D = $Bike
@onready var cam: Camera2D = $BikeCamera


func _ready() -> void:
    process_physics_priority = -20
    if not bike.has_method("get_telemetry") or not cam.has_method("get_camera_state"):
        print("[CAMERA INTEGRATION TEST FAIL] Missing bike or camera methods")
        _finished = true
        get_tree().quit(1)


func _release_all_inputs() -> void:
    Input.action_release("bike_gas")
    Input.action_release("bike_brake")
    Input.action_release("bike_front_brake")
    Input.action_release("bike_shift_up")
    Input.action_release("bike_shift_down")
    Input.action_release("bike_clutch")


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    # Ticks 1..50: bike settles on ground, capture idle camera framing
    if _ticks == 50:
        var st_idle: Dictionary = cam.get_camera_state()
        _idle_cam_x_offset = cam.global_position.x - bike.global_position.x
        _idle_zoom = float(st_idle["zoom"])
        Input.action_press("bike_gas")

    # Tick 111: shift to gear 2 for higher speed framing
    if _ticks == 111:
        Input.action_press("bike_shift_up")

    if _ticks == 112:
        Input.action_release("bike_shift_up")

    # Tick 180: capture high-speed camera state, then brake hard with subtle shake
    if _ticks == 180:
        var st_fast: Dictionary = cam.get_camera_state()
        _fast_bike_speed = bike.linear_velocity.x
        _fast_cam_x_offset = cam.global_position.x - bike.global_position.x
        var la: Vector2 = st_fast["look_ahead"]
        _fast_look_ahead_x = la.x
        _fast_zoom = float(st_fast["zoom"])

        Input.action_release("bike_gas")
        Input.action_press("bike_brake")
        Input.action_press("bike_front_brake")
        cam.add_shake(0.35)

    if _ticks == 260:
        Input.action_release("bike_brake")
        Input.action_release("bike_front_brake")

    # Tick 340: evaluate settled stop state
    if _ticks >= 340:
        _release_all_inputs()
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var st_final: Dictionary = cam.get_camera_state()
    var final_bike_speed: float = absf(bike.linear_velocity.x)
    var final_cam_x_offset: float = cam.global_position.x - bike.global_position.x
    var final_zoom: float = float(st_final["zoom"])
    var final_trauma: float = float(st_final["shake_trauma"])

    var checks := {
        "bike_reached_high_speed": _fast_bike_speed > 250.0,
        "camera_followed_bike": cam.global_position.x > 500.0,
        "camera_leads_more_at_speed": _fast_cam_x_offset > _idle_cam_x_offset + 20.0,
        "look_ahead_active_at_speed": _fast_look_ahead_x > 40.0,
        "zoom_pulled_out_at_speed": _fast_zoom < _idle_zoom - 0.04,
        "bike_stopped_after_braking": final_bike_speed < 15.0,
        "zoom_recovered_after_stop": final_zoom > _fast_zoom + 0.02,
        "camera_recentered_after_stop": absf(final_cam_x_offset - _idle_cam_x_offset) < 35.0,
        "shake_decayed": is_equal_approx(final_trauma, 0.0),
        "no_nan": not is_nan(cam.global_position.x) and not is_nan(cam.global_position.y) and not is_nan(final_zoom)
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[CAMERA INTEGRATION TEST FAIL] ", key)
            all_ok = false

    print(
        "Camera integration -> fast_v: ", snappedf(_fast_bike_speed, 0.1),
        " | idle/fast/final_dx: ", snappedf(_idle_cam_x_offset, 0.1), "/", snappedf(_fast_cam_x_offset, 0.1), "/", snappedf(final_cam_x_offset, 0.1),
        " | zoom idle/fast/final: ", snappedf(_idle_zoom, 0.001), "/", snappedf(_fast_zoom, 0.001), "/", snappedf(final_zoom, 0.001)
    )

    if all_ok:
        print("[BIKE CAMERA INTEGRATION TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
