extends Node

const AudioManagerScript = preload("res://src/audio/audio_manager.gd")
const PATH: String = "user://test_phase13_audio_settings.json"
var failures: int = 0

func _ready() -> void:
    call_deferred("_run_tests")

func _check(cond: bool, desc: String) -> void:
    if cond:
        print("[PASS] ", desc)
    else:
        failures += 1
        push_error("[FAIL] " + desc)

func _run_tests() -> void:
    _check(get_node_or_null("/root/AudioManager") != null, "AudioManager autoload registered")
    var mgr: Node = AudioManagerScript.new()
    add_child(mgr)
    mgr.call("set_settings_path", PATH, false)
    mgr.get("settings").call("delete_settings")
    _check(bool(mgr.call("get_audio_state")["buses_ready"]), "Buses exist")

    mgr.call("set_master_volume", 0.5)
    mgr.call("set_music_volume", 0.4)
    mgr.call("set_sfx_volume", 0.75)
    mgr.call("set_muted", true)
    var m_idx: int = AudioServer.get_bus_index("Master")
    _check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(m_idx)), 0.5), "Master vol 0.5")
    _check(AudioServer.is_bus_mute(m_idx), "Master muted")

    var mgr2: Node = AudioManagerScript.new()
    add_child(mgr2)
    var res: Dictionary = mgr2.call("set_settings_path", PATH, true)
    var cfg: Dictionary = mgr2.call("get_settings_dict")
    _check(bool(res.get("loaded", false)) and bool(cfg["muted"]), "Settings reloaded")
    _check(is_equal_approx(float(cfg["music_volume"]), 0.4) and is_equal_approx(float(cfg["sfx_volume"]), 0.75), "Music & SFX vol restored")

    mgr2.call("set_muted", false, false)
    mgr2.call("play_menu_music")
    _check(bool(mgr2.call("is_menu_music_playing")), "Menu music plays")
    mgr2.call("stop_menu_music")
    _check(not bool(mgr2.call("is_menu_music_playing")), "Menu music stops")

    mgr2.call("update_bike_audio", 1400.0, 10200.0, 0.0, false, 0.0, 0.0, 0.016)
    var p_idle: float = float(mgr2.call("get_audio_state")["engine_pitch"])
    mgr2.call("update_bike_audio", 8800.0, 10200.0, 1.0, false, 0.0, 260.0, 0.016)
    var st_hi: Dictionary = mgr2.call("get_audio_state")
    _check(bool(st_hi["engine_playing"]) and float(st_hi["engine_pitch"]) > p_idle + 0.8, "Engine pitch scales with RPM")
    _check(not bool(st_hi["brake_playing"]), "Brake silent without brake")

    mgr2.call("update_bike_audio", 5000.0, 10200.0, 0.0, false, 0.9, 240.0, 0.016)
    _check(bool(mgr2.call("get_audio_state")["brake_playing"]), "Brake plays when braking at speed")

    mgr2.call("set_engine_paused", true)
    _check(bool(mgr2.call("get_audio_state")["engine_paused"]), "Engine pauses")
    mgr2.call("stop_engine_audio")
    _check(not bool(mgr2.call("get_audio_state")["engine_playing"]), "Engine stops")

    _check(bool(mgr2.call("play_sfx", "reward")) and bool(mgr2.call("play_sfx", "shift")) and bool(mgr2.call("play_sfx", "transition")), "SFX play ok")
    _check(not bool(mgr2.call("play_sfx", "unknown")), "Unknown SFX rejected")

    mgr2.get("settings").call("delete_settings")
    mgr.queue_free()
    mgr2.queue_free()
    await get_tree().process_frame
    await get_tree().create_timer(0.05).timeout
    if failures == 0:
        print("[AUDIO MANAGER TEST OK]")
        get_tree().quit(0)
    else:
        push_error("[AUDIO MANAGER TEST FAILED]")
        get_tree().quit(1)
