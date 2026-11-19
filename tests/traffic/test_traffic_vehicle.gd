extends Node2D

const TrafficVehicleConfigScript = preload("res://src/traffic/traffic_vehicle_config.gd")

var _ticks: int = 0
var _finished: bool = false

var _presets_ok: bool = false
var _min_bumper_gap: float = INF
var _fast_final_speed: float = 0.0
var _slow_final_speed: float = 0.0

var _near_miss_events: int = 0
var _collision_events: int = 0
var _last_near_miss_speed: float = 0.0
var _last_collision_speed: float = 0.0
var _near_miss_after_pass1: int = -1
var _collision_after_pass1: int = -1

@onready var slow_truck: Node2D = $SlowTruck
@onready var fast_sedan: Node2D = $FastSedan
@onready var detector_car: Node2D = $DetectorCar
@onready var bike: RigidBody2D = $Bike


func _ready() -> void:
    var sedan_cfg = TrafficVehicleConfigScript.create_sedan()
    var pickup_cfg = TrafficVehicleConfigScript.create_pickup()
    var truck_cfg = TrafficVehicleConfigScript.create_truck()

    _presets_ok = (
        sedan_cfg.vehicle_type == "sedan"
        and pickup_cfg.vehicle_type == "pickup"
        and truck_cfg.vehicle_type == "truck"
        and truck_cfg.width > pickup_cfg.width
        and pickup_cfg.width > sedan_cfg.width
        and sedan_cfg.target_speed > truck_cfg.target_speed
    )

    # Configure headway lane vehicles (lane 0, eastbound)
    truck_cfg.target_speed = 90.0
    sedan_cfg.target_speed = 240.0
    sedan_cfg.safe_headway = 70.0
    sedan_cfg.deceleration = 340.0

    slow_truck.activate(Vector2(380.0, 100.0), 1, 0, truck_cfg, 90.0)
    fast_sedan.activate(Vector2(80.0, 100.0), 1, 0, sedan_cfg, 240.0)

    # Configure stationary detector vehicle on lane 1 (y = 300) for near-miss vs collision
    var det_cfg = TrafficVehicleConfigScript.create_sedan()
    det_cfg.target_speed = 0.0
    det_cfg.near_miss_margin = Vector2(28.0, 24.0)
    detector_car.activate(Vector2(200.0, 300.0), 1, 1, det_cfg, 0.0)
    detector_car.near_miss_detected.connect(_on_near_miss)
    detector_car.player_collided.connect(_on_collision)

    # Disable gravity on bike so it flies along exact test trajectories
    bike.gravity_scale = 0.0
    _teleport_bike(Vector2(40.0, 248.0), Vector2(400.0, 0.0))


func _on_near_miss(_vehicle: Node2D, _bike: Node2D, rel_speed: float) -> void:
    _near_miss_events += 1
    _last_near_miss_speed = rel_speed


func _on_collision(_vehicle: Node2D, _bike: Node2D, rel_speed: float) -> void:
    _collision_events += 1
    _last_collision_speed = rel_speed


func _teleport_bike(pos: Vector2, vel: Vector2) -> void:
    var xf := Transform2D(0.0, pos)
    bike.global_transform = xf
    bike.linear_velocity = vel
    bike.angular_velocity = 0.0
    var rid: RID = bike.get_rid()
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, xf)
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, vel)
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    # Track minimum bumper-to-bumper gap between FastSedan and SlowTruck
    var gap: float = (
        (slow_truck.global_position.x - fast_sedan.global_position.x)
        - (slow_truck.get_width() * 0.5 + fast_sedan.get_width() * 0.5)
    )
    _min_bumper_gap = minf(_min_bumper_gap, gap)

    # Tick 65: Pass 1 (clean near-miss above roof at y=248) has completed
    if _ticks == 65:
        _near_miss_after_pass1 = _near_miss_events
        _collision_after_pass1 = _collision_events
        # Start Pass 2: direct collision through HitboxArea at y=284
        _teleport_bike(Vector2(40.0, 284.0), Vector2(400.0, 0.0))

    # Tick 160: evaluate headway convergence + both detection passes
    if _ticks >= 160:
        var fast_st: Dictionary = fast_sedan.get_vehicle_state()
        var slow_st: Dictionary = slow_truck.get_vehicle_state()
        _fast_final_speed = float(fast_st["current_speed"])
        _slow_final_speed = float(slow_st["current_speed"])
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var checks := {
        "presets_valid": _presets_ok,
        "vehicles_moved_east": slow_truck.global_position.x > 600.0 and fast_sedan.global_position.x > 400.0,
        "no_overlap_kept_safe_gap": _min_bumper_gap > 45.0,
        "fast_sedan_matched_truck_speed": absf(_fast_final_speed - _slow_final_speed) < 12.0,
        "pass1_triggered_near_miss": _near_miss_after_pass1 == 1 and _last_near_miss_speed > 300.0,
        "pass1_had_no_collision": _collision_after_pass1 == 0,
        "pass2_triggered_collision": _collision_events == 1 and _last_collision_speed > 300.0,
        "pass2_suppressed_near_miss": _near_miss_events == 1
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[TRAFFIC VEHICLE TEST FAIL] ", key)
            all_ok = false

    print(
        "Traffic vehicle -> min_gap: ", snappedf(_min_bumper_gap, 0.1),
        " | speed fast/slow: ", snappedf(_fast_final_speed, 0.1), "/", snappedf(_slow_final_speed, 0.1),
        " | near_miss: ", _near_miss_events,
        " | collisions: ", _collision_events
    )

    if all_ok:
        print("[TRAFFIC VEHICLE TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
