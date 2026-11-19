extends Node


func get_bike_input() -> Dictionary:
    return {
        "gas": Input.get_action_strength("bike_gas"),
        "brake": Input.get_action_strength("bike_brake"),
        "front_brake": Input.get_action_strength("bike_front_brake"),
        "lean_back": Input.get_action_strength("bike_lean_back"),
        "lean_forward": Input.get_action_strength("bike_lean_forward"),
        "clutch": Input.is_action_pressed("bike_clutch"),
        "shift_up": Input.is_action_just_pressed("bike_shift_up"),
        "shift_down": Input.is_action_just_pressed("bike_shift_down")
    }
