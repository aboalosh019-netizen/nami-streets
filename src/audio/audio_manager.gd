extends Node

signal settings_changed(settings_dict: Dictionary)

const AudioSynthScript = preload("res://src/audio/audio_synth.gd")
const AudioSettingsScript = preload("res://src/audio/audio_settings.gd")

const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const SFX_POOL_SIZE: int = 4

var settings: RefCounted
var _music_player: AudioStreamPlayer
var _engine_player: AudioStreamPlayer
var _brake_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _sfx_streams: Dictionary = {}

var _engine_active: bool = false
var _last_rpm: float = 0.0
var _last_throttle: float = 0.0
var _last_rev_limiter: bool = false
var _last_brake_level: float = 0.0
var _rev_stutter_phase: float = 0.0
var _sfx_play_counts: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_audio_buses()
    _init_players()
    settings = AudioSettingsScript.new()
    settings.call("load_settings")
    apply_settings()


func _exit_tree() -> void:
    stop_menu_music()
    stop_engine_audio()
    for p_node in _sfx_players:
        if p_node != null and is_instance_valid(p_node):
            p_node.stop()
            p_node.stream = null
    if _music_player != null and is_instance_valid(_music_player):
        _music_player.stream = null
    if _engine_player != null and is_instance_valid(_engine_player):
        _engine_player.stream = null
    if _brake_player != null and is_instance_valid(_brake_player):
        _brake_player.stream = null
    _sfx_streams.clear()


func _ensure_audio_buses() -> void:
    if AudioServer.get_bus_index(BUS_MUSIC) == -1:
        var idx: int = AudioServer.bus_count
        AudioServer.add_bus(idx)
        AudioServer.set_bus_name(idx, BUS_MUSIC)
        AudioServer.set_bus_send(idx, BUS_MASTER)

    if AudioServer.get_bus_index(BUS_SFX) == -1:
        var idx: int = AudioServer.bus_count
        AudioServer.add_bus(idx)
        AudioServer.set_bus_name(idx, BUS_SFX)
        AudioServer.set_bus_send(idx, BUS_MASTER)


func _init_players() -> void:
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.bus = BUS_MUSIC
    _music_player.stream = AudioSynthScript.create_menu_music_loop()
    add_child(_music_player)

    _engine_player = AudioStreamPlayer.new()
    _engine_player.name = "EnginePlayer"
    _engine_player.bus = BUS_SFX
    _engine_player.stream = AudioSynthScript.create_engine_loop()
    _engine_player.volume_db = -18.0
    add_child(_engine_player)

    _brake_player = AudioStreamPlayer.new()
    _brake_player.name = "BrakePlayer"
    _brake_player.bus = BUS_SFX
    _brake_player.stream = AudioSynthScript.create_brake_loop()
    _brake_player.volume_db = -40.0
    add_child(_brake_player)

    _sfx_streams = {
        "reward": AudioSynthScript.create_reward_sfx(),
        "near_miss": AudioSynthScript.create_reward_sfx(),
        "wheelie": AudioSynthScript.create_reward_sfx(),
        "shift": AudioSynthScript.create_shift_sfx(),
        "transition": AudioSynthScript.create_transition_sfx(),
        "collision": AudioSynthScript.create_collision_sfx(),
        "ui_click": AudioSynthScript.create_ui_click_sfx(),
        "purchase": AudioSynthScript.create_reward_sfx()
    }

    for i in range(SFX_POOL_SIZE):
        var p := AudioStreamPlayer.new()
        p.name = "SfxPlayer_%d" % i
        p.bus = BUS_SFX
        add_child(p)
        _sfx_players.append(p)


func set_settings_path(custom_path: String, reload: bool = true) -> Dictionary:
    settings = AudioSettingsScript.new(custom_path)
    var res: Dictionary = {"loaded": false, "reason": "skipped"}
    if reload:
        res = settings.call("load_settings")
    apply_settings()
    return res


func _apply_bus_volume(bus_name: String, linear_vol: float, force_mute: bool) -> void:
    var idx: int = AudioServer.get_bus_index(bus_name)
    if idx == -1:
        return
    var clamped: float = clampf(linear_vol, 0.0, 1.0)
    var should_mute: bool = force_mute or clamped <= 0.001
    AudioServer.set_bus_mute(idx, should_mute)
    AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, clamped)))


func apply_settings() -> void:
    if settings == null:
        return
    var is_muted: bool = bool(settings.get("muted"))
    _apply_bus_volume(BUS_MASTER, float(settings.get("master_volume")), is_muted)
    _apply_bus_volume(BUS_MUSIC, float(settings.get("music_volume")), is_muted)
    _apply_bus_volume(BUS_SFX, float(settings.get("sfx_volume")), is_muted)
    settings_changed.emit(get_settings_dict())


func set_master_volume(val: float, persist: bool = true) -> void:
    settings.set("master_volume", clampf(val, 0.0, 1.0))
    apply_settings()
    if persist:
        save_settings()


func set_music_volume(val: float, persist: bool = true) -> void:
    settings.set("music_volume", clampf(val, 0.0, 1.0))
    apply_settings()
    if persist:
        save_settings()


func set_sfx_volume(val: float, persist: bool = true) -> void:
    settings.set("sfx_volume", clampf(val, 0.0, 1.0))
    apply_settings()
    if persist:
        save_settings()


func set_muted(val: bool, persist: bool = true) -> void:
    settings.set("muted", val)
    apply_settings()
    if persist:
        save_settings()


func save_settings() -> bool:
    if settings == null:
        return false
    return bool(settings.call("save_settings"))


func get_settings_dict() -> Dictionary:
    if settings == null:
        return {}
    return settings.call("to_dict")


func play_menu_music() -> void:
    if _music_player != null and not _music_player.playing:
        _music_player.play()


func stop_menu_music() -> void:
    if _music_player != null and _music_player.playing:
        _music_player.stop()


func is_menu_music_playing() -> bool:
    return _music_player != null and _music_player.playing


func start_engine_audio() -> void:
    _engine_active = true
    if _engine_player != null and not _engine_player.playing:
        _engine_player.play()


func stop_engine_audio() -> void:
    _engine_active = false
    if _engine_player != null and _engine_player.playing:
        _engine_player.stop()
    if _brake_player != null and _brake_player.playing:
        _brake_player.stop()


func set_engine_paused(paused: bool) -> void:
    if _engine_player != null:
        _engine_player.stream_paused = paused
    if _brake_player != null:
        _brake_player.stream_paused = paused


func update_bike_audio(
    rpm: float,
    max_rpm: float,
    throttle: float,
    rev_limiter: bool,
    brake_level: float,
    speed: float,
    delta: float = 0.016
) -> void:
    _last_rpm = maxf(0.0, rpm)
    _last_throttle = clampf(throttle, 0.0, 1.0)
    _last_rev_limiter = rev_limiter
    _last_brake_level = clampf(brake_level, 0.0, 1.0)

    if not _engine_active:
        start_engine_audio()

    var norm_rpm: float = clampf(_last_rpm / maxf(1000.0, max_rpm), 0.0, 1.0)
    var pitch: float = lerpf(0.65, 2.35, norm_rpm)
    var vol_db: float = lerpf(-18.0, -5.0, clampf(norm_rpm * 0.65 + _last_throttle * 0.35, 0.0, 1.0))

    if rev_limiter:
        _rev_stutter_phase += maxf(0.0, delta) * 28.0
        if sin(_rev_stutter_phase * TAU) < 0.0:
            vol_db -= 8.0
            pitch *= 0.94
    else:
        _rev_stutter_phase = 0.0

    _engine_player.pitch_scale = pitch
    _engine_player.volume_db = vol_db

    var brake_intensity: float = _last_brake_level * clampf(speed / 120.0, 0.0, 1.0)
    if brake_intensity > 0.12:
        if not _brake_player.playing:
            _brake_player.play()
        _brake_player.volume_db = lerpf(-26.0, -9.0, brake_intensity)
        _brake_player.pitch_scale = lerpf(0.85, 1.35, brake_intensity)
    else:
        if _brake_player.playing:
            _brake_player.stop()


func play_sfx(sfx_name: String, pitch_scale: float = 1.0) -> bool:
    if not _sfx_streams.has(sfx_name) or _sfx_players.is_empty():
        return false

    var player: AudioStreamPlayer = _sfx_players[_sfx_cursor]
    _sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
    player.stream = _sfx_streams[sfx_name]
    player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
    player.play()
    _sfx_play_counts[sfx_name] = int(_sfx_play_counts.get(sfx_name, 0)) + 1
    return true


func get_audio_state() -> Dictionary:
    return {
        "buses_ready": AudioServer.get_bus_index(BUS_MUSIC) != -1 and AudioServer.get_bus_index(BUS_SFX) != -1,
        "music_playing": is_menu_music_playing(),
        "engine_active": _engine_active,
        "engine_playing": _engine_player != null and _engine_player.playing,
        "engine_paused": _engine_player != null and _engine_player.stream_paused,
        "engine_pitch": _engine_player.pitch_scale if _engine_player != null else 1.0,
        "engine_vol_db": _engine_player.volume_db if _engine_player != null else -80.0,
        "brake_playing": _brake_player != null and _brake_player.playing,
        "last_rpm": _last_rpm,
        "last_rev_limiter": _last_rev_limiter,
        "sfx_counts": _sfx_play_counts.duplicate(),
        "settings": get_settings_dict()
    }
