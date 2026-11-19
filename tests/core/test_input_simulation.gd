extends Node


func _ready() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var input_manager = get_node("/root/InputManager")

    Input.action_press("bike_gas")

    await get_tree().process_frame

    var input_data: Dictionary = input_manager.get_bike_input()
    var gas_value: float = input_data["gas"]

    print("Gas value: ", gas_value)

    var passed := gas_value > 0.0

    Input.action_release("bike_gas")

    if passed:
        print("[INPUT SIMULATION TEST OK]")
        get_tree().quit(0)
    else:
        print("[INPUT SIMULATION TEST FAILED]")
        get_tree().quit(1)
