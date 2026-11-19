extends Node2D

const PlayerEconomyStateScript = preload("res://src/economy/player_economy_state.gd")
const BikeUpgradeApplierScript = preload("res://src/economy/bike_upgrade_applier.gd")
const RewardTrackerScript = preload("res://src/economy/reward_tracker.gd")

var _ticks: int = 0
var _finished: bool = false

var _idempotent_ok: bool = false
var _stiffness_ratio_ok: bool = false
var _stock_accel_x: float = 0.0
var _upgraded_accel_x: float = 0.0
var _stock_accel_vx: float = 0.0
var _upgraded_accel_vx: float = 0.0
var _min_wheelie_rot: float = 0.0

var _economy: PlayerEconomyStateScript
var _tracker: Node
var _reward_log: Array = []
var _combo_reset_reasons: Array = []

@onready var stock_bike: RigidBody2D = $StockBike
@onready var upgraded_bike: RigidBody2D = $UpgradedBike
@onready var dummy_spawner: Node2D = $TrafficSpawner


func _ready() -> void:
    process_physics_priority = -20

    # 1. Economy state for upgraded bike (T-Max + Engine L3 + Gearing L3 + Suspension L2)
    var upg_state = PlayerEconomyStateScript.new()
    upg_state.add_cash(10000, "test_budget")
    upg_state.buy_bike("tmax")
    upg_state.equip_bike("tmax")
    upg_state.buy_upgrade("tmax", "engine")
    upg_state.buy_upgrade("tmax", "engine")
    upg_state.buy_upgrade("tmax", "engine")
    upg_state.buy_upgrade("tmax", "gearing")
    upg_state.buy_upgrade("tmax", "gearing")
    upg_state.buy_upgrade("tmax", "gearing")
    upg_state.buy_upgrade("tmax", "suspension")
    upg_state.buy_upgrade("tmax", "suspension")

    var stock_mods: Dictionary = BikeUpgradeApplierScript.apply_bike_profile(stock_bike, "cg125", {})
    var upg_mods_1: Dictionary = BikeUpgradeApplierScript.apply_economy_state(upgraded_bike, upg_state)
    var force_after_first: float = float(upgraded_bike.get_node("BikeController").get("drivetrain_config").get("base_drive_force"))
    var upg_mods_2: Dictionary = BikeUpgradeApplierScript.apply_economy_state(upgraded_bike, upg_state)
    var force_after_second: float = float(upgraded_bike.get_node("BikeController").get("drivetrain_config").get("base_drive_force"))

    _idempotent_ok = (
        absf(force_after_first - force_after_second) < 0.01
        and float(upg_mods_1["torque_mult"]) > float(stock_mods["torque_mult"]) * 1.5
        and absf(float(upg_mods_1["torque_mult"]) - float(upg_mods_2["torque_mult"])) < 0.001
    )

    var stock_stiff: float = float(stock_bike.get("config").get("front_stiffness"))
    var upg_stiff: float = float(upgraded_bike.get("config").get("front_stiffness"))
    var expected_ratio: float = float(upg_mods_1["suspension_mult"])
    _stiffness_ratio_ok = absf((upg_stiff / stock_stiff) - expected_ratio) < 0.01

    # 2. Setup RewardTracker on stock_bike + fresh economy state
    _economy = PlayerEconomyStateScript.new()
    _tracker = RewardTrackerScript.new()
    _tracker.name = "RewardTracker"
    add_child(_tracker)
    _tracker.bind_economy(_economy)
    _tracker.bind_bike(stock_bike)
    _tracker.bind_traffic_spawner(dummy_spawner)
    _tracker.reward_earned.connect(_on_reward_earned)
    _tracker.combo_reset.connect(_on_combo_reset)


func _on_reward_earned(reward_type: String, amount: int, combo: int) -> void:
    _reward_log.append({"type": reward_type, "amount": amount, "combo": combo})


func _on_combo_reset(reason: String) -> void:
    _combo_reset_reasons.append(reason)


func _reset_bike_for_wheelie(bike: RigidBody2D, pos: Vector2) -> void:
    var xf := Transform2D(0.0, pos)
    bike.global_transform = xf
    bike.linear_velocity = Vector2.ZERO
    bike.angular_velocity = 0.0
    var rid: RID = bike.get_rid()
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, xf)
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)

    var ctrl: Node = bike.get_node("BikeController")
    var dt = ctrl.get("drivetrain")
    if dt != null:
        dt.current_gear = 1
        dt.throttle = 0.0
        dt.rpm = float(dt.config.idle_rpm)


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1
    var stock_ctrl: Node = stock_bike.get_node("BikeController")
    var upg_ctrl: Node = upgraded_bike.get_node("BikeController")

    # Phase A (ticks 20..120): Identical drag race comparison on Stock vs Upgraded
    if _ticks == 20:
        stock_ctrl.set_input_override({"gas": 1.0})
        upg_ctrl.set_input_override({"gas": 1.0})

    if _ticks == 65:
        stock_ctrl.set_input_override({"gas": 1.0, "shift_up": true})
        upg_ctrl.set_input_override({"gas": 1.0, "shift_up": true})

    if _ticks == 66:
        stock_ctrl.set_input_override({"gas": 1.0})
        upg_ctrl.set_input_override({"gas": 1.0})

    if _ticks == 120:
        _stock_accel_x = stock_bike.global_position.x
        _upgraded_accel_x = upgraded_bike.global_position.x
        _stock_accel_vx = stock_bike.linear_velocity.x
        _upgraded_accel_vx = upgraded_bike.linear_velocity.x

        # Stop upgraded bike and reset stock bike to standstill in Gear 1 for a clean wheelie launch
        upg_ctrl.set_input_override({})
        stock_ctrl.set_input_override({})
        _reset_bike_for_wheelie(stock_bike, Vector2(100.0, 62.0))

    # Phase B (ticks 136..200): Launch from Gear 1 with gas + lean_back, shift to Gear 2 to sustain wheelie
    if _ticks == 136:
        stock_ctrl.set_input_override({"gas": 1.0, "lean_back": 1.0})

    if _ticks == 165:
        stock_ctrl.set_input_override({"gas": 1.0, "lean_back": 1.0, "shift_up": true})

    if _ticks == 166:
        stock_ctrl.set_input_override({"gas": 1.0, "lean_back": 1.0})

    if _ticks >= 136 and _ticks <= 215:
        _min_wheelie_rot = minf(_min_wheelie_rot, stock_bike.rotation)

    if _ticks == 196:
        stock_ctrl.set_input_override({"gas": 0.1})

    # Phase C (ticks 240..260): Trigger two near-misses then a collision via TrafficSpawner
    if _ticks == 240:
        stock_ctrl.set_input_override({})
        dummy_spawner.traffic_near_miss.emit(null, stock_bike, 250.0)

    if _ticks == 250:
        dummy_spawner.traffic_near_miss.emit(null, stock_bike, 250.0)

    if _ticks == 260:
        dummy_spawner.traffic_collision.emit(null, stock_bike, 220.0)

    if _ticks >= 270:
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var tr_st: Dictionary = _tracker.get_tracker_state()

    var nm_payouts: Array = []
    var wheelie_payouts: Array = []
    for entry in _reward_log:
        if entry["type"] == "near_miss":
            nm_payouts.append(int(entry["amount"]))
        elif entry["type"] == "wheelie":
            wheelie_payouts.append(int(entry["amount"]))

    var checks := {
        "upgrade_apply_idempotent": _idempotent_ok,
        "suspension_stiffness_scaled": _stiffness_ratio_ok,
        "upgraded_bike_faster": _upgraded_accel_vx > _stock_accel_vx * 1.25,
        "upgraded_bike_covered_more_distance": _upgraded_accel_x > _stock_accel_x + 40.0,
        "wheelie_detected_and_paid": wheelie_payouts.size() >= 1 and float(_economy.stats["longest_wheelie_sec"]) >= 0.25,
        "near_miss_escalated_with_combo": nm_payouts.size() == 2 and nm_payouts[1] > nm_payouts[0],
        "collision_reset_combo": int(tr_st["combo"]) == 1 and int(tr_st["collision_resets"]) == 1 and _combo_reset_reasons.has("collision"),
        "economy_cash_matches_session": _economy.cash == int(tr_st["session_earned"]) and _economy.cash > 100
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[UPGRADES REWARDS TEST FAIL] ", key)
            all_ok = false

    print(
        "Upgrades & Rewards -> vx(stock/upg): ", snappedf(_stock_accel_vx, 0.1), "/", snappedf(_upgraded_accel_vx, 0.1),
        " | x(stock/upg): ", snappedf(_stock_accel_x, 0.1), "/", snappedf(_upgraded_accel_x, 0.1),
        " | min_rot: ", snappedf(_min_wheelie_rot, 0.001),
        " | wheelie_sec: ", snappedf(float(_economy.stats["longest_wheelie_sec"]), 0.01),
        " | nm_payouts: ", nm_payouts,
        " | cash: ", _economy.cash
    )

    if all_ok:
        print("[UPGRADES AND REWARDS TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
