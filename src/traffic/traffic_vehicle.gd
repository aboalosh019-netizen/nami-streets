class_name TrafficVehicle
extends Node2D

const TrafficVehicleConfigScript = preload("res://src/traffic/traffic_vehicle_config.gd")
const BikePhysicsBodyScript = preload("res://src/bike/physics/bike_physics_body.gd")

const ACTIVE_GROUP: String = "active_traffic_vehicles"

signal near_miss_detected(vehicle: Node2D, bike: Node2D, relative_speed: float)
signal player_collided(vehicle: Node2D, bike: Node2D, relative_speed: float)

@export var config: Resource
@export var lane_id: int = 0
@export var direction: int = 1
@export var active_on_ready: bool = true
@export var auto_sense_lead: bool = true

var _active: bool = false
var _current_speed: float = 0.0
var _desired_speed: float = 0.0
var _last_lead_gap: float = INF
var _tracked_bikes: Dictionary = {}
var _near_miss_count: int = 0
var _collision_count: int = 0

@onready var visuals: Node2D = $Visuals
@onready var body_poly: Polygon2D = $Visuals/BodyPolygon
@onready var cabin_poly: Polygon2D = $Visuals/CabinPolygon
@onready var hitbox_area: Area2D = $HitboxArea
@onready var hitbox_shape: CollisionShape2D = $HitboxArea/CollisionShape2D
@onready var near_miss_area: Area2D = $NearMissArea
@onready var near_miss_shape: CollisionShape2D = $NearMissArea/CollisionShape2D


func _ready() -> void:
    if config == null:
        config = TrafficVehicleConfigScript.create_sedan()

    direction = 1 if direction >= 0 else -1

    hitbox_area.collision_layer = 0
    hitbox_area.collision_mask = 2
    hitbox_area.monitorable = false

    near_miss_area.collision_layer = 0
    near_miss_area.collision_mask = 2
    near_miss_area.monitorable = false

    if not hitbox_area.body_entered.is_connected(_on_hitbox_body_entered):
        hitbox_area.body_entered.connect(_on_hitbox_body_entered)
    if not near_miss_area.body_entered.is_connected(_on_near_miss_body_entered):
        near_miss_area.body_entered.connect(_on_near_miss_body_entered)
    if not near_miss_area.body_exited.is_connected(_on_near_miss_body_exited):
        near_miss_area.body_exited.connect(_on_near_miss_body_exited)

    apply_config(config)

    if active_on_ready:
        activate(global_position, direction, lane_id, config, float(config.target_speed))
    else:
        deactivate()


func apply_config(new_config: Resource) -> void:
    if new_config != null:
        config = new_config
    elif config == null:
        config = TrafficVehicleConfigScript.create_sedan()

    if not is_node_ready():
        return

    var w: float = float(config.width)
    var h: float = float(config.height)
    var margin: Vector2 = config.near_miss_margin

    var hb := RectangleShape2D.new()
    hb.size = Vector2(w, h)
    hitbox_shape.shape = hb
    hitbox_shape.position = Vector2(0.0, -h * 0.5)

    var nm := RectangleShape2D.new()
    nm.size = Vector2(w + margin.x * 2.0, h + margin.y * 2.0)
    near_miss_shape.shape = nm
    near_miss_shape.position = Vector2(0.0, -h * 0.5)

    var half_w: float = w * 0.5
    var wheel_clearance: float = 5.0
    var body_top: float = -h * 0.62
    body_poly.color = config.body_color
    body_poly.polygon = PackedVector2Array([
        Vector2(-half_w, -wheel_clearance),
        Vector2(-half_w, body_top),
        Vector2(half_w, body_top),
        Vector2(half_w, -wheel_clearance)
    ])

    cabin_poly.color = config.cabin_color
    cabin_poly.polygon = PackedVector2Array([
        Vector2(-half_w * 0.45, body_top),
        Vector2(-half_w * 0.25, -h),
        Vector2(half_w * 0.35, -h),
        Vector2(half_w * 0.55, body_top)
    ])

    visuals.scale.x = float(direction)


func activate(
    spawn_pos: Vector2,
    travel_dir: int,
    assigned_lane: int,
    new_config: Resource = null,
    initial_speed: float = -1.0
) -> void:
    direction = 1 if travel_dir >= 0 else -1
    lane_id = assigned_lane
    global_position = spawn_pos

    if new_config != null:
        apply_config(new_config)
    else:
        apply_config(config)

    _current_speed = float(config.target_speed) if initial_speed < 0.0 else maxf(0.0, initial_speed)
    _desired_speed = float(config.target_speed)
    _last_lead_gap = INF
    _tracked_bikes.clear()
    _active = true
    visible = true

    if not is_in_group(ACTIVE_GROUP):
        add_to_group(ACTIVE_GROUP)

    hitbox_area.monitoring = true
    near_miss_area.monitoring = true
    set_physics_process(true)


func deactivate() -> void:
    _active = false
    _current_speed = 0.0
    _desired_speed = 0.0
    _last_lead_gap = INF
    _tracked_bikes.clear()
    visible = false

    if is_in_group(ACTIVE_GROUP):
        remove_from_group(ACTIVE_GROUP)

    if is_node_ready():
        hitbox_area.monitoring = false
        near_miss_area.monitoring = false

    set_physics_process(false)


func is_active() -> bool:
    return _active


func get_velocity() -> Vector2:
    if not _active:
        return Vector2.ZERO
    return Vector2(float(direction) * _current_speed, 0.0)


func get_width() -> float:
    return float(config.width) if config != null else 84.0


func get_height() -> float:
    return float(config.height) if config != null else 32.0


func _physics_process(delta: float) -> void:
    if not _active or delta <= 0.0 or config == null:
        return

    var target_spd: float = maxf(0.0, float(config.target_speed))
    var desired: float = target_spd
    _last_lead_gap = INF

    if auto_sense_lead and target_spd > 0.0:
        var lead_info: Dictionary = _find_closest_lead_vehicle()
        if bool(lead_info["found"]):
            var gap: float = float(lead_info["gap"])
            var lead_speed: float = float(lead_info["speed"])
            _last_lead_gap = gap

            var safe_gap: float = maxf(8.0, float(config.safe_headway))
            var caution_gap: float = maxf(safe_gap + 10.0, safe_gap * float(config.caution_multiplier))

            if gap <= safe_gap * 0.5:
                desired = 0.0
            elif gap <= safe_gap:
                desired = minf(target_spd, lead_speed * 0.85)
            elif gap < caution_gap:
                var ratio: float = clampf((gap - safe_gap) / (caution_gap - safe_gap), 0.0, 1.0)
                desired = lerpf(lead_speed, target_spd, ratio)

    _desired_speed = desired

    if _desired_speed > _current_speed:
        _current_speed = move_toward(_current_speed, _desired_speed, float(config.acceleration) * delta)
    else:
        _current_speed = move_toward(_current_speed, _desired_speed, float(config.deceleration) * delta)

    global_position.x += float(direction) * _current_speed * delta


func _find_closest_lead_vehicle() -> Dictionary:
    var result := {"found": false, "gap": INF, "speed": 0.0}
    var tree := get_tree()
    if tree == null:
        return result

    var my_half_w: float = get_width() * 0.5
    var nodes: Array = tree.get_nodes_in_group(ACTIVE_GROUP)

    for node in nodes:
        if node == self or not is_instance_valid(node):
            continue
        if not (node is Node2D):
            continue
        if int(node.get("lane_id")) != lane_id:
            continue
        if int(node.get("direction")) != direction:
            continue

        var other_node := node as Node2D
        var center_delta: float = (other_node.global_position.x - global_position.x) * float(direction)
        if center_delta <= 0.0:
            continue

        var other_half_w: float = float(node.get_width()) * 0.5 if node.has_method("get_width") else 42.0
        var gap: float = center_delta - (my_half_w + other_half_w)

        if gap < float(result["gap"]):
            var other_vel: Vector2 = node.get_velocity() if node.has_method("get_velocity") else Vector2.ZERO
            result["found"] = true
            result["gap"] = gap
            result["speed"] = absf(other_vel.x)

    return result


func _compute_relative_speed(bike: Node) -> float:
    var bike_vel: Vector2 = bike.get("linear_velocity") if "linear_velocity" in bike else Vector2.ZERO
    return (bike_vel - get_velocity()).length()


func _on_near_miss_body_entered(body: Node) -> void:
    if not _active or not (body is BikePhysicsBodyScript):
        return

    var bid: int = body.get_instance_id()
    var rel_speed: float = _compute_relative_speed(body)
    if not _tracked_bikes.has(bid):
        _tracked_bikes[bid] = {
            "collided": false,
            "max_rel_speed": rel_speed
        }
    else:
        var entry: Dictionary = _tracked_bikes[bid]
        entry["max_rel_speed"] = maxf(float(entry["max_rel_speed"]), rel_speed)


func _on_hitbox_body_entered(body: Node) -> void:
    if not _active or not (body is BikePhysicsBodyScript):
        return

    var bid: int = body.get_instance_id()
    var rel_speed: float = _compute_relative_speed(body)
    if not _tracked_bikes.has(bid):
        _tracked_bikes[bid] = {
            "collided": false,
            "max_rel_speed": rel_speed
        }

    var entry: Dictionary = _tracked_bikes[bid]
    if not bool(entry["collided"]):
        entry["collided"] = true
        entry["max_rel_speed"] = maxf(float(entry["max_rel_speed"]), rel_speed)
        _collision_count += 1
        player_collided.emit(self, body as Node2D, rel_speed)


func _on_near_miss_body_exited(body: Node) -> void:
    if not _active or not (body is BikePhysicsBodyScript):
        return

    var bid: int = body.get_instance_id()
    if not _tracked_bikes.has(bid):
        return

    var entry: Dictionary = _tracked_bikes[bid]
    _tracked_bikes.erase(bid)

    if not bool(entry["collided"]):
        var rel_speed: float = maxf(float(entry["max_rel_speed"]), _compute_relative_speed(body))
        _near_miss_count += 1
        near_miss_detected.emit(self, body as Node2D, rel_speed)


func get_vehicle_state() -> Dictionary:
    return {
        "active": _active,
        "vehicle_type": str(config.vehicle_type) if config != null else "",
        "lane_id": lane_id,
        "direction": direction,
        "position": global_position,
        "current_speed": _current_speed,
        "desired_speed": _desired_speed,
        "lead_gap": _last_lead_gap,
        "near_miss_count": _near_miss_count,
        "collision_count": _collision_count
    }
