extends SceneTree

const SCENE = preload("res://src/ui/pause_menu.tscn")
const PAUSE_SCRIPT = preload("res://src/ui/pause_menu.gd")


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var menu = SCENE.instantiate()
    root.add_child(menu)

    await process_frame

    assert(menu.get_script() == PAUSE_SCRIPT)
    assert(menu.visible == false)
    assert(menu.has_method("open_menu"))
    assert(menu.has_method("close_menu"))

    print("[PAUSE MENU SCENE TEST OK]")

    menu.queue_free()
    quit()
