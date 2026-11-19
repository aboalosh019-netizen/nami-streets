extends Node


func _ready() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var manager = get_node("/root/SceneManager")

    var result: Error = manager.change_scene(
        "res://tests/core/test_scene_target.tscn"
    )

    if result != OK:
        push_error("[SCENE TRANSITION TEST FAILED]")
        get_tree().quit(1)
