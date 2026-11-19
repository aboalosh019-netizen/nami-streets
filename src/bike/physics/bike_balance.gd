class_name BikeBalance
extends RefCounted

var restoring_torque_strength: float = 180000.0
var ground_angular_damping: float = 28000.0
var air_angular_damping: float = 6000.0
var max_stable_angle_rad: float = 1.15
var single_wheel_restore_scale: float = 0.35
var speed_damping_gain: float = 40.0
var max_speed_damping_bonus: float = 12000.0

var current_angle_rad: float = 0.0
var target_angle_rad: float = 0.0
var angle_error_rad: float = 0.0
var last_restoring_torque: float = 0.0
var last_damping_torque: float = 0.0
var last_total_torque: float = 0.0
var is_stable: bool = true


func configure(
    p_restoring_strength: float,
    p_ground_damping: float,
    p_air_damping: float,
    p_max_stable_angle_rad: float
) -> void:
    restoring_torque_strength = p_restoring_strength
    ground_angular_damping = p_ground_damping
    air_angular_damping = p_air_damping
    max_stable_angle_rad = p_max_stable_angle_rad


func _normal_to_slope_angle(normal: Vector2) -> float:
    return atan2(normal.x, -normal.y)


func compute_target_angle(
    front_grounded: bool,
    rear_grounded: bool,
    front_normal: Vector2,
    rear_normal: Vector2
) -> float:
    if front_grounded and rear_grounded:
        var avg_normal := (front_normal + rear_normal).normalized()
        if avg_normal.length_squared() > 0.0001:
            return _normal_to_slope_angle(avg_normal)
    elif front_grounded:
        return _normal_to_slope_angle(front_normal)
    elif rear_grounded:
        return _normal_to_slope_angle(rear_normal)
    return 0.0


func compute_torque(
    bike_angle_rad: float,
    angular_velocity: float,
    front_grounded: bool,
    rear_grounded: bool,
    front_normal: Vector2,
    rear_normal: Vector2,
    horizontal_speed: float
) -> float:
    current_angle_rad = wrapf(bike_angle_rad, -PI, PI)
    target_angle_rad = wrapf(
        compute_target_angle(front_grounded, rear_grounded, front_normal, rear_normal),
        -PI,
        PI
    )
    angle_error_rad = wrapf(target_angle_rad - current_angle_rad, -PI, PI)
    is_stable = absf(angle_error_rad) <= max_stable_angle_rad

    var grounded_count: int = int(front_grounded) + int(rear_grounded)

    if grounded_count == 0:
        last_restoring_torque = 0.0
        last_damping_torque = -angular_velocity * air_angular_damping
        last_total_torque = last_restoring_torque + last_damping_torque
        return last_total_torque

    var restore_scale: float = 1.0 if grounded_count == 2 else single_wheel_restore_scale
    var speed_bonus: float = minf(absf(horizontal_speed) * speed_damping_gain, max_speed_damping_bonus)

    last_restoring_torque = angle_error_rad * restoring_torque_strength * restore_scale
    last_damping_torque = -angular_velocity * (ground_angular_damping + speed_bonus)
    last_total_torque = last_restoring_torque + last_damping_torque
    return last_total_torque
