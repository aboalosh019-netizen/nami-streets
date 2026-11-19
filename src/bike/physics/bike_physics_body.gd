class_name BikePhysicsBody
extends RigidBody2D

const BikePhysicsConfigScript = preload("res://src/bike/physics/bike_physics_config.gd")
const WheelSuspensionScript = preload("res://src/bike/physics/wheel_suspension.gd")
const BikeBalanceScript = preload("res://src/bike/physics/bike_balance.gd")

@export var config: Resource

var front_wheel: WheelSuspensionScript
var rear_wheel: WheelSuspensionScript
var balance: BikeBalanceScript


func _ready() -> void:
    if config == null:
        config = BikePhysicsConfigScript.new()

    front_wheel = WheelSuspensionScript.new()
    rear_wheel = WheelSuspensionScript.new()
    balance = BikeBalanceScript.new()

    apply_config()


func apply_config() -> void:
    mass = float(config.mass)
    inertia = float(config.inertia)
    center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = config.center_of_mass_offset
    linear_damp = float(config.linear_damp)
    angular_damp = float(config.angular_damp)
    can_sleep = false

    front_wheel.configure(
        "front",
        config.front_wheel_offset,
        float(config.front_wheel_radius),
        float(config.front_rest_length),
        float(config.front_stiffness),
        float(config.front_compression_damping),
        float(config.front_rebound_damping)
    )

    rear_wheel.configure(
        "rear",
        config.rear_wheel_offset,
        float(config.rear_wheel_radius),
        float(config.rear_rest_length),
        float(config.rear_stiffness),
        float(config.rear_compression_damping),
        float(config.rear_rebound_damping)
    )

    balance.configure(
        float(config.restoring_torque_strength),
        float(config.balance_angular_damping),
        float(config.air_angular_damping),
        float(config.max_stable_angle_rad)
    )


func _physics_process(delta: float) -> void:
    if delta <= 0.0:
        return

    var space_state := get_world_2d().direct_space_state
    if space_state == null:
        return

    var com_global: Vector2 = get_center_of_mass_global()
    var exclude_rids: Array[RID] = [get_rid()]
    var mask: int = int(config.suspension_collision_mask)

    front_wheel.update_from_space_state(
        space_state,
        global_transform,
        com_global,
        linear_velocity,
        angular_velocity,
        exclude_rids,
        mask,
        delta
    )

    rear_wheel.update_from_space_state(
        space_state,
        global_transform,
        com_global,
        linear_velocity,
        angular_velocity,
        exclude_rids,
        mask,
        delta
    )

    _apply_wheel_forces(front_wheel, delta)
    _apply_wheel_forces(rear_wheel, delta)

    var forward_speed: float = linear_velocity.dot(global_transform.x.normalized())
    var balance_torque: float = balance.compute_torque(
        rotation,
        angular_velocity,
        front_wheel.is_grounded,
        rear_wheel.is_grounded,
        front_wheel.contact_normal,
        rear_wheel.contact_normal,
        forward_speed
    )
    apply_torque(balance_torque)


func _apply_wheel_forces(wheel: WheelSuspensionScript, delta: float) -> void:
    if not wheel.is_grounded:
        return

    var suspension_force: Vector2 = wheel.contact_normal * wheel.total_force
    var mount_offset: Vector2 = wheel.ray_origin_global - global_position
    apply_force(suspension_force, mount_offset)

    var speed: float = wheel.linear_ground_speed
    if absf(speed) > 0.01:
        var ramp: float = minf(1.0, absf(speed) / 5.0)
        var resist_mag: float = float(config.rolling_resistance) * float(config.traction_grip) * ramp
        var max_stop_force: float = (absf(speed) * mass * 0.25) / delta
        resist_mag = minf(resist_mag, max_stop_force)
        var resist_force: Vector2 = -wheel.surface_tangent * signf(speed) * resist_mag
        var wheel_offset: Vector2 = wheel.wheel_center_global - global_position
        apply_force(resist_force, wheel_offset)


func get_center_of_mass_global() -> Vector2:
    return global_transform * center_of_mass


func is_grounded() -> bool:
    return front_wheel.is_grounded or rear_wheel.is_grounded


func get_grounded_wheel_count() -> int:
    return int(front_wheel.is_grounded) + int(rear_wheel.is_grounded)


func get_telemetry() -> Dictionary:
    return {
        "position": global_position,
        "rotation": rotation,
        "linear_velocity": linear_velocity,
        "angular_velocity": angular_velocity,
        "center_of_mass_global": get_center_of_mass_global(),
        "front_grounded": front_wheel.is_grounded,
        "rear_grounded": rear_wheel.is_grounded,
        "front_compression": front_wheel.compression,
        "rear_compression": rear_wheel.compression,
        "front_force": front_wheel.total_force,
        "rear_force": rear_wheel.total_force,
        "is_stable": balance.is_stable,
        "target_angle": balance.target_angle_rad
    }
