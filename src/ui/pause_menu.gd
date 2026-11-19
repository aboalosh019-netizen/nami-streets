class_name PauseMenu
extends Control

signal resume_requested
signal garage_requested
signal respawn_requested
signal main_menu_requested

var _status_label: Label
var _world_manager: Node


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_interface()
    visible = false


func _build_interface() -> void:
    var background := ColorRect.new()
    background.color = Color(0.04, 0.05, 0.08, 0.92)
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(300, 0)
    center.add_child(panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 12)
    panel.add_child(layout)

    var title := Label.new()
    title.text = "GAME PAUSED"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layout.add_child(title)

    _add_button(layout, "RESUME", _on_resume_pressed)
    _add_button(layout, "GARAGE", _on_garage_pressed)
    _add_button(layout, "RESPAWN", _on_respawn_pressed)
    _add_button(layout, "MAIN MENU", _on_main_menu_pressed)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layout.add_child(_status_label)


func _add_button(parent: VBoxContainer, button_text: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = button_text
    button.custom_minimum_size = Vector2(240, 48)
    button.pressed.connect(callback)
    parent.add_child(button)


func bind_world_manager(world_manager: Node) -> void:
    _world_manager = world_manager


func open_menu() -> void:
    visible = true
    _set_game_paused(true)


func close_menu() -> void:
    visible = false
    _set_game_paused(false)


func toggle_menu() -> void:
    if visible:
        close_menu()
    else:
        open_menu()


func _set_game_paused(paused: bool) -> void:
    get_tree().paused = paused
    var game_manager := get_node_or_null("/root/GameManager")

    if game_manager != null:
        if paused:
            game_manager.change_state(game_manager.GameState.PAUSED)
        else:
            game_manager.change_state(game_manager.GameState.PLAYING)


func _on_resume_pressed() -> void:
    close_menu()
    resume_requested.emit()


func _on_garage_pressed() -> void:
    garage_requested.emit()


func _on_respawn_pressed() -> void:
    var respawn_success := false

    if _world_manager != null and is_instance_valid(_world_manager):
        if _world_manager.has_method("get_current_zone"):
            var current_zone = _world_manager.get_current_zone()
            if current_zone != null and current_zone.has_method("respawn_bike"):
                respawn_success = current_zone.respawn_bike()

    respawn_requested.emit()

    if respawn_success:
        _set_status("Bike respawned.")
    else:
        _set_status("Respawn failed: WorldManager not bound or zone unavailable.")


func _on_main_menu_pressed() -> void:
    close_menu()
    main_menu_requested.emit()


func _set_status(message: String) -> void:
    if _status_label != null:
        _status_label.text = message
