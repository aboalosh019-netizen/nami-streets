class_name TrafficSpawner
extends Node2D

const TrafficVehicleScene = preload("res://src/traffic/traffic_vehicle.tscn")
const TrafficVehicleConfigScript = preload("res://src/traffic/traffic_vehicle_config.gd")

signal vehicle_spawned(vehicle: Node2D, lane_id: int, direction: int)
signal vehicle_recycled(vehicle: Node2D)
signal traffic_near_miss(vehicle: Node2D, bike: Node2D, relative_speed: float)
signal traffic_collision(vehicle: Node2D, bike: Node2D, relative_speed: float)

@export_group("Pool & Limits")
@export var pool_size: int = 8
@export var max_active_vehicles: int = 4
@export var enabled: bool = true
@export var auto_bind_zone_bike: bool = true

@export_group("Spawn Timing & Spacing")
@export var spawn_interval: float = 1.4
@export var min_spawn_spacing: float = 220.0
@export var min_player_clearance: float = 180.0
@export var spawn_ahead_distance: float = 480.0
@export var despawn_distance: float = 720.0

@export_group("Road & Lanes")
@export var road_y: float = 100.0
@export var oncoming_y_offset: float = 0.0
@export var road_min_x: float = -200.0
@export var road_max_x: float = 3000.0
@export var allow_same_direction: bool = true
@export var allow_oncoming: bool = true

@export_group("Determinism")
@export var deterministic_seed: int = 0

var _rng := RandomNumberGenerator.new()
var _pool_container: Node2D = null
var _pool: Array = []
var _active_vehicles: Array = []
var _vehicle_presets: Array = []
var _target: Node2D = null

var _spawn_timer: float = 0.0
var _lane_toggle: int = 0
var _total_spawned: int = 0
var _total_recycled: int = 0
var _near_miss_count: int = 0
var _collision_count: int = 0


func _ready() -> void:
    if deterministic_seed != 0:
        _rng.seed = deterministic_seed
    else:
        _rng.randomize()

    _vehicle_presets = [
        TrafficVehicleConfigScript.create_sedan(),
        TrafficVehicleConfigScript.create_pickup(),
        TrafficVehicleConfigScript.create_truck()
    ]

    _ensure_pool_container()
    _build_pool()
    _try_bind_zone_bike()


func _ensure_pool_container() -> void:
    _pool_container = get_node_or_null("PoolContainer") as Node2D
    if _pool_container == null:
        _pool_container = Node2D.new()
        _pool_container.name = "PoolContainer"
        add_child(_pool_container)


func _build_pool() -> void:
    var count: int = maxi(1, pool_size)
    _pool.clear()
    _active_vehicles.clear()

    for i in range(count):
        var vehicle: Node2D = TrafficVehicleScene.instantiate() as Node2D
        vehicle.name = "TrafficVehicle_%d" % i
        vehicle.set("active_on_ready", false)
        _pool_container.add_child(vehicle)

        if not vehicle.near_miss_detected.is_connected(_on_vehicle_near_miss):
            vehicle.near_miss_detected.connect(_on_vehicle_near_miss)
        if not vehicle.player_collided.is_connected(_on_vehicle_collided):
            vehicle.player_collided.connect(_on_vehicle_collided)

        _pool.append(vehicle)


func _try_bind_zone_bike() -> void:
    if not auto_bind_zone_bike:
        return
    if _target != null and is_instance_valid(_target):
        return

    var parent_node: Node = get_parent()
    if parent_node != null and parent_node.has_method("get_bike"):
        var bike: Node2D = parent_node.get_bike() as Node2D
        if bike != null:
            _target = bike


func set_target(new_target: Node2D) -> void:
    _target = new_target


func set_enabled(is_enabled: bool) -> void:
    enabled = is_enabled


func set_road_bounds(min_x: float, max_x: float) -> void:
    road_min_x = min_x
    road_max_x = max_x


func clear_all_active() -> void:
    var to_recycle: Array = _active_vehicles.duplicate()
    for vehicle in to_recycle:
        _recycle_vehicle(vehicle)


func _physics_process(delta: float) -> void:
    if delta <= 0.0:
        return

    if _target == null or not is_instance_valid(_target):
        _try_bind_zone_bike()
        if _target == null or not is_instance_valid(_target):
            return

    var anchor_x: float = _target.global_position.x
    _recycle_out_of_range(anchor_x)

    if not enabled:
        return

    _spawn_timer += delta
    var interval: float = maxf(0.05, spawn_interval)
    if _spawn_timer >= interval:
        _spawn_timer = 0.0
        try_spawn_vehicle(anchor_x)


func _recycle_out_of_range(anchor_x: float) -> void:
    var i: int = _active_vehicles.size() - 1
    while i >= 0:
        var vehicle: Node2D = _active_vehicles[i] as Node2D
        if vehicle == null or not is_instance_valid(vehicle):
            _active_vehicles.remove_at(i)
            i -= 1
            continue

        var vx: float = vehicle.global_position.x
        var out_of_view: bool = absf(vx - anchor_x) > despawn_distance
        var out_of_road: bool = vx < (road_min_x - 90.0) or vx > (road_max_x + 90.0)
        if out_of_view or out_of_road:
            _recycle_vehicle(vehicle)

        i -= 1


func _acquire_inactive_vehicle() -> Node2D:
    for vehicle in _pool:
        if vehicle != null and is_instance_valid(vehicle) and not vehicle.is_active():
            return vehicle as Node2D
    return null


func _pick_vehicle_config() -> Resource:
    if _vehicle_presets.is_empty():
        return TrafficVehicleConfigScript.create_sedan()
    var idx: int = _rng.randi_range(0, _vehicle_presets.size() - 1)
    return _vehicle_presets[idx] as Resource


func _get_candidate_lanes() -> Array:
    var lanes: Array = []
    if allow_same_direction and allow_oncoming:
        if _lane_toggle % 2 == 0:
            lanes = [0, 1]
        else:
            lanes = [1, 0]
        _lane_toggle += 1
    elif allow_same_direction:
        lanes = [0]
    elif allow_oncoming:
        lanes = [1]
    return lanes


func _can_spawn_in_lane(spawn_x: float, anchor_x: float, lane_id: int, vehicle_width: float) -> bool:
    if spawn_x < road_min_x or spawn_x > road_max_x:
        return false

    if absf(spawn_x - anchor_x) < min_player_clearance:
        return false

    var half_w: float = vehicle_width * 0.5
    for vehicle in _active_vehicles:
        if vehicle == null or not is_instance_valid(vehicle):
            continue
        if int(vehicle.get("lane_id")) != lane_id:
            continue

        var other_half_w: float = float(vehicle.get_width()) * 0.5 if vehicle.has_method("get_width") else 42.0
        var required_dist: float = half_w + other_half_w + min_spawn_spacing
        if absf(vehicle.global_position.x - spawn_x) < required_dist:
            return false

    return true


func try_spawn_vehicle(anchor_x: float) -> Node2D:
    var cap: int = mini(maxi(0, max_active_vehicles), _pool.size())
    if _active_vehicles.size() >= cap:
        return null

    var vehicle: Node2D = _acquire_inactive_vehicle()
    if vehicle == null:
        return null

    var cfg: Resource = _pick_vehicle_config()
    var v_width: float = float(cfg.width)
    var candidate_lanes: Array = _get_candidate_lanes()

    for lane_entry in candidate_lanes:
        var lane_id: int = int(lane_entry)
        var travel_dir: int = 1 if lane_id == 0 else -1
        var spawn_x: float = anchor_x + spawn_ahead_distance
        var spawn_y: float = road_y if lane_id == 0 else (road_y + oncoming_y_offset)

        if not _can_spawn_in_lane(spawn_x, anchor_x, lane_id, v_width):
            continue

        vehicle.z_index = 0 if lane_id == 0 else -1
        vehicle.activate(Vector2(spawn_x, spawn_y), travel_dir, lane_id, cfg, float(cfg.target_speed))
        _active_vehicles.append(vehicle)
        _total_spawned += 1
        vehicle_spawned.emit(vehicle, lane_id, travel_dir)
        return vehicle

    return null


func _recycle_vehicle(vehicle: Node2D) -> void:
    if vehicle == null or not is_instance_valid(vehicle):
        return

    var idx: int = _active_vehicles.find(vehicle)
    if idx != -1:
        _active_vehicles.remove_at(idx)

    if vehicle.is_active():
        vehicle.deactivate()
        _total_recycled += 1
        vehicle_recycled.emit(vehicle)


func _on_vehicle_near_miss(vehicle: Node2D, bike: Node2D, relative_speed: float) -> void:
    _near_miss_count += 1
    traffic_near_miss.emit(vehicle, bike, relative_speed)


func _on_vehicle_collided(vehicle: Node2D, bike: Node2D, relative_speed: float) -> void:
    _collision_count += 1
    traffic_collision.emit(vehicle, bike, relative_speed)


func get_active_vehicles() -> Array:
    return _active_vehicles.duplicate()


func get_spawner_state() -> Dictionary:
    var active_cnt: int = _active_vehicles.size()
    return {
        "enabled": enabled,
        "pool_size": _pool.size(),
        "pool_children": _pool_container.get_child_count() if _pool_container != null else 0,
        "active_count": active_cnt,
        "inactive_count": _pool.size() - active_cnt,
        "total_spawned": _total_spawned,
        "total_recycled": _total_recycled,
        "near_miss_count": _near_miss_count,
        "collision_count": _collision_count
    }
