extends Node2D

const PlayerEconomyStateScript = preload("res://src/economy/player_economy_state.gd")
const RewardTrackerScript = preload("res://src/economy/reward_tracker.gd")

var _ticks: int = 0
var _finished: bool = false

var _idle_state_ok: bool = false
var _moving_state_ok: bool = false
var _popup_visible_on_reward: bool = false
var _combo_x2_ok: bool = false
var _popup_expired_ok: bool = false
var _combo_reset_on_collision_ok: bool = false
var _pause_signal_count: int = 0

var _economy: PlayerEconomyStateScript
var _tracker: Node

@onready var bike: RigidBody2D = $Bike
@onready var hud: Control = $CanvasLayer/GameplayHUD


func _ready() -> void:
    process_physics_priority = -20
    if not hud.has_method("get_hud_state"):
        print("[GAMEPLAY HUD TEST FAIL] GameplayHUD script missing")
        _finished = true
        get_tree().quit(1)
        return

    _economy = PlayerEconomyStateScript.new()
    _tracker = RewardTrackerScript.new()
    _tracker.name = "RewardTracker"
    add_child(_tracker)

    _tracker.bind_economy(_economy)
    _tracker.bind_bike(bike)

    hud.bind_bike(bike)
    hud.bind_economy(_economy)
    hud.bind_reward_tracker(_tracker)
    hud.pause_requested.connect(func() -> void:
        _pause_signal_count += 1
    )

    var st0: Dictionary = hud.get_hud_state()
    _idle_state_ok = (
        st0["gear_text"] == "G:1"
        and st0["cash_text"] == "$0"
        and st0["combo_visible"] == false
        and st0["popup_visible"] == false
    )


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1
    var ctrl: Node = bike.get_node("BikeController")

    # Tick 15: Accelerate bike so speed, RPM, and bar advance
    if _ticks == 15:
        ctrl.set_input_override({"gas": 1.0})

    # Tick 55: Capture moving HUD state + trigger a reward + pause button press
    if _ticks == 55:
        var st_move: Dictionary = hud.get_hud_state()
        _moving_state_ok = (
            float(st_move["rpm_value"]) > 2500.0
            and str(st_move["speed_text"]) != "0 KM/H"
        )
        _tracker._on_traffic_near_miss(null, bike, 240.0)
        var st_rew: Dictionary = hud.get_hud_state()
        _popup_visible_on_reward = (
            bool(st_rew["popup_visible"]) == true
            and str(st_rew["popup_text"]).begins_with("NEAR MISS")
            and int(st_rew["combo"]) == 2
            and bool(st_rew["combo_visible"]) == true
            and str(st_rew["cash_text"]) != "$0"
        )
        _combo_x2_ok = int(st_rew["combo"]) == 2
        hud.get_node("TopBar/PauseButton").pressed.emit()

    # Tick 100 (45 ticks = 0.75s > 0.6s popup_duration_sec): popup should have hidden automatically
    if _ticks == 100:
        var st_after: Dictionary = hud.get_hud_state()
        _popup_expired_ok = bool(st_after["popup_visible"]) == false

        # Trigger collision -> resets combo back to x1 and hides combo badge
        _tracker._on_traffic_collision(null, bike, 180.0)
        var st_col: Dictionary = hud.get_hud_state()
        _combo_reset_on_collision_ok = int(st_col["combo"]) == 1 and bool(st_col["combo_visible"]) == false

        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var checks := {
        "idle_state_valid": _idle_state_ok,
        "moving_updates_speed_and_rpm": _moving_state_ok,
        "reward_shows_popup_and_cash": _popup_visible_on_reward,
        "combo_x2_displayed": _combo_x2_ok,
        "popup_auto_hides_after_duration": _popup_expired_ok,
        "collision_resets_combo_badge": _combo_reset_on_collision_ok,
        "pause_button_emits_signal": _pause_signal_count == 1
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[GAMEPLAY HUD TEST FAIL] ", key)
            all_ok = false

    var final_st: Dictionary = hud.get_hud_state()
    print(
        "Gameplay HUD -> speed: ", final_st["speed_text"],
        " | gear: ", final_st["gear_text"],
        " | rpm: ", final_st["rpm_text"],
        " | cash: ", final_st["cash_text"],
        " | pauses: ", _pause_signal_count
    )

    if all_ok:
        print("[GAMEPLAY HUD TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
