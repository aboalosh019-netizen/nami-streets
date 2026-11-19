extends SceneTree


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    assert(root.has_node("InputManager"))

    var input_manager = root.get_node("InputManager")
    var input_data: Dictionary = input_manager.get_bike_input()

    var expected_keys := [
        "gas",
        "brake",
        "front_brake",
        "lean_back",
        "lean_forward",
        "clutch",
        "shift_up",
        "shift_down"
    ]

    for key in expected_keys:
        assert(input_data.has(key))

    assert(input_data["gas"] is float)
    assert(input_data["brake"] is float)
    assert(input_data["clutch"] is bool)
    assert(input_data["shift_up"] is bool)
    assert(input_data["shift_down"] is bool)

    print("[INPUT MANAGER TEST OK]")
    print("Input keys: ", input_data.keys())

    quit()
