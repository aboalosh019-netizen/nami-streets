extends SceneTree

const GarageMenuScript = preload("res://src/ui/garage/garage_menu.gd")
const EconomyScript = preload("res://src/economy/player_economy_state.gd")
const SaveStoreScript = preload("res://src/economy/save_store.gd")


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var economy = EconomyScript.new()
    economy.reset_to_defaults()
    economy.add_cash(5000, "garage_test")

    var store = SaveStoreScript.new("user://test_garage_save.json")

    var garage = GarageMenuScript.new()
    root.add_child(garage)
    await process_frame

    garage.bind_data(economy, store)

    assert(garage.select_bike("max"))
    assert(garage.purchase_selected_bike())
    assert(economy.owns_bike("max"))
    assert(economy.cash == 3800)

    assert(garage.equip_selected_bike())
    assert(economy.active_bike_id == "max")

    assert(garage.purchase_upgrade("engine"))
    assert(economy.get_upgrade_level("max", "engine") == 1)

    assert(store.save_exists())

    var loaded = store.load_state()
    assert(bool(loaded.get("loaded", false)))

    var loaded_state = loaded.get("state")
    assert(loaded_state != null)
    assert(loaded_state.owns_bike("max"))
    assert(loaded_state.get_upgrade_level("max", "engine") == 1)

    print("[GARAGE MENU TEST OK]")
    print("Cash: ", economy.cash)
    print("Active bike: ", economy.active_bike_id)
    print("Engine level: ", economy.get_upgrade_level("max", "engine"))

    store.delete_save()
    garage.queue_free()
    quit()


