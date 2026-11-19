class_name ZoneRegistry
extends RefCounted

var _zones: Dictionary = {}


func _init(populate_defaults: bool = true) -> void:
    if populate_defaults:
        register_default_zones()


func register_default_zones() -> void:
    register_zone(
        "hub_boulevard",
        "res://src/world/zones/hub_boulevard_zone.tscn",
        "Hub Boulevard",
        "default",
        true
    )
    register_zone(
        "test_track",
        "res://src/world/zones/test_track_zone.tscn",
        "Test Track",
        "default",
        false
    )
    register_zone(
        "highway_strip",
        "res://src/world/zones/highway_strip_zone.tscn",
        "Highway Strip",
        "default",
        false
    )


func register_zone(
    zone_id: String,
    scene_path: String,
    display_name: String = "",
    default_spawn_id: String = "default",
    is_hub: bool = false
) -> void:
    if zone_id.is_empty() or scene_path.is_empty():
        return

    _zones[zone_id] = {
        "id": zone_id,
        "scene_path": scene_path,
        "display_name": display_name if not display_name.is_empty() else zone_id,
        "default_spawn_id": default_spawn_id,
        "is_hub": is_hub
    }


func has_zone(zone_id: String) -> bool:
    return _zones.has(zone_id)


func get_zone_info(zone_id: String) -> Dictionary:
    if not _zones.has(zone_id):
        return {}
    return (_zones[zone_id] as Dictionary).duplicate()


func get_scene_path(zone_id: String) -> String:
    if not _zones.has(zone_id):
        return ""
    return str((_zones[zone_id] as Dictionary).get("scene_path", ""))


func get_default_spawn_id(zone_id: String) -> String:
    if not _zones.has(zone_id):
        return "default"
    return str((_zones[zone_id] as Dictionary).get("default_spawn_id", "default"))


func get_hub_zone_id() -> String:
    for key in _zones.keys():
        var info: Dictionary = _zones[key]
        if bool(info.get("is_hub", false)):
            return str(key)
    return ""


func get_all_zone_ids() -> Array:
    var ids: Array = _zones.keys()
    ids.sort()
    return ids
