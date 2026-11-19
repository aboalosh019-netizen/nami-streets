extends Node


func change_scene(scene_path: String) -> Error:
    if not scene_path.begins_with("res://"):
        push_error("[SCENE MANAGER] Invalid scene path: " + scene_path)
        return ERR_INVALID_PARAMETER

    if not ResourceLoader.exists(scene_path, "PackedScene"):
        push_error("[SCENE MANAGER] Scene not found: " + scene_path)
        return ERR_FILE_NOT_FOUND

    var result := get_tree().change_scene_to_file(scene_path)

    if result != OK:
        push_error("[SCENE MANAGER] Failed to change scene: " + scene_path)
        return result

    print("[SCENE MANAGER] Scene changed: ", scene_path)
    return OK
