extends Node2D

var _ticks: int = 0
var _finished: bool = false

var _settled_y: float = 0.0
var _min_y_sidewalk: float = INF
var _min_y_ramp: float = INF
var _max_x_driven: float = 0.0
var _max_abs_rot_drive: float = 0.0
var _post_ramp_y: float = 0.0
var _wall_test_x: float = 0.0
var _respawn_ramp_pos: Vector2 = Vector2.ZERO

@onready var zone: Node2D = $Zone


func _ready() -> void:
    process_physics_priority = -20
    if not zone.has_method("get_zone_state"):
        print("[FIRST PLAYABLE AREA FAIL] Zone script missing")
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

    var bike: RigidBody2D = zone.get_bike()
    if bike == null:
        print("[FIRST PLAYABLE AREA FAIL] Bike not spawned")
        _finished = true
        get_tree().quit(1)
        return

    _ticks += 1

    # Ticks 1..40: settle at DefaultSpawn
    if _ticks == 40:
        _settled_y = bike.global_position.y
        Input.action_press("bike_gas")

    # Tick 100: shift up to gear 2 for full-track traversal
    if _ticks == 100:
        Input.action_press("bike_shift_up")

    if _ticks == 101:
        Input.action_release("bike_shift_up")

    # Ticks 41..560: monitor sidewalk climb, ramp climb, obstacle traversal, and stability
    if _ticks >= 41 and _ticks <= 560:
        var pos: Vector2 = bike.global_position
        _max_x_driven = maxf(_max_x_driven, pos.x)
        _max_abs_rot_drive = maxf(_max_abs_rot_drive, absf(bike.rotation))

        if pos.x >= 670.0 and pos.x <= 1030.0:
            _min_y_sidewalk = minf(_min_y_sidewalk, pos.y)

        if pos.x >= 1340.0 and pos.x <= 2220.0:
            _min_y_ramp = minf(_min_y_ramp, pos.y)

    # Tick 560: record post-ramp level, then position near RightBoundaryWall to test wall blocking
    if _ticks == 560:
        _post_ramp_y = bike.global_position.y
        _release_all_inputs()

        var xf := Transform2D(0.0, Vector2(3090.0, 62.0))
        bike.global_transform = xf
        bike.linear_velocity = Vector2.ZERO
        bike.angular_velocity = 0.0
        PhysicsServer2D.body_set_state(bike.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, xf)
        PhysicsServer2D.body_set_state(bike.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
        PhysicsServer2D.body_set_state(bike.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)

        var controller: Node = bike.get_node_or_null("BikeController")
        if controller != null and controller.get("drivetrain") != null:
            controller.get("drivetrain").set_gear(1)

    if _ticks == 565:
        Input.action_press("bike_gas")

    if _ticks == 630:
        _wall_test_x = bike.global_position.x
        _release_all_inputs()
        zone.respawn_bike("ramp")

    if _ticks == 670:
        _respawn_ramp_pos = bike.global_position
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var st: Dictionary = zone.get_zone_state()
    var bike: RigidBody2D = zone.get_bike()
    var t: Dictionary = bike.get_telemetry()
    var limits: Dictionary = st["camera_limits"]

    var sidewalk_rise: float = _settled_y - _min_y_sidewalk
    var ramp_rise: float = _settled_y - _min_y_ramp

    var checks := {
        "zone_id_correct": st["zone_id"] == "test_track",
        "camera_limits_set": limits.get("left") == -200 and limits.get("right") == 3200,
        "traversed_past_ramp_and_obstacle": _max_x_driven > 2580.0,
        "climbed_sidewalk": sidewalk_rise > 9.0,
        "climbed_overpass_ramp": ramp_rise > 48.0,
        "returned_to_road_level": absf(_post_ramp_y - _settled_y) < 18.0,
        "remained_upright_during_drive": _max_abs_rot_drive < 0.75,
        "reached_near_east_wall": _wall_test_x > 3130.0,
        "blocked_by_east_boundary": _wall_test_x < 3190.0,
        "respawned_cleanly_at_ramp": absf(_respawn_ramp_pos.x - 1220.0) < 10.0 and t["front_grounded"] == true and t["rear_grounded"] == true,
        "stable_at_finish": t["is_stable"] == true,
        "no_nan": not is_nan(bike.global_position.x) and not is_nan(bike.global_position.y)
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[FIRST PLAYABLE AREA FAIL] ", key)
            all_ok = false

    print(
        "Playable area -> max_x: ", snappedf(_max_x_driven, 0.1),
        " | sidewalk_rise: ", snappedf(sidewalk_rise, 0.1),
        " | ramp_rise: ", snappedf(ramp_rise, 0.1),
        " | wall_x: ", snappedf(_wall_test_x, 0.1),
        " | max_rot: ", snappedf(_max_abs_rot_drive, 0.001),
        " | respawn_pos: ", _respawn_ramp_pos.snapped(Vector2(0.1, 0.1))
    )

    if all_ok:
        print("[FIRST PLAYABLE AREA TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
