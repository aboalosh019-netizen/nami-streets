class_name UpgradeCatalog
extends RefCounted

const MAX_UPGRADE_LEVEL: int = 3

const BIKES: Dictionary = {
    "cg125": {
        "id": "cg125",
        "display_name": "CG125 Nami",
        "price": 0,
        "torque_mult": 1.0,
        "max_speed_mult": 1.0,
        "brake_mult": 1.0,
        "suspension_mult": 1.0,
        "wheelie_torque_mult": 1.0
    },
    "max": {
        "id": "max",
        "display_name": "Max 150",
        "price": 1200,
        "torque_mult": 1.18,
        "max_speed_mult": 1.15,
        "brake_mult": 1.10,
        "suspension_mult": 1.08,
        "wheelie_torque_mult": 1.12
    },
    "tmax": {
        "id": "tmax",
        "display_name": "T-Max 560",
        "price": 3500,
        "torque_mult": 1.42,
        "max_speed_mult": 1.35,
        "brake_mult": 1.25,
        "suspension_mult": 1.18,
        "wheelie_torque_mult": 1.20
    }
}

const UPGRADE_TRACKS: Dictionary = {
    "engine": {
        "id": "engine",
        "display_name": "Engine",
        "stat_key": "torque_mult",
        "bonus_per_level": 0.12,
        "costs": [200, 450, 900]
    },
    "gearing": {
        "id": "gearing",
        "display_name": "Gearing",
        "stat_key": "max_speed_mult",
        "bonus_per_level": 0.08,
        "costs": [180, 400, 800]
    },
    "brakes": {
        "id": "brakes",
        "display_name": "Brakes",
        "stat_key": "brake_mult",
        "bonus_per_level": 0.15,
        "costs": [150, 350, 700]
    },
    "suspension": {
        "id": "suspension",
        "display_name": "Suspension",
        "stat_key": "suspension_mult",
        "bonus_per_level": 0.10,
        "costs": [160, 360, 720]
    }
}


static func get_bike_ids() -> Array:
    return ["cg125", "max", "tmax"]


static func get_upgrade_track_ids() -> Array:
    return ["engine", "gearing", "brakes", "suspension"]


static func has_bike(bike_id: String) -> bool:
    return BIKES.has(bike_id)


static func has_track(track_id: String) -> bool:
    return UPGRADE_TRACKS.has(track_id)


static func get_bike_info(bike_id: String) -> Dictionary:
    if not BIKES.has(bike_id):
        return {}
    return (BIKES[bike_id] as Dictionary).duplicate(true)


static func get_bike_price(bike_id: String) -> int:
    if not BIKES.has(bike_id):
        return -1
    return int((BIKES[bike_id] as Dictionary).get("price", 0))


static func get_max_upgrade_level(track_id: String) -> int:
    if not UPGRADE_TRACKS.has(track_id):
        return 0
    var costs: Array = (UPGRADE_TRACKS[track_id] as Dictionary).get("costs", [])
    return costs.size()


static func get_upgrade_cost(track_id: String, current_level: int) -> int:
    if not UPGRADE_TRACKS.has(track_id):
        return -1
    var costs: Array = (UPGRADE_TRACKS[track_id] as Dictionary).get("costs", [])
    if current_level < 0 or current_level >= costs.size():
        return -1
    return int(costs[current_level])


static func create_default_upgrade_levels() -> Dictionary:
    var levels: Dictionary = {}
    for track_id in get_upgrade_track_ids():
        levels[track_id] = 0
    return levels


static func get_effective_modifiers(bike_id: String, upgrade_levels: Dictionary = {}) -> Dictionary:
    var resolved_id: String = bike_id if BIKES.has(bike_id) else "cg125"
    var base: Dictionary = BIKES[resolved_id] as Dictionary

    var result: Dictionary = {
        "bike_id": resolved_id,
        "torque_mult": float(base.get("torque_mult", 1.0)),
        "max_speed_mult": float(base.get("max_speed_mult", 1.0)),
        "brake_mult": float(base.get("brake_mult", 1.0)),
        "suspension_mult": float(base.get("suspension_mult", 1.0)),
        "wheelie_torque_mult": float(base.get("wheelie_torque_mult", 1.0))
    }

    for track_id in get_upgrade_track_ids():
        var track: Dictionary = UPGRADE_TRACKS[track_id] as Dictionary
        var max_lvl: int = get_max_upgrade_level(track_id)
        var lvl: int = clampi(int(upgrade_levels.get(track_id, 0)), 0, max_lvl)
        var stat_key: String = str(track.get("stat_key", ""))
        var bonus: float = float(track.get("bonus_per_level", 0.0))
        if not stat_key.is_empty() and result.has(stat_key):
            result[stat_key] = float(result[stat_key]) * (1.0 + bonus * float(lvl))

    return result
