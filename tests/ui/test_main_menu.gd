extends Node

const MainMenuScene = preload("res://src/ui/main_menu.tscn")
const SaveStoreScript = preload("res://src/economy/save_store.gd")
const EconomyStateScript = preload("res://src/economy/player_economy_state.gd")
const TEST_SAVE: String = "user://test_phase13_main_menu_save.json"

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
    var store = SaveStoreScript.new(TEST_SAVE)
    var st = EconomyStateScript.new()
    st.add_cash(1800)
    store.save_state(st)

    var menu: Control = MainMenuScene.instantiate() as Control
    menu.set("save_path", TEST_SAVE)
    add_child(menu)

    var audio: Node = get_node_or_null("/root/AudioManager")
    var m0: Dictionary = menu.call("get_menu_state")
    _check(bool(m0["main_visible"]) and not bool(m0["garage_visible"]) and not bool(m0["settings_visible"]), "MainMenu opens cleanly")
    _check(int(m0["cash"]) == 1800 and str(m0["summary"]).contains("$1800"), "MainMenu loads saved cash into summary")
    _check(audio != null and bool(audio.call("is_menu_music_playing")), "MainMenu starts menu music")

    menu.call("_on_garage_pressed")
    var m_g: Dictionary = menu.call("get_menu_state")
    _check(bool(m_g["garage_visible"]) and not bool(m_g["main_visible"]), "Garage overlay opens from MainMenu")
    menu.get("_garage_menu").emit_signal("close_requested")
    _check(bool(menu.call("get_menu_state")["main_visible"]), "Closing Garage returns to MainMenu")

    menu.call("_on_settings_pressed")
    var m_s: Dictionary = menu.call("get_menu_state")
    _check(bool(m_s["settings_visible"]) and not bool(m_s["main_visible"]), "Settings overlay opens from MainMenu")
    menu.get("_settings_menu").emit_signal("close_requested")
    _check(bool(menu.call("get_menu_state")["main_visible"]), "Closing Settings returns to MainMenu")

    var events := {"play_path": "", "quit": 0}
    menu.connect("play_requested", func(path: String) -> void: events["play_path"] = path)
    menu.connect("quit_requested", func() -> void: events["quit"] = int(events["quit"]) + 1)

    menu.call("_on_play_pressed")
    var m_p: Dictionary = menu.call("get_menu_state")
    _check(bool(m_p["loading_visible"]) and str(events["play_path"]) == "res://src/gameplay/gameplay.tscn", "Play shows loading overlay and targets Gameplay")
    _check(audio != null and not bool(audio.call("is_menu_music_playing")), "Play stops menu music")

    menu.call("_on_quit_pressed")
    _check(int(events["quit"]) == 1, "Quit emits quit_requested")

    menu.queue_free()
    await get_tree().process_frame
    store.delete_save()

    if failures == 0:
        print("[MAIN MENU TEST OK]")
        get_tree().quit(0)
    else:
        push_error("[MAIN MENU TEST FAILED]")
        get_tree().quit(1)
