extends Node2D

signal main_menu_requested

const EconomyStateScript = preload("res://src/economy/player_economy_state.gd")
const SaveStoreScript = preload("res://src/economy/save_store.gd")
const UpgradeApplier = preload("res://src/economy/bike_upgrade_applier.gd")

@export var save_path: String = ""
@export var main_menu_scene_path: String = "res://src/ui/main_menu.tscn"

@onready var world_manager: Node = $WorldManager
@onready var reward_tracker: Node = $RewardTracker
@onready var gameplay_hud: Node = $UI/GameplayHUD
@onready var touch_controls: Node = $UI/TouchControls
@onready var pause_menu: Node = $UI/PauseMenu
@onready var garage_menu: Node = $UI/GarageMenu

var economy_state: RefCounted
var save_store: RefCounted
var last_save_load_result: Dictionary = {}
var last_save_ok: bool = true
var last_save_error: String = ""
var _active_bike: Node2D = null
var _active_controller: Node = null
var _last_audio_gear: int = -1
var _active_camera: Node = null
var _rev_juice_timer: float = 0.0
var _haptic_count: int = 0
var _shake_count: int = 0


func _ready() -> void:
    _initialize_economy()
    _connect_world_signals()
    _connect_ui_signals()

    reward_tracker.call("bind_economy", economy_state)
    gameplay_hud.call("bind_economy", economy_state)
    gameplay_hud.call("bind_reward_tracker", reward_tracker)
    pause_menu.call("bind_world_manager", world_manager)
    garage_menu.call("bind_data", economy_state, save_store)

    _bind_current_zone()
    _start_gameplay_audio()


func _exit_tree() -> void:
    _stop_gameplay_audio()
    _active_bike = null
    _active_controller = null
    _active_camera = null
    _last_audio_gear = -1
    _disconnect_all_signals()

    if reward_tracker != null and is_instance_valid(reward_tracker):
        reward_tracker.call("unbind_traffic_spawner")
        reward_tracker.call("bind_bike", null)
        reward_tracker.call("bind_economy", null)

    if gameplay_hud != null and is_instance_valid(gameplay_hud):
        gameplay_hud.call("bind_bike", null)
        gameplay_hud.call("bind_economy", null)
        gameplay_hud.call("bind_reward_tracker", null)

    if touch_controls != null and is_instance_valid(touch_controls):
        touch_controls.call("release_all")

    var tree: SceneTree = get_tree()
    if tree != null and tree.paused:
        tree.paused = false


func _initialize_economy() -> void:
    economy_state = EconomyStateScript.new()
    if save_path.is_empty():
        save_store = SaveStoreScript.new()
    else:
        save_store = SaveStoreScript.new(save_path)

    last_save_load_result = save_store.call("load_state", economy_state)
    economy_state = last_save_load_result.get("state", economy_state)


func set_save_store(store: RefCounted) -> void:
    save_store = store
    if garage_menu != null and is_instance_valid(garage_menu):
        garage_menu.set("save_store", store)


func _connect_signal_safe(emitter: Object, signal_name: StringName, callback: Callable) -> void:
    if emitter == null or not is_instance_valid(emitter):
        return
    if emitter.has_signal(signal_name) and not emitter.is_connected(signal_name, callback):
        emitter.connect(signal_name, callback)


func _disconnect_signal_safe(emitter: Object, signal_name: StringName, callback: Callable) -> void:
    if emitter == null or not is_instance_valid(emitter):
        return
    if emitter.has_signal(signal_name) and emitter.is_connected(signal_name, callback):
        emitter.disconnect(signal_name, callback)


func _connect_world_signals() -> void:
    _connect_signal_safe(world_manager, &"zone_loaded", _on_zone_loaded)
    _connect_signal_safe(world_manager, &"zone_transition_started", _on_zone_transition_started)


func _connect_ui_signals() -> void:
    _connect_signal_safe(gameplay_hud, &"pause_requested", _on_pause_requested)
    _connect_signal_safe(pause_menu, &"resume_requested", _on_resume_requested)
    _connect_signal_safe(pause_menu, &"garage_requested", _on_garage_requested)
    _connect_signal_safe(pause_menu, &"respawn_requested", _on_respawn_requested)
    _connect_signal_safe(pause_menu, &"main_menu_requested", _on_main_menu_requested)
    _connect_signal_safe(garage_menu, &"close_requested", _on_garage_close_requested)
    _connect_signal_safe(garage_menu, &"bike_equipped", _on_bike_equipped)
    _connect_signal_safe(garage_menu, &"purchase_completed", _on_purchase_completed)
    _connect_signal_safe(reward_tracker, &"reward_earned", _on_reward_earned)
    _connect_signal_safe(reward_tracker, &"combo_reset", _on_combo_reset)


func _disconnect_all_signals() -> void:
    _disconnect_signal_safe(world_manager, &"zone_loaded", _on_zone_loaded)
    _disconnect_signal_safe(world_manager, &"zone_transition_started", _on_zone_transition_started)
    _disconnect_signal_safe(gameplay_hud, &"pause_requested", _on_pause_requested)
    _disconnect_signal_safe(pause_menu, &"resume_requested", _on_resume_requested)
    _disconnect_signal_safe(pause_menu, &"garage_requested", _on_garage_requested)
    _disconnect_signal_safe(pause_menu, &"respawn_requested", _on_respawn_requested)
    _disconnect_signal_safe(pause_menu, &"main_menu_requested", _on_main_menu_requested)
    _disconnect_signal_safe(garage_menu, &"close_requested", _on_garage_close_requested)
    _disconnect_signal_safe(garage_menu, &"bike_equipped", _on_bike_equipped)
    _disconnect_signal_safe(garage_menu, &"purchase_completed", _on_purchase_completed)
    _disconnect_signal_safe(reward_tracker, &"reward_earned", _on_reward_earned)
    _disconnect_signal_safe(reward_tracker, &"combo_reset", _on_combo_reset)


func _bind_current_zone() -> void:
    var bike: Node2D = world_manager.call("get_active_bike") as Node2D
    if bike == null:
        push_warning("[GAMEPLAY] Active bike is not available.")
        return

    _active_bike = bike
    _active_controller = bike.get_node_or_null("BikeController")
    var phys_dbg: Node = bike.get_node_or_null("PhysicsDebug")
    if phys_dbg != null and phys_dbg.has_method("set_debug_enabled"):
        phys_dbg.call("set_debug_enabled", false)
    var cur_zone: Node = world_manager.call("get_current_zone") if (world_manager != null and world_manager.has_method("get_current_zone")) else null
    _active_camera = cur_zone.call("get_active_camera") if (cur_zone != null and cur_zone.has_method("get_active_camera")) else (cur_zone.get_node_or_null("BikeCamera") if cur_zone != null else null)
    if _active_controller != null and _active_controller.has_method("get_controller_state"):
        _last_audio_gear = int(_active_controller.call("get_controller_state").get("gear", 1))
    else:
        _last_audio_gear = -1
    gameplay_hud.call("bind_bike", bike)
    reward_tracker.call("bind_bike", bike)
    UpgradeApplier.apply_economy_state(bike, economy_state)

    var zone: Node = world_manager.call("get_current_zone") as Node
    var spawner: Node = null

    if zone != null:
        spawner = zone.get_node_or_null("TrafficSpawner")

    reward_tracker.call("bind_traffic_spawner", spawner)
    gameplay_hud.call("refresh_now")


func _on_zone_loaded(_zone_id: String, _spawn_id: String, _zone_node: Node2D) -> void:
    _bind_current_zone()


func _on_pause_requested() -> void:
    if garage_menu.visible:
        return
    touch_controls.set("controls_enabled", false)
    pause_menu.call("open_menu")
    _set_engine_audio_paused(true)
    _play_sfx("ui_click")


func _on_resume_requested() -> void:
    garage_menu.visible = false
    touch_controls.set("controls_enabled", true)
    _set_engine_audio_paused(false)
    _play_sfx("ui_click")


func _on_garage_requested() -> void:
    pause_menu.visible = false
    garage_menu.process_mode = Node.PROCESS_MODE_ALWAYS
    garage_menu.call("refresh_menu")
    garage_menu.visible = true
    _play_sfx("ui_click")
    touch_controls.set("controls_enabled", false)


func _on_garage_close_requested() -> void:
    garage_menu.visible = false
    pause_menu.visible = true
    _play_sfx("ui_click")


func _on_respawn_requested() -> void:
    _bind_current_zone()
    _play_sfx("transition")


func _on_bike_equipped(_bike_id: String) -> void:
    _bind_current_zone()
    _save_progress()
    _play_sfx("ui_click")


func _on_purchase_completed(_item_id: String) -> void:
    _bind_current_zone()
    _save_progress()
    _play_sfx("purchase")


func _on_reward_earned(reward_type: String, _amount: int, combo: int) -> void:
    _save_progress()
    var sfx: String = "near_miss" if reward_type == "near_miss" else "reward"
    _play_sfx(sfx, minf(1.4, 1.0 + float(maxi(0, combo - 1)) * 0.06))
    if reward_type == "near_miss":
        _trigger_juice(0.18, 22, 0.45)


func _on_main_menu_requested() -> void:
    touch_controls.set("controls_enabled", false)
    _stop_gameplay_audio()
    _play_sfx("ui_click")
    main_menu_requested.emit()
    if get_signal_connection_list(&"main_menu_requested").is_empty():
        call_deferred("_go_to_main_menu")


func _go_to_main_menu() -> void:
    var tree: SceneTree = get_tree()
    if tree != null and tree.paused:
        tree.paused = false
    var sm: Node = get_node_or_null("/root/SceneManager")
    if sm != null and sm.has_method("change_scene"):
        sm.call("change_scene", main_menu_scene_path)


func _save_progress() -> bool:
    if save_store == null or economy_state == null:
        last_save_ok = false
        last_save_error = "missing_store_or_state"
        return false

    last_save_ok = bool(save_store.call("save_state", economy_state))
    last_save_error = str(save_store.get("last_error"))
    return last_save_ok


func get_gameplay_state() -> Dictionary:
    return {
        "zone_id": str(world_manager.call("get_current_zone_id")) if world_manager != null else "",
        "active_bike_id": str(economy_state.get("active_bike_id")) if economy_state != null else "",
        "cash": int(economy_state.get("cash")) if economy_state != null else 0,
        "paused": get_tree().paused if get_tree() != null else false,
        "pause_visible": pause_menu.visible if pause_menu != null else false,
        "garage_visible": garage_menu.visible if garage_menu != null else false,
        "touch_enabled": bool(touch_controls.get("controls_enabled")) if touch_controls != null else false,
        "last_save_ok": last_save_ok,
        "last_save_error": last_save_error,
        "last_load_reason": str(last_save_load_result.get("reason", ""))
    }

func _physics_process(delta: float) -> void:
    if get_tree() != null and get_tree().paused:
        return
    if _active_bike == null or not is_instance_valid(_active_bike):
        return
    if _active_controller == null or not is_instance_valid(_active_controller):
        return

    var audio: Node = _get_audio_manager()
    if audio == null:
        return

    var ctrl: Dictionary = _active_controller.call("get_controller_state")
    var dt_cfg: Resource = _active_controller.get("drivetrain_config")
    var max_rpm: float = float(dt_cfg.get("redline_rpm")) if dt_cfg != null else 10200.0
    var gear: int = int(ctrl.get("gear", 1))
    if _last_audio_gear != -1 and gear != _last_audio_gear:
        _play_sfx("shift", 1.05 if gear > _last_audio_gear else 0.9)
        _trigger_juice(0.12, 14, 0.3)
    _last_audio_gear = gear

    var brake_lvl: float = maxf(float(ctrl.get("rear_brake_level", 0.0)), float(ctrl.get("front_brake_level", 0.0)))
    var speed: float = _active_bike.linear_velocity.length() if _active_bike is RigidBody2D else 0.0
    var rev_lim: bool = bool(ctrl.get("rev_limiter", false))
    audio.call("update_bike_audio", float(ctrl.get("rpm", 1400.0)), max_rpm, float(ctrl.get("throttle", 0.0)), rev_lim, brake_lvl, speed, delta)
    if rev_lim:
        _rev_juice_timer += delta
        if _rev_juice_timer >= 0.09:
            _rev_juice_timer = 0.0
            _trigger_juice(0.15, 18, 0.35)
    else:
        _rev_juice_timer = 0.0


func _get_audio_manager() -> Node:
    return get_node_or_null("/root/AudioManager")


func _play_sfx(sfx_name: String, pitch_scale: float = 1.0) -> void:
    var audio: Node = _get_audio_manager()
    if audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", sfx_name, pitch_scale)


func _start_gameplay_audio() -> void:
    var audio: Node = _get_audio_manager()
    if audio != null:
        audio.call("stop_menu_music")
        audio.call("start_engine_audio")
        audio.call("set_engine_paused", false)


func _stop_gameplay_audio() -> void:
    var audio: Node = _get_audio_manager()
    if audio != null:
        audio.call("set_engine_paused", false)
        audio.call("stop_engine_audio")


func _set_engine_audio_paused(paused: bool) -> void:
    var audio: Node = _get_audio_manager()
    if audio != null:
        audio.call("set_engine_paused", paused)


func _on_zone_transition_started(from_zone_id: String, _to_zone_id: String, _spawn_id: String, _portal_id: String) -> void:
    if not from_zone_id.is_empty():
        _play_sfx("transition")


func _on_combo_reset(reason: String) -> void:
    if reason == "collision":
        _play_sfx("collision")
        _trigger_juice(0.65, 90, 0.85)

func _trigger_juice(shake_amount: float, haptic_ms: int, haptic_amp: float = -1.0) -> void:
    if shake_amount > 0.0 and _active_camera != null and is_instance_valid(_active_camera) and _active_camera.has_method("add_shake"):
        _active_camera.call("add_shake", shake_amount)
        _shake_count += 1
    if haptic_ms > 0:
        Input.vibrate_handheld(haptic_ms, haptic_amp)
        _haptic_count += 1


func get_juice_state() -> Dictionary:
    var dbg_enabled: bool = false
    if _active_bike != null and is_instance_valid(_active_bike):
        var dbg: Node = _active_bike.get_node_or_null("PhysicsDebug")
        if dbg != null and dbg.has_method("is_debug_enabled"):
            dbg_enabled = bool(dbg.call("is_debug_enabled"))
    return {
        "shake_count": _shake_count,
        "haptic_count": _haptic_count,
        "camera_bound": _active_camera != null and is_instance_valid(_active_camera),
        "physics_debug_enabled": dbg_enabled
    }
