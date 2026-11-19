extends Node2D

const BikeScene = preload("res://src/bike/controller/controllable_bike.tscn")
const Applier = preload("res://src/economy/bike_upgrade_applier.gd")
var failures: int = 0

func _ready() -> void:
    call_deferred("_run")

func _check(cond: bool, desc: String) -> void:
    if cond:
        print("[PASS] ", desc)
    else:
        failures += 1
        push_error("[FAIL] " + desc)

func _run() -> void:
    var floor_body := StaticBody2D.new()
    floor_body.position = Vector2(0, 80)
    floor_body.collision_layer = 1
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(2000, 40)
    shape.shape = rect
    floor_body.add_child(shape)
    add_child(floor_body)

    var bike: RigidBody2D = BikeScene.instantiate() as RigidBody2D
    bike.position = Vector2(0, 20)
    add_child(bike)

    var vis: Node = bike.get_node_or_null("BikeVisual")
    var vfx: Node = bike.get_node_or_null("BikeVFX")
    var ctrl: Node = bike.get_node_or_null("BikeController")
    _check(vis != null and vfx != null and ctrl != null, "BikeVisual and BikeVFX attached")

    Applier.apply_bike_profile(bike, "cg125")
    var tip_cg: Vector2 = vis.call("get_visual_state")["exhaust_tip_local"]
    Applier.apply_bike_profile(bike, "max")
    var st_max: Dictionary = vis.call("get_visual_state")
    Applier.apply_bike_profile(bike, "tmax")
    var st_tmax: Dictionary = vis.call("get_visual_state")
    _check(str(st_max["bike_id"]) == "max" and str(st_tmax["bike_id"]) == "tmax", "Applier switches models")
    _check(tip_cg != Vector2(st_tmax["exhaust_tip_local"]), "Models have distinct exhaust tips")

    ctrl.call("set_input_override", {"gas": 1.0, "clutch": true})
    for _i in range(120):
        await get_tree().process_frame
        if int(vfx.call("get_vfx_state")["flame_emitted"]) > 0:
            break
    var vst1: Dictionary = vfx.call("get_vfx_state")
    _check(int(vst1["smoke_emitted"]) > 0 and int(vst1["flame_emitted"]) > 0, "Throttle smoke & rev-limiter flame emitted")

    ctrl.call("set_input_override", {"gas": 0.0, "brake": 1.0})
    bike.linear_velocity = Vector2(220.0, 0.0)
    for _i in range(15):
        await get_tree().physics_frame
    _check(bool(vis.call("get_visual_state")["brake_light_on"]), "Brake light turns on")
    _check(int(vfx.call("get_vfx_state")["smoke_emitted"]) > int(vst1["smoke_emitted"]), "Braking at speed emits tire smoke")

    if failures == 0:
        print("[BIKE VISUAL & VFX TEST OK]")
        get_tree().quit(0)
    else:
        push_error("[BIKE VISUAL & VFX TEST FAILED]")
        get_tree().quit(1)
