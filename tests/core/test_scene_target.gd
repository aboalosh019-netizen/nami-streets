extends Node2D


func _ready() -> void:
    call_deferred("_verify_transition")


func _verify_transition() -> void:
    if get_tree().current_scene != self:
        push_error("[SCENE TRANSITION TEST FAILED]")
        get_tree().quit(1)
        return

    print("[SCENE TRANSITION TEST OK]")
    get_tree().quit(0)
