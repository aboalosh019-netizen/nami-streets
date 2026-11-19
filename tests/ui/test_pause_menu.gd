extends SceneTree

const PauseMenuScript = preload("res://src/ui/pause_menu.gd")


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var menu = PauseMenuScript.new()
    root.add_child(menu)

    await process_frame

    var game_manager = root.get_node_or_null("GameManager")

    assert(game_manager != null)

    menu.open_menu()

    assert(menu.visible)
    assert(paused)
    assert(game_manager.current_state == game_manager.GameState.PAUSED)

    print("[PAUSE ACTIVATION OK]")

    var resume_events := [0]
    menu.resume_requested.connect(func(): resume_events[0] += 1)

    menu._on_resume_pressed()

    assert(not menu.visible)
    assert(not paused)
    assert(game_manager.current_state == game_manager.GameState.PLAYING)
    assert(resume_events[0] == 1)

    print("[RESUME TEST OK]")

    var respawn_events := [0]
    menu.respawn_requested.connect(func(): respawn_events[0] += 1)
    menu._on_respawn_pressed()

    assert(respawn_events[0] == 1)

    print("[RESPAWN SIGNAL TEST OK]")
    print("[PAUSE MENU TEST OK]")

    menu.queue_free()
    quit()
