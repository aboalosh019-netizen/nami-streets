class_name BikeVisual
extends Node2D

const BikePhysicsBodyScript = preload("res://src/bike/physics/bike_physics_body.gd")

@export var bike_id: String = "cg125"

const PROFILES: Dictionary = {
    "cg125": {
        "primary": Color(0.84, 0.14, 0.16, 1.0),
        "accent": Color(0.95, 0.78, 0.22, 1.0),
        "frame": Color(0.16, 0.17, 0.20, 1.0),
        "chrome": Color(0.82, 0.86, 0.90, 1.0),
        "seat": Color(0.11, 0.11, 0.13, 1.0),
        "exhaust_tip": Vector2(-35.0, 13.0),
        "style": "classic"
    },
    "max": {
        "primary": Color(0.12, 0.46, 0.92, 1.0),
        "accent": Color(0.90, 0.94, 0.98, 1.0),
        "frame": Color(0.12, 0.14, 0.18, 1.0),
        "chrome": Color(0.55, 0.60, 0.68, 1.0),
        "seat": Color(0.10, 0.11, 0.15, 1.0),
        "exhaust_tip": Vector2(-33.0, 6.0),
        "style": "sport"
    },
    "tmax": {
        "primary": Color(0.20, 0.22, 0.27, 1.0),
        "accent": Color(0.94, 0.68, 0.16, 1.0),
        "frame": Color(0.10, 0.11, 0.14, 1.0),
        "chrome": Color(0.75, 0.78, 0.82, 1.0),
        "seat": Color(0.14, 0.14, 0.17, 1.0),
        "exhaust_tip": Vector2(-34.0, 4.0),
        "style": "maxi"
    }
}

var _bike: BikePhysicsBodyScript = null
var _controller: Node = null
var _front_local: Vector2 = Vector2(26.0, 18.0)
var _rear_local: Vector2 = Vector2(-26.0, 18.0)
var _front_rot: float = 0.0
var _rear_rot: float = 0.0
var _wheel_radius: float = 14.0
var _rider_lean: float = 0.0
var _brake_light_on: bool = false
var _rev_limiter: bool = false


func _ready() -> void:
    z_index = 2
    _bike = get_parent() as BikePhysicsBodyScript
    if _bike != null:
        _controller = _bike.get_node_or_null("BikeController")
    set_bike_model(bike_id)


func set_bike_model(new_id: String) -> void:
    var key: String = new_id.to_lower()
    bike_id = key if PROFILES.has(key) else "cg125"
    queue_redraw()


func _get_profile() -> Dictionary:
    return PROFILES.get(bike_id, PROFILES["cg125"])


func get_exhaust_tip_local() -> Vector2:
    return Vector2(_get_profile()["exhaust_tip"])


func get_rear_contact_local() -> Vector2:
    return _rear_local + Vector2(0.0, _wheel_radius)


func _process(delta: float) -> void:
    if _bike != null and _bike.front_wheel != null and _bike.rear_wheel != null:
        _front_local = to_local(_bike.front_wheel.wheel_center_global)
        _rear_local = to_local(_bike.rear_wheel.wheel_center_global)
        _front_rot = _bike.front_wheel.wheel_rotation
        _rear_rot = _bike.rear_wheel.wheel_rotation
        _wheel_radius = _bike.rear_wheel.wheel_radius

    if _controller != null and _controller.has_method("get_controller_state"):
        var st: Dictionary = _controller.call("get_controller_state")
        var target_lean: float = float(st.get("lean_input", 0.0))
        _rider_lean = lerpf(_rider_lean, target_lean, clampf(delta * 10.0, 0.0, 1.0))
        _brake_light_on = float(st.get("rear_brake_level", 0.0)) > 0.1 or float(st.get("front_brake_level", 0.0)) > 0.1
        _rev_limiter = bool(st.get("rev_limiter", false))

    queue_redraw()


func _draw() -> void:
    var p: Dictionary = _get_profile()
    var primary: Color = p["primary"]
    var accent: Color = p["accent"]
    var frame: Color = p["frame"]
    var chrome: Color = p["chrome"]
    var seat: Color = p["seat"]
    var style: String = str(p["style"])

    # Headlight beam
    draw_colored_polygon(PackedVector2Array([
        Vector2(24, -12), Vector2(96, -24), Vector2(96, 12), Vector2(24, -4)
    ]), Color(1.0, 0.95, 0.72, 0.14))

    # Wheels
    _draw_wheel(_rear_local, _rear_rot, _wheel_radius, chrome, style == "maxi")
    _draw_wheel(_front_local, _front_rot, _wheel_radius, chrome, style == "maxi")

    # Suspension: swingarm, rear shock, front forks
    draw_line(Vector2(-6, 5), _rear_local, frame, 4.0)
    draw_line(Vector2(-15, -6), _rear_local + Vector2(2, -2), accent, 2.5)
    draw_line(Vector2(17, -14), _front_local, chrome, 3.0)
    draw_line(Vector2(17, -14), Vector2(17, -14).lerp(_front_local, 0.45), frame, 4.5)

    # Engine block & exhaust pipe
    draw_rect(Rect2(-8, -3, 18, 12), Color(0.28, 0.30, 0.34, 1.0), true)
    draw_rect(Rect2(-6, -1, 14, 2), chrome, true)
    draw_rect(Rect2(-6, 3, 14, 2), chrome, true)
    var tip: Vector2 = get_exhaust_tip_local()
    draw_line(Vector2(6, 7), Vector2(-12, 11), chrome, 3.0)
    draw_line(Vector2(-12, 11), tip, chrome if style == "classic" else frame, 5.0)
    draw_circle(tip, 2.2, Color(0.1, 0.1, 0.12, 1.0))

    # Chassis & bodywork by model
    if style == "classic":
        # CG125 boxy tank, flat seat, classic round lamp
        draw_colored_polygon(PackedVector2Array([
            Vector2(-4, -14), Vector2(15, -15), Vector2(17, -6), Vector2(-4, -5)
        ]), primary)
        draw_line(Vector2(-2, -10), Vector2(14, -10), accent, 2.0)
        draw_colored_polygon(PackedVector2Array([
            Vector2(-24, -10), Vector2(-3, -11), Vector2(-3, -5), Vector2(-24, -5)
        ]), seat)
        draw_rect(Rect2(19, -15, 5, 7), Color(0.98, 0.95, 0.72, 1.0), true)
    elif style == "sport":
        # Max 150 sharp shrouds & upswept tail
        draw_colored_polygon(PackedVector2Array([
            Vector2(-4, -15), Vector2(16, -16), Vector2(21, -4), Vector2(-5, -4)
        ]), primary)
        draw_colored_polygon(PackedVector2Array([
            Vector2(5, -13), Vector2(18, -11), Vector2(15, -6), Vector2(3, -8)
        ]), accent)
        draw_colored_polygon(PackedVector2Array([
            Vector2(-26, -14), Vector2(-4, -10), Vector2(-4, -5), Vector2(-22, -8)
        ]), seat)
        draw_colored_polygon(PackedVector2Array([
            Vector2(18, -17), Vector2(25, -13), Vector2(21, -8), Vector2(16, -11)
        ]), primary)
        draw_rect(Rect2(22, -14, 4, 5), Color(0.85, 0.95, 1.0, 1.0), true)
    else:
        # T-Max 560 maxi body, tall windshield, wide stepped seat
        draw_colored_polygon(PackedVector2Array([
            Vector2(-25, -12), Vector2(22, -16), Vector2(26, -3), Vector2(12, 8), Vector2(-18, 6)
        ]), primary)
        draw_line(Vector2(-18, -5), Vector2(20, -10), accent, 2.5)
        draw_colored_polygon(PackedVector2Array([
            Vector2(-23, -14), Vector2(-10, -14), Vector2(-6, -10), Vector2(6, -10), Vector2(6, -6), Vector2(-23, -6)
        ]), seat)
        draw_line(Vector2(16, -16), Vector2(11, -26), Color(0.65, 0.85, 0.98, 0.75), 2.5)
        draw_rect(Rect2(23, -14, 4, 6), Color(0.95, 0.98, 1.0, 1.0), true)

    # Brake / tail light
    var tail_pos := Vector2(-25.0, -10.0 if style != "classic" else -8.0)
    if _brake_light_on:
        draw_circle(tail_pos, 6.0, Color(1.0, 0.12, 0.12, 0.35))
        draw_rect(Rect2(tail_pos - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.2, 0.2, 1.0), true)
    else:
        draw_rect(Rect2(tail_pos - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.55, 0.08, 0.08, 1.0), true)

    # Handlebars & rider
    draw_line(Vector2(15, -15), Vector2(11, -20), chrome, 2.5)
    _draw_rider(style, accent)


func _draw_wheel(center: Vector2, rot: float, rad: float, rim_col: Color, alloy: bool) -> void:
    draw_circle(center, rad, Color(0.08, 0.08, 0.10, 1.0))
    draw_circle(center, rad * 0.62, Color(0.18, 0.19, 0.22, 1.0))
    draw_arc(center, rad * 0.62, 0.0, TAU, 16, rim_col, 1.6)
    var spokes: int = 5 if alloy else 6
    for i in range(spokes):
        var a: float = rot + TAU * float(i) / float(spokes)
        draw_line(center, center + Vector2.RIGHT.rotated(a) * (rad * 0.60), rim_col, 1.8 if alloy else 1.1)
    draw_circle(center, 2.6, rim_col)


func _draw_rider(style: String, accent: Color) -> void:
    var lean_x: float = _rider_lean * 7.0 + (3.0 if style == "sport" else 0.0)
    var hip := Vector2(-10.0, -12.0)
    var shoulder := Vector2(-5.0 + lean_x, -28.0)
    var head := shoulder + Vector2(3.0 + lean_x * 0.25, -7.0)
    var hand := Vector2(11.0, -20.0)
    var foot := Vector2(-3.0, 5.0)
    var knee := Vector2(2.0, -4.0)

    draw_line(hip, knee, Color(0.16, 0.22, 0.34, 1.0), 4.5)
    draw_line(knee, foot, Color(0.14, 0.18, 0.28, 1.0), 4.0)
    draw_line(hip, shoulder, Color(0.15, 0.16, 0.20, 1.0), 6.5)
    draw_line(shoulder, hand, Color(0.22, 0.24, 0.28, 1.0), 3.5)
    draw_circle(head, 5.5, Color(0.92, 0.93, 0.96, 1.0))
    draw_rect(Rect2(head + Vector2(1.0, -2.5), Vector2(4.5, 3.0)), Color(0.08, 0.12, 0.18, 1.0), true)
    draw_line(head + Vector2(-4.5, -1.0), head + Vector2(1.0, -1.0), accent, 1.5)


func get_visual_state() -> Dictionary:
    return {
        "bike_id": bike_id,
        "front_wheel_local": _front_local,
        "rear_wheel_local": _rear_local,
        "rider_lean": _rider_lean,
        "brake_light_on": _brake_light_on,
        "rev_limiter": _rev_limiter,
        "exhaust_tip_local": get_exhaust_tip_local()
    }
