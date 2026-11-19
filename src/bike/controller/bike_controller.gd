class_name BikeController
extends Node

const BikePhysicsBodyScript = preload("res://src/bike/physics/bike_physics_body.gd")
const BikeDrivetrainConfigScript = preload("res://src/bike/systems/bike_drivetrain_config.gd")
const BikeDrivetrainScript = preload("res://src/bike/systems/bike_drivetrain.gd")

@export var drivetrain_config: Resource
@export var bike_body_path: NodePath = NodePath("..")
@export var enabled: bool = true

var drivetrain: BikeDrivetrainScript
var rear_brake_level: float = 0.0
var front_brake_level: float = 0.0
var lean_input: float = 0.0
var last_lean_torque: float = 0.0
var last_pitch_torque: float = 0.0

var _bike: BikePhysicsBodyScript = null
var _input_override: Dictionary = {}
var _use_input_override: bool = false


func _ready() -> void:
    process_physics_priority = -10

    if drivetrain_config == null:
        drivetrain_config = BikeDrivetrainConfigScript.new()

    drivetrain = BikeDrivetrainScript.new(drivetrain_config)
    _bike = get_node_or_null(bike_body_path) as BikePhysicsBodyScript


func set_input_override(input_data: Dictionary) -> void:
    _input_override = input_data.duplicate()
    _use_input_override = true


func clear_input_override() -> void:
    _input_override.clear()
    _use_input_override = false


func _read_input() -> Dictionary:
    if _use_input_override:
        return _input_override

    var input_manager: Node = get_node_or_null("/root/InputManager")
    if input_manager != null and input_manager.has_method("get_bike_input"):
        var data: Dictionary = input_manager.get_bike_input()
        return data

    return {
        "gas": 0.0,
        "brake": 0.0,
        "front_brake": 0.0,
        "lean_back": 0.0,
        "lean_forward": 0.0,
        "clutch": false,
        "shift_up": false,
        "shift_down": false
    }


func _physics_process(delta: float) -> void:
    if delta <= 0.0 or _bike == null:
        return
    if _bike.rear_wheel == null or _bike.front_wheel == null:
        return

    if not enabled:
        _bike.clear_control_commands()
        return

    var input_data: Dictionary = _read_input()
    var raw_gas: float = clampf(float(input_data.get("gas", 0.0)), 0.0, 1.0)
    var raw_rear_brake: float = clampf(float(input_data.get("brake", 0.0)), 0.0, 1.0)
    var raw_front_brake: float = clampf(float(input_data.get("front_brake", 0.0)), 0.0, 1.0)
    var raw_lean_back: float = clampf(float(input_data.get("lean_back", 0.0)), 0.0, 1.0)
    var raw_lean_forward: float = clampf(float(input_data.get("lean_forward", 0.0)), 0.0, 1.0)
    var clutch_pressed: bool = bool(input_data.get("clutch", false))
    var shift_up_pressed: bool = bool(input_data.get("shift_up", false))
    var shift_down_pressed: bool = bool(input_data.get("shift_down", false))

    var drive_force: float = drivetrain.update(
        raw_gas,
        clutch_pressed,
        shift_up_pressed,
        shift_down_pressed,
        _bike.rear_wheel.linear_ground_speed,
        _bike.rear_wheel.is_grounded,
        delta
    )

    var brake_rise: float = float(drivetrain_config.brake_rise_rate)
    var brake_fall: float = float(drivetrain_config.brake_fall_rate)

    var rear_rate: float = brake_rise if raw_rear_brake >= rear_brake_level else brake_fall
    rear_brake_level = move_toward(rear_brake_level, raw_rear_brake, rear_rate * delta)

    var front_rate: float = brake_rise if raw_front_brake >= front_brake_level else brake_fall
    front_brake_level = move_toward(front_brake_level, raw_front_brake, front_rate * delta)

    var rear_brake_cmd: float = rear_brake_level * float(drivetrain_config.rear_brake_force)
    var front_brake_cmd: float = front_brake_level * float(drivetrain_config.front_brake_force)

    lean_input = raw_lean_forward - raw_lean_back
    var grounded_count: int = _bike.get_grounded_wheel_count()
    var lean_scale: float = 1.0 if grounded_count > 0 else float(drivetrain_config.air_lean_scale)

    if lean_input > 0.0:
        last_lean_torque = lean_input * float(drivetrain_config.lean_forward_torque) * lean_scale
    elif lean_input < 0.0:
        last_lean_torque = lean_input * float(drivetrain_config.lean_back_torque) * lean_scale
    else:
        last_lean_torque = 0.0

    var pitch_torque: float = 0.0
    if _bike.rear_wheel.is_grounded and drive_force > 0.0:
        pitch_torque -= drive_force * float(drivetrain_config.drive_pitch_torque_factor)

    if _bike.front_wheel.is_grounded and front_brake_cmd > 0.0 and _bike.front_wheel.linear_ground_speed > 10.0:
        var speed_factor: float = minf(1.0, _bike.front_wheel.linear_ground_speed / 80.0)
        pitch_torque += front_brake_cmd * float(drivetrain_config.front_brake_dive_torque_factor) * speed_factor

    last_pitch_torque = pitch_torque

    _bike.apply_control_commands(
        drive_force,
        rear_brake_cmd,
        front_brake_cmd,
        last_lean_torque,
        last_pitch_torque
    )


func get_controller_state() -> Dictionary:
    var state: Dictionary = drivetrain.get_state()
    state["rear_brake_level"] = rear_brake_level
    state["front_brake_level"] = front_brake_level
    state["lean_input"] = lean_input
    state["lean_torque"] = last_lean_torque
    state["pitch_torque"] = last_pitch_torque
    return state
