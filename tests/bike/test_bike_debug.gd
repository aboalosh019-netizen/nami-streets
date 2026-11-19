extends Node2D

var _ticks: int = 0
var _finished: bool = false

@onready var bike: RigidBody2D = $Bike


func _ready() -> void:
    if not bike.has_node("PhysicsDebug"):
        print("[BIKE DEBUG TEST FAIL] PhysicsDebug child node missing")
        _finished = true
        get_tree().quit(1)


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1
    if _ticks >= 60:
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var debug_node: Node2D = bike.get_node("PhysicsDebug")

    # Test toggle off and back on
    debug_node.set_debug_enabled(false)
    var off_ok: bool = (not debug_node.is_debug_enabled()) and (not debug_node.visible)

    debug_node.toggle()
    var on_ok: bool = debug_node.is_debug_enabled() and debug_node.visible

    var snap: Dictionary = debug_node.get_debug_snapshot()

    var required_keys := [
        "enabled",
        "bike_angle_rad",
        "bike_angle_deg",
        "center_of_mass_global",
        "velocity_vector",
        "front_ray",
        "rear_ray",
        "front_contact_point",
        "rear_contact_point",
        "front_suspension_line",
        "rear_suspension_line"
    ]

    var keys_ok := true
    for key in required_keys:
        if not snap.has(key):
            print("[BIKE DEBUG TEST FAIL] Missing snapshot key: ", key)
            keys_ok = false

    var front_line: Dictionary = snap.get("front_suspension_line", {})
    var rear_line: Dictionary = snap.get("rear_suspension_line", {})
    var front_ray: Dictionary = snap.get("front_ray", {})

    var checks := {
        "toggle_off_works": off_ok,
        "toggle_on_works": on_ok,
        "all_keys_present": keys_ok,
        "front_grounded_in_debug": front_line.get("grounded", false) == true,
        "rear_grounded_in_debug": rear_line.get("grounded", false) == true,
        "ray_has_length": front_ray.get("origin", Vector2.ZERO).distance_to(front_ray.get("end", Vector2.ZERO)) > 20.0,
        "angle_is_float": snap.get("bike_angle_deg") is float
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[BIKE DEBUG TEST FAIL] ", key)
            all_ok = false

    print(
        "Debug snapshot -> enabled: ", snap.get("enabled"),
        " | angle_deg: ", snappedf(float(snap.get("bike_angle_deg", 0.0)), 0.01),
        " | com: ", snap.get("center_of_mass_global")
    )

    if all_ok:
        print("[BIKE DEBUG TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
