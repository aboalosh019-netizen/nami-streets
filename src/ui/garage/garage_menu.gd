class_name GarageMenu
extends Control

signal close_requested
signal bike_equipped(bike_id: String)
signal purchase_completed(item_id: String)

const Catalog = preload("res://src/economy/upgrade_catalog.gd")

var economy_state: RefCounted = null
var save_store: RefCounted = null
var selected_bike_id: String = "cg125"

var _status_label: Label
var _cash_label: Label
var _bike_container: VBoxContainer
var _upgrade_container: VBoxContainer


func _ready() -> void:
    _build_interface()
    refresh_menu()


func bind_data(state: RefCounted, store: RefCounted) -> void:
    economy_state = state
    save_store = store

    if economy_state != null:
        selected_bike_id = str(economy_state.get("active_bike_id"))

    refresh_menu()


func _build_interface() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_theme_constant_override("separation", 10)
    add_child(root)

    var title := Label.new()
    title.text = "NAMI GARAGE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(title)

    _cash_label = Label.new()
    _cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(_cash_label)

    var bike_title := Label.new()
    bike_title.text = "MOTORCYCLES"
    root.add_child(bike_title)

    _bike_container = VBoxContainer.new()
    root.add_child(_bike_container)

    var upgrade_title := Label.new()
    upgrade_title.text = "UPGRADES"
    root.add_child(upgrade_title)

    _upgrade_container = VBoxContainer.new()
    root.add_child(_upgrade_container)

    _status_label = Label.new()
    _status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(_status_label)

    var close_button := Button.new()
    close_button.text = "CLOSE"
    close_button.pressed.connect(func() -> void:
        close_requested.emit()
    )
    root.add_child(close_button)


func refresh_menu() -> void:
    if not is_node_ready():
        return

    _cash_label.text = "CASH: $%d" % _get_cash()
    _clear_container(_bike_container)
    _clear_container(_upgrade_container)

    for bike_id in Catalog.get_bike_ids():
        var info: Dictionary = Catalog.get_bike_info(bike_id)
        var price: int = Catalog.get_bike_price(bike_id)
        var owned: bool = _owns_bike(bike_id)
        var active: bool = _get_active_bike() == bike_id

        var button := Button.new()
        var state_text: String

        if active:
            state_text = "EQUIPPED"
        elif owned:
            state_text = "EQUIP"
        else:
            state_text = "BUY $%d" % price

        button.text = "%s  |  %s" % [
            str(info.get("display_name", bike_id)),
            state_text
        ]
        button.pressed.connect(_on_bike_selected.bind(str(bike_id)))
        _bike_container.add_child(button)

    var selected_owned: bool = _owns_bike(selected_bike_id)

    for track_id in Catalog.get_upgrade_track_ids():
        var row := HBoxContainer.new()
        var level: int = _get_upgrade_level(selected_bike_id, track_id)
        var max_level: int = Catalog.get_max_upgrade_level(track_id)
        var cost: int = Catalog.get_upgrade_cost(track_id, level)

        var info: Dictionary = Catalog.UPGRADE_TRACKS[track_id]
        var label := Label.new()
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        label.text = "%s  Lv.%d/%d" % [
            str(info.get("display_name", track_id)),
            level,
            max_level
        ]
        row.add_child(label)

        var button := Button.new()
        if level >= max_level:
            button.text = "MAX"
            button.disabled = true
        else:
            button.text = "UPGRADE $%d" % cost
            button.disabled = not selected_owned or _get_cash() < cost

        button.pressed.connect(_on_upgrade_pressed.bind(str(track_id)))
        row.add_child(button)
        _upgrade_container.add_child(row)

    if not selected_owned:
        _status_label.text = "Select a motorcycle to purchase it."
    elif selected_bike_id == _get_active_bike():
        _status_label.text = "Currently equipped."
    else:
        _status_label.text = "Motorcycle owned. Equip it to ride."


func select_bike(bike_id: String) -> bool:
    if not Catalog.has_bike(bike_id):
        return false

    selected_bike_id = bike_id
    refresh_menu()
    return true


func purchase_selected_bike() -> bool:
    if economy_state == null or _owns_bike(selected_bike_id):
        return false

    if not economy_state.buy_bike(selected_bike_id):
        _set_status("Not enough cash or invalid purchase.")
        refresh_menu()
        return false

    _save_progress()
    purchase_completed.emit(selected_bike_id)
    _set_status("Motorcycle purchased.")
    refresh_menu()
    return true


func equip_selected_bike() -> bool:
    if economy_state == null:
        return false

    if not economy_state.equip_bike(selected_bike_id):
        _set_status("Motorcycle is not owned.")
        return false

    _save_progress()
    bike_equipped.emit(selected_bike_id)
    _set_status("Motorcycle equipped.")
    refresh_menu()
    return true


func purchase_upgrade(track_id: String) -> bool:
    if economy_state == null or not _owns_bike(selected_bike_id):
        return false

    if not Catalog.has_track(track_id):
        return false

    if not economy_state.buy_upgrade(selected_bike_id, track_id):
        _set_status("Upgrade unavailable or insufficient cash.")
        refresh_menu()
        return false

    _save_progress()
    purchase_completed.emit("%s:%s" % [selected_bike_id, track_id])
    _set_status("Upgrade purchased.")
    refresh_menu()
    return true


func _on_bike_selected(bike_id: String) -> void:
    select_bike(bike_id)

    if _owns_bike(bike_id):
        equip_selected_bike()
    else:
        purchase_selected_bike()


func _on_upgrade_pressed(track_id: String) -> void:
    purchase_upgrade(track_id)


func _get_cash() -> int:
    if economy_state == null:
        return 0
    return int(economy_state.get("cash"))


func _get_active_bike() -> String:
    if economy_state == null:
        return ""
    return str(economy_state.get("active_bike_id"))


func _owns_bike(bike_id: String) -> bool:
    if economy_state == null:
        return false
    return bool(economy_state.owns_bike(bike_id))


func _get_upgrade_level(bike_id: String, track_id: String) -> int:
    if economy_state == null:
        return 0
    return int(economy_state.get_upgrade_level(bike_id, track_id))


func _save_progress() -> void:
    if save_store != null and economy_state != null:
        if not save_store.save_state(economy_state):
            push_warning("[GARAGE] Save failed: " + str(save_store.get("last_error")))


func _set_status(message: String) -> void:
    if _status_label != null:
        _status_label.text = message


func _clear_container(container: Node) -> void:
    for child in container.get_children():
        container.remove_child(child)
        child.queue_free()
