class_name WorldManager
extends Node2D

const ZoneRegistryScript = preload("res://src/world/navigation/zone_registry.gd")
const ZonePortalScript = preload("res://src/world/navigation/zone_portal.gd")

signal zone_transition_started(from_zone_id: String, to_zone_id: String, target_spawn_id: String, via_portal_id: String)
signal zone_loaded(zone_id: String, spawn_id: String, zone_node: Node2D)
signal zone_transition_failed(target_zone_id: String, reason: String)

@export var initial_zone_id: String = ""
@export var initial_spawn_id: String = ""
@export var auto_load_initial_zone: bool = false
@export var arrival_portal_cooldown: float = 0.75

var registry: ZoneRegistryScript

var _zone_container: Node2D = null
var _current_zone: Node2D = null
var _current_zone_id: String = ""
var _current_spawn_id: String = ""
var _connected_portals: Array = []
var _is_transitioning: bool = false
var _transition_count: int = 0


func _ready() -> void:
    if registry == null:
        registry = ZoneRegistryScript.new()

    _ensure_zone_container()

    if auto_load_initial_zone:
        var start_zone: String = initial_zone_id if not initial_zone_id.is_empty() else registry.get_hub_zone_id()
        if not start_zone.is_empty():
            load_zone(start_zone, initial_spawn_id)


func _ensure_zone_container() -> void:
    _zone_container = get_node_or_null("ZoneContainer") as Node2D
    if _zone_container == null:
        _zone_container = Node2D.new()
        _zone_container.name = "ZoneContainer"
        add_child(_zone_container)


func request_zone_transition(
    target_zone_id: String,
    target_spawn_id: String = "",
    via_portal_id: String = ""
) -> bool:
    if _is_transitioning:
        return false

    if not _validate_target_zone(target_zone_id):
        return false

    _is_transitioning = true
    call_deferred("_perform_zone_transition", target_zone_id, target_spawn_id, via_portal_id)
    return true


func load_zone(
    target_zone_id: String,
    target_spawn_id: String = "",
    via_portal_id: String = ""
) -> bool:
    if _is_transitioning:
        return false

    if not _validate_target_zone(target_zone_id):
        return false

    _is_transitioning = true
    return _perform_zone_transition(target_zone_id, target_spawn_id, via_portal_id)


func _validate_target_zone(target_zone_id: String) -> bool:
    if registry == null:
        registry = ZoneRegistryScript.new()

    if not registry.has_zone(target_zone_id):
        zone_transition_failed.emit(target_zone_id, "unknown_zone")
        return false

    var scene_path: String = registry.get_scene_path(target_zone_id)
    if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
        zone_transition_failed.emit(target_zone_id, "missing_scene")
        return false

    return true


func _perform_zone_transition(
    target_zone_id: String,
    target_spawn_id: String,
    via_portal_id: String
) -> bool:
    _ensure_zone_container()

    var scene_path: String = registry.get_scene_path(target_zone_id)
    var packed: PackedScene = load(scene_path) as PackedScene
    if packed == null:
        _is_transitioning = false
        zone_transition_failed.emit(target_zone_id, "load_failed")
        return false

    var new_zone: Node2D = packed.instantiate() as Node2D
    if new_zone == null:
        _is_transitioning = false
        zone_transition_failed.emit(target_zone_id, "invalid_zone_root")
        return false

    var resolved_spawn: String = target_spawn_id if not target_spawn_id.is_empty() else registry.get_default_spawn_id(target_zone_id)
    var from_zone_id: String = _current_zone_id

    zone_transition_started.emit(from_zone_id, target_zone_id, resolved_spawn, via_portal_id)

    _unload_current_zone()

    # Prevent PlayableZone from spawning at its default point before we spawn at resolved_spawn
    if "auto_spawn_on_ready" in new_zone:
        new_zone.set("auto_spawn_on_ready", false)

    _zone_container.add_child(new_zone)

    if new_zone.has_method("spawn_bike"):
        new_zone.spawn_bike(resolved_spawn)

    _current_zone = new_zone
    _current_zone_id = target_zone_id

    if new_zone.has_method("get_zone_state"):
        var z_state: Dictionary = new_zone.get_zone_state()
        _current_spawn_id = str(z_state.get("current_spawn_id", resolved_spawn))
    else:
        _current_spawn_id = resolved_spawn

    _transition_count += 1
    refresh_zone_portals()
    _is_transitioning = false

    zone_loaded.emit(_current_zone_id, _current_spawn_id, _current_zone)
    return true


func _unload_current_zone() -> void:
    _disconnect_portals()

    if _current_zone != null and is_instance_valid(_current_zone):
        if _current_zone.get_parent() != null:
            _current_zone.get_parent().remove_child(_current_zone)
        _current_zone.queue_free()

    _current_zone = null


func _disconnect_portals() -> void:
    for portal in _connected_portals:
        if portal != null and is_instance_valid(portal):
            if portal.portal_triggered.is_connected(_on_portal_triggered):
                portal.portal_triggered.disconnect(_on_portal_triggered)
    _connected_portals.clear()


func refresh_zone_portals() -> void:
    _disconnect_portals()
    if _current_zone != null and is_instance_valid(_current_zone):
        _bind_portals_recursive(_current_zone)


func _bind_portals_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is ZonePortalScript:
            if child.has_method("arm_cooldown"):
                child.arm_cooldown(arrival_portal_cooldown)
            if not child.portal_triggered.is_connected(_on_portal_triggered):
                child.portal_triggered.connect(_on_portal_triggered)
            _connected_portals.append(child)
        elif child.get_child_count() > 0:
            _bind_portals_recursive(child)


func _on_portal_triggered(portal_id: String, target_zone_id: String, target_spawn_id: String) -> void:
    request_zone_transition(target_zone_id, target_spawn_id, portal_id)


func get_current_zone() -> Node2D:
    return _current_zone


func get_current_zone_id() -> String:
    return _current_zone_id


func get_active_bike() -> RigidBody2D:
    if _current_zone != null and is_instance_valid(_current_zone) and _current_zone.has_method("get_bike"):
        return _current_zone.get_bike()
    return null


func get_active_camera() -> Camera2D:
    if _current_zone != null and is_instance_valid(_current_zone) and _current_zone.has_method("get_camera"):
        return _current_zone.get_camera()
    return null


func get_connected_portal_count() -> int:
    return _connected_portals.size()


func get_world_state() -> Dictionary:
    var bike: RigidBody2D = get_active_bike()
    return {
        "current_zone_id": _current_zone_id,
        "current_spawn_id": _current_spawn_id,
        "is_transitioning": _is_transitioning,
        "transition_count": _transition_count,
        "portal_count": _connected_portals.size(),
        "zone_container_children": _zone_container.get_child_count() if _zone_container != null else 0,
        "has_bike": bike != null,
        "has_camera": get_active_camera() != null,
        "bike_position": bike.global_position if bike != null else Vector2.ZERO
    }
