class_name ZonePortal
extends Area2D

const BikePhysicsBodyScript = preload("res://src/bike/physics/bike_physics_body.gd")

signal portal_triggered(portal_id: String, target_zone_id: String, target_spawn_id: String)

@export var portal_id: String = "portal"
@export var target_zone_id: String = ""
@export var target_spawn_id: String = "default"
@export var cooldown_seconds: float = 0.75
@export var enabled: bool = true
@export var require_bike_body: bool = true

var _cooldown_remaining: float = 0.0
var _trigger_count: int = 0


func _ready() -> void:
    monitoring = true
    monitorable = false
    collision_layer = 0
    collision_mask = 2

    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
    if _cooldown_remaining > 0.0 and delta > 0.0:
        _cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)


func arm_cooldown(duration: float = -1.0) -> void:
    var seconds: float = cooldown_seconds if duration < 0.0 else duration
    _cooldown_remaining = maxf(0.0, seconds)


func reset_cooldown() -> void:
    _cooldown_remaining = 0.0


func is_on_cooldown() -> bool:
    return _cooldown_remaining > 0.0


func _is_valid_trigger_body(body: Node) -> bool:
    if not require_bike_body:
        return true
    return body is BikePhysicsBodyScript


func _on_body_entered(body: Node) -> void:
    if not enabled or target_zone_id.is_empty():
        return
    if _cooldown_remaining > 0.0:
        return
    if not _is_valid_trigger_body(body):
        return

    _cooldown_remaining = maxf(0.0, cooldown_seconds)
    _trigger_count += 1
    portal_triggered.emit(portal_id, target_zone_id, target_spawn_id)


func get_portal_state() -> Dictionary:
    return {
        "portal_id": portal_id,
        "target_zone_id": target_zone_id,
        "target_spawn_id": target_spawn_id,
        "enabled": enabled,
        "on_cooldown": is_on_cooldown(),
        "cooldown_remaining": _cooldown_remaining,
        "trigger_count": _trigger_count
    }
