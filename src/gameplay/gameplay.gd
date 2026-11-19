extends Node2D

signal main_menu_requested

const EconomyStateScript = preload("res://src/economy/player_economy_state.gd")
const SaveStoreScript = preload("res://src/economy/save_store.gd")
const UpgradeApplier = preload("res://src/economy/bike_upgrade_applier.gd")

@export var save_path: String = ""

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


func _exit_tree() -> void:
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


func _disconnect_all_signals() -> void:
    _disconnect_signal_safe(world_manager, &"zone_loaded", _on_zone_loaded)
    _disconnect_signal_safe(gameplay_hud, &"pause_requested", _on_pause_requested)
    _disconnect_signal_safe(pause_menu, &"resume_requested", _on_resume_requested)
    _disconnect_signal_safe(pause_menu, &"garage_requested", _on_garage_requested)
    _disconnect_signal_safe(pause_menu, &"respawn_requested", _on_respawn_requested)
    _disconnect_signal_safe(pause_menu, &"main_menu_requested", _on_main_menu_requested)
    _disconnect_signal_safe(garage_menu, &"close_requested", _on_garage_close_requested)
    _disconnect_signal_safe(garage_menu, &"bike_equipped", _on_bike_equipped)
    _disconnect_signal_safe(garage_menu, &"purchase_completed", _on_purchase_completed)
    _disconnect_signal_safe(reward_tracker, &"reward_earned", _on_reward_earned)


func _bind_current_zone() -> void:
    var bike: Node2D = world_manager.call("get_active_bike") as Node2D
    if bike == null:
        push_warning("[GAMEPLAY] Active bike is not available.")
        return

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


func _on_resume_requested() -> void:
    garage_menu.visible = false
    touch_controls.set("controls_enabled", true)


func _on_garage_requested() -> void:
    pause_menu.visible = false
    garage_menu.process_mode = Node.PROCESS_MODE_ALWAYS
    garage_menu.call("refresh_menu")
    garage_menu.visible = true
    touch_controls.set("controls_enabled", false)


func _on_garage_close_requested() -> void:
    garage_menu.visible = false
    pause_menu.visible = true


func _on_respawn_requested() -> void:
    _bind_current_zone()


func _on_bike_equipped(_bike_id: String) -> void:
    _bind_current_zone()
    _save_progress()


func _on_purchase_completed(_item_id: String) -> void:
    _bind_current_zone()
    _save_progress()


func _on_reward_earned(_reward_type: String, _amount: int, _combo: int) -> void:
    _save_progress()


func _on_main_menu_requested() -> void:
    touch_controls.set("controls_enabled", false)
    main_menu_requested.emit()
    if get_signal_connection_list(&"main_menu_requested").is_empty():
        push_warning("[GAMEPLAY] Main Menu scene has not been implemented yet.")


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
