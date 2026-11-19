class_name GameplayHUD
extends Control

signal pause_requested

@export var popup_duration_sec: float = 1.1
@export var speed_display_scale: float = 0.25

var _bike: Node2D = null
var _controller: Node = null
var _economy: RefCounted = null
var _tracker: Node = null

var _popup_timer: float = 0.0
var _last_combo: int = 1
var _last_cash: int = 0

@onready var speed_label: Label = $TopBar/SpeedLabel
@onready var gear_label: Label = $TopBar/GearLabel
@onready var rpm_label: Label = $TopBar/RpmLabel
@onready var rpm_bar: ProgressBar = $TopBar/RpmBar
@onready var rev_badge: Label = $TopBar/RevBadge
@onready var cash_label: Label = $TopBar/CashLabel
@onready var pause_button: Button = $TopBar/PauseButton
@onready var combo_label: Label = $StatusBanner/ComboLabel
@onready var popup_label: Label = $StatusBanner/PopupLabel


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if pause_button != null:
        pause_button.focus_mode = Control.FOCUS_NONE
        if not pause_button.pressed.is_connected(_on_pause_button_pressed):
            pause_button.pressed.connect(_on_pause_button_pressed)

    _set_combo_display(1)
    _hide_popup()
    refresh_now()


func bind_bike(bike: Node2D) -> void:
    _bike = bike
    _controller = null
    if _bike != null and is_instance_valid(_bike):
        _controller = _bike.get_node_or_null("BikeController")
    refresh_now()


func bind_economy(economy_state: RefCounted) -> void:
    if _economy != null and is_instance_valid(_economy):
        if _economy.has_signal("cash_changed") and _economy.cash_changed.is_connected(_on_cash_changed):
            _economy.cash_changed.disconnect(_on_cash_changed)

    _economy = economy_state
    if _economy != null and is_instance_valid(_economy):
        if _economy.has_signal("cash_changed") and not _economy.cash_changed.is_connected(_on_cash_changed):
            _economy.cash_changed.connect(_on_cash_changed)
        _last_cash = int(_economy.get("cash")) if "cash" in _economy else 0
    else:
        _last_cash = 0

    refresh_now()


func bind_reward_tracker(tracker: Node) -> void:
    if _tracker != null and is_instance_valid(_tracker):
        if _tracker.has_signal("reward_earned") and _tracker.reward_earned.is_connected(_on_reward_earned):
            _tracker.reward_earned.disconnect(_on_reward_earned)
        if _tracker.has_signal("combo_changed") and _tracker.combo_changed.is_connected(_on_combo_changed):
            _tracker.combo_changed.disconnect(_on_combo_changed)
        if _tracker.has_signal("combo_reset") and _tracker.combo_reset.is_connected(_on_combo_reset):
            _tracker.combo_reset.disconnect(_on_combo_reset)

    _tracker = tracker
    if _tracker != null and is_instance_valid(_tracker):
        if _tracker.has_signal("reward_earned") and not _tracker.reward_earned.is_connected(_on_reward_earned):
            _tracker.reward_earned.connect(_on_reward_earned)
        if _tracker.has_signal("combo_changed") and not _tracker.combo_changed.is_connected(_on_combo_changed):
            _tracker.combo_changed.connect(_on_combo_changed)
        if _tracker.has_signal("combo_reset") and not _tracker.combo_reset.is_connected(_on_combo_reset):
            _tracker.combo_reset.connect(_on_combo_reset)

    refresh_now()


func _exit_tree() -> void:
    bind_economy(null)
    bind_reward_tracker(null)


func _on_pause_button_pressed() -> void:
    pause_requested.emit()


func _on_cash_changed(new_cash: int, _delta: int, _reason: String) -> void:
    _last_cash = new_cash
    if cash_label != null:
        cash_label.text = "$%d" % _last_cash


func _on_reward_earned(reward_type: String, amount: int, combo: int) -> void:
    var title: String = reward_type.replace("_", " ").to_upper()
    if combo > 1:
        show_popup("%s +$%d (x%d)" % [title, amount, combo])
    else:
        show_popup("%s +$%d" % [title, amount])
    _set_combo_display(combo)


func _on_combo_changed(new_combo: int) -> void:
    _set_combo_display(new_combo)


func _on_combo_reset(_reason: String) -> void:
    _set_combo_display(1)


func show_popup(text: String, duration: float = -1.0) -> void:
    if popup_label == null:
        return
    popup_label.text = text
    popup_label.visible = true
    _popup_timer = popup_duration_sec if duration < 0.0 else maxf(0.05, duration)


func _hide_popup() -> void:
    _popup_timer = 0.0
    if popup_label != null:
        popup_label.visible = false
        popup_label.text = ""


func _set_combo_display(combo_val: int) -> void:
    _last_combo = maxi(1, combo_val)
    if combo_label == null:
        return
    if _last_combo > 1:
        combo_label.visible = true
        combo_label.text = "COMBO x%d" % _last_combo
    else:
        combo_label.visible = false
        combo_label.text = ""


func _physics_process(delta: float) -> void:
    if delta > 0.0 and _popup_timer > 0.0:
        _popup_timer = maxf(0.0, _popup_timer - delta)
        if _popup_timer <= 0.0:
            _hide_popup()
    refresh_now()


func refresh_now() -> void:
    var speed_kmh: int = 0
    var gear_text: String = "1"
    var rpm_val: float = 0.0
    var max_rpm: float = 10200.0
    var limiter_on: bool = false

    if _bike != null and is_instance_valid(_bike) and "linear_velocity" in _bike:
        var vel: Vector2 = _bike.get("linear_velocity")
        speed_kmh = int(round(vel.length() * speed_display_scale))

    if _controller != null and is_instance_valid(_controller) and _controller.has_method("get_controller_state"):
        var cst: Dictionary = _controller.get_controller_state()
        var gear_num: int = int(cst.get("gear", 1))
        gear_text = "N" if gear_num == 0 else str(gear_num)
        rpm_val = float(cst.get("rpm", 0.0))
        limiter_on = bool(cst.get("rev_limiter", false))

        var cfg = _controller.get("drivetrain_config")
        if cfg != null and "rev_limiter_rpm" in cfg:
            max_rpm = maxf(1.0, float(cfg.get("rev_limiter_rpm")))

    if speed_label != null:
        speed_label.text = "%d KM/H" % speed_kmh
    if gear_label != null:
        gear_label.text = "G:%s" % gear_text
    if rpm_label != null:
        rpm_label.text = "%d RPM" % int(round(rpm_val))
    if rpm_bar != null:
        rpm_bar.max_value = max_rpm
        rpm_bar.value = clampf(rpm_val, 0.0, max_rpm)
    if rev_badge != null:
        rev_badge.visible = limiter_on

    if _economy != null and is_instance_valid(_economy) and "cash" in _economy:
        _last_cash = int(_economy.get("cash"))
    if cash_label != null:
        cash_label.text = "$%d" % _last_cash


func get_hud_state() -> Dictionary:
    return {
        "speed_text": speed_label.text if speed_label != null else "",
        "gear_text": gear_label.text if gear_label != null else "",
        "rpm_text": rpm_label.text if rpm_label != null else "",
        "rpm_value": rpm_bar.value if rpm_bar != null else 0.0,
        "rev_limiter_visible": rev_badge.visible if rev_badge != null else false,
        "cash_text": cash_label.text if cash_label != null else "",
        "combo": _last_combo,
        "combo_visible": combo_label.visible if combo_label != null else false,
        "popup_visible": popup_label.visible if popup_label != null else false,
        "popup_text": popup_label.text if popup_label != null else ""
    }
