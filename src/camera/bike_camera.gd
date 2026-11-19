class_name BikeCamera
extends Camera2D

const BikeCameraConfigScript = preload("res://src/camera/bike_camera_config.gd")

@export var config: Resource
@export var target_path: NodePath

var _target: Node2D = null
var _anchor_position: Vector2 = Vector2.ZERO
var _prev_target_position: Vector2 = Vector2.ZERO
var _has_initialized_anchor: bool = false

var _current_look_ahead: Vector2 = Vector2.ZERO
var _current_speed_framing: Vector2 = Vector2.ZERO
var _current_zoom: float = 1.0

var _shake_trauma: float = 0.0
var _shake_time: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
    process_physics_priority = 10
    position_smoothing_enabled = false

    if config == null:
        config = BikeCameraConfigScript.new()

    _current_zoom = clampf(
        float(config.base_zoom),
        float(config.min_zoom),
        float(config.max_zoom)
    )
    zoom = Vector2(_current_zoom, _current_zoom)

    if not target_path.is_empty():
        var resolved: Node2D = get_node_or_null(target_path) as Node2D
        if resolved != null:
            set_target(resolved, true)


func set_target(new_target: Node2D, snap: bool = true) -> void:
    _target = new_target
    _has_initialized_anchor = false
    if _target != null and snap:
        snap_to_target()


func snap_to_target() -> void:
    if _target == null or config == null:
        return

    var base_offset: Vector2 = config.base_offset
    _anchor_position = _target.global_position
    _prev_target_position = _target.global_position
    _has_initialized_anchor = true

    _current_look_ahead = Vector2.ZERO
    _current_speed_framing = Vector2.ZERO
    _current_zoom = clampf(
        float(config.base_zoom),
        float(config.min_zoom),
        float(config.max_zoom)
    )

    global_position = _anchor_position + base_offset
    zoom = Vector2(_current_zoom, _current_zoom)
    _shake_trauma = 0.0
    _shake_offset = Vector2.ZERO
    offset = Vector2.ZERO


func add_shake(amount: float) -> void:
    if amount <= 0.0:
        return
    _shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)


func clear_shake() -> void:
    _shake_trauma = 0.0
    _shake_offset = Vector2.ZERO
    offset = Vector2.ZERO


func set_world_limits(left: int, top: int, right: int, bottom: int) -> void:
    limit_left = left
    limit_top = top
    limit_right = right
    limit_bottom = bottom


func _get_target_velocity(delta: float) -> Vector2:
    if _target == null:
        return Vector2.ZERO

    if "linear_velocity" in _target:
        var lv: Vector2 = _target.get("linear_velocity")
        return lv

    if "velocity" in _target:
        var v: Vector2 = _target.get("velocity")
        return v

    if delta > 0.0 and _has_initialized_anchor:
        return (_target.global_position - _prev_target_position) / delta

    return Vector2.ZERO


func _physics_process(delta: float) -> void:
    if delta <= 0.0 or config == null:
        return

    if _target != null:
        if not _has_initialized_anchor:
            snap_to_target()
            return

        var target_pos: Vector2 = _target.global_position
        var target_vel: Vector2 = _get_target_velocity(delta)
        _prev_target_position = target_pos

        # 1. Dead zone update around anchor
        var dead_zone: Vector2 = config.dead_zone_half_size
        var dx: float = target_pos.x - _anchor_position.x
        var dy: float = target_pos.y - _anchor_position.y

        if absf(dx) > dead_zone.x:
            _anchor_position.x = target_pos.x - signf(dx) * dead_zone.x
        if absf(dy) > dead_zone.y:
            _anchor_position.y = target_pos.y - signf(dy) * dead_zone.y

        # 2. Look ahead
        var desired_look_ahead := Vector2(
            clampf(target_vel.x * float(config.look_ahead_time), -float(config.max_look_ahead_x), float(config.max_look_ahead_x)),
            clampf(target_vel.y * float(config.vertical_look_ahead_time), -float(config.max_look_ahead_y), float(config.max_look_ahead_y))
        )
        var look_alpha: float = 1.0 - exp(-float(config.look_ahead_smooth) * delta)
        _current_look_ahead = _current_look_ahead.lerp(desired_look_ahead, look_alpha)

        # 3. Speed-based framing
        var speed: float = target_vel.length()
        var min_spd: float = float(config.min_framing_speed)
        var max_spd: float = maxf(min_spd + 1.0, float(config.max_framing_speed))
        var speed_ratio: float = clampf((speed - min_spd) / (max_spd - min_spd), 0.0, 1.0)

        var dir_x: float = signf(target_vel.x) if absf(target_vel.x) > 5.0 else 0.0
        var desired_framing := Vector2(
            dir_x * float(config.speed_framing_extra_x) * speed_ratio,
            float(config.speed_framing_extra_y) * speed_ratio
        )
        var frame_alpha: float = 1.0 - exp(-float(config.framing_smooth) * delta)
        _current_speed_framing = _current_speed_framing.lerp(desired_framing, frame_alpha)

        # 4. Smooth follow toward desired camera position
        var base_offset: Vector2 = config.base_offset
        var desired_pos: Vector2 = _anchor_position + base_offset + _current_look_ahead + _current_speed_framing
        var follow_alpha_x: float = 1.0 - exp(-float(config.follow_speed_x) * delta)
        var follow_alpha_y: float = 1.0 - exp(-float(config.follow_speed_y) * delta)

        global_position = Vector2(
            lerpf(global_position.x, desired_pos.x, follow_alpha_x),
            lerpf(global_position.y, desired_pos.y, follow_alpha_y)
        )

        # 5. Speed-based zoom
        var desired_zoom: float = clampf(
            lerpf(float(config.base_zoom), float(config.high_speed_zoom), speed_ratio),
            float(config.min_zoom),
            float(config.max_zoom)
        )
        var zoom_alpha: float = 1.0 - exp(-float(config.zoom_smooth) * delta)
        _current_zoom = lerpf(_current_zoom, desired_zoom, zoom_alpha)
        zoom = Vector2(_current_zoom, _current_zoom)

    # 6. Bounded camera shake
    _update_shake(delta)


func _update_shake(delta: float) -> void:
    if _shake_trauma <= 0.0:
        _shake_offset = Vector2.ZERO
        offset = Vector2.ZERO
        return

    var decay: float = float(config.shake_decay)
    var freq: float = float(config.shake_frequency)
    var max_off: Vector2 = config.max_shake_offset

    _shake_time += delta * freq
    var intensity: float = _shake_trauma * _shake_trauma
    var wave_x: float = sin(_shake_time) * cos(_shake_time * 0.37)
    var wave_y: float = cos(_shake_time * 1.13) * sin(_shake_time * 0.53)

    _shake_offset = Vector2(
        clampf(wave_x * max_off.x * intensity, -max_off.x, max_off.x),
        clampf(wave_y * max_off.y * intensity, -max_off.y, max_off.y)
    )
    offset = _shake_offset

    _shake_trauma = maxf(0.0, _shake_trauma - decay * delta)
    if _shake_trauma <= 0.0:
        _shake_offset = Vector2.ZERO
        offset = Vector2.ZERO


func get_camera_state() -> Dictionary:
    return {
        "position": global_position,
        "anchor_position": _anchor_position,
        "look_ahead": _current_look_ahead,
        "speed_framing": _current_speed_framing,
        "zoom": _current_zoom,
        "shake_trauma": _shake_trauma,
        "shake_offset": _shake_offset
    }
