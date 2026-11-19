extends SceneTree


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    assert(root.has_node("GameConfig"))
    assert(root.has_node("GameManager"))
    assert(root.has_node("SceneManager"))

    var config = root.get_node("GameConfig")
    var manager = root.get_node("GameManager")

    assert(config.BASE_WIDTH == 640)
    assert(config.BASE_HEIGHT == 360)

    assert(manager.current_state == manager.GameState.MAIN_MENU)

    manager.change_state(manager.GameState.PLAYING)
    assert(manager.is_playing())

    manager.change_state(manager.GameState.PAUSED)
    assert(not manager.is_playing())

    manager.change_state(manager.GameState.MAIN_MENU)
    assert(not manager.is_playing())

    print("[CORE INTEGRATION TEST OK]")

    quit()
