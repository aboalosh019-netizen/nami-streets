extends Node2D

const ZoneRegistryScript = preload("res://src/world/navigation/zone_registry.gd")

var _ticks: int = 0
var _finished: bool = false

var _registry_ok: bool = false
var _dummy_entered_area: bool = false
var _triggers_after_dummy: int = -1
var _triggers_after_first_entry: int = -1
var _triggers_during_cooldown: int = -1
var _cooldown_active_after_first: bool = false
var _cooldown_expired_before_second: bool = false
var _last_payload: Dictionary = {}
var _signal_count: int = 0

@onready var portal: Area2D = $ZonePortal
@onready var dummy_body: RigidBody2D = $DummyBody
@onready var bike: RigidBody2D = $Bike


func _ready() -> void:
    _test_registry()

    if not portal.has_method("get_portal_state"):
        print("[ZONE PORTAL TEST FAIL] ZonePortal script missing")
        _finished = true
        get_tree().quit(1)
        return

    portal.body_entered.connect(_on_any_body_entered)
    portal.portal_triggered.connect(_on_portal_triggered)

    # Send non-bike body across the portal first
    dummy_body.linear_velocity = Vector2(360.0, 0.0)


func _test_registry() -> void:
    var reg = ZoneRegistryScript.new()
    var ids: Array = reg.get_all_zone_ids()
    var hub_id: String = reg.get_hub_zone_id()
    var track_path: String = reg.get_scene_path("test_track")
    var unknown_path: String = reg.get_scene_path("nonexistent_zone")

    _registry_ok = (
        ids.size() == 3
        and reg.has_zone("hub_boulevard")
        and reg.has_zone("test_track")
        and reg.has_zone("highway_strip")
        and hub_id == "hub_boulevard"
        and track_path == "res://src/world/zones/test_track_zone.tscn"
        and unknown_path == ""
    )


func _on_any_body_entered(body: Node) -> void:
    if body == dummy_body:
        _dummy_entered_area = true


func _on_portal_triggered(p_id: String, t_zone: String, t_spawn: String) -> void:
    _signal_count += 1
    _last_payload = {
        "portal_id": p_id,
        "target_zone_id": t_zone,
        "target_spawn_id": t_spawn
    }


func _teleport_body(body: RigidBody2D, pos: Vector2, vel: Vector2 = Vector2.ZERO) -> void:
    var xf := Transform2D(0.0, pos)
    body.global_transform = xf
    body.linear_velocity = vel
    body.angular_velocity = 0.0
    var rid: RID = body.get_rid()
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, xf)
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, vel)
    PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    # Tick 24: dummy has crossed the portal; check it was ignored and park it away
    if _ticks == 24:
        _triggers_after_dummy = _signal_count
        _teleport_body(dummy_body, Vector2(900.0, -200.0), Vector2.ZERO)
        _teleport_body(bike, Vector2(110.0, 51.0), Vector2(420.0, 0.0))

    # Tick 40: bike has entered portal for the first time
    if _ticks == 40:
        _triggers_after_first_entry = _signal_count
        _cooldown_active_after_first = portal.is_on_cooldown()
        # Move bike out of portal while cooldown (0.5s = 30 ticks) is active
        _teleport_body(bike, Vector2(-120.0, 51.0), Vector2.ZERO)

    # Tick 46: re-enter portal while cooldown is still active
    if _ticks == 46:
        _teleport_body(bike, Vector2(200.0, 51.0), Vector2.ZERO)

    # Tick 52: confirm re-entry was blocked by cooldown, then move out
    if _ticks == 52:
        _triggers_during_cooldown = _signal_count
        _teleport_body(bike, Vector2(-120.0, 51.0), Vector2.ZERO)

    # Tick 90: cooldown should have fully elapsed; re-enter portal
    if _ticks == 90:
        _cooldown_expired_before_second = not portal.is_on_cooldown()
        _teleport_body(bike, Vector2(200.0, 51.0), Vector2.ZERO)

    if _ticks == 100:
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var checks := {
        "registry_valid": _registry_ok,
        "dummy_actually_entered_area": _dummy_entered_area,
        "dummy_ignored_by_portal": _triggers_after_dummy == 0,
        "bike_triggered_first_time": _triggers_after_first_entry == 1,
        "payload_matches_portal": (
            _last_payload.get("portal_id") == "east_exit"
            and _last_payload.get("target_zone_id") == "highway_strip"
            and _last_payload.get("target_spawn_id") == "from_hub"
        ),
        "cooldown_active_after_trigger": _cooldown_active_after_first,
        "reentry_blocked_during_cooldown": _triggers_during_cooldown == 1,
        "cooldown_expired": _cooldown_expired_before_second,
        "bike_triggered_after_cooldown": _signal_count == 2
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[ZONE PORTAL TEST FAIL] ", key)
            all_ok = false

    print(
        "Portal test -> dummy_entered: ", _dummy_entered_area,
        " | triggers(dummy/1st/cd/2nd): ", _triggers_after_dummy, "/", _triggers_after_first_entry, "/", _triggers_during_cooldown, "/", _signal_count,
        " | payload: ", _last_payload
    )

    if all_ok:
        print("[ZONE PORTAL TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
