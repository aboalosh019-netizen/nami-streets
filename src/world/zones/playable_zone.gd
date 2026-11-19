class_name PlayableZone
extends Node2D

const BikeScene = preload("res://src/bike/controller/controllable_bike.tscn")
const CameraScene = preload("res://src/camera/bike_camera.tscn")
const SpawnPointScript = preload("res://src/world/zones/spawn_point.gd")
const ZoneBackdropScript = preload("res://src/world/visual/zone_backdrop.gd")

@export var zone_id: String = "playable_zone"
@export var bounds_left: float = -200.0
@export var bounds_right: float = 4000.0
@export var bounds_top: float = -500.0
@export var bounds_bottom: float = 450.0
@export var fall_respawn_margin: float = 120.0
@export var default_spawn_id: String = "default"
@export var auto_spawn_on_ready: bool = true
@export var set_playing_state_on_ready: bool = true

var _spawn_points: Dictionary = {}
var _current_spawn_id: String = ""
var _active_bike: RigidBody2D = null
var _active_camera: Camera2D = null
var _respawn_count: int = 0


func _ready() -> void:
    _collect_spawn_points(self)
    _setup_backdrop()
    _setup_camera()

    if set_playing_state_on_ready:
        var gm: Node = get_node_or_null("/root/GameManager")
        if gm != null and gm.has_method("change_state"):
            gm.change_state(gm.GameState.PLAYING)

    if auto_spawn_on_ready:
        spawn_bike(default_spawn_id)


func _collect_spawn_points(root_node: Node) -> void:
    for child in root_node.get_children():
        if child is SpawnPointScript:
            var sp: Marker2D = child as Marker2D
            var sid: String = str(sp.get("spawn_id"))
            if sid.is_empty():
                sid = sp.name
            _spawn_points[sid] = sp
        elif child.get_child_count() > 0:
            _collect_spawn_points(child)


func _setup_camera() -> void:
    var existing: Camera2D = get_node_or_null("BikeCamera") as Camera2D
    if existing != null:
        _active_camera = existing
    else:
        _active_camera = CameraScene.instantiate() as Camera2D
        _active_camera.name = "BikeCamera"
        add_child(_active_camera)

    if _active_camera != null and _active_camera.has_method("set_world_limits"):
        _active_camera.set_world_limits(
            int(bounds_left),
            int(bounds_top),
            int(bounds_right),
            int(bounds_bottom)
        )


func get_spawn_ids() -> Array:
    var ids: Array = _spawn_points.keys()
    ids.sort()
    return ids


func get_spawn_point(spawn_id: String = "") -> Marker2D:
    if not spawn_id.is_empty() and _spawn_points.has(spawn_id):
        return _spawn_points[spawn_id] as Marker2D

    if _spawn_points.has(default_spawn_id):
        return _spawn_points[default_spawn_id] as Marker2D

    for key in _spawn_points.keys():
        var sp: Marker2D = _spawn_points[key] as Marker2D
        if bool(sp.get("is_default")):
            return sp

    if not _spawn_points.is_empty():
        var first_key = _spawn_points.keys()[0]
        return _spawn_points[first_key] as Marker2D

    return null


func spawn_bike(spawn_id: String = "") -> RigidBody2D:
    var sp: Marker2D = get_spawn_point(spawn_id)
    var spawn_pos: Vector2 = sp.global_position if sp != null else Vector2.ZERO
    var spawn_rot: float = sp.global_rotation if sp != null else 0.0

    if sp != null:
        _current_spawn_id = str(sp.get("spawn_id"))
    else:
        _current_spawn_id = default_spawn_id

    if _active_bike == null:
        var existing_bike: RigidBody2D = get_node_or_null("PlayerBike") as RigidBody2D
        if existing_bike != null:
            _active_bike = existing_bike
        else:
            _active_bike = BikeScene.instantiate() as RigidBody2D
            _active_bike.name = "PlayerBike"
            add_child(_active_bike)

    _place_bike_cleanly(spawn_pos, spawn_rot)

    if _active_camera != null and _active_camera.has_method("set_target"):
        _active_camera.set_target(_active_bike, true)

    return _active_bike


func respawn_bike(spawn_id: String = "") -> bool:
    if _active_bike == null:
        return spawn_bike(spawn_id) != null

    var target_id: String = spawn_id if not spawn_id.is_empty() else _current_spawn_id
    var sp: Marker2D = get_spawn_point(target_id)
    var spawn_pos: Vector2 = sp.global_position if sp != null else Vector2.ZERO
    var spawn_rot: float = sp.global_rotation if sp != null else 0.0

    if sp != null:
        _current_spawn_id = str(sp.get("spawn_id"))

    _place_bike_cleanly(spawn_pos, spawn_rot)
    _respawn_count += 1

    if _active_camera != null and _active_camera.has_method("snap_to_target"):
        _active_camera.snap_to_target()

    return true


func _place_bike_cleanly(pos: Vector2, rot: float) -> void:
    if _active_bike == null:
        return

    var xf := Transform2D(rot, pos)
    _active_bike.global_transform = xf
    _active_bike.linear_velocity = Vector2.ZERO
    _active_bike.angular_velocity = 0.0

    var rid: RID = _active_bike.get_rid()
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, xf)
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)

    if _active_bike.has_method("clear_control_commands"):
        _active_bike.clear_control_commands()

    var controller: Node = _active_bike.get_node_or_null("BikeController")
    if controller != null and controller.get("drivetrain") != null:
        var dt_sys = controller.get("drivetrain")
        if dt_sys.has_method("set_gear"):
            dt_sys.set_gear(1)


func _physics_process(_delta: float) -> void:
    if _active_bike == null:
        return

    if _active_bike.global_position.y > bounds_bottom + fall_respawn_margin:
        respawn_bike(_current_spawn_id)


func get_bike() -> RigidBody2D:
    return _active_bike


func get_camera() -> Camera2D:
    return _active_camera


func get_zone_state() -> Dictionary:
    var cam_limits := {}
    if _active_camera != null:
        cam_limits = {
            "left": _active_camera.limit_left,
            "top": _active_camera.limit_top,
            "right": _active_camera.limit_right,
            "bottom": _active_camera.limit_bottom
        }

    return {
        "zone_id": zone_id,
        "spawn_ids": get_spawn_ids(),
        "current_spawn_id": _current_spawn_id,
        "has_bike": _active_bike != null,
        "has_camera": _active_camera != null,
        "bike_position": _active_bike.global_position if _active_bike != null else Vector2.ZERO,
        "respawn_count": _respawn_count,
        "camera_limits": cam_limits,
        "bounds": Rect2(bounds_left, bounds_top, bounds_right - bounds_left, bounds_bottom - bounds_top)
    }

func _setup_backdrop() -> void:
    var existing: Node = get_node_or_null("ZoneBackdrop")
    if existing != null:
        return
    var bd: ParallaxBackground = ZoneBackdropScript.new()
    bd.name = "ZoneBackdrop"
    add_child(bd)
    bd.call("setup_for_zone", zone_id)
