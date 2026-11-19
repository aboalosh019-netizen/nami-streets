extends Node

var failures: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_run_flow")


func _check(cond: bool, desc: String) -> void:
    if cond:
        print("[PASS] ", desc)
    else:
        failures += 1
        push_error("[FAIL] " + desc)


func _wait_for_scene(expected_name: String, max_frames: int = 30) -> Node:
    for _i in range(max_frames):
        var cur: Node = get_tree().current_scene
        if cur != null and cur.name == expected_name:
            return cur
        await get_tree().process_frame
    return get_tree().current_scene


func _run_flow() -> void:
    # Keep runner alive across SceneManager transitions
    get_tree().current_scene = null
    var sm: Node = get_node_or_null("/root/SceneManager")
    var audio: Node = get_node_or_null("/root/AudioManager")
    var gm: Node = get_node_or_null("/root/GameManager")

    _check(sm != null and audio != null and gm != null, "Autoloads ready")

    # 1. Load MainMenu
    sm.call("change_scene", "res://src/ui/main_menu.tscn")
    var menu: Node = await _wait_for_scene("MainMenu")
    _check(menu != null and menu.name == "MainMenu", "MainMenu loaded via SceneManager")
    _check(bool(audio.call("is_menu_music_playing")), "Menu music playing in MainMenu")
    _check(int(gm.get("current_state")) == 0, "GameManager state is MAIN_MENU")

    # 2. Press Play -> transition to Gameplay
    menu.call("_on_play_pressed")
    var gameplay: Node = await _wait_for_scene("Gameplay")
    _check(gameplay != null and gameplay.name == "Gameplay", "Play transitions to Gameplay scene")
    _check(not bool(audio.call("is_menu_music_playing")), "Menu music stopped in Gameplay")
    var a_play: Dictionary = audio.call("get_audio_state")
    _check(bool(a_play["engine_active"]) and bool(a_play["engine_playing"]), "Engine audio active in Gameplay")

    # 3. Pause -> engine audio pauses
    var hud: Node = gameplay.get_node("UI/GameplayHUD")
    var pause_menu: Node = gameplay.get_node("UI/PauseMenu")
    hud.emit_signal("pause_requested")
    await get_tree().process_frame
    _check(get_tree().paused and bool(audio.call("get_audio_state")["engine_paused"]), "Pause pauses engine audio")

    # 4. Main Menu button -> transition back to MainMenu
    pause_menu.call("_on_main_menu_pressed")
    var menu2: Node = await _wait_for_scene("MainMenu")
    _check(menu2 != null and menu2.name == "MainMenu", "Pause Main Menu returns to MainMenu scene")
    _check(not get_tree().paused, "Returning to MainMenu unpauses SceneTree")
    var a_back: Dictionary = audio.call("get_audio_state")
    _check(not bool(a_back["engine_playing"]) and bool(a_back["music_playing"]), "Engine stopped and menu music resumed")

    if failures == 0:
        print("[PHASE 13 FLOW TEST OK]")
        get_tree().quit(0)
    else:
        push_error("[PHASE 13 FLOW TEST FAILED]")
        get_tree().quit(1)
