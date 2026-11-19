class_name BikeVFX
extends Node2D

const BikePhysicsBodyScript = preload("res://src/bike/physics/bike_physics_body.gd")
const MAX_PARTICLES: int = 96

var _bike: BikePhysicsBodyScript = null
var _controller: Node = null
var _visual: Node = null
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

var _exhaust_timer: float = 0.0
var _flame_timer: float = 0.0
var _tire_timer: float = 0.0
var _spark_timer: float = 0.0

var flame_emitted: int = 0
var smoke_emitted: int = 0
var spark_emitted: int = 0
var rev_flame_active: bool = false


func _ready() -> void:
    z_index = 3
    _rng.seed = 1410
    _bike = get_parent() as BikePhysicsBodyScript
    if _bike != null:
        _controller = _bike.get_node_or_null("BikeController")
        _visual = _bike.get_node_or_null("BikeVisual")


func _spawn_particle(pos_global: Vector2, vel: Vector2, life: float, size: float, col: Color, gravity: float) -> void:
    if _particles.size() >= MAX_PARTICLES:
        _particles.pop_front()
    _particles.append({
        "pos": pos_global,
        "vel": vel,
        "life": life,
        "max_life": life,
        "size": size,
        "color": col,
        "gravity": gravity
    })


func _process(delta: float) -> void:
    if delta <= 0.0:
        return
    _update_emitters(delta)
    _step_particles(delta)
    queue_redraw()


func _update_emitters(delta: float) -> void:
    rev_flame_active = false
    if _bike == null or _controller == null or not _controller.has_method("get_controller_state"):
        return

    var st: Dictionary = _controller.call("get_controller_state")
    var throttle: float = float(st.get("throttle", 0.0))
    var rev_lim: bool = bool(st.get("rev_limiter", false))
    var brake_lvl: float = maxf(float(st.get("rear_brake_level", 0.0)), float(st.get("front_brake_level", 0.0)))
    var speed: float = _bike.linear_velocity.length()

    var tip_local: Vector2 = _visual.call("get_exhaust_tip_local") if (_visual != null and _visual.has_method("get_exhaust_tip_local")) else Vector2(-34.0, 10.0)
    var tip_global: Vector2 = _bike.to_global(tip_local)
    var back_dir: Vector2 = Vector2.LEFT.rotated(_bike.rotation)

    if rev_lim:
        rev_flame_active = true
        _flame_timer += delta
        if _flame_timer >= 0.03:
            _flame_timer = 0.0
            var f_vel: Vector2 = _bike.linear_velocity * 0.25 + back_dir * _rng.randf_range(90.0, 150.0) + Vector2(0, _rng.randf_range(-18, 18))
            var f_col: Color = Color(1.0, 0.55, 0.12, 0.95) if _rng.randf() > 0.35 else Color(0.45, 0.80, 1.0, 0.95)
            _spawn_particle(tip_global, f_vel, 0.14, _rng.randf_range(3.0, 5.5), f_col, -20.0)
            flame_emitted += 1
    else:
        _flame_timer = 0.0

    if throttle > 0.2:
        _exhaust_timer += delta
        if _exhaust_timer >= 0.07:
            _exhaust_timer = 0.0
            var s_vel: Vector2 = _bike.linear_velocity * 0.2 + back_dir * _rng.randf_range(35.0, 65.0) + Vector2(0, -18.0)
            _spawn_particle(tip_global, s_vel, 0.38, _rng.randf_range(2.5, 4.5), Color(0.55, 0.58, 0.64, 0.55), -35.0)
            smoke_emitted += 1

    var rear_grounded: bool = _bike.rear_wheel != null and _bike.rear_wheel.is_grounded
    var front_grounded: bool = _bike.front_wheel != null and _bike.front_wheel.is_grounded
    if rear_grounded and brake_lvl > 0.30 and speed > 60.0:
        _tire_timer += delta
        if _tire_timer >= 0.04:
            _tire_timer = 0.0
            var contact_g: Vector2 = _bike.rear_wheel.contact_point
            var t_vel: Vector2 = Vector2(-_bike.linear_velocity.x * 0.15 + _rng.randf_range(-15, 15), _rng.randf_range(-28, -10))
            _spawn_particle(contact_g, t_vel, 0.45, _rng.randf_range(4.0, 7.0), Color(0.84, 0.85, 0.88, 0.65), -25.0)
            smoke_emitted += 1

    if rear_grounded and not front_grounded and absf(_bike.rotation) > 0.62 and speed > 40.0:
        _spark_timer += delta
        if _spark_timer >= 0.04:
            _spark_timer = 0.0
            var tail_g: Vector2 = _bike.to_global(Vector2(-30.0, 4.0))
            var sp_vel: Vector2 = Vector2(-absf(_bike.linear_velocity.x) * 0.35, _rng.randf_range(-70, -25))
            _spawn_particle(tail_g, sp_vel, 0.24, 2.2, Color(1.0, 0.82, 0.25, 1.0), 220.0)
            spark_emitted += 1


func _step_particles(delta: float) -> void:
    var i: int = _particles.size() - 1
    while i >= 0:
        var pt: Dictionary = _particles[i]
        pt["life"] = float(pt["life"]) - delta
        if float(pt["life"]) <= 0.0:
            _particles.remove_at(i)
        else:
            var v: Vector2 = pt["vel"]
            v.y += float(pt["gravity"]) * delta
            pt["vel"] = v
            pt["pos"] = Vector2(pt["pos"]) + v * delta
        i -= 1


func _draw() -> void:
    for pt in _particles:
        var ratio: float = clampf(float(pt["life"]) / maxf(0.001, float(pt["max_life"])), 0.0, 1.0)
        var col: Color = pt["color"]
        col.a *= ratio
        var sz: float = float(pt["size"]) * (0.6 + 0.4 * ratio)
        var lp: Vector2 = to_local(Vector2(pt["pos"]))
        draw_rect(Rect2(lp - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), col, true)


func get_vfx_state() -> Dictionary:
    return {
        "active_particles": _particles.size(),
        "flame_emitted": flame_emitted,
        "smoke_emitted": smoke_emitted,
        "spark_emitted": spark_emitted,
        "rev_flame_active": rev_flame_active
    }
