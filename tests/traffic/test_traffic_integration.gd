extends Node2D

var _total_ticks: int = 0
var _zone_ticks: int = 0
var _stage: int = 0
var _finished: bool = false

var _hub_has_spawner: bool = false
var _highway_has_spawner: bool = false
var _track_has_no_spawner: bool = false

var _hub_spawned: int = 0
var _highway_spawned: int = 0
var _highway_events: int = 0
var _highway_near_misses: int = 0
var _highway_collisions: int = 0
var _active_in_group_on_track: int = -1

@onready var world: Node2D = $WorldManager


func _ready() -> void:
    process_physics_priority = -20
    if not world.has_method("get_world_state"):
        print("[TRAFFIC INTEGRATION FAIL] WorldManager missing")
        _finished = true
        get_tree().quit(1)
        return

    world.zone_loaded.connect(_on_zone_loaded)
    _bind_zone_spawner(world.get_current_zone(), world.get_current_zone_id())


func _release_all_inputs() -> void:
    Input.action_release("bike_gas")
    Input.action_release("bike_brake")
    Input.action_release("bike_front_brake")
    Input.action_release("bike_shift_up")
    Input.action_release("bike_shift_down")
    Input.action_release("bike_clutch")


func _bind_zone_spawner(zone_node: Node2D, zone_id: String) -> void:
    if zone_node == null:
        return

    var spawner: Node = zone_node.get_node_or_null("TrafficSpawner")
    if zone_id == "hub_boulevard":
        _hub_has_spawner = spawner != null
        if spawner != null:
            spawner.vehicle_spawned.connect(_on_hub_spawned)
    elif zone_id == "highway_strip":
        _highway_has_spawner = spawner != null
        if spawner != null:
            spawner.vehicle_spawned.connect(_on_highway_spawned)
            spawner.traffic_near_miss.connect(_on_highway_near_miss)
            spawner.traffic_collision.connect(_on_highway_collision)
    elif zone_id == "test_track":
        _track_has_no_spawner = spawner == null


func _on_hub_spawned(_v: Node2D, _lane: int, _dir: int) -> void:
    _hub_spawned += 1


func _on_highway_spawned(_v: Node2D, _lane: int, _dir: int) -> void:
    _highway_spawned += 1


func _on_highway_near_miss(_v: Node2D, _bike: Node2D, _rel_speed: float) -> void:
    _highway_near_misses += 1
    _highway_events += 1


func _on_highway_collision(_v: Node2D, _bike: Node2D, _rel_speed: float) -> void:
    _highway_collisions += 1
    _highway_events += 1


func _on_zone_loaded(zone_id: String, _spawn_id: String, zone_node: Node2D) -> void:
    _zone_ticks = 0
    _bind_zone_spawner(zone_node, zone_id)

    if _stage == 0 and zone_id == "highway_strip":
        _stage = 1
    elif _stage == 1 and zone_id == "test_track":
        _stage = 2
        _release_all_inputs()


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _total_ticks += 1
    _zone_ticks += 1

    if _stage < 2:
        if _zone_ticks == 20:
            Input.action_press("bike_gas")
        if _zone_ticks == 80:
            Input.action_press("bike_shift_up")
        if _zone_ticks == 81:
            Input.action_release("bike_shift_up")
    else:
        if _zone_ticks >= 20:
            _active_in_group_on_track = get_tree().get_nodes_in_group("active_traffic_vehicles").size()
            _finished = true
            _evaluate_and_quit()
            return

    if _total_ticks >= 1150:
        _release_all_inputs()
        _finished = true
        print("[TRAFFIC INTEGRATION FAIL] Timed out at stage ", _stage, " zone=", world.get_current_zone_id())
        get_tree().quit(1)


func _evaluate_and_quit() -> void:
    _release_all_inputs()

    var checks := {
        "hub_has_spawner": _hub_has_spawner,
        "highway_has_spawner": _highway_has_spawner,
        "track_stays_traffic_free": _track_has_no_spawner,
        "hub_spawned_traffic": _hub_spawned >= 1,
        "highway_spawned_traffic": _highway_spawned >= 2,
        "highway_detected_bike_interaction": _highway_events >= 1,
        "zero_stale_vehicles_after_unload": _active_in_group_on_track == 0
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[TRAFFIC INTEGRATION FAIL] ", key)
            all_ok = false

    print(
        "Traffic integration -> hub_spawned: ", _hub_spawned,
        " | hwy_spawned: ", _highway_spawned,
        " | hwy_events(nm/col): ", _highway_near_misses, "/", _highway_collisions,
        " | group_on_track: ", _active_in_group_on_track,
        " | ticks: ", _total_ticks
    )

    if all_ok:
        print("[TRAFFIC INTEGRATION TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
