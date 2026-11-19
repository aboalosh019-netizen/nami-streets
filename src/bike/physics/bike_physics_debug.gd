class_name BikePhysicsDebug
extends Node2D

const BikePhysicsBodyScript = preload("res://src/bike/physics/bike_physics_body.gd")
const WheelSuspensionScript = preload("res://src/bike/physics/wheel_suspension.gd")

@export var enabled: bool = true
@export var sync_with_game_config: bool = true
@export var velocity_scale: float = 0.15
@export var angle_indicator_length: float = 36.0

var _bike: BikePhysicsBodyScript = null


func _ready() -> void:
    _bike = get_parent() as BikePhysicsBodyScript

    if sync_with_game_config:
        var game_config: Node = get_node_or_null("/root/GameConfig")
        if game_config != null and "debug_overlay_enabled" in game_config:
            enabled = bool(game_config.debug_overlay_enabled)

    set_debug_enabled(enabled)


func set_debug_enabled(value: bool) -> void:
    enabled = value
    visible = value
    queue_redraw()


func is_debug_enabled() -> bool:
    return enabled


func toggle() -> void:
    set_debug_enabled(not enabled)


func _process(_delta: float) -> void:
    if enabled and _bike != null:
        queue_redraw()


func get_debug_snapshot() -> Dictionary:
    if _bike == null or _bike.front_wheel == null or _bike.rear_wheel == null:
        return {}

    var front: WheelSuspensionScript = _bike.front_wheel
    var rear: WheelSuspensionScript = _bike.rear_wheel

    return {
        "enabled": enabled,
        "bike_angle_rad": _bike.rotation,
        "bike_angle_deg": rad_to_deg(_bike.rotation),
        "center_of_mass_global": _bike.get_center_of_mass_global(),
        "velocity_vector": _bike.linear_velocity,
        "front_ray": {
            "origin": front.ray_origin_global,
            "end": front.ray_end_global
        },
        "rear_ray": {
            "origin": rear.ray_origin_global,
            "end": rear.ray_end_global
        },
        "front_contact_point": front.contact_point,
        "rear_contact_point": rear.contact_point,
        "front_suspension_line": {
            "from": front.ray_origin_global,
            "to": front.wheel_center_global,
            "grounded": front.is_grounded
        },
        "rear_suspension_line": {
            "from": rear.ray_origin_global,
            "to": rear.wheel_center_global,
            "grounded": rear.is_grounded
        }
    }


func _draw() -> void:
    if not enabled or _bike == null or _bike.front_wheel == null or _bike.rear_wheel == null:
        return

    _draw_wheel_debug(_bike.front_wheel)
    _draw_wheel_debug(_bike.rear_wheel)

    # Center of mass
    var com_local: Vector2 = to_local(_bike.get_center_of_mass_global())
    draw_circle(com_local, 3.0, Color(1.0, 0.2, 0.8, 1.0))
    draw_line(com_local + Vector2(-6.0, 0.0), com_local + Vector2(6.0, 0.0), Color(1.0, 0.2, 0.8, 1.0), 1.0)
    draw_line(com_local + Vector2(0.0, -6.0), com_local + Vector2(0.0, 6.0), Color(1.0, 0.2, 0.8, 1.0), 1.0)

    # Velocity vector
    var vel_end_global: Vector2 = _bike.get_center_of_mass_global() + _bike.linear_velocity * velocity_scale
    draw_line(com_local, to_local(vel_end_global), Color(0.2, 0.7, 1.0, 1.0), 1.5)

    # Bike angle (world horizon reference vs chassis heading)
    var horizon_end: Vector2 = to_local(_bike.get_center_of_mass_global() + Vector2(angle_indicator_length, 0.0))
    var heading_end: Vector2 = to_local(_bike.get_center_of_mass_global() + Vector2.RIGHT.rotated(_bike.rotation) * angle_indicator_length)
    draw_line(com_local, horizon_end, Color(0.8, 0.8, 0.8, 0.5), 1.0)
    draw_line(com_local, heading_end, Color(1.0, 1.0, 0.2, 1.0), 1.5)


func _draw_wheel_debug(wheel: WheelSuspensionScript) -> void:
    var ray_start: Vector2 = to_local(wheel.ray_origin_global)
    var ray_end: Vector2 = to_local(wheel.ray_end_global)
    var wheel_center: Vector2 = to_local(wheel.wheel_center_global)
    var contact_local: Vector2 = to_local(wheel.contact_point)

    # Raycast line
    draw_line(ray_start, ray_end, Color(0.7, 0.7, 0.7, 0.5), 1.0)

    # Suspension line
    var susp_color: Color = Color(0.2, 1.0, 0.4, 1.0) if wheel.is_grounded else Color(1.0, 0.6, 0.2, 1.0)
    draw_line(ray_start, wheel_center, susp_color, 2.0)

    # Wheel circle and rotation spoke
    draw_arc(wheel_center, wheel.wheel_radius, 0.0, TAU, 24, susp_color, 1.2)
    var spoke_end: Vector2 = wheel_center + Vector2.RIGHT.rotated(wheel.wheel_rotation) * wheel.wheel_radius
    draw_line(wheel_center, spoke_end, susp_color, 1.0)

    # Contact point and surface normal
    if wheel.is_grounded:
        draw_circle(contact_local, 2.5, Color(1.0, 0.2, 0.2, 1.0))
        var normal_end: Vector2 = to_local(wheel.contact_point + wheel.contact_normal * 16.0)
        draw_line(contact_local, normal_end, Color(0.2, 1.0, 1.0, 1.0), 1.2)
