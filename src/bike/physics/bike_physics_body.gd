class_name BikePhysicsBody
extends RigidBody2D

const BikePhysicsConfigScript = preload("res://src/bike/physics/bike_physics_config.gd")
const WheelSuspensionScript = preload("res://src/bike/physics/wheel_suspension.gd")
const BikeBalanceScript = preload("res://src/bike/physics/bike_balance.gd")

@export var config: Resource

var front_wheel: WheelSuspensionScript
var rear_wheel: WheelSuspensionScript
var balance: BikeBalanceScript

var _cmd_rear_drive_force: float = 0.0
var _cmd_rear_brake_force: float = 0.0
var _cmd_front_brake_force: float = 0.0
var _cmd_lean_torque: float = 0.0
var _cmd_pitch_torque: float = 0.0


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


func apply_control_commands(
    rear_drive_force: float,
    rear_brake_force: float,
    front_brake_force: float,
    lean_torque: float,
    pitch_torque: float = 0.0
) -> void:
    _cmd_rear_drive_force = rear_drive_force
    _cmd_rear_brake_force = maxf(0.0, rear_brake_force)
    _cmd_front_brake_force = maxf(0.0, front_brake_force)
    _cmd_lean_torque = lean_torque
    _cmd_pitch_torque = pitch_torque


func clear_control_commands() -> void:
    _cmd_rear_drive_force = 0.0
    _cmd_rear_brake_force = 0.0
    _cmd_front_brake_force = 0.0
    _cmd_lean_torque = 0.0
    _cmd_pitch_torque = 0.0


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
    _apply_drive_and_brake_forces(delta)

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
    apply_torque(balance_torque + _cmd_lean_torque + _cmd_pitch_torque)


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


func _apply_drive_and_brake_forces(delta: float) -> void:
    var grip: float = float(config.traction_grip)

    if rear_wheel.is_grounded and absf(_cmd_rear_drive_force) > 0.01:
        if _cmd_rear_drive_force > 0.0:
            apply_central_force(rear_wheel.surface_tangent * (_cmd_rear_drive_force * grip))
        else:
            var speed: float = rear_wheel.linear_ground_speed
            if speed > 0.5:
                var ebrake_mag: float = minf(absf(_cmd_rear_drive_force) * grip, (speed * mass * 0.4) / delta)
                apply_central_force(-rear_wheel.surface_tangent * ebrake_mag)

    _apply_wheel_brake(rear_wheel, _cmd_rear_brake_force, grip, delta)
    _apply_wheel_brake(front_wheel, _cmd_front_brake_force, grip, delta)


func _apply_wheel_brake(wheel: WheelSuspensionScript, brake_force: float, grip: float, delta: float) -> void:
    if not wheel.is_grounded or brake_force <= 0.01:
        return

    var speed: float = wheel.linear_ground_speed
    if absf(speed) <= 0.05:
        return

    var ramp: float = minf(1.0, absf(speed) / 8.0)
    var brake_mag: float = brake_force * grip * ramp
    var max_stop_force: float = (absf(speed) * mass * 0.45) / delta
    brake_mag = minf(brake_mag, max_stop_force)
    apply_central_force(-wheel.surface_tangent * signf(speed) * brake_mag)


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
