class_name WheelSuspension
extends RefCounted

var wheel_name: String = "wheel"
var local_mount: Vector2 = Vector2.ZERO
var wheel_radius: float = 14.0
var rest_length: float = 14.0
var stiffness: float = 12000.0
var compression_damping: float = 1100.0
var rebound_damping: float = 1450.0

var is_grounded: bool = false
var compression: float = 0.0
var previous_compression: float = 0.0
var compression_velocity: float = 0.0
var compression_ratio: float = 0.0

var spring_force: float = 0.0
var damping_force: float = 0.0
var total_force: float = 0.0

var contact_point: Vector2 = Vector2.ZERO
var contact_normal: Vector2 = Vector2.UP
var surface_tangent: Vector2 = Vector2.RIGHT

var ray_origin_global: Vector2 = Vector2.ZERO
var ray_end_global: Vector2 = Vector2.ZERO
var wheel_center_global: Vector2 = Vector2.ZERO

var linear_ground_speed: float = 0.0
var wheel_angular_velocity: float = 0.0
var wheel_rotation: float = 0.0


func configure(
    p_name: String,
    p_local_mount: Vector2,
    p_radius: float,
    p_rest_length: float,
    p_stiffness: float,
    p_compression_damping: float,
    p_rebound_damping: float
) -> void:
    wheel_name = p_name
    local_mount = p_local_mount
    wheel_radius = p_radius
    rest_length = p_rest_length
    stiffness = p_stiffness
    compression_damping = p_compression_damping
    rebound_damping = p_rebound_damping


func get_max_ray_length() -> float:
    return rest_length + wheel_radius


func update_from_hit(
    has_contact: bool,
    hit_distance: float,
    hit_point: Vector2,
    hit_normal: Vector2,
    tangent_speed: float,
    delta: float,
    ray_origin: Vector2 = Vector2.ZERO,
    down_dir: Vector2 = Vector2.DOWN
) -> float:
    var dir := down_dir.normalized()
    ray_origin_global = ray_origin
    ray_end_global = ray_origin + dir * get_max_ray_length()

    if has_contact:
        is_grounded = true
        contact_point = hit_point
        contact_normal = hit_normal.normalized()
        surface_tangent = Vector2(-contact_normal.y, contact_normal.x).normalized()

        var current_length := clampf(hit_distance - wheel_radius, 0.0, rest_length)
        compression = clampf(rest_length - current_length, 0.0, rest_length)
        compression_ratio = compression / rest_length if rest_length > 0.0 else 0.0
        compression_velocity = (compression - previous_compression) / delta if delta > 0.0 else 0.0

        spring_force = compression * stiffness
        var damping_coeff := compression_damping if compression_velocity >= 0.0 else rebound_damping
        damping_force = compression_velocity * damping_coeff
        total_force = maxf(0.0, spring_force + damping_force)

        wheel_center_global = ray_origin + dir * current_length
        linear_ground_speed = tangent_speed
        if wheel_radius > 0.0:
            wheel_angular_velocity = linear_ground_speed / wheel_radius
    else:
        is_grounded = false
        contact_point = ray_end_global
        contact_normal = Vector2.UP
        surface_tangent = Vector2.RIGHT

        compression = 0.0
        compression_ratio = 0.0
        compression_velocity = 0.0
        spring_force = 0.0
        damping_force = 0.0
        total_force = 0.0

        wheel_center_global = ray_origin + dir * rest_length
        linear_ground_speed = 0.0
        wheel_angular_velocity = move_toward(wheel_angular_velocity, 0.0, 2.0 * delta)

    wheel_rotation = wrapf(wheel_rotation + wheel_angular_velocity * delta, -PI, PI)
    previous_compression = compression
    return total_force


func update_from_space_state(
    space_state: PhysicsDirectSpaceState2D,
    body_transform: Transform2D,
    center_of_mass_global: Vector2,
    body_linear_velocity: Vector2,
    body_angular_velocity: float,
    exclude_rids: Array[RID],
    collision_mask: int,
    delta: float
) -> float:
    var ray_origin := body_transform * local_mount
    var down_dir := body_transform.y.normalized()
    var ray_end := ray_origin + down_dir * get_max_ray_length()

    var query := PhysicsRayQueryParameters2D.create(ray_origin, ray_end, collision_mask, exclude_rids)
    query.hit_from_inside = false
    var hit := space_state.intersect_ray(query)

    if hit.is_empty():
        return update_from_hit(false, get_max_ray_length(), ray_end, Vector2.UP, 0.0, delta, ray_origin, down_dir)

    var hit_pos: Vector2 = hit["position"]
    var hit_norm: Vector2 = hit["normal"]
    var hit_dist: float = ray_origin.distance_to(hit_pos)

    var r := hit_pos - center_of_mass_global
    var point_vel := body_linear_velocity + Vector2(-body_angular_velocity * r.y, body_angular_velocity * r.x)
    var tangent := Vector2(-hit_norm.y, hit_norm.x).normalized()
    var tangent_speed := point_vel.dot(tangent)

    return update_from_hit(true, hit_dist, hit_pos, hit_norm, tangent_speed, delta, ray_origin, down_dir)
