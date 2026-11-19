extends SceneTree

const PauseMenuScript = preload("res://src/ui/pause_menu.gd")


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var menu = PauseMenuScript.new()
    root.add_child(menu)

    await process_frame

    assert(menu is Control)
    assert(menu.has_method("open_menu"))
    assert(menu.has_method("close_menu"))
    assert(menu.has_method("toggle_menu"))
    assert(menu.visible == false)

    print("[PAUSE MENU SCRIPT LOAD TEST OK]")

    menu.queue_free()
    quit()
