extends Node

const GameplayScene = preload("res://src/gameplay/gameplay.tscn")
const SaveStoreScript = preload("res://src/economy/save_store.gd")

const TEST_SAVE_PATH: String = "user://test_phase12_gameplay_save.json"

var failures: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_run_tests")


func _check(condition: bool, description: String) -> void:
    if condition:
        print("[PASS] ", description)
    else:
        failures += 1
        push_error("[FAIL] " + description)


func _cleanup_save() -> void:
    var store = SaveStoreScript.new(TEST_SAVE_PATH)
    store.delete_save()


func _write_corrupt_save() -> void:
    var f: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
    if f != null:
        f.store_string("{corrupt_json_payload!!!")
        f.close()


func _get_bike_stats(bike: Node2D) -> Dictionary:
    var ctrl: Node = bike.get_node("BikeController")
    var dt_cfg: Resource = ctrl.get("drivetrain_config")
    var phys_cfg: Resource = bike.get("config")
    var speeds: PackedFloat32Array = dt_cfg.get("gear_max_speeds")
    return {
        "drive_force": float(dt_cfg.get("base_drive_force")),
        "rear_brake": float(dt_cfg.get("rear_brake_force")),
        "gear1_speed": float(speeds[1]) if speeds.size() > 1 else 0.0,
        "front_stiffness": float(phys_cfg.get("front_stiffness"))
    }


func _run_tests() -> void:
    # 1. Corrupt save recovery on startup
    _write_corrupt_save()
    var gameplay: Node = GameplayScene.instantiate()
    gameplay.set("save_path", TEST_SAVE_PATH)
    add_child(gameplay)

    var state_0: Dictionary = gameplay.call("get_gameplay_state")
    _check(state_0["last_load_reason"] == "corrupt_json", "Corrupt save detected gracefully on load")
    _check(state_0["active_bike_id"] == "cg125" and int(state_0["cash"]) == 0, "Corrupt save falls back to default cg125 and $0")

    # 2. Save error handling without crash
    var orig_state = gameplay.get("economy_state")
    gameplay.set("economy_state", null)
    var bad_save_ok: bool = bool(gameplay.call("_save_progress"))
    _check(not bad_save_ok and gameplay.get("last_save_error") == "missing_store_or_state", "Save failure handled cleanly without crash")
    gameplay.set("economy_state", orig_state)

    # 3. No duplicate signal connections
    gameplay.call("_connect_world_signals")
    gameplay.call("_connect_ui_signals")
    var world: Node = gameplay.get_node("WorldManager")
    var hud: Node = gameplay.get_node("UI/GameplayHUD")
    var pause: Node = gameplay.get_node("UI/PauseMenu")
    var garage: Node = gameplay.get_node("UI/GarageMenu")
    var tracker: Node = gameplay.get_node("RewardTracker")
    var touch: Node = gameplay.get_node("UI/TouchControls")

    _check(world.get_signal_connection_list(&"zone_loaded").size() == 1, "No duplicate zone_loaded connections")
    _check(hud.get_signal_connection_list(&"pause_requested").size() == 1, "No duplicate pause_requested connections")
    _check(tracker.get_signal_connection_list(&"reward_earned").size() == 2, "No duplicate reward_earned connections (Gameplay + HUD)")

    # 4. Earn rewards, open pause & garage -> verify cash refreshes
    tracker.call("_grant_reward", "near_miss", 2500)
    hud.emit_signal("pause_requested")
    pause.emit_signal("garage_requested")

    var cash_label: Label = garage.get("_cash_label") as Label
    _check(cash_label != null and cash_label.text == "CASH: $2500", "Garage refreshes cash display when opened")

    # 5. Buy & equip Max 150, then buy Lv1 of all 4 upgrade tracks
    _check(bool(garage.call("select_bike", "max")), "Select Max 150 in garage")
    _check(bool(garage.call("purchase_selected_bike")), "Purchase Max 150 succeeds")
    _check(bool(garage.call("equip_selected_bike")), "Equip Max 150 succeeds")
    _check(bool(garage.call("purchase_upgrade", "engine")), "Buy Engine Lv1 on Max 150")
    _check(bool(garage.call("purchase_upgrade", "gearing")), "Buy Gearing Lv1 on Max 150")
    _check(bool(garage.call("purchase_upgrade", "brakes")), "Buy Brakes Lv1 on Max 150")
    _check(bool(garage.call("purchase_upgrade", "suspension")), "Buy Suspension Lv1 on Max 150")

    var expected_drive: float = 11500.0 * 1.18 * 1.12
    var expected_speed1: float = 190.0 * 1.15 * 1.08
    var expected_brake: float = 34000.0 * 1.10 * 1.15
    var expected_stiff: float = 12000.0 * 1.08 * 1.10

    var hub_bike: Node2D = world.call("get_active_bike") as Node2D
    var hub_stats: Dictionary = _get_bike_stats(hub_bike)
    _check(is_equal_approx(hub_stats["drive_force"], expected_drive), "Hub bike drive force matches Max+Engine1")
    _check(is_equal_approx(hub_stats["gear1_speed"], expected_speed1), "Hub bike gearing matches Max+Gearing1")
    _check(is_equal_approx(hub_stats["rear_brake"], expected_brake), "Hub bike brakes match Max+Brakes1")
    _check(is_equal_approx(hub_stats["front_stiffness"], expected_stiff), "Hub bike suspension matches Max+Suspension1")

    # Repeated bind must not stack multipliers
    gameplay.call("_bind_current_zone")
    var hub_stats_reapplied: Dictionary = _get_bike_stats(hub_bike)
    _check(is_equal_approx(hub_stats_reapplied["drive_force"], expected_drive), "Repeated bind does not stack drive multiplier")
    _check(is_equal_approx(hub_stats_reapplied["front_stiffness"], expected_stiff), "Repeated bind does not stack suspension multiplier")

    # 6. Respawn via PauseMenu keeps upgrades & resets transform cleanly
    garage.emit_signal("close_requested")
    _check(pause.visible and not garage.visible, "Closing garage returns to pause menu")

    var spawn_pos: Vector2 = world.call("get_current_zone").call("get_spawn_point", "default").global_position
    hub_bike.global_position = Vector2(950.0, 220.0)
    hub_bike.linear_velocity = Vector2(280.0, -50.0)
    pause.call("_on_respawn_pressed")

    var respawn_stats: Dictionary = _get_bike_stats(world.call("get_active_bike") as Node2D)
    _check(hub_bike.global_position.distance_to(spawn_pos) < 1.0, "Respawn moves bike back to spawn point")
    _check(hub_bike.linear_velocity.length() < 0.1, "Respawn zeroes bike velocity")
    _check(is_equal_approx(respawn_stats["drive_force"], expected_drive), "Respawn preserves exact upgrade multipliers")

    pause.call("_on_resume_pressed")
    _check(not get_tree().paused and bool(touch.get("controls_enabled")), "Resume unpauses and re-enables touch controls")

    # 7. Zone transitions across all 3 zones preserve upgrades without stacking
    var zones_sequence: Array = ["test_track", "highway_strip", "hub_boulevard"]
    var old_spawners: Array = []

    for target_zone in zones_sequence:
        var prev_spawner: Node = world.call("get_current_zone").get_node_or_null("TrafficSpawner")
        if prev_spawner != null and not old_spawners.has(prev_spawner):
            old_spawners.append(prev_spawner)

        var ok: bool = bool(world.call("load_zone", target_zone))
        var z_bike: Node2D = world.call("get_active_bike") as Node2D
        var z_stats: Dictionary = _get_bike_stats(z_bike)
        var z_spawner: Node = world.call("get_current_zone").get_node_or_null("TrafficSpawner")

        _check(ok and world.call("get_current_zone_id") == target_zone, "Loaded zone: " + target_zone)
        _check(is_equal_approx(z_stats["drive_force"], expected_drive), "Drive upgrade preserved in " + target_zone)
        _check(is_equal_approx(z_stats["front_stiffness"], expected_stiff), "Suspension upgrade preserved in " + target_zone)
        _check(hud.get("_bike") == z_bike and tracker.get("_bike") == z_bike, "HUD & Tracker rebound in " + target_zone)
        _check(tracker.get("_spawner") == z_spawner, "TrafficSpawner binding matches in " + target_zone)

    await get_tree().process_frame
    var all_old_freed: bool = true
    for sp in old_spawners:
        if sp != null and is_instance_valid(sp):
            all_old_freed = false
    _check(all_old_freed, "All previous zone TrafficSpawners freed cleanly")

    # 8. Main menu signal forwarding + cleanup while paused
    var menu_signal_tracker := {"count": 0}
    gameplay.connect("main_menu_requested", func() -> void:
        menu_signal_tracker["count"] = int(menu_signal_tracker["count"]) + 1
    )
    hud.emit_signal("pause_requested")
    pause.call("_on_main_menu_pressed")
    _check(int(menu_signal_tracker["count"]) == 1, "Main menu signal forwarded from PauseMenu")

    hud.emit_signal("pause_requested")
    _check(get_tree().paused, "Paused before teardown test")
    var saved_cash_expected: int = int(orig_state.get("cash"))
    gameplay.queue_free()
    await get_tree().process_frame
    _check(not get_tree().paused, "Teardown while paused clears SceneTree.paused")

    # 9. Fresh Gameplay instance loads saved progress and applies all 4 upgrades
    var gameplay2: Node = GameplayScene.instantiate()
    gameplay2.set("save_path", TEST_SAVE_PATH)
    add_child(gameplay2)

    var state_2: Dictionary = gameplay2.call("get_gameplay_state")
    var bike_2: Node2D = gameplay2.get_node("WorldManager").call("get_active_bike") as Node2D
    var stats_2: Dictionary = _get_bike_stats(bike_2)

    _check(state_2["active_bike_id"] == "max", "Reloaded Gameplay restores active bike Max 150")
    _check(int(state_2["cash"]) == saved_cash_expected, "Reloaded Gameplay restores exact cash balance")
    _check(is_equal_approx(stats_2["drive_force"], expected_drive), "Reloaded Gameplay applies saved Engine upgrade")
    _check(is_equal_approx(stats_2["gear1_speed"], expected_speed1), "Reloaded Gameplay applies saved Gearing upgrade")
    _check(is_equal_approx(stats_2["rear_brake"], expected_brake), "Reloaded Gameplay applies saved Brakes upgrade")
    _check(is_equal_approx(stats_2["front_stiffness"], expected_stiff), "Reloaded Gameplay applies saved Suspension upgrade")

    gameplay2.queue_free()
    await get_tree().process_frame
    _cleanup_save()

    if failures == 0:
        print("[PHASE 12 GAMEPLAY INTEGRATION FULL TEST OK]")
        get_tree().quit(0)
    else:
        push_error("[PHASE 12 GAMEPLAY INTEGRATION FULL TEST FAILED] %d failures" % failures)
        get_tree().quit(1)
