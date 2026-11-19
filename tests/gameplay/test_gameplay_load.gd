extends Node

const SaveStoreScript = preload("res://src/economy/save_store.gd")
const EconomyStateScript = preload("res://src/economy/player_economy_state.gd")

var failures: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_run_test")


func _check(condition: bool, description: String) -> void:
    if condition:
        print("[PASS] ", description)
    else:
        failures += 1
        push_error("[FAIL] " + description)


func _run_test() -> void:
    var packed := load("res://src/gameplay/gameplay.tscn") as PackedScene
    _check(packed != null, "Gameplay scene resource loads")

    if packed == null:
        _finish()
        return

    var gameplay := packed.instantiate()
    add_child(gameplay)

    # Verify that gameplay rewards are persisted and can be restored.
    var test_store = SaveStoreScript.new("user://test_gameplay_reward_save.json")
    test_store.delete_save()
    gameplay.set("save_store", test_store)

    var economy: Object = gameplay.get("economy_state")
    var cash_before: int = int(economy.get("cash"))

    gameplay.get_node("RewardTracker").call(
        "_grant_reward", "integration_test", 125
    )

    var fresh_state = EconomyStateScript.new()
    var load_result: Dictionary = test_store.load_state(fresh_state)
    var restored_state: Object = load_result.get("state")

    _check(bool(load_result.get("loaded", false)),
        "Reward save file loads successfully")
    _check(
        restored_state != null
        and int(restored_state.get("cash")) == cash_before + 125,
        "Reward cash is restored with the correct amount"
    )

    _check(test_store.delete_save(),
        "Temporary reward save file is deleted")

    # Verify garage upgrade purchase, application, and persistence.
    var upgrade_garage: Node = gameplay.get_node("UI/GarageMenu")
    upgrade_garage.set("save_store", test_store)
    upgrade_garage.call("select_bike", "cg125")

    _check(economy.call("add_cash", 500, "upgrade_test"),
        "Test funds added for upgrade purchase")

    var upgrade_bike: Node2D = gameplay.get_node(
        "WorldManager"
    ).call("get_active_bike") as Node2D

    var upgrade_controller: Node = upgrade_bike.get_node("BikeController")
    var base_drive_force: float = float(
        upgrade_controller.get("drivetrain_config").get("base_drive_force")
    )

    var upgrade_bought: bool = bool(
        upgrade_garage.call("purchase_upgrade", "engine")
    )

    _check(upgrade_bought, "Engine upgrade purchase succeeds")
    _check(
        economy.call("get_upgrade_level", "cg125", "engine") == 1,
        "Engine upgrade level increases to one"
    )

    var upgraded_config: Resource = upgrade_controller.get("drivetrain_config")
    var upgraded_drive_force: float = float(
        upgraded_config.get("base_drive_force")
    )

    _check(
        is_equal_approx(upgraded_drive_force, base_drive_force * 1.12),
        "Engine upgrade applies the expected torque multiplier"
    )

    var upgrade_load_state = EconomyStateScript.new()
    var upgrade_load_result: Dictionary = test_store.load_state(
        upgrade_load_state
    )
    var restored_upgrade_state: Object = upgrade_load_result.get("state")

    _check(
        bool(upgrade_load_result.get("loaded", false)),
        "Upgrade save file loads successfully"
    )
    _check(
        restored_upgrade_state != null
        and restored_upgrade_state.call(
            "get_upgrade_level", "cg125", "engine"
        ) == 1,
        "Purchased engine upgrade is restored from save"
    )
    _check(
        restored_upgrade_state != null
        and int(restored_upgrade_state.get("cash"))
        == int(economy.get("cash")),
        "Post-upgrade cash balance is restored correctly"
    )

    _check(test_store.delete_save(),
        "Temporary upgrade save file is deleted")

    var world: Node = gameplay.get_node("WorldManager")
    var hud: Node = gameplay.get_node("UI/GameplayHUD")
    var touch: Node = gameplay.get_node("UI/TouchControls")
    var pause: Node = gameplay.get_node("UI/PauseMenu")
    var garage: Node = gameplay.get_node("UI/GarageMenu")
    var tracker: Node = gameplay.get_node("RewardTracker")

    _check(world.call("get_current_zone_id") == "hub_boulevard",
        "Initial hub zone loaded")

    var bike: Node2D = world.call("get_active_bike") as Node2D
    _check(bike != null, "Player bike spawned")

    _check(bike != null and bike.get_node_or_null("BikeController") != null,
        "Bike controller exists")

    _check(tracker.get("_bike") == bike,
        "Reward tracker bound to active bike")

    _check(hud.get("_bike") == bike,
        "HUD bound to active bike")

    _check(bool(touch.get("controls_enabled")),
        "Touch controls enabled initially")

    hud.emit_signal("pause_requested")

    _check(get_tree().paused, "Pause signal pauses the game")
    _check(pause.visible, "Pause menu becomes visible")
    _check(not bool(touch.get("controls_enabled")),
        "Touch controls disabled while paused")

    pause.emit_signal("garage_requested")

    _check(get_tree().paused, "Game remains paused in garage")
    _check(not pause.visible and garage.visible,
        "Garage replaces pause menu visually")

    garage.emit_signal("close_requested")

    _check(get_tree().paused, "Closing garage keeps game paused")
    _check(not garage.visible and pause.visible,
        "Closing garage returns to pause menu")

    pause.call("_on_resume_pressed")

    _check(not get_tree().paused, "Resume unpauses the game")
    _check(bool(touch.get("controls_enabled")),
        "Touch controls re-enabled after resume")

    var old_spawner: Node = world.get_current_zone().get_node_or_null("TrafficSpawner")
    _check(old_spawner != null, "Hub traffic spawner exists")
    _check(tracker.get("_spawner") == old_spawner,
        "Reward tracker bound to hub traffic")

    var hub_bike := bike
    var track_loaded: bool = world.call("load_zone", "test_track")
    _check(track_loaded, "Transition to Test Track succeeds")
    _check(world.call("get_current_zone_id") == "test_track",
        "Test Track becomes current zone")

    bike = world.call("get_active_bike") as Node2D
    _check(bike != null and bike != hub_bike,
        "New bike instance created for Test Track")
    _check(hud.get("_bike") == bike,
        "HUD rebound to Test Track bike")
    _check(tracker.get("_bike") == bike,
        "Reward tracker rebound to Test Track bike")
    _check(tracker.get("_spawner") == null,
        "Old traffic spawner disconnected on Test Track")

    var highway_loaded: bool = world.call("load_zone", "highway_strip")
    _check(highway_loaded, "Transition to Highway succeeds")
    _check(world.call("get_current_zone_id") == "highway_strip",
        "Highway becomes current zone")

    bike = world.call("get_active_bike") as Node2D
    var highway_spawner: Node = world.get_current_zone().get_node_or_null("TrafficSpawner")
    _check(bike != null and hud.get("_bike") == bike,
        "HUD follows bike into Highway")
    _check(tracker.get("_bike") == bike,
        "Reward tracker follows bike into Highway")
    _check(highway_spawner != null and tracker.get("_spawner") == highway_spawner,
        "Reward tracker binds to Highway traffic")

    await get_tree().process_frame
    _check(old_spawner == null or not is_instance_valid(old_spawner),
        "Previous zone traffic spawner is freed after frame cleanup")

    _finish()


func _finish() -> void:
    get_tree().paused = false

    if failures == 0:
        print("[GAMEPLAY INTEGRATION TEST OK]")
    else:
        push_error("[GAMEPLAY INTEGRATION TEST FAILED] %d failures" % failures)

    get_tree().quit(0 if failures == 0 else 1)
