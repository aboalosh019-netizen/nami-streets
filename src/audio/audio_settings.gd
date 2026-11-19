class_name AudioSettings
extends RefCounted

const DEFAULT_PATH: String = "user://nami_audio_settings.json"
const SCHEMA_VERSION: int = 1

var settings_path: String = DEFAULT_PATH
var master_volume: float = 0.85
var music_volume: float = 0.65
var sfx_volume: float = 0.90
var muted: bool = false
var last_error: String = ""


func _init(custom_path: String = "") -> void:
    if not custom_path.is_empty():
        settings_path = custom_path


func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "master_volume": clampf(master_volume, 0.0, 1.0),
        "music_volume": clampf(music_volume, 0.0, 1.0),
        "sfx_volume": clampf(sfx_volume, 0.0, 1.0),
        "muted": muted
    }


func from_dict(data: Dictionary) -> void:
    master_volume = clampf(float(data.get("master_volume", 0.85)), 0.0, 1.0)
    music_volume = clampf(float(data.get("music_volume", 0.65)), 0.0, 1.0)
    sfx_volume = clampf(float(data.get("sfx_volume", 0.90)), 0.0, 1.0)
    muted = bool(data.get("muted", false))


func save_settings() -> bool:
    last_error = ""
    var file: FileAccess = FileAccess.open(settings_path, FileAccess.WRITE)
    if file == null:
        last_error = "open_write_failed"
        return false

    file.store_string(JSON.stringify(to_dict(), "    "))
    file.close()
    return true


func load_settings() -> Dictionary:
    last_error = ""
    if not FileAccess.file_exists(settings_path):
        return {"loaded": false, "reason": "not_found"}

    var file: FileAccess = FileAccess.open(settings_path, FileAccess.READ)
    if file == null:
        last_error = "open_read_failed"
        return {"loaded": false, "reason": "open_read_failed"}

    var raw: String = file.get_as_text()
    file.close()

    var json := JSON.new()
    var err: Error = json.parse(raw)
    if err != OK or not (json.data is Dictionary):
        last_error = "corrupt_json"
        return {"loaded": false, "reason": "corrupt_json"}

    from_dict(json.data as Dictionary)
    return {"loaded": true, "reason": "ok"}


func delete_settings() -> bool:
    if not FileAccess.file_exists(settings_path):
        return true
    var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
    return err == OK
