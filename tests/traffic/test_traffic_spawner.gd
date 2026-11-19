extends Node2D

var _anchor: Node2D
var _ticks: int = 0
var _finished: bool = false

var _pool_count_constant: bool = true
var _max_active_seen: int = 0
var _no_same_lane_overlap: bool = true
var _saw_same_dir: bool = false
var _saw_oncoming: bool = false
var _spawn_signal_count: int = 0
var _recycle_signal_count: int = 0
var _state_before_disable: Dictionary = {}
var _spawned_while_disabled: int = 0
var _state_after_clear: Dictionary = {}

@onready var spawner: Node2D = $TrafficSpawner


func _ready() -> void:
    _anchor = Node2D.new()
    _anchor.position = Vector2(200.0, 100.0)
    add_child(_anchor)

    if not spawner.has_method("get_spawner_state"):
        print("[TRAFFIC SPAWNER TEST FAIL] TrafficSpawner script missing")
        _finished = true
        get_tree().quit(1)
        return

    spawner.set_target(_anchor)
    spawner.vehicle_spawned.connect(_on_vehicle_spawned)
    spawner.vehicle_recycled.connect(_on_vehicle_recycled)


func _on_vehicle_spawned(_vehicle: Node2D, _lane_id: int, direction: int) -> void:
    _spawn_signal_count += 1
    if direction > 0:
        _saw_same_dir = true
    elif direction < 0:
        _saw_oncoming = true


func _on_vehicle_recycled(_vehicle: Node2D) -> void:
    _recycle_signal_count += 1


func _check_lane_overlaps() -> void:
    var active: Array = spawner.get_active_vehicles()
    for i in range(active.size()):
        var a: Node2D = active[i] as Node2D
        for j in range(i + 1, active.size()):
            var b: Node2D = active[j] as Node2D
            if int(a.get("lane_id")) != int(b.get("lane_id")):
                continue
            var min_center: float = float(a.get_width()) * 0.5 + float(b.get_width()) * 0.5
            if absf(a.global_position.x - b.global_position.x) < min_center:
                _no_same_lane_overlap = false


func _physics_process(delta: float) -> void:
    if _finished:
        return

    _ticks += 1

    # Advance anchor steadily along road
    _anchor.global_position.x += 280.0 * delta

    var st: Dictionary = spawner.get_spawner_state()
    if int(st["pool_children"]) != 6 or int(st["pool_size"]) != 6:
        _pool_count_constant = false

    _max_active_seen = maxi(_max_active_seen, int(st["active_count"]))
    _check_lane_overlaps()

    # Tick 220: disable spawning and verify no further spawns occur for 30 ticks
    if _ticks == 220:
        _state_before_disable = spawner.get_spawner_state()
        spawner.set_enabled(false)

    # Tick 250: check disabled behavior, then clear all active vehicles
    if _ticks == 250:
        var st_now: Dictionary = spawner.get_spawner_state()
        _spawned_while_disabled = int(st_now["total_spawned"]) - int(_state_before_disable["total_spawned"])
        spawner.clear_all_active()
        _state_after_clear = spawner.get_spawner_state()
        _finished = true
        _evaluate_and_quit()


func _evaluate_and_quit() -> void:
    var total_spawned: int = int(_state_after_clear["total_spawned"])
    var total_recycled: int = int(_state_after_clear["total_recycled"])

    var checks := {
        "pool_size_constant_no_alloc": _pool_count_constant,
        "active_capped_at_max": _max_active_seen >= 2 and _max_active_seen <= 3,
        "spawned_both_directions": _saw_same_dir and _saw_oncoming,
        "no_same_lane_overlap": _no_same_lane_overlap,
        "recycled_and_reused_from_pool": total_spawned >= 5 and int(_state_before_disable["total_recycled"]) >= 2,
        "signals_match_counters": _spawn_signal_count == total_spawned and _recycle_signal_count == total_recycled,
        "disabled_stopped_spawning": _spawned_while_disabled == 0,
        "clear_all_recycled_everything": int(_state_after_clear["active_count"]) == 0 and int(_state_after_clear["inactive_count"]) == 6 and total_recycled == total_spawned
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[TRAFFIC SPAWNER TEST FAIL] ", key)
            all_ok = false

    print(
        "Traffic spawner -> max_active: ", _max_active_seen,
        " | spawned/recycled: ", total_spawned, "/", total_recycled,
        " | pre_disable_recycled: ", _state_before_disable.get("total_recycled", 0),
        " | dirs(same/oncoming): ", _saw_same_dir, "/", _saw_oncoming
    )

    if all_ok:
        print("[TRAFFIC SPAWNER TEST OK]")
        get_tree().quit(0)
    else:
        get_tree().quit(1)
