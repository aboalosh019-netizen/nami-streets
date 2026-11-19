extends Node2D

const ZonePortalScript = preload("res://src/world/navigation/zone_portal.gd")

var _ticks: int = 0
var _finished: bool = false

var _initial_load_ok: bool = false
var _first_zone_instance_id: int = 0
var _first_bike_pos: Vector2 = Vector2.ZERO
var _invalid_load_result: bool = true
var _invalid_kept_same_zone: bool = false
var _portal_armed_on_bind: bool = false

var _started_events: Array = []
var _loaded_events: Array = []
var _failed_events: Array = []

@onready var world: Node2D = $WorldManager


func _ready() -> void:
    if not world.has_method("load_zone") or not world.has_method("get_world_state"):
        print("[WORLD MANAGER TEST FAIL] WorldManager methods missing")
        _finished = true
        get_tree().quit(1)
        return

    world.zone_transition_started.connect(_on_transition_started)
    world.zone_loaded.connect(_on_zone_loaded)
    world.zone_transition_failed.connect(_on_transition_failed)

    _initial_load_ok = world.load_zone("test_track", "default")
    if world.get_current_zone() != null:
        _first_zone_instance_id = world.get_current_zone().get_instance_id()


func _on_transition_started(from_id: String, to_id: String, spawn_id: String, via_portal: String) -> void:
    _started_events.append({
        "from": from_id,
        "to": to_id,
        "spawn": spawn_id,
        "portal": via_portal
    })


func _on_zone_loaded(zone_id: String, spawn_id: String, _zone_node: Node2D) -> void:
    _loaded_events.append({
        "zone": zone_id,
        "spawn": spawn_id
    })


func _on_transition_failed(target_id: String, reason: String) -> void:
    _failed_events.append({
        "target": target_id,
        "reason": reason
    })


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    if _ticks == 12:
        var st1: Dictionary = world.get_world_state()
        _first_bike_pos = st1["bike_position"]

        # 1. Invalid zone must fail cleanly without unloading the active zone
        _invalid_load_result = world.load_zone("nonexistent_zone")
        _invalid_kept_same_zone = (
            world.get_current_zone() != null
            and world.get_current_zone().get_instance_id() == _first_zone_instance_id
        )

        # 2. Attach a portal dynamically, verify bind + cooldown arming, then trigger deferred transition
        var portal = ZonePortalScript.new()
        portal.portal_id = "manual_portal"
        portal.target_zone_id = "test_track"
        portal.target_spawn_id = "ramp"
        world.get_current_zone().add_child(portal)
        world.refresh_zone_portals()
        _portal_armed_on_bind = portal.is_on_cooldown()

        portal.reset_cooldown()
        portal.portal_triggered.emit("manual_portal", "test_track", "ramp")

    if _ticks == 28:
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var st_final: Dictionary = world.get_world_state()
    var second_zone: Node2D = world.get_current_zone()
    var second_instance_id: int = second_zone.get_instance_id() if second_zone != null else 0
    var second_bike_pos: Vector2 = st_final["bike_position"]

    var second_start: Dictionary = _started_events[1] if _started_events.size() >= 2 else {}
    var first_fail: Dictionary = _failed_events[0] if _failed_events.size() >= 1 else {}

    var checks := {
        "initial_load_succeeded": _initial_load_ok,
        "first_spawn_at_default": absf(_first_bike_pos.x - 120.0) < 10.0,
        "invalid_zone_returned_false": _invalid_load_result == false,
        "invalid_zone_emitted_failure": first_fail.get("target") == "nonexistent_zone" and first_fail.get("reason") == "unknown_zone",
        "invalid_zone_preserved_active_zone": _invalid_kept_same_zone,
        "portal_cooldown_armed_on_bind": _portal_armed_on_bind,
        "deferred_portal_transition_started": (
            second_start.get("from") == "test_track"
            and second_start.get("to") == "test_track"
            and second_start.get("spawn") == "ramp"
            and second_start.get("portal") == "manual_portal"
        ),
        "zone_instance_replaced_cleanly": second_instance_id != 0 and second_instance_id != _first_zone_instance_id,
        "single_zone_in_container": int(st_final["zone_container_children"]) == 1,
        "second_spawn_at_ramp": absf(second_bike_pos.x - 1220.0) < 10.0,
        "loaded_events_count_2": _loaded_events.size() == 2,
        "transition_count_2": int(st_final["transition_count"]) == 2,
        "bike_and_camera_active": st_final["has_bike"] == true and st_final["has_camera"] == true
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[WORLD MANAGER TEST FAIL] ", key)
            all_ok = false

    print(
        "WorldManager -> first_pos: ", _first_bike_pos.snapped(Vector2(0.1, 0.1)),
        " | second_pos: ", second_bike_pos.snapped(Vector2(0.1, 0.1)),
        " | transitions: ", st_final["transition_count"],
        " | container_children: ", st_final["zone_container_children"]
    )

    if all_ok:
        print("[WORLD MANAGER TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
