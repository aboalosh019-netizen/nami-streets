extends SceneTree

const GarageMenuScript = preload("res://src/ui/garage/garage_menu.gd")


func _initialize() -> void:
    var garage = GarageMenuScript.new()
    root.add_child(garage)

    await process_frame

    assert(garage is Control)
    assert(garage.has_method("refresh_menu"))

    print("[GARAGE SCRIPT LOAD TEST OK]")

    garage.queue_free()
    quit()
