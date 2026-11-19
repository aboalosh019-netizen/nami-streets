extends Node

const ZONES: Dictionary = {
    "res://src/world/zones/hub_boulevard_zone.tscn": "boulevard",
    "res://src/world/zones/test_track_zone.tscn": "track",
    "res://src/world/zones/highway_strip_zone.tscn": "highway"
}

var failures: int = 0


func _ready() -> void:
    call_deferred("_run")


func _check(cond: bool, desc: String) -> void:
    if cond:
        print("[PASS] ", desc)
    else:
        failures += 1
        push_error("[FAIL] " + desc)


func _run() -> void:
    for path in ZONES.keys():
        var expected: String = ZONES[path]
        var z: Node = (load(path) as PackedScene).instantiate()
        z.set("auto_spawn_on_ready", false)
        z.set("set_playing_state_on_ready", false)
        add_child(z)
        await get_tree().process_frame

        var bd: Node = z.get_node_or_null("ZoneBackdrop")
        _check(bd != null, "ZoneBackdrop attached to " + expected)
        if bd != null:
            var st: Dictionary = bd.call("get_backdrop_state")
            _check(str(st["theme"]) == expected, "Theme matches " + expected)
            _check(int(st["layer_count"]) == 3 and bool(st["mirroring_enabled"]), "3 parallax layers with mirroring for " + expected)

        z.queue_free()
        await get_tree().process_frame

    if failures == 0:
        print("[ZONE BACKDROP TEST OK]")
        get_tree().quit(0)
    else:
        push_error("[ZONE BACKDROP TEST FAILED]")
        get_tree().quit(1)
