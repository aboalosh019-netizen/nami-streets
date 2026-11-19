class_name PlayerEconomyState
extends RefCounted

const UpgradeCatalogScript = preload("res://src/economy/upgrade_catalog.gd")

const SAVE_VERSION: int = 1
const DEFAULT_BIKE_ID: String = "cg125"

signal cash_changed(new_cash: int, delta: int, reason: String)
signal bike_purchased(bike_id: String)
signal active_bike_changed(bike_id: String)
signal upgrade_purchased(bike_id: String, track_id: String, new_level: int)

var cash: int = 0
var owned_bikes: Array = []
var active_bike_id: String = DEFAULT_BIKE_ID
var upgrades_by_bike: Dictionary = {}
var stats: Dictionary = {}


func _init() -> void:
    reset_to_defaults()


func reset_to_defaults() -> void:
    cash = 0
    owned_bikes = [DEFAULT_BIKE_ID]
    active_bike_id = DEFAULT_BIKE_ID
    upgrades_by_bike = {
        DEFAULT_BIKE_ID: UpgradeCatalogScript.create_default_upgrade_levels()
    }
    stats = {
        "total_earned": 0,
        "total_spent": 0,
        "near_misses": 0,
        "longest_wheelie_sec": 0.0,
        "highest_combo": 1
    }


func add_cash(amount: int, reason: String = "reward") -> bool:
    if amount <= 0:
        return false
    cash += amount
    stats["total_earned"] = int(stats.get("total_earned", 0)) + amount
    cash_changed.emit(cash, amount, reason)
    return true


func spend_cash(amount: int, reason: String = "purchase") -> bool:
    if amount <= 0 or cash < amount:
        return false
    cash -= amount
    stats["total_spent"] = int(stats.get("total_spent", 0)) + amount
    cash_changed.emit(cash, -amount, reason)
    return true


func owns_bike(bike_id: String) -> bool:
    return owned_bikes.has(bike_id)


func buy_bike(bike_id: String) -> bool:
    if not UpgradeCatalogScript.has_bike(bike_id):
        return false
    if owns_bike(bike_id):
        return false

    var price: int = UpgradeCatalogScript.get_bike_price(bike_id)
    if price < 0 or cash < price:
        return false

    if price > 0:
        if not spend_cash(price, "buy_bike:" + bike_id):
            return false

    owned_bikes.append(bike_id)
    if not upgrades_by_bike.has(bike_id):
        upgrades_by_bike[bike_id] = UpgradeCatalogScript.create_default_upgrade_levels()

    bike_purchased.emit(bike_id)
    return true


func equip_bike(bike_id: String) -> bool:
    if not UpgradeCatalogScript.has_bike(bike_id):
        return false
    if not owns_bike(bike_id):
        return false

    if active_bike_id == bike_id:
        return true

    active_bike_id = bike_id
    active_bike_changed.emit(active_bike_id)
    return true


func get_upgrade_level(bike_id: String, track_id: String) -> int:
    if not upgrades_by_bike.has(bike_id):
        return 0
    var bike_upgrades: Dictionary = upgrades_by_bike[bike_id] as Dictionary
    return int(bike_upgrades.get(track_id, 0))


func get_bike_upgrades(bike_id: String = "") -> Dictionary:
    var target_id: String = bike_id if not bike_id.is_empty() else active_bike_id
    if not upgrades_by_bike.has(target_id):
        return UpgradeCatalogScript.create_default_upgrade_levels()
    return (upgrades_by_bike[target_id] as Dictionary).duplicate()


func get_next_upgrade_cost(bike_id: String, track_id: String) -> int:
    if not owns_bike(bike_id) or not UpgradeCatalogScript.has_track(track_id):
        return -1
    var cur_lvl: int = get_upgrade_level(bike_id, track_id)
    return UpgradeCatalogScript.get_upgrade_cost(track_id, cur_lvl)


func buy_upgrade(bike_id: String, track_id: String) -> bool:
    if not owns_bike(bike_id) or not UpgradeCatalogScript.has_track(track_id):
        return false

    var cur_lvl: int = get_upgrade_level(bike_id, track_id)
    var max_lvl: int = UpgradeCatalogScript.get_max_upgrade_level(track_id)
    if cur_lvl >= max_lvl:
        return false

    var cost: int = UpgradeCatalogScript.get_upgrade_cost(track_id, cur_lvl)
    if cost < 0 or cash < cost:
        return false

    if not spend_cash(cost, "upgrade:" + bike_id + ":" + track_id):
        return false

    if not upgrades_by_bike.has(bike_id):
        upgrades_by_bike[bike_id] = UpgradeCatalogScript.create_default_upgrade_levels()

    var new_lvl: int = cur_lvl + 1
    (upgrades_by_bike[bike_id] as Dictionary)[track_id] = new_lvl
    upgrade_purchased.emit(bike_id, track_id, new_lvl)
    return true


func get_active_modifiers() -> Dictionary:
    return UpgradeCatalogScript.get_effective_modifiers(
        active_bike_id,
        get_bike_upgrades(active_bike_id)
    )


func record_near_miss(combo_value: int = 1) -> void:
    stats["near_misses"] = int(stats.get("near_misses", 0)) + 1
    stats["highest_combo"] = maxi(int(stats.get("highest_combo", 1)), combo_value)


func record_wheelie_duration(duration_sec: float) -> void:
    if duration_sec > float(stats.get("longest_wheelie_sec", 0.0)):
        stats["longest_wheelie_sec"] = duration_sec


func to_dict() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "cash": cash,
        "owned_bikes": owned_bikes.duplicate(),
        "active_bike_id": active_bike_id,
        "upgrades_by_bike": upgrades_by_bike.duplicate(true),
        "stats": stats.duplicate(true)
    }


func from_dict(data: Dictionary) -> bool:
    if data.is_empty() or not data.has("cash"):
        return false

    reset_to_defaults()
    cash = maxi(0, int(data.get("cash", 0)))

    var loaded_owned: Array = []
    var raw_owned = data.get("owned_bikes", [DEFAULT_BIKE_ID])
    if raw_owned is Array:
        for item in raw_owned:
            var bid: String = str(item)
            if UpgradeCatalogScript.has_bike(bid) and not loaded_owned.has(bid):
                loaded_owned.append(bid)
    if not loaded_owned.has(DEFAULT_BIKE_ID):
        loaded_owned.insert(0, DEFAULT_BIKE_ID)
    owned_bikes = loaded_owned

    var raw_active: String = str(data.get("active_bike_id", DEFAULT_BIKE_ID))
    active_bike_id = raw_active if owned_bikes.has(raw_active) else DEFAULT_BIKE_ID

    upgrades_by_bike.clear()
    var raw_upgrades = data.get("upgrades_by_bike", {})
    for bid in owned_bikes:
        var clean_tracks: Dictionary = UpgradeCatalogScript.create_default_upgrade_levels()
        if raw_upgrades is Dictionary and raw_upgrades.has(bid) and raw_upgrades[bid] is Dictionary:
            var src_tracks: Dictionary = raw_upgrades[bid] as Dictionary
            for track_id in UpgradeCatalogScript.get_upgrade_track_ids():
                var max_lvl: int = UpgradeCatalogScript.get_max_upgrade_level(track_id)
                clean_tracks[track_id] = clampi(int(src_tracks.get(track_id, 0)), 0, max_lvl)
        upgrades_by_bike[bid] = clean_tracks

    var raw_stats = data.get("stats", {})
    if raw_stats is Dictionary:
        stats["total_earned"] = maxi(0, int(raw_stats.get("total_earned", 0)))
        stats["total_spent"] = maxi(0, int(raw_stats.get("total_spent", 0)))
        stats["near_misses"] = maxi(0, int(raw_stats.get("near_misses", 0)))
        stats["longest_wheelie_sec"] = maxf(0.0, float(raw_stats.get("longest_wheelie_sec", 0.0)))
        stats["highest_combo"] = maxi(1, int(raw_stats.get("highest_combo", 1)))

    return true
