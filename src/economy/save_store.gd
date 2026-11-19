class_name SaveStore
extends RefCounted

const PlayerEconomyStateScript = preload("res://src/economy/player_economy_state.gd")

const DEFAULT_SAVE_PATH: String = "user://nami_save.json"

var save_path: String = DEFAULT_SAVE_PATH
var last_error: String = ""


func _init(custom_path: String = DEFAULT_SAVE_PATH) -> void:
    if not custom_path.is_empty():
        save_path = custom_path


func save_exists() -> bool:
    return FileAccess.file_exists(save_path)


func save_state(state: PlayerEconomyStateScript) -> bool:
    last_error = ""
    if state == null:
        last_error = "null_state"
        return false

    var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        last_error = "open_write_failed"
        return false

    var json_text: String = JSON.stringify(state.to_dict(), "  ")
    file.store_string(json_text)
    file.close()
    return true


func load_state(target_state: PlayerEconomyStateScript = null) -> Dictionary:
    last_error = ""
    var state: PlayerEconomyStateScript = target_state if target_state != null else PlayerEconomyStateScript.new()

    if not FileAccess.file_exists(save_path):
        state.reset_to_defaults()
        last_error = "missing_file"
        return {"loaded": false, "reason": last_error, "state": state}

    var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        state.reset_to_defaults()
        last_error = "open_read_failed"
        return {"loaded": false, "reason": last_error, "state": state}

    var content: String = file.get_as_text()
    file.close()

    var json := JSON.new()
    if json.parse(content) != OK or not (json.data is Dictionary):
        state.reset_to_defaults()
        last_error = "corrupt_json"
        return {"loaded": false, "reason": last_error, "state": state}

    if not state.from_dict(json.data as Dictionary):
        state.reset_to_defaults()
        last_error = "invalid_schema"
        return {"loaded": false, "reason": last_error, "state": state}

    return {"loaded": true, "reason": "", "state": state}


func delete_save() -> bool:
    if not FileAccess.file_exists(save_path):
        return true
    var abs_path: String = ProjectSettings.globalize_path(save_path)
    return DirAccess.remove_absolute(abs_path) == OK
