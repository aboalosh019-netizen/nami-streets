extends SceneTree

const WorldManagerScript = preload("res://src/world/navigation/world_manager.gd")
const PauseMenuScript = preload("res://src/ui/pause_menu.gd")


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var world = WorldManagerScript.new()
    root.add_child(world)

    await process_frame

    assert(world.load_zone("test_track"))

    await process_frame
    await physics_frame

    var zone = world.get_current_zone()
    assert(zone != null)

    var bike = world.get_active_bike()
    assert(bike != null)

    var spawn = zone.get_spawn_point("default")
    assert(spawn != null)

    var expected_position = spawn.global_position

    bike.global_position = Vector2(900, 250)
    bike.linear_velocity = Vector2(300, 100)
    bike.angular_velocity = 2.0

    var menu = PauseMenuScript.new()
    root.add_child(menu)
    menu.bind_world_manager(world)

    await process_frame

    menu.open_menu()
    menu._on_respawn_pressed()

    assert(bike.global_position.distance_to(expected_position) < 1.0)
    assert(bike.linear_velocity.length() < 0.1)
    assert(absf(bike.angular_velocity) < 0.01)
    assert(zone.get_zone_state().get("respawn_count", 0) >= 1)

    print("[PAUSE MENU REAL RESPAWN TEST OK]")
    print("Bike position: ", bike.global_position)
    print("Expected position: ", expected_position)
    print("Bike velocity: ", bike.linear_velocity)

    menu.close_menu()
    menu.queue_free()
    world.queue_free()

    await process_frame
    quit()
