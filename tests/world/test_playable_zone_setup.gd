extends Node2D

var _ticks: int = 0
var _finished: bool = false

var _pos_default: Vector2 = Vector2.ZERO
var _pos_secondary: Vector2 = Vector2.ZERO
var _respawn_before_fall: int = 0

@onready var zone: Node2D = $Zone


func _ready() -> void:
    if not zone.has_method("get_zone_state"):
        print("[PLAYABLE ZONE SETUP FAIL] PlayableZone script missing")
        _finished = true
        get_tree().quit(1)


func _physics_process(_delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    if _ticks == 20:
        var st: Dictionary = zone.get_zone_state()
        _pos_default = st["bike_position"]
        zone.respawn_bike("ramp")

    if _ticks == 30:
        var st2: Dictionary = zone.get_zone_state()
        _pos_secondary = st2["bike_position"]
        _respawn_before_fall = int(st2["respawn_count"])
        # Force bike below fall threshold to verify automatic fall respawn
        var bike: RigidBody2D = zone.get_bike()
        var xf := Transform2D(0.0, Vector2(400.0, 900.0))
        bike.global_transform = xf
        PhysicsServer2D.body_set_state(bike.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, xf)

    if _ticks == 40:
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var st: Dictionary = zone.get_zone_state()
    var limits: Dictionary = st["camera_limits"]
    var gm: Node = get_node_or_null("/root/GameManager")
    var is_playing: bool = gm != null and gm.is_playing()
    var spawn_ids: Array = st["spawn_ids"]
    var final_pos: Vector2 = st["bike_position"]

    var checks := {
        "game_state_playing": is_playing,
        "found_two_spawns": spawn_ids.size() == 2 and spawn_ids.has("default") and spawn_ids.has("ramp"),
        "bike_spawned": st["has_bike"] == true,
        "camera_created": st["has_camera"] == true,
        "camera_limits_applied": limits.get("left") == -100 and limits.get("right") == 2000 and limits.get("top") == -300 and limits.get("bottom") == 400,
        "spawned_at_default_x": absf(_pos_default.x - 100.0) < 5.0,
        "respawned_at_secondary_x": absf(_pos_secondary.x - 600.0) < 5.0,
        "auto_respawn_triggered_on_fall": int(st["respawn_count"]) > _respawn_before_fall,
        "returned_above_ground_after_fall": final_pos.y < 150.0 and absf(final_pos.x - 600.0) < 10.0
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[PLAYABLE ZONE SETUP FAIL] ", key)
            all_ok = false

    print(
        "Zone setup -> spawns: ", spawn_ids,
        " | default_pos: ", _pos_default.snapped(Vector2(0.1, 0.1)),
        " | secondary_pos: ", _pos_secondary.snapped(Vector2(0.1, 0.1)),
        " | final_pos: ", final_pos.snapped(Vector2(0.1, 0.1)),
        " | respawns: ", st["respawn_count"]
    )

    if all_ok:
        print("[PLAYABLE ZONE SETUP TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
