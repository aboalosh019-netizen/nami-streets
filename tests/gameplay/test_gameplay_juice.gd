extends Node

const GameplayScene = preload("res://src/gameplay/gameplay.tscn")
const TEST_SAVE: String = "user://test_phase14_juice_save.json"

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
    var gp: Node = GameplayScene.instantiate()
    gp.set("save_path", TEST_SAVE)
    add_child(gp)
    await get_tree().process_frame

    var j0: Dictionary = gp.call("get_juice_state")
    _check(bool(j0["camera_bound"]), "Gameplay binds active BikeCamera")
    _check(not bool(j0["physics_debug_enabled"]), "PhysicsDebug hidden in Gameplay")

    var ctrl: Node = gp.get("_active_controller")
    ctrl.call("set_input_override", {"gas": 1.0, "clutch": true})
    for _i in range(120):
        await get_tree().process_frame
        if int(gp.call("get_juice_state")["shake_count"]) > 0:
            break
    var j1: Dictionary = gp.call("get_juice_state")
    _check(int(j1["shake_count"]) > 0 and int(j1["haptic_count"]) > 0, "Rev-limiter triggers shake & haptics")

    gp.call("_on_combo_reset", "collision")
    var j2: Dictionary = gp.call("get_juice_state")
    _check(int(j2["shake_count"]) > int(j1["shake_count"]) and int(j2["haptic_count"]) > int(j1["haptic_count"]), "Collision triggers shake & haptics")

    gp.get("save_store").call("delete_save")
    gp.queue_free()
    await get_tree().process_frame

    if failures == 0:
        print("[GAMEPLAY JUICE TEST OK]")
        get_tree().quit(0)
    else:
        push_error("[GAMEPLAY JUICE TEST FAILED]")
        get_tree().quit(1)
