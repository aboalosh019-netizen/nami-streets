class_name BikeDrivetrainConfig
extends Resource

@export_group("Engine & Gears")
@export var gear_ratios: PackedFloat32Array = PackedFloat32Array([0.0, 3.1, 2.2, 1.65, 1.28, 1.0])
@export var gear_max_speeds: PackedFloat32Array = PackedFloat32Array([0.0, 190.0, 310.0, 440.0, 580.0, 740.0])
@export var idle_rpm: float = 1400.0
@export var redline_rpm: float = 9500.0
@export var rev_limiter_rpm: float = 10200.0
@export var rev_limiter_reset_rpm: float = 9800.0
@export var base_drive_force: float = 11500.0
@export var engine_braking_force: float = 3600.0

@export_group("Response Rates")
@export var throttle_rise_rate: float = 7.5
@export var throttle_fall_rate: float = 10.5
@export var clutch_engage_rate: float = 9.0
@export var clutch_disengage_rate: float = 14.0
@export var free_rev_rate: float = 9500.0
@export var free_fall_rate: float = 5500.0
@export var coupled_rpm_response: float = 18.0

@export_group("Brakes")
@export var rear_brake_force: float = 34000.0
@export var front_brake_force: float = 42000.0
@export var brake_rise_rate: float = 10.0
@export var brake_fall_rate: float = 14.0

@export_group("Rider Lean & Pitch")
@export var lean_back_torque: float = 1600000.0
@export var lean_forward_torque: float = 1400000.0
@export var air_lean_scale: float = 0.15
@export var drive_pitch_torque_factor: float = 45.0
@export var front_brake_dive_torque_factor: float = 35.0
