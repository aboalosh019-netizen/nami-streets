extends Node2D

func _ready() -> void:
    var viewport_size := get_viewport_rect().size
    var renderer := RenderingServer.get_video_adapter_name()

    var status_label: Label = $CanvasLayer/StatusLabel
    status_label.text = (
        "Nami Streets - Boot OK\n"
        + "FPS: " + str(Engine.get_frames_per_second()) + "\n"
        + "Viewport: " + str(viewport_size) + "\n"
        + "Renderer: " + renderer
    )

    print("[BOOT OK]")
    print("Viewport: ", viewport_size)
    print("Renderer: ", renderer)
