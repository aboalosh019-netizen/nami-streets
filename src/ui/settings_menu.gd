class_name SettingsMenu
extends Control

signal close_requested

var _audio_manager: Node = null
var _syncing_ui: bool = false

var _master_slider: HSlider
var _master_value: Label
var _music_slider: HSlider
var _music_value: Label
var _sfx_slider: HSlider
var _sfx_value: Label
var _mute_check: CheckButton
var _status_label: Label


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_interface()
    if _audio_manager == null:
        _audio_manager = get_node_or_null("/root/AudioManager")
    refresh_from_audio()


func bind_audio_manager(audio_manager: Node) -> void:
    _audio_manager = audio_manager
    refresh_from_audio()


func _build_interface() -> void:
    var bg := ColorRect.new()
    bg.color = Color(0.04, 0.05, 0.08, 0.94)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(360, 0)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    margin.add_child(vbox)

    var title := Label.new()
    title.text = "AUDIO SETTINGS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var m_row := _add_slider_row(vbox, "Master", _on_master_changed)
    _master_slider = m_row["slider"]
    _master_value = m_row["label"]

    var mu_row := _add_slider_row(vbox, "Music", _on_music_changed)
    _music_slider = mu_row["slider"]
    _music_value = mu_row["label"]

    var s_row := _add_slider_row(vbox, "SFX", _on_sfx_changed)
    _sfx_slider = s_row["slider"]
    _sfx_value = s_row["label"]

    _mute_check = CheckButton.new()
    _mute_check.text = "Mute All Audio"
    _mute_check.toggled.connect(_on_mute_toggled)
    vbox.add_child(_mute_check)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(_status_label)

    var back_btn := Button.new()
    back_btn.name = "BackButton"
    back_btn.text = "BACK"
    back_btn.custom_minimum_size = Vector2(200, 40)
    back_btn.pressed.connect(_on_back_pressed)
    vbox.add_child(back_btn)


func _add_slider_row(parent: VBoxContainer, caption: String, callback: Callable) -> Dictionary:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    parent.add_child(row)

    var name_lbl := Label.new()
    name_lbl.text = caption
    name_lbl.custom_minimum_size = Vector2(72, 0)
    row.add_child(name_lbl)

    var slider := HSlider.new()
    slider.min_value = 0.0
    slider.max_value = 100.0
    slider.step = 1.0
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.value_changed.connect(callback)
    row.add_child(slider)

    var val_lbl := Label.new()
    val_lbl.custom_minimum_size = Vector2(44, 0)
    val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(val_lbl)

    return {"slider": slider, "label": val_lbl}


func refresh_from_audio() -> void:
    if not is_node_ready():
        return
    var mgr: Node = _get_audio()
    if mgr == null or not mgr.has_method("get_settings_dict"):
        _status_label.text = "AudioManager unavailable."
        return

    var cfg: Dictionary = mgr.call("get_settings_dict")
    _syncing_ui = true
    var m_pct: float = round(float(cfg.get("master_volume", 0.85)) * 100.0)
    var mu_pct: float = round(float(cfg.get("music_volume", 0.65)) * 100.0)
    var s_pct: float = round(float(cfg.get("sfx_volume", 0.90)) * 100.0)
    _master_slider.value = m_pct
    _music_slider.value = mu_pct
    _sfx_slider.value = s_pct
    _mute_check.button_pressed = bool(cfg.get("muted", false))
    _master_value.text = "%d%%" % int(m_pct)
    _music_value.text = "%d%%" % int(mu_pct)
    _sfx_value.text = "%d%%" % int(s_pct)
    _status_label.text = "Audio muted." if _mute_check.button_pressed else "Audio active."
    _syncing_ui = false


func _get_audio() -> Node:
    if _audio_manager != null and is_instance_valid(_audio_manager):
        return _audio_manager
    return get_node_or_null("/root/AudioManager")


func _on_master_changed(val: float) -> void:
    _master_value.text = "%d%%" % int(round(val))
    if _syncing_ui:
        return
    var mgr: Node = _get_audio()
    if mgr != null:
        mgr.call("set_master_volume", val / 100.0)


func _on_music_changed(val: float) -> void:
    _music_value.text = "%d%%" % int(round(val))
    if _syncing_ui:
        return
    var mgr: Node = _get_audio()
    if mgr != null:
        mgr.call("set_music_volume", val / 100.0)


func _on_sfx_changed(val: float) -> void:
    _sfx_value.text = "%d%%" % int(round(val))
    if _syncing_ui:
        return
    var mgr: Node = _get_audio()
    if mgr != null:
        mgr.call("set_sfx_volume", val / 100.0)


func _on_mute_toggled(pressed: bool) -> void:
    if _syncing_ui:
        return
    var mgr: Node = _get_audio()
    if mgr != null:
        mgr.call("set_muted", pressed)
        if not pressed:
            mgr.call("play_sfx", "ui_click")
    _status_label.text = "Audio muted." if pressed else "Audio active."


func _on_back_pressed() -> void:
    var mgr: Node = _get_audio()
    if mgr != null:
        mgr.call("play_sfx", "ui_click")
    close_requested.emit()


func get_settings_ui_state() -> Dictionary:
    return {
        "master_pct": int(round(_master_slider.value)) if _master_slider != null else 0,
        "music_pct": int(round(_music_slider.value)) if _music_slider != null else 0,
        "sfx_pct": int(round(_sfx_slider.value)) if _sfx_slider != null else 0,
        "muted": _mute_check.button_pressed if _mute_check != null else false
    }
