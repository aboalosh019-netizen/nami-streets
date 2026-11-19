extends SceneTree

const UpgradeCatalogScript = preload("res://src/economy/upgrade_catalog.gd")
const PlayerEconomyStateScript = preload("res://src/economy/player_economy_state.gd")
const SaveStoreScript = preload("res://src/economy/save_store.gd")


func _initialize() -> void:
    var test_path: String = "user://test_nami_economy_save.json"
    var store = SaveStoreScript.new(test_path)
    store.delete_save()

    var state = PlayerEconomyStateScript.new()
    var signal_tracker := {"cash_changes": 0}
    state.cash_changed.connect(func(_new_cash: int, _delta: int, _reason: String) -> void:
        signal_tracker["cash_changes"] = int(signal_tracker["cash_changes"]) + 1
    )

    # 1. Missing file loads clean default state
    var missing_res: Dictionary = store.load_state(state)

    # 2. Cash operations & rejections
    var reject_neg_add: bool = not state.add_cash(-50)
    var reject_over_spend: bool = not state.spend_cash(10)
    var add_ok: bool = state.add_cash(2500, "test_grant")
    var reject_equip_unowned: bool = not state.equip_bike("max")
    var reject_expensive_bike: bool = not state.buy_bike("tmax")

    # 3. Buy & equip Max 150 (1200 cash -> 1300 left)
    var buy_max_ok: bool = state.buy_bike("max")
    var reject_dup_buy: bool = not state.buy_bike("max")
    var equip_max_ok: bool = state.equip_bike("max")

    # 4. Upgrade engine twice on Max (200 + 450 = 650 -> 650 left)
    var upg_eng_1: bool = state.buy_upgrade("max", "engine")
    var upg_eng_2: bool = state.buy_upgrade("max", "engine")
    # Level 3 costs 900, only 650 left -> must fail
    var reject_eng_3_broke: bool = not state.buy_upgrade("max", "engine")

    # Grant 1000 more -> buy level 3 (900) -> try level 4 (over max -> must fail)
    state.add_cash(1000, "test_grant_2")
    var upg_eng_3: bool = state.buy_upgrade("max", "engine")
    var reject_over_max: bool = not state.buy_upgrade("max", "engine")

    # Record stats
    state.record_near_miss(4)
    state.record_wheelie_duration(3.75)

    var mods: Dictionary = state.get_active_modifiers()
    var expected_torque: float = 1.18 * (1.0 + 0.12 * 3.0)

    # 5. Save and reload into brand-new state
    var save_ok: bool = store.save_state(state)
    var reloaded = PlayerEconomyStateScript.new()
    var load_res: Dictionary = store.load_state(reloaded)

    # 6. Corrupt file recovery
    var corrupt_file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
    corrupt_file.store_string("{not valid json!!!")
    corrupt_file.close()

    var recovered = PlayerEconomyStateScript.new()
    recovered.add_cash(999)
    var corrupt_res: Dictionary = store.load_state(recovered)

    # Clean up test file
    store.delete_save()

    var checks := {
        "missing_save_returns_defaults": missing_res["loaded"] == false and missing_res["reason"] == "missing_file" and state.owns_bike("cg125"),
        "cash_guards_work": reject_neg_add and reject_over_spend and add_ok and int(signal_tracker["cash_changes"]) == 6,
        "bike_purchase_and_equip": reject_equip_unowned and reject_expensive_bike and buy_max_ok and reject_dup_buy and equip_max_ok and state.active_bike_id == "max",
        "upgrades_and_caps": upg_eng_1 and upg_eng_2 and reject_eng_3_broke and upg_eng_3 and reject_over_max and state.get_upgrade_level("max", "engine") == 3,
        "cash_math_exact": state.cash == 750,
        "effective_torque_modifier_exact": absf(float(mods["torque_mult"]) - expected_torque) < 0.001,
        "save_and_reload_exact": (
            save_ok
            and load_res["loaded"] == true
            and reloaded.cash == 750
            and reloaded.active_bike_id == "max"
            and reloaded.owns_bike("cg125")
            and reloaded.owns_bike("max")
            and reloaded.get_upgrade_level("max", "engine") == 3
            and int(reloaded.stats["near_misses"]) == 1
            and absf(float(reloaded.stats["longest_wheelie_sec"]) - 3.75) < 0.001
        ),
        "corrupt_save_recovers_safely": (
            corrupt_res["loaded"] == false
            and corrupt_res["reason"] == "corrupt_json"
            and recovered.cash == 0
            and recovered.active_bike_id == "cg125"
        )
    }

    var all_ok := true
    for key in checks.keys():
        if not checks[key]:
            print("[ECONOMY SAVE TEST FAIL] ", key)
            all_ok = false

    print(
        "Economy & Save -> cash: ", reloaded.cash,
        " | active: ", reloaded.active_bike_id,
        " | eng_lvl: ", reloaded.get_upgrade_level("max", "engine"),
        " | torque_mult: ", snappedf(float(mods["torque_mult"]), 0.001)
    )

    if all_ok:
        print("[ECONOMY AND SAVE TEST OK]")
        quit(0)
    else:
        quit(1)
