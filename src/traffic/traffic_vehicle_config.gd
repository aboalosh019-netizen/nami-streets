class_name TrafficVehicleConfig
extends Resource

@export var vehicle_type: String = "sedan"
@export var width: float = 84.0
@export var height: float = 32.0
@export var target_speed: float = 180.0
@export var acceleration: float = 140.0
@export var deceleration: float = 340.0
@export var safe_headway: float = 72.0
@export var caution_multiplier: float = 2.4
@export var near_miss_margin: Vector2 = Vector2(28.0, 24.0)
@export var body_color: Color = Color(0.24, 0.45, 0.72, 1.0)
@export var cabin_color: Color = Color(0.72, 0.84, 0.94, 1.0)


static func create_sedan() -> TrafficVehicleConfig:
    var cfg := new()
    cfg.vehicle_type = "sedan"
    cfg.width = 84.0
    cfg.height = 32.0
    cfg.target_speed = 190.0
    cfg.acceleration = 150.0
    cfg.deceleration = 340.0
    cfg.safe_headway = 70.0
    cfg.near_miss_margin = Vector2(28.0, 24.0)
    cfg.body_color = Color(0.24, 0.45, 0.72, 1.0)
    return cfg


static func create_pickup() -> TrafficVehicleConfig:
    var cfg := new()
    cfg.vehicle_type = "pickup"
    cfg.width = 96.0
    cfg.height = 36.0
    cfg.target_speed = 165.0
    cfg.acceleration = 130.0
    cfg.deceleration = 300.0
    cfg.safe_headway = 78.0
    cfg.near_miss_margin = Vector2(30.0, 24.0)
    cfg.body_color = Color(0.76, 0.34, 0.22, 1.0)
    return cfg


static func create_truck() -> TrafficVehicleConfig:
    var cfg := new()
    cfg.vehicle_type = "truck"
    cfg.width = 132.0
    cfg.height = 48.0
    cfg.target_speed = 125.0
    cfg.acceleration = 90.0
    cfg.deceleration = 240.0
    cfg.safe_headway = 92.0
    cfg.near_miss_margin = Vector2(34.0, 26.0)
    cfg.body_color = Color(0.78, 0.78, 0.80, 1.0)
    return cfg
