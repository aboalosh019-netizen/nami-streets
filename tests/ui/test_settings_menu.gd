extends Node

const SettingsScene = preload("res://src/ui/settings_menu.tscn")
const AudioManagerScript = preload("res://src/audio/audio_manager.gd")
const TEST_PATH: String = "user://test_settings_menu_audio.json"

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
    var mgr: Node = AudioManagerScript.new()
    add_child(mgr)
    mgr.call("set_settings_path", TEST_PATH, false)
    mgr.get("settings").call("delete_settings")

    var menu: Control = SettingsScene.instantiate() as Control
    add_child(menu)
    menu.call("bind_audio_manager", mgr)

    var closed := {"count": 0}
    menu.connect("close_requested", func() -> void:
        closed["count"] = int(closed["count"]) + 1
    )

    menu.get("_master_slider").value = 60.0
    menu.get("_music_slider").value = 35.0
    menu.get("_sfx_slider").value = 80.0
    menu.get("_mute_check").button_pressed = true

    var ui_st: Dictionary = menu.call("get_settings_ui_state")
    var cfg: Dictionary = mgr.call("get_settings_dict")
    _check(int(ui_st["master_pct"]) == 60 and is_equal_approx(float(cfg["master_volume"]), 0.6), "Master slider updates AudioManager")
    _check(int(ui_st["music_pct"]) == 35 and is_equal_approx(float(cfg["music_volume"]), 0.35), "Music slider updates AudioManager")
    _check(int(ui_st["sfx_pct"]) == 80 and is_equal_approx(float(cfg["sfx_volume"]), 0.8), "SFX slider updates AudioManager")
    _check(bool(ui_st["muted"]) and bool(cfg["muted"]), "Mute toggle updates AudioManager")

    menu.call("_on_back_pressed")
    _check(int(closed["count"]) == 1, "Back button emits close_requested")

    mgr.get("settings").call("delete_settings")
    menu.queue_free()
    mgr.queue_free()
    await get_tree().process_frame

    if failures == 0:
        print("[SETTINGS MENU TEST OK]")
        get_tree().quit(0)
    else:
        push_error("[SETTINGS MENU TEST FAILED]")
        get_tree().quit(1)
