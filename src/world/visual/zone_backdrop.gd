class_name ZoneBackdrop
extends ParallaxBackground

const TILE_W: float = 640.0
const VIEW_H: float = 360.0

var zone_id: String = "hub_boulevard"
var theme_name: String = "boulevard"


class BackdropCanvas extends Node2D:
    var kind: String = "sky"
    var theme: String = "boulevard"

    func _draw() -> void:
        if kind == "sky":
            _draw_sky()
        elif kind == "far":
            _draw_far()
        elif kind == "mid":
            _draw_mid()

    func _draw_sky() -> void:
        var bands: Array[Color]
        if theme == "boulevard":
            bands = [Color(0.11, 0.12, 0.26), Color(0.24, 0.16, 0.32), Color(0.55, 0.25, 0.26), Color(0.86, 0.48, 0.22), Color(0.95, 0.72, 0.36)]
        elif theme == "track":
            bands = [Color(0.10, 0.16, 0.25), Color(0.16, 0.24, 0.35), Color(0.24, 0.34, 0.45), Color(0.36, 0.44, 0.52), Color(0.45, 0.50, 0.55)]
        else:
            bands = [Color(0.03, 0.04, 0.09), Color(0.05, 0.07, 0.14), Color(0.07, 0.10, 0.19), Color(0.10, 0.14, 0.24), Color(0.13, 0.17, 0.27)]

        var bh: float = 360.0 / float(bands.size())
        for i in range(bands.size()):
            draw_rect(Rect2(0.0, float(i) * bh, 640.0, bh + 1.0), bands[i], true)

        if theme == "boulevard":
            draw_circle(Vector2(500, 175), 34.0, Color(1.0, 0.80, 0.40, 0.22))
            draw_circle(Vector2(500, 175), 22.0, Color(1.0, 0.88, 0.52, 0.95))
        elif theme == "highway":
            draw_circle(Vector2(520, 62), 14.0, Color(0.95, 0.96, 0.88, 0.95))
            draw_circle(Vector2(526, 58), 12.0, Color(0.03, 0.04, 0.09, 1.0))
            for i in range(28):
                var sx: float = fmod(float(i * 97 + 23), 630.0)
                var sy: float = fmod(float(i * 43 + 11), 130.0)
                draw_rect(Rect2(sx, sy, 2.0, 2.0), Color(0.92, 0.95, 1.0, 0.75), true)

    func _draw_far() -> void:
        var base_y: float = 250.0
        var sil: Color = Color(0.14, 0.10, 0.18) if theme == "boulevard" else (Color(0.14, 0.18, 0.24) if theme == "track" else Color(0.06, 0.08, 0.13))
        var win: Color = Color(1.0, 0.82, 0.42, 0.75) if theme != "track" else Color(0.75, 0.88, 0.95, 0.45)
        var widths: Array[float] = [44, 34, 58, 40, 62, 36, 52, 48, 66, 38, 54, 42, 66]
        var heights: Array[float] = [68, 96, 54, 112, 74, 88, 62, 104, 58, 92, 70, 84, 64]
        var x: float = 0.0
        for i in range(widths.size()):
            var w: float = widths[i]
            var h: float = heights[i] * (0.72 if theme == "track" else 1.0)
            draw_rect(Rect2(x, base_y - h, w - 3.0, h + 110.0), sil, true)
            for wy in range(int(base_y - h + 8), int(base_y - 12), 12):
                for wx in range(int(x + 6), int(x + w - 12), 10):
                    if ((wx + wy + i) % 3) != 0:
                        draw_rect(Rect2(float(wx), float(wy), 4.0, 5.0), win, true)
            x += w

    func _draw_mid() -> void:
        var ground_y: float = 275.0
        if theme == "boulevard":
            for i in range(4):
                var px: float = 40.0 + float(i) * 160.0
                draw_line(Vector2(px, ground_y), Vector2(px + 8.0, ground_y - 78.0), Color(0.12, 0.09, 0.11), 5.0)
                var top := Vector2(px + 8.0, ground_y - 78.0)
                for ang in [-2.5, -1.9, -1.2, -0.5, 0.1, 0.55]:
                    var tip := top + Vector2.RIGHT.rotated(ang) * 26.0
                    draw_line(top, tip, Color(0.10, 0.22, 0.15), 3.0)
                var lx: float = px + 80.0
                draw_line(Vector2(lx, ground_y), Vector2(lx, ground_y - 72.0), Color(0.16, 0.17, 0.22), 3.0)
                draw_line(Vector2(lx, ground_y - 72.0), Vector2(lx + 10.0, ground_y - 72.0), Color(0.16, 0.17, 0.22), 2.5)
                draw_circle(Vector2(lx + 10.0, ground_y - 70.0), 14.0, Color(1.0, 0.78, 0.35, 0.20))
                draw_rect(Rect2(lx + 8.0, ground_y - 72.0, 5.0, 3.0), Color(1.0, 0.92, 0.65), true)
        elif theme == "track":
            for i in range(4):
                var tx: float = 60.0 + float(i) * 160.0
                draw_line(Vector2(tx, ground_y), Vector2(tx, ground_y - 88.0), Color(0.24, 0.27, 0.32), 4.0)
                draw_rect(Rect2(tx - 10.0, ground_y - 92.0, 20.0, 6.0), Color(0.85, 0.92, 1.0), true)
                draw_circle(Vector2(tx, ground_y - 86.0), 16.0, Color(0.80, 0.90, 1.0, 0.16))
        else:
            for i in range(4):
                var hx: float = 50.0 + float(i) * 160.0
                draw_line(Vector2(hx, ground_y), Vector2(hx, ground_y - 84.0), Color(0.18, 0.21, 0.27), 3.0)
                draw_line(Vector2(hx - 12.0, ground_y - 84.0), Vector2(hx + 12.0, ground_y - 84.0), Color(0.18, 0.21, 0.27), 2.5)
                draw_circle(Vector2(hx - 12.0, ground_y - 82.0), 13.0, Color(0.55, 0.85, 1.0, 0.18))
                draw_circle(Vector2(hx + 12.0, ground_y - 82.0), 13.0, Color(0.55, 0.85, 1.0, 0.18))


func setup_for_zone(p_zone_id: String) -> void:
    zone_id = p_zone_id
    if p_zone_id.contains("highway"):
        theme_name = "highway"
    elif p_zone_id.contains("track"):
        theme_name = "track"
    else:
        theme_name = "boulevard"

    layer = -10
    for c in get_children():
        c.queue_free()

    _add_layer("SkyLayer", "sky", Vector2.ZERO, Vector2.ZERO)
    _add_layer("FarLayer", "far", Vector2(0.14, 0.0), Vector2(TILE_W, 0.0))
    _add_layer("MidLayer", "mid", Vector2(0.42, 0.0), Vector2(TILE_W, 0.0))


func _add_layer(layer_name: String, kind: String, scale_vec: Vector2, mirror_vec: Vector2) -> void:
    var pl := ParallaxLayer.new()
    pl.name = layer_name
    pl.motion_scale = scale_vec
    pl.motion_mirroring = mirror_vec
    add_child(pl)

    var canvas := BackdropCanvas.new()
    canvas.name = "Canvas"
    canvas.kind = kind
    canvas.theme = theme_name
    pl.add_child(canvas)


func get_backdrop_state() -> Dictionary:
    var mid: ParallaxLayer = get_node_or_null("MidLayer") as ParallaxLayer
    return {
        "zone_id": zone_id,
        "theme": theme_name,
        "layer_count": get_child_count(),
        "mirroring_enabled": mid != null and mid.motion_mirroring.x > 0.0
    }
