class_name BikePhysicsConfig
extends Resource

@export_group("Chassis")
@export var mass: float = 120.0
@export var inertia: float = 75000.0
@export var center_of_mass_offset: Vector2 = Vector2(0.0, 4.0)
@export var linear_damp: float = 0.08
@export var angular_damp: float = 0.15

@export_group("Wheels")
@export var front_wheel_offset: Vector2 = Vector2(26.0, 6.0)
@export var rear_wheel_offset: Vector2 = Vector2(-26.0, 6.0)
@export var front_wheel_radius: float = 14.0
@export var rear_wheel_radius: float = 14.0

@export_group("Front Suspension")
@export var front_rest_length: float = 14.0
@export var front_stiffness: float = 12000.0
@export var front_compression_damping: float = 1100.0
@export var front_rebound_damping: float = 1450.0

@export_group("Rear Suspension")
@export var rear_rest_length: float = 14.0
@export var rear_stiffness: float = 12000.0
@export var rear_compression_damping: float = 1100.0
@export var rear_rebound_damping: float = 1450.0

@export_group("Ground Contact")
@export var rolling_resistance: float = 18.0
@export var traction_grip: float = 1.0
@export var suspension_collision_mask: int = 1

@export_group("Balance")
@export var restoring_torque_strength: float = 180000.0
@export var balance_angular_damping: float = 28000.0
@export var air_angular_damping: float = 6000.0
@export var max_stable_angle_rad: float = 1.15
