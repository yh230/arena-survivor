extends Node2D

const EMBER_COUNT := 26
const DUST_COUNT := 18
const BACKGROUND_PATHS := [
    "res://assets/art/bg_ch1.jpg",
    "res://assets/art/bg_ch2.jpg",
    "res://assets/art/bg_ch3.jpg",
]
const EMBERS := [
    Color("#5eead4"),
    Color("#fbbf24"),
    Color("#d8b4fe"),
]
const BRAZIERS := [
    Vector2(126.0, 92.0),
    Vector2(1154.0, 104.0),
    Vector2(132.0, 626.0),
    Vector2(1152.0, 638.0),
]

var chapter := 1
var _time := 0.0
var _backgrounds: Array = []
var _glows: Array = []
var _glow_base: Array = []

func _ready() -> void:
    z_index = -10
    for path in BACKGROUND_PATHS:
        _backgrounds.append(load(path))
    for index in range(BRAZIERS.size()):
        var strength := 0.075 + float(index % 2) * 0.012
        var glow := ArtFX.add_glow(self, Color(1.0, 0.5, 0.18), 92.0, strength, 1)
        glow.position = BRAZIERS[index]
        _glows.append(glow)
        _glow_base.append(strength)
    var center_glow := ArtFX.add_glow(self, Color(1.0, 0.62, 0.3), 300.0, 0.05, 1)
    center_glow.position = Vector2(640.0, 390.0)
    _glows.append(center_glow)
    _glow_base.append(0.05)

func set_chapter(value: int) -> void:
    chapter = clampi(value, 1, _backgrounds.size())
    queue_redraw()

func _process(delta: float) -> void:
    _time += delta
    for index in range(_glows.size()):
        var glow: Sprite2D = _glows[index]
        var base: float = _glow_base[index]
        glow.modulate.a = base * (0.82 + 0.18 * sin(_time * (2.2 + float(index % 3) * 0.7) + float(index) * 1.7))
    queue_redraw()

func _draw() -> void:
    var view_size := get_viewport_rect().size
    draw_texture_rect(_backgrounds[chapter - 1], Rect2(Vector2.ZERO, view_size), false)
    draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.01, 0.03, 0.04, 0.30))
    _draw_light_shafts(view_size)
    var center := Vector2(view_size.x * 0.5, view_size.y * 0.5 - 6.0)
    for index in range(6):
        draw_circle(center, 300.0 - float(index) * 46.0, Color(0.0, 0.02, 0.03, 0.018))
    _draw_floor_runes(center)
    _draw_embers(view_size)
    _draw_dust(view_size)
    _draw_vignette(view_size)
    draw_rect(Rect2(20.0, 20.0, view_size.x - 40.0, view_size.y - 40.0), Color(0.15, 0.75, 0.70, 0.24), false, 2.0)
    draw_line(Vector2(20.0, 66.0), Vector2(56.0, 20.0), Color(0.85, 0.71, 0.42, 0.35), 1.0)
    draw_line(Vector2(view_size.x - 20.0, 66.0), Vector2(view_size.x - 56.0, 20.0), Color(0.85, 0.71, 0.42, 0.35), 1.0)
    draw_line(Vector2(20.0, view_size.y - 66.0), Vector2(56.0, view_size.y - 20.0), Color(0.85, 0.71, 0.42, 0.35), 1.0)
    draw_line(Vector2(view_size.x - 20.0, view_size.y - 66.0), Vector2(view_size.x - 56.0, view_size.y - 20.0), Color(0.85, 0.71, 0.42, 0.35), 1.0)

func _draw_light_shafts(view_size: Vector2) -> void:
    for index in range(3):
        var x := 170.0 + float(index) * 390.0
        var sway := sin(_time * 0.22 + float(index) * 1.8) * 24.0
        var alpha := 0.032 + 0.012 * sin(_time * 0.7 + float(index))
        draw_polygon(
            PackedVector2Array([
                Vector2(x, 0.0),
                Vector2(x + 84.0, 0.0),
                Vector2(x + 224.0 + sway, view_size.y),
                Vector2(x + 46.0 + sway, view_size.y),
            ]),
            PackedColorArray([
                Color(1.0, 0.62, 0.28, alpha),
                Color(1.0, 0.62, 0.28, alpha * 0.6),
                Color(1.0, 0.6, 0.26, 0.0),
                Color(1.0, 0.6, 0.26, 0.0),
            ])
        )

func _draw_floor_runes(center: Vector2) -> void:
    var slow := _time * 0.045
    var fast := -_time * 0.07
    var brass := Color(0.85, 0.71, 0.42, 0.035)
    var teal := Color(0.25, 0.9, 0.82, 0.03)
    draw_arc(center, 302.0, slow, slow + TAU * 0.72, 64, brass, 2.0, true)
    draw_arc(center, 296.0, slow + PI, slow + PI + TAU * 0.18, 24, brass, 1.0, true)
    draw_arc(center, 268.0, fast, fast + TAU * 0.5, 64, teal, 1.5, true)
    for index in range(12):
        var angle := slow * 1.6 + TAU * float(index) / 12.0
        var inner := center + Vector2.from_angle(angle) * 304.0
        var outer := center + Vector2.from_angle(angle) * 314.0
        draw_line(inner, outer, Color(0.85, 0.71, 0.42, 0.05), 1.0, true)
    for index in range(4):
        var diamond_angle := fast * 2.0 + TAU * float(index) / 4.0
        var at := center + Vector2.from_angle(diamond_angle) * 302.0
        var size := 5.0
        draw_colored_polygon(
            PackedVector2Array([at + Vector2(0.0, -size), at + Vector2(size, 0.0), at + Vector2(0.0, size), at + Vector2(-size, 0.0)]),
            Color(0.85, 0.71, 0.42, 0.05)
        )

func _draw_embers(view_size: Vector2) -> void:
    var ember: Color = EMBERS[chapter - 1]
    for index in range(EMBER_COUNT):
        var phase := float(index) * 2.399
        var drift := fposmod(_time * (14.0 + float(index % 5) * 6.0) + float(index) * 47.0, view_size.y + 40.0)
        var x := fposmod(sin(phase) * 620.0 + 640.0 + sin(_time * 0.6 + phase) * 24.0, view_size.x)
        var y := view_size.y + 20.0 - drift
        var alpha := 0.14 + 0.26 * (0.5 + 0.5 * sin(_time * 2.0 + phase))
        var size := 1.6 + float(index % 3) * 0.7
        draw_circle(Vector2(x, y), size * 2.4, Color(ember.r, ember.g, ember.b, alpha * 0.18))
        draw_circle(Vector2(x, y), size, Color(ember.r, ember.g, ember.b, alpha))

func _draw_dust(view_size: Vector2) -> void:
    for index in range(DUST_COUNT):
        var phase := float(index) * 1.7
        var x := fposmod(float(index) * 79.0 + _time * (7.0 + float(index % 4) * 4.0) + sin(phase) * 40.0, view_size.x)
        var y := fposmod(float(index) * 53.0 + sin(_time * 0.5 + phase) * 28.0, view_size.y)
        var alpha := 0.035 + 0.035 * (0.5 + 0.5 * sin(_time * 1.3 + phase))
        draw_circle(Vector2(x, y), 1.0 + float(index % 2) * 0.6, Color(0.7, 0.85, 0.82, alpha))

func _draw_vignette(view_size: Vector2) -> void:
    var depth := 108.0
    var edge := Color(0.0, 0.0, 0.0, 0.64)
    var clear := Color(0.0, 0.0, 0.0, 0.0)
    draw_polygon(
        PackedVector2Array([Vector2(0.0, 0.0), Vector2(view_size.x, 0.0), Vector2(view_size.x, depth), Vector2(0.0, depth)]),
        PackedColorArray([edge, edge, clear, clear])
    )
    draw_polygon(
        PackedVector2Array([Vector2(0.0, view_size.y - depth), Vector2(view_size.x, view_size.y - depth), Vector2(view_size.x, view_size.y), Vector2(0.0, view_size.y)]),
        PackedColorArray([clear, clear, edge, edge])
    )
    draw_polygon(
        PackedVector2Array([Vector2(0.0, 0.0), Vector2(depth, 0.0), Vector2(depth, view_size.y), Vector2(0.0, view_size.y)]),
        PackedColorArray([edge, clear, clear, edge])
    )
    draw_polygon(
        PackedVector2Array([Vector2(view_size.x - depth, 0.0), Vector2(view_size.x, 0.0), Vector2(view_size.x, view_size.y), Vector2(view_size.x - depth, view_size.y)]),
        PackedColorArray([clear, edge, edge, clear])
    )
