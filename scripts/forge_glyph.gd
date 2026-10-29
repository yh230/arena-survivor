extends Control

const ICON_IDS := {
    "炮": "peony",
    "刃": "maple",
    "链": "justice",
    "穿": "vigil",
    "锤": "hammer",
    "毒": "elixir",
    "磁": "magnet",
    "靴": "boots",
    "火": "holy_fire",
    "猫": "lucky_cat",
    "砧": "anvil",
    "翠": "jade",
}

var text := "":
    set(value):
        text = value
        queue_redraw()

var tint := Color("#ecd689"):
    set(value):
        tint = value
        queue_redraw()

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
    var icon_id := str(ICON_IDS.get(text, ""))
    if icon_id == "":
        return
    var s := minf(size.x, size.y)
    var half := s * 0.5
    var c := size * 0.5
    var w := maxf(1.4, s * 0.065)
    var light := tint.lightened(0.35)
    var dark := tint.darkened(0.35)
    match icon_id:
        "peony":
            _peony(c, half, w, tint, light, dark)
        "maple":
            _maple(c, half, w, tint, light)
        "justice":
            _justice(c, half, w, tint, light)
        "vigil":
            _vigil(c, half, w, tint, light)
        "hammer":
            _hammer(c, half, w, tint, light, dark)
        "elixir":
            _elixir(c, half, w, tint, light, dark)
        "magnet":
            _magnet(c, half, w, tint, light, dark)
        "boots":
            _boots(c, half, w, tint, light)
        "holy_fire":
            _holy_fire(c, half, w, tint, light)
        "lucky_cat":
            _cat(c, half, w, tint, light, dark)
        "anvil":
            _anvil(c, half, w, tint, light)
        "jade":
            _jade(c, half, w, tint, light)

func _p(center: Vector2, half: float, x: float, y: float) -> Vector2:
    return center + Vector2(x, y) * half

func _peony(c: Vector2, k: float, w: float, tint: Color, light: Color, dark: Color) -> void:
    for index in range(5):
        var angle := -PI * 0.5 + TAU * float(index) / 5.0
        draw_arc(c + Vector2(0.0, -0.12) * k, 0.46 * k, angle - 0.42, angle + 0.42, 10, Color(tint.r, tint.g, tint.b, 0.65), w * 1.3, true)
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, -0.52, 0.40), _p(c, k, 0.52, 0.40),
        _p(c, k, 0.40, 0.74), _p(c, k, -0.40, 0.74),
    ]), Color(tint.r, tint.g, tint.b, 0.92))
    draw_rect(Rect2(_p(c, k, -0.19, -0.58), Vector2(0.38, 0.96) * k), Color(tint.r, tint.g, tint.b, 0.92))
    draw_line(_p(c, k, -0.62, 0.32), _p(c, k, 0.62, 0.32), dark, w)
    draw_arc(c + Vector2(0.0, -0.58) * k, 0.19 * k, 0.0, TAU, 20, light, w, true)
    draw_circle(c + Vector2(0.0, -0.58) * k, 0.11 * k, dark)
    draw_circle(_p(c, k, 0.0, 0.20), 0.07 * k, dark)

func _maple(c: Vector2, k: float, w: float, tint: Color, light: Color) -> void:
    draw_arc(c, 0.62 * k, 0.0, TAU, 40, tint, w, true)
    for index in range(3):
        var angle := -PI * 0.5 + TAU * float(index) / 3.0
        var inner := c + Vector2.from_angle(angle) * 0.62 * k
        var outer := c + Vector2.from_angle(angle) * 0.86 * k
        draw_line(inner, outer, tint, w * 1.5, true)
        draw_circle(outer, w * 0.9, light)
    draw_circle(c, 0.15 * k, light)

func _justice(c: Vector2, k: float, w: float, tint: Color, light: Color) -> void:
    var points := PackedVector2Array([
        _p(c, k, -0.72, 0.48), _p(c, k, -0.30, 0.04),
        _p(c, k, 0.04, 0.42), _p(c, k, 0.44, -0.18),
        _p(c, k, 0.72, -0.62),
    ])
    draw_polyline(points, tint, w * 1.2, true)
    for point in points:
        draw_circle(point, w * 0.95, light)

func _vigil(c: Vector2, k: float, w: float, tint: Color, light: Color) -> void:
    draw_line(_p(c, k, -0.68, 0.68), _p(c, k, 0.48, -0.48), tint, w * 1.2, true)
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, 0.72, -0.72), _p(c, k, 0.18, -0.52), _p(c, k, 0.52, -0.18),
    ]), tint)
    draw_line(_p(c, k, -0.52, 0.10), _p(c, k, -0.10, 0.52), dark_line(tint), w * 0.8)

func _hammer(c: Vector2, k: float, w: float, tint: Color, light: Color, dark: Color) -> void:
    draw_rect(Rect2(_p(c, k, -0.58, -0.72), Vector2(1.16, 0.44) * k), tint)
    draw_rect(Rect2(_p(c, k, -0.44, -0.60), Vector2(0.88, 0.18) * k), Color(tint.r, tint.g, tint.b, 0.65))
    draw_circle(_p(c, k, 0.0, -0.50), 0.13 * k, dark)
    draw_line(_p(c, k, 0.0, -0.28), _p(c, k, 0.0, 0.62), dark, w * 2.0)
    draw_line(_p(c, k, -0.10, 0.20), _p(c, k, 0.10, 0.20), light, w * 0.8)
    draw_line(_p(c, k, -0.10, 0.34), _p(c, k, 0.10, 0.34), light, w * 0.8)
    draw_circle(_p(c, k, 0.0, 0.68), w * 1.0, light)
    draw_line(_p(c, k, -0.40, -0.66), _p(c, k, 0.40, -0.66), light, w * 0.7)

func _elixir(c: Vector2, k: float, w: float, tint: Color, light: Color, dark: Color) -> void:
    draw_rect(Rect2(_p(c, k, -0.13, -0.72), Vector2(0.26, 0.32) * k), tint)
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, -0.13, -0.40), _p(c, k, 0.13, -0.40),
        _p(c, k, 0.42, 0.48), _p(c, k, -0.42, 0.48),
    ]), Color(tint.r, tint.g, tint.b, 0.55))
    draw_arc(c + Vector2(0.0, 0.16) * k, 0.30 * k, 0.0, TAU, 28, tint, w, true)
    draw_circle(_p(c, k, -0.14, 0.26), w * 0.9, light)
    draw_circle(_p(c, k, 0.12, 0.40), w * 0.7, light)
    draw_circle(_p(c, k, 0.0, 0.06), w * 0.5, dark)

func _magnet(c: Vector2, k: float, w: float, tint: Color, light: Color, dark: Color) -> void:
    draw_arc(c + Vector2(0.0, 0.06) * k, 0.36 * k, 0.0, PI, 28, tint, w * 1.8, true)
    draw_line(_p(c, k, -0.36, 0.06), _p(c, k, -0.36, -0.62), tint, w * 1.8, true)
    draw_line(_p(c, k, 0.36, 0.06), _p(c, k, 0.36, -0.62), tint, w * 1.8, true)
    draw_line(_p(c, k, -0.36, -0.66), _p(c, k, -0.36, -0.44), light, w * 2.0, true)
    draw_line(_p(c, k, 0.36, -0.66), _p(c, k, 0.36, -0.44), light, w * 2.0, true)
    draw_arc(c + Vector2(0.0, 0.06) * k, 0.36 * k, 0.0, PI, 28, dark, w * 0.6, true)

func _boots(c: Vector2, k: float, w: float, tint: Color, light: Color) -> void:
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, -0.36, -0.74), _p(c, k, 0.06, -0.74),
        _p(c, k, 0.06, 0.02), _p(c, k, 0.44, 0.08),
        _p(c, k, 0.64, 0.34), _p(c, k, 0.64, 0.52),
        _p(c, k, -0.36, 0.52),
    ]), tint)
    draw_line(_p(c, k, -0.36, 0.40), _p(c, k, 0.64, 0.40), light, w * 1.1)
    draw_rect(Rect2(_p(c, k, -0.36, 0.24), Vector2(0.24, 0.28) * k), Color(tint.r, tint.g, tint.b, 0.65))
    draw_line(_p(c, k, -0.22, -0.52), _p(c, k, 0.0, -0.62), light, w * 0.7)
    draw_line(_p(c, k, -0.22, -0.30), _p(c, k, 0.0, -0.40), light, w * 0.7)
    draw_arc(_p(c, k, 0.24, 0.02), 0.14 * k, 0.0, TAU, 16, light, w * 0.8, true)
    draw_circle(_p(c, k, 0.24, 0.02), 0.05 * k, light)

func _holy_fire(c: Vector2, k: float, w: float, tint: Color, light: Color) -> void:
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, 0.0, -0.82), _p(c, k, 0.34, -0.18),
        _p(c, k, 0.46, 0.22), _p(c, k, 0.20, 0.64),
        _p(c, k, -0.20, 0.64), _p(c, k, -0.46, 0.22),
        _p(c, k, -0.30, -0.20),
    ]), tint)
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, 0.0, -0.30), _p(c, k, 0.20, 0.16),
        _p(c, k, 0.0, 0.48), _p(c, k, -0.20, 0.16),
    ]), light)
    draw_arc(c + Vector2(0.0, 0.10) * k, 0.52 * k, -PI * 0.15, PI * 0.15, 12, dark_line(tint), w * 0.6)

func _cat(c: Vector2, k: float, w: float, tint: Color, light: Color, dark: Color) -> void:
    draw_circle(c + Vector2(0.0, 0.10) * k, 0.46 * k, tint)
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, -0.44, -0.16), _p(c, k, -0.36, -0.68), _p(c, k, -0.04, -0.36),
    ]), tint)
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, 0.44, -0.16), _p(c, k, 0.36, -0.68), _p(c, k, 0.04, -0.36),
    ]), tint)
    draw_circle(_p(c, k, -0.17, 0.04), w * 0.9, dark)
    draw_circle(_p(c, k, 0.17, 0.04), w * 0.9, dark)
    draw_line(_p(c, k, 0.0, 0.20), _p(c, k, -0.06, 0.30), light, w * 0.6)
    draw_line(_p(c, k, 0.0, 0.20), _p(c, k, 0.06, 0.30), light, w * 0.6)
    draw_line(_p(c, k, -0.44, 0.28), _p(c, k, -0.68, 0.20), light, w * 0.5)
    draw_line(_p(c, k, 0.44, 0.28), _p(c, k, 0.68, 0.20), light, w * 0.5)

func _anvil(c: Vector2, k: float, w: float, tint: Color, light: Color) -> void:
    draw_colored_polygon(PackedVector2Array([
        _p(c, k, -0.62, -0.40), _p(c, k, 0.62, -0.40),
        _p(c, k, 0.44, -0.06), _p(c, k, 0.16, -0.06),
        _p(c, k, 0.34, 0.40), _p(c, k, -0.34, 0.40),
        _p(c, k, -0.16, -0.06), _p(c, k, -0.44, -0.06),
    ]), tint)
    draw_rect(Rect2(_p(c, k, -0.46, 0.44), Vector2(0.92, 0.20) * k), Color(tint.r, tint.g, tint.b, 0.85))
    draw_line(_p(c, k, -0.46, -0.34), _p(c, k, 0.46, -0.34), light, w * 0.7)

func _jade(c: Vector2, k: float, w: float, tint: Color, light: Color) -> void:
    var points := PackedVector2Array()
    for index in range(6):
        var angle := -PI * 0.5 + TAU * float(index) / 6.0
        points.append(c + Vector2.from_angle(angle) * 0.62 * k)
    draw_colored_polygon(points, Color(tint.r, tint.g, tint.b, 0.85))
    var closed := points.duplicate()
    closed.append(points[0])
    draw_polyline(closed, light, w, true)
    draw_line(points[0], points[3], Color(light.r, light.g, light.b, 0.45), w * 0.6)
    draw_line(points[1], points[4], Color(light.r, light.g, light.b, 0.30), w * 0.5)
    draw_circle(c + Vector2(-0.14, -0.16) * k, 0.10 * k, light)

func dark_line(color: Color) -> Color:
    return Color(color.r, color.g, color.b, 0.45)
