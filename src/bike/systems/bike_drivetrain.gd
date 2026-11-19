class_name BikeDrivetrain
extends RefCounted

const BikeDrivetrainConfigScript = preload("res://src/bike/systems/bike_drivetrain_config.gd")

var config: Resource
var current_gear: int = 1
var throttle: float = 0.0
var clutch_engagement: float = 1.0
var rpm: float = 1400.0
var is_rev_limiter_active: bool = false
var last_drive_force: float = 0.0


func _init(p_config: Resource = null) -> void:
    configure(p_config)


func configure(p_config: Resource) -> void:
    if p_config == null:
        config = BikeDrivetrainConfigScript.new()
    else:
        config = p_config
    rpm = float(config.idle_rpm)
    current_gear = clampi(current_gear, 0, get_max_gear())


func get_max_gear() -> int:
    var ratios: PackedFloat32Array = config.gear_ratios
    return maxi(0, ratios.size() - 1)


func set_gear(gear: int) -> void:
    current_gear = clampi(gear, 0, get_max_gear())


func shift_up() -> bool:
    if current_gear < get_max_gear():
        current_gear += 1
        return true
    return false


func shift_down() -> bool:
    if current_gear > 0:
        current_gear -= 1
        return true
    return false


func _torque_curve_factor(current_rpm: float) -> float:
    var idle: float = float(config.idle_rpm)
    var redline: float = float(config.redline_rpm)
    var span: float = maxf(1.0, redline - idle)
    var norm: float = clampf((current_rpm - idle) / span, 0.0, 1.0)
    # Peak torque around 65% of RPM band, strong mid-range without dead low-end
    var dist_from_peak: float = norm - 0.65
    return clampf(1.0 - (dist_from_peak * dist_from_peak) * 0.75, 0.65, 1.0)


func update(
    raw_gas: float,
    clutch_pressed: bool,
    shift_up_pressed: bool,
    shift_down_pressed: bool,
    wheel_ground_speed: float,
    is_rear_grounded: bool,
    delta: float
) -> float:
    if delta <= 0.0:
        return last_drive_force

    if shift_up_pressed and not shift_down_pressed:
        shift_up()
    elif shift_down_pressed and not shift_up_pressed:
        shift_down()

    var target_throttle: float = clampf(raw_gas, 0.0, 1.0)
    var throttle_rate: float = float(config.throttle_rise_rate) if target_throttle >= throttle else float(config.throttle_fall_rate)
    throttle = move_toward(throttle, target_throttle, throttle_rate * delta)

    var target_clutch: float = 0.0 if clutch_pressed else 1.0
    var clutch_rate: float = float(config.clutch_disengage_rate) if clutch_pressed else float(config.clutch_engage_rate)
    clutch_engagement = move_toward(clutch_engagement, target_clutch, clutch_rate * delta)

    var idle: float = float(config.idle_rpm)
    var redline: float = float(config.redline_rpm)
    var rev_limit: float = float(config.rev_limiter_rpm)
    var rev_reset: float = float(config.rev_limiter_reset_rpm)
    var ratios: PackedFloat32Array = config.gear_ratios
    var max_speeds: PackedFloat32Array = config.gear_max_speeds

    var free_target_rpm: float = lerpf(idle, rev_limit + 250.0, throttle)
    var is_free_revving: bool = (current_gear == 0) or (clutch_engagement <= 0.05) or (not is_rear_grounded)

    if is_free_revving:
        var rev_rate: float = float(config.free_rev_rate) if free_target_rpm >= rpm else float(config.free_fall_rate)
        rpm = move_toward(rpm, free_target_rpm, rev_rate * delta)
    else:
        var gear_max_speed: float = maxf(1.0, float(max_speeds[current_gear]))
        var speed_ratio: float = clampf(maxf(0.0, wheel_ground_speed) / gear_max_speed, 0.0, 1.25)
        var wheel_coupled_rpm: float = idle + speed_ratio * (redline - idle)
        var blended_target_rpm: float = lerpf(free_target_rpm, wheel_coupled_rpm, clutch_engagement)
        var blend_alpha: float = clampf(float(config.coupled_rpm_response) * delta, 0.0, 1.0)
        rpm = lerpf(rpm, blended_target_rpm, blend_alpha)

    if rpm >= rev_limit:
        is_rev_limiter_active = true
        rpm = rev_limit
    elif is_rev_limiter_active and rpm <= rev_reset:
        is_rev_limiter_active = false

    if current_gear == 0 or clutch_engagement <= 0.05 or not is_rear_grounded:
        last_drive_force = 0.0
        return last_drive_force

    var gear_ratio: float = float(ratios[current_gear])

    if is_rev_limiter_active:
        last_drive_force = 0.0
    elif throttle > 0.02:
        var torque_factor: float = _torque_curve_factor(rpm)
        last_drive_force = float(config.base_drive_force) * gear_ratio * torque_factor * throttle * clutch_engagement
    elif wheel_ground_speed > 5.0:
        last_drive_force = -float(config.engine_braking_force) * gear_ratio * 0.45 * clutch_engagement
    else:
        last_drive_force = 0.0

    return last_drive_force


func get_state() -> Dictionary:
    return {
        "gear": current_gear,
        "throttle": throttle,
        "clutch_engagement": clutch_engagement,
        "rpm": rpm,
        "rev_limiter": is_rev_limiter_active,
        "drive_force": last_drive_force
    }
