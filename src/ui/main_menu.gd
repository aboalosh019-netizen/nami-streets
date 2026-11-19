class_name MainMenu
extends Control

signal play_requested(scene_path: String)
signal quit_requested

const EconomyStateScript = preload("res://src/economy/player_economy_state.gd")
const SaveStoreScript = preload("res://src/economy/save_store.gd")
const GarageScene = preload("res://src/ui/garage/garage_menu.tscn")
const SettingsScene = preload("res://src/ui/settings_menu.tscn")

@export var save_path: String = ""
@export var gameplay_scene_path: String = "res://src/gameplay/gameplay.tscn"

var economy_state: RefCounted
var save_store: RefCounted

var _main_panel: Control
var _summary_label: Label
var _garage_menu: Control
var _settings_menu: Control
var _loading_overlay: Control
var _is_loading: bool = false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if get_tree() != null and get_tree().paused:
        get_tree().paused = false

    _init_economy()
    _build_ui()
    _refresh_summary()

    var gm: Node = get_node_or_null("/root/GameManager")
    if gm != null and gm.has_method("change_state"):
        gm.call("change_state", 0)

    var audio: Node = _get_audio()
    if audio != null:
        audio.call("stop_engine_audio")
        audio.call("play_menu_music")


func _exit_tree() -> void:
    if _garage_menu != null and is_instance_valid(_garage_menu):
        if _garage_menu.is_connected(&"close_requested", _on_overlay_closed):
            _garage_menu.disconnect(&"close_requested", _on_overlay_closed)
        if _garage_menu.is_connected(&"bike_equipped", _on_garage_changed):
            _garage_menu.disconnect(&"bike_equipped", _on_garage_changed)
        if _garage_menu.is_connected(&"purchase_completed", _on_garage_changed):
            _garage_menu.disconnect(&"purchase_completed", _on_garage_changed)
    if _settings_menu != null and is_instance_valid(_settings_menu):
        if _settings_menu.is_connected(&"close_requested", _on_overlay_closed):
            _settings_menu.disconnect(&"close_requested", _on_overlay_closed)


func _init_economy() -> void:
    economy_state = EconomyStateScript.new()
    save_store = SaveStoreScript.new() if save_path.is_empty() else SaveStoreScript.new(save_path)
    var res: Dictionary = save_store.call("load_state", economy_state)
    economy_state = res.get("state", economy_state)


func _build_ui() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.06, 0.07, 0.11, 1.0)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    _main_panel = center

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(300, 0)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    panel.add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    margin.add_child(vbox)

    var title := Label.new()
    title.text = "NAMI STREETS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    _summary_label = Label.new()
    _summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(_summary_label)

    _add_btn(vbox, "PlayButton", "PLAY", _on_play_pressed)
    _add_btn(vbox, "GarageButton", "GARAGE", _on_garage_pressed)
    _add_btn(vbox, "SettingsButton", "SETTINGS", _on_settings_pressed)
    _add_btn(vbox, "QuitButton", "QUIT", _on_quit_pressed)

    _garage_menu = GarageScene.instantiate() as Control
    _garage_menu.visible = false
    add_child(_garage_menu)
    _garage_menu.call("bind_data", economy_state, save_store)
    _garage_menu.connect(&"close_requested", _on_overlay_closed)
    _garage_menu.connect(&"bike_equipped", _on_garage_changed)
    _garage_menu.connect(&"purchase_completed", _on_garage_changed)

    _settings_menu = SettingsScene.instantiate() as Control
    _settings_menu.visible = false
    add_child(_settings_menu)
    _settings_menu.connect(&"close_requested", _on_overlay_closed)

    _loading_overlay = ColorRect.new()
    _loading_overlay.color = Color(0.03, 0.04, 0.07, 0.96)
    _loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _loading_overlay.visible = false
    add_child(_loading_overlay)

    var load_center := CenterContainer.new()
    load_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _loading_overlay.add_child(load_center)

    var load_lbl := Label.new()
    load_lbl.text = "LOADING STREETS..."
    load_center.add_child(load_lbl)


func _add_btn(parent: VBoxContainer, node_name: String, text: String, cb: Callable) -> Button:
    var btn := Button.new()
    btn.name = node_name
    btn.text = text
    btn.custom_minimum_size = Vector2(220, 38)
    btn.pressed.connect(cb)
    parent.add_child(btn)
    return btn


func _refresh_summary() -> void:
    if _summary_label == null or economy_state == null:
        return
    var bike_id: String = str(economy_state.get("active_bike_id")).to_upper()
    var cash: int = int(economy_state.get("cash"))
    _summary_label.text = "BIKE: %s  |  CASH: $%d" % [bike_id, cash]


func _get_audio() -> Node:
    return get_node_or_null("/root/AudioManager")


func _play_click() -> void:
    var audio: Node = _get_audio()
    if audio != null:
        audio.call("play_sfx", "ui_click")


func _on_play_pressed() -> void:
    if _is_loading:
        return
    _is_loading = true
    _play_click()
    var audio: Node = _get_audio()
    if audio != null:
        audio.call("stop_menu_music")
    _main_panel.visible = false
    _loading_overlay.visible = true
    play_requested.emit(gameplay_scene_path)
    if get_signal_connection_list(&"play_requested").is_empty():
        call_deferred("_go_to_gameplay")


func _go_to_gameplay() -> void:
    var sm: Node = get_node_or_null("/root/SceneManager")
    if sm != null and sm.has_method("change_scene"):
        sm.call("change_scene", gameplay_scene_path)


func _on_garage_pressed() -> void:
    _play_click()
    _main_panel.visible = false
    _garage_menu.call("refresh_menu")
    _garage_menu.visible = true


func _on_settings_pressed() -> void:
    _play_click()
    _main_panel.visible = false
    _settings_menu.call("refresh_from_audio")
    _settings_menu.visible = true


func _on_overlay_closed() -> void:
    _play_click()
    _garage_menu.visible = false
    _settings_menu.visible = false
    _main_panel.visible = true
    _refresh_summary()


func _on_garage_changed(_id: String) -> void:
    if save_store != null and economy_state != null:
        save_store.call("save_state", economy_state)
    _refresh_summary()


func _on_quit_pressed() -> void:
    _play_click()
    var audio: Node = _get_audio()
    if audio != null:
        audio.call("stop_menu_music")
    quit_requested.emit()
    if get_signal_connection_list(&"quit_requested").is_empty() and get_tree() != null:
        get_tree().quit(0)


func get_menu_state() -> Dictionary:
    return {
        "main_visible": _main_panel.visible if _main_panel != null else false,
        "garage_visible": _garage_menu.visible if _garage_menu != null else false,
        "settings_visible": _settings_menu.visible if _settings_menu != null else false,
        "loading_visible": _loading_overlay.visible if _loading_overlay != null else false,
        "summary": _summary_label.text if _summary_label != null else "",
        "active_bike_id": str(economy_state.get("active_bike_id")) if economy_state != null else "",
        "cash": int(economy_state.get("cash")) if economy_state != null else 0
    }
