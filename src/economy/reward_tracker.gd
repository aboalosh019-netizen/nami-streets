class_name RewardTracker
extends Node

const PlayerEconomyStateScript = preload("res://src/economy/player_economy_state.gd")

signal reward_earned(reward_type: String, amount: int, combo: int)
signal combo_changed(new_combo: int)
signal combo_reset(reason: String)

@export_group("Near Miss Rewards")
@export var base_near_miss_cash: int = 35
@export var near_miss_speed_factor: float = 0.08
@export var max_combo: int = 5
@export var combo_timeout_sec: float = 4.0

@export_group("Wheelie Rewards")
@export var min_wheelie_angle_rad: float = 0.14
@export var min_wheelie_speed: float = 60.0
@export var min_wheelie_duration: float = 0.25
@export var wheelie_cash_per_sec: float = 80.0

@export_group("High Speed Rewards")
@export var high_speed_threshold: float = 340.0
@export var high_speed_payout_interval: float = 1.0
@export var high_speed_cash_per_tick: int = 15

var economy_state: PlayerEconomyStateScript = null

var _bike: Node2D = null
var _spawner: Node = null

var _combo: int = 1
var _combo_timer: float = 0.0
var _wheelie_active: bool = false
var _wheelie_duration: float = 0.0
var _high_speed_timer: float = 0.0

var _session_earned: int = 0
var _near_miss_rewards: int = 0
var _wheelie_rewards: int = 0
var _high_speed_rewards: int = 0
var _collision_resets: int = 0


func bind_economy(state: PlayerEconomyStateScript) -> void:
    economy_state = state


func bind_bike(bike: Node2D) -> void:
    _bike = bike
    _wheelie_active = false
    _wheelie_duration = 0.0
    _high_speed_timer = 0.0


func bind_traffic_spawner(spawner: Node) -> void:
    unbind_traffic_spawner()
    _spawner = spawner
    if _spawner == null or not is_instance_valid(_spawner):
        _spawner = null
        return

    if _spawner.has_signal("traffic_near_miss") and not _spawner.traffic_near_miss.is_connected(_on_traffic_near_miss):
        _spawner.traffic_near_miss.connect(_on_traffic_near_miss)
    if _spawner.has_signal("traffic_collision") and not _spawner.traffic_collision.is_connected(_on_traffic_collision):
        _spawner.traffic_collision.connect(_on_traffic_collision)


func unbind_traffic_spawner() -> void:
    if _spawner != null and is_instance_valid(_spawner):
        if _spawner.has_signal("traffic_near_miss") and _spawner.traffic_near_miss.is_connected(_on_traffic_near_miss):
            _spawner.traffic_near_miss.disconnect(_on_traffic_near_miss)
        if _spawner.has_signal("traffic_collision") and _spawner.traffic_collision.is_connected(_on_traffic_collision):
            _spawner.traffic_collision.disconnect(_on_traffic_collision)
    _spawner = null


func _exit_tree() -> void:
    unbind_traffic_spawner()


func _physics_process(delta: float) -> void:
    if delta <= 0.0:
        return

    if _combo > 1:
        _combo_timer -= delta
        if _combo_timer <= 0.0:
            _reset_combo("timeout")

    if _bike == null or not is_instance_valid(_bike) or not _bike.has_method("get_telemetry"):
        return

    var tel: Dictionary = _bike.get_telemetry()
    _update_wheelie(delta, tel)
    _update_high_speed(delta, tel)


func _update_wheelie(delta: float, tel: Dictionary) -> void:
    var front_grounded: bool = bool(tel.get("front_grounded", true))
    var rear_grounded: bool = bool(tel.get("rear_grounded", true))
    var is_stable: bool = bool(tel.get("is_stable", true))
    var rot: float = float(tel.get("rotation", 0.0))
    var vel: Vector2 = tel.get("linear_velocity", Vector2.ZERO)
    var fwd_speed: float = vel.x

    if not is_stable:
        if _wheelie_active:
            _wheelie_active = false
            _wheelie_duration = 0.0
        _reset_combo("crash")
        return

    var in_wheelie: bool = (
        rear_grounded
        and not front_grounded
        and fwd_speed >= min_wheelie_speed
        and rot <= -min_wheelie_angle_rad
    )

    if in_wheelie:
        _wheelie_active = true
        _wheelie_duration += delta
        _combo_timer = combo_timeout_sec
    elif _wheelie_active:
        if front_grounded and rear_grounded:
            _bank_wheelie()
        elif not rear_grounded:
            # Bike became airborne; do not bank yet unless it lands cleanly
            pass
        else:
            _bank_wheelie()


func _bank_wheelie() -> void:
    var dur: float = _wheelie_duration
    _wheelie_active = false
    _wheelie_duration = 0.0

    if dur < min_wheelie_duration:
        return

    if economy_state != null:
        economy_state.record_wheelie_duration(dur)

    var payout: int = maxi(1, int(round(dur * wheelie_cash_per_sec * float(_combo))))
    _wheelie_rewards += 1
    _grant_reward("wheelie", payout)
    _increment_combo()


func _update_high_speed(delta: float, tel: Dictionary) -> void:
    var vel: Vector2 = tel.get("linear_velocity", Vector2.ZERO)
    var grounded: bool = bool(tel.get("rear_grounded", false)) or bool(tel.get("front_grounded", false))
    if grounded and absf(vel.x) >= high_speed_threshold:
        _high_speed_timer += delta
        if _high_speed_timer >= high_speed_payout_interval:
            _high_speed_timer -= high_speed_payout_interval
            var payout: int = maxi(1, high_speed_cash_per_tick * _combo)
            _high_speed_rewards += 1
            _grant_reward("high_speed", payout)
    else:
        _high_speed_timer = 0.0


func _on_traffic_near_miss(_vehicle: Node2D, _bike_node: Node2D, relative_speed: float) -> void:
    var speed_bonus: float = maxf(0.0, relative_speed) * near_miss_speed_factor
    var payout: int = maxi(1, int(round((float(base_near_miss_cash) + speed_bonus) * float(_combo))))
    _near_miss_rewards += 1

    if economy_state != null:
        economy_state.record_near_miss(_combo)

    _grant_reward("near_miss", payout)
    _increment_combo()


func _on_traffic_collision(_vehicle: Node2D, _bike_node: Node2D, _relative_speed: float) -> void:
    _wheelie_active = false
    _wheelie_duration = 0.0
    _high_speed_timer = 0.0
    _collision_resets += 1
    _reset_combo("collision")


func _increment_combo() -> void:
    _combo_timer = combo_timeout_sec
    var next_combo: int = mini(max_combo, _combo + 1)
    if next_combo != _combo:
        _combo = next_combo
        combo_changed.emit(_combo)


func _reset_combo(reason: String) -> void:
    _combo_timer = 0.0
    if _combo != 1:
        _combo = 1
        combo_changed.emit(_combo)
    combo_reset.emit(reason)


func _grant_reward(reward_type: String, amount: int) -> void:
    if amount <= 0:
        return
    _session_earned += amount
    if economy_state != null:
        economy_state.add_cash(amount, reward_type)
    reward_earned.emit(reward_type, amount, _combo)


func get_tracker_state() -> Dictionary:
    return {
        "combo": _combo,
        "combo_timer": _combo_timer,
        "wheelie_active": _wheelie_active,
        "wheelie_duration": _wheelie_duration,
        "session_earned": _session_earned,
        "near_miss_rewards": _near_miss_rewards,
        "wheelie_rewards": _wheelie_rewards,
        "high_speed_rewards": _high_speed_rewards,
        "collision_resets": _collision_resets
    }
