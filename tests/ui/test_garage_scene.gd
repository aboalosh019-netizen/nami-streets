extends SceneTree

const GarageScene = preload("res://src/ui/garage/garage_menu.tscn")


func _initialize() -> void:
    call_deferred("_run_test")


func _run_test() -> void:
    var garage = GarageScene.instantiate()
    root.add_child(garage)

    await process_frame

    assert(garage is Control)
    assert(garage.has_method("bind_data"))
    assert(garage.has_method("refresh_menu"))

    print("[GARAGE SCENE TEST OK]")

    garage.queue_free()
    quit()
