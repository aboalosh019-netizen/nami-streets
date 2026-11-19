class_name BikeCameraConfig
extends Resource

@export_group("Offset & Dead Zone")
@export var base_offset: Vector2 = Vector2(56.0, -32.0)
@export var dead_zone_half_size: Vector2 = Vector2(14.0, 10.0)

@export_group("Smooth Follow")
@export var follow_speed_x: float = 8.5
@export var follow_speed_y: float = 6.5

@export_group("Look Ahead & Speed Framing")
@export var look_ahead_time: float = 0.22
@export var max_look_ahead_x: float = 110.0
@export var vertical_look_ahead_time: float = 0.08
@export var max_look_ahead_y: float = 28.0
@export var look_ahead_smooth: float = 4.5
@export var min_framing_speed: float = 80.0
@export var max_framing_speed: float = 560.0
@export var speed_framing_extra_x: float = 34.0
@export var speed_framing_extra_y: float = -12.0
@export var framing_smooth: float = 3.5

@export_group("Zoom")
@export var base_zoom: float = 1.0
@export var high_speed_zoom: float = 0.80
@export var min_zoom: float = 0.72
@export var max_zoom: float = 1.25
@export var zoom_smooth: float = 3.0

@export_group("Camera Shake")
@export var max_shake_offset: Vector2 = Vector2(8.0, 6.0)
@export var shake_decay: float = 2.4
@export var shake_frequency: float = 42.0
