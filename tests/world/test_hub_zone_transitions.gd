extends Node2D

var _total_ticks: int = 0
var _zone_ticks: int = 0
var _stage: int = 0
var _finished: bool = false

var _initial_zone_id: String = ""
var _initial_spawn_pos: Vector2 = Vector2.ZERO
var _visited_zones: Array = []
var _portal_chain: Array = []
var _highway_arrival_pos: Vector2 = Vector2.ZERO
var _highway_cam_right: int = 0
var _track_arrival_pos: Vector2 = Vector2.ZERO
var _track_cam_right: int = 0
var _return_hub_pos: Vector2 = Vector2.ZERO
var _return_hub_cam_right: int = 0

@onready var world: Node2D = $WorldManager


func _ready() -> void:
    process_physics_priority = -20
    if not world.has_method("get_world_state"):
        print("[HUB TRANSITIONS TEST FAIL] WorldManager missing")
        _finished = true
        get_tree().quit(1)
        return

    var st0: Dictionary = world.get_world_state()
    _initial_zone_id = str(st0["current_zone_id"])
    _initial_spawn_pos = st0["bike_position"]
    _visited_zones.append(_initial_zone_id)

    world.zone_transition_started.connect(_on_transition_started)
    world.zone_loaded.connect(_on_zone_loaded)


func _release_all_inputs() -> void:
    Input.action_release("bike_gas")
    Input.action_release("bike_brake")
    Input.action_release("bike_front_brake")
    Input.action_release("bike_shift_up")
    Input.action_release("bike_shift_down")
    Input.action_release("bike_clutch")


func _on_transition_started(_from_id: String, _to_id: String, _spawn_id: String, via_portal: String) -> void:
    _portal_chain.append(via_portal)


func _on_zone_loaded(zone_id: String, _spawn_id: String, zone_node: Node2D) -> void:
    _visited_zones.append(zone_id)
    _zone_ticks = 0

    var cam: Camera2D = world.get_active_camera()
    var bike: RigidBody2D = world.get_active_bike()
    var bpos: Vector2 = bike.global_position if bike != null else Vector2.ZERO
    var cright: int = cam.limit_right if cam != null else 0

    if _stage == 0 and zone_id == "highway_strip":
        _stage = 1
        _highway_arrival_pos = bpos
        _highway_cam_right = cright
    elif _stage == 1 and zone_id == "test_track":
        _stage = 2
        _track_arrival_pos = bpos
        _track_cam_right = cright
    elif _stage == 2 and zone_id == "hub_boulevard":
        _stage = 3
        _return_hub_pos = bpos
        _return_hub_cam_right = cright
        _release_all_inputs()

    if zone_node == null:
        print("[HUB TRANSITIONS TEST FAIL] Null zone_node on load")


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _total_ticks += 1
    _zone_ticks += 1

    # Stage 0..2: actively drive forward through portals using real InputManager actions
    if _stage < 3:
        if _zone_ticks == 20:
            Input.action_press("bike_gas")
        if _zone_ticks == 75:
            Input.action_press("bike_shift_up")
        if _zone_ticks == 76:
            Input.action_release("bike_shift_up")
        if _stage == 1 and _zone_ticks == 145:
            Input.action_press("bike_shift_up")
        if _stage == 1 and _zone_ticks == 146:
            Input.action_release("bike_shift_up")
    else:
        # Stage 3: returned to Hub Boulevard; let bike settle for 35 ticks without re-triggering portals
        if _zone_ticks >= 35:
            _finished = true
            _evaluate_and_quit()
            return

    if _total_ticks >= 1650:
        _release_all_inputs()
        _finished = true
        print("[HUB TRANSITIONS TEST FAIL] Timed out at stage ", _stage, " zone=", world.get_current_zone_id(), " pos=", world.get_world_state()["bike_position"])
        get_tree().quit(1)


func _evaluate_and_quit() -> void:
    _release_all_inputs()
    var st: Dictionary = world.get_world_state()
    var bike: RigidBody2D = world.get_active_bike()
    var tel: Dictionary = bike.get_telemetry() if bike != null else {}

    var expected_zones := ["hub_boulevard", "highway_strip", "test_track", "hub_boulevard"]
    var expected_portals := ["hub_to_highway", "highway_to_track", "track_to_hub"]

    var checks := {
        "auto_loaded_hub": _initial_zone_id == "hub_boulevard",
        "started_at_hub_default": absf(_initial_spawn_pos.x - 160.0) < 5.0,
        "completed_full_zone_loop": _visited_zones == expected_zones,
        "triggered_expected_portals": _portal_chain == expected_portals,
        "arrived_highway_from_hub": absf(_highway_arrival_pos.x - 140.0) < 5.0 and _highway_cam_right == 2200,
        "arrived_track_from_highway": absf(_track_arrival_pos.x - 200.0) < 5.0 and _track_cam_right == 3200,
        "returned_hub_from_track": absf(_return_hub_pos.x - 260.0) < 5.0 and _return_hub_cam_right == 1500,
        "single_zone_loaded": int(st["zone_container_children"]) == 1,
        "transition_count_4": int(st["transition_count"]) == 4,
        "settled_upright_at_hub": tel.get("front_grounded", false) == true and tel.get("rear_grounded", false) == true and tel.get("is_stable", false) == true
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[HUB TRANSITIONS TEST FAIL] ", key)
            all_ok = false

    print(
        "Hub transitions -> zones: ", _visited_zones,
        " | portals: ", _portal_chain,
        " | ticks: ", _total_ticks,
        " | final_pos: ", st["bike_position"].snapped(Vector2(0.1, 0.1))
    )

    if all_ok:
        print("[HUB ZONE TRANSITIONS TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
