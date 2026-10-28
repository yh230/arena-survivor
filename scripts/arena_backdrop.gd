extends Node2D

const EMBER_COUNT := 26
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

var chapter := 1
var _time := 0.0
var _backgrounds: Array = []

func _ready() -> void:
    z_index = -10
    for path in BACKGROUND_PATHS:
        _backgrounds.append(load(path))

func set_chapter(value: int) -> void:
    chapter = clampi(value, 1, _backgrounds.size())
    queue_redraw()

func _process(delta: float) -> void:
    _time += delta
    queue_redraw()

func _draw() -> void:
    var view_size := get_viewport_rect().size
    draw_texture_rect(_backgrounds[chapter - 1], Rect2(Vector2.ZERO, view_size), false)
    draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.01, 0.03, 0.04, 0.32))
    var center := view_size * 0.5
    for index in range(6):
        draw_circle(center, 300.0 - float(index) * 46.0, Color(0.0, 0.02, 0.03, 0.020))
    _draw_embers(view_size)
    _draw_vignette(view_size)
    draw_rect(Rect2(20.0, 20.0, view_size.x - 40.0, view_size.y - 40.0), Color(0.15, 0.75, 0.70, 0.28), false, 2.0)

func _draw_embers(view_size: Vector2) -> void:
    var ember: Color = EMBERS[chapter - 1]
    for index in range(EMBER_COUNT):
        var phase := float(index) * 2.399
        var drift := fposmod(_time * (14.0 + float(index % 5) * 6.0) + float(index) * 47.0, view_size.y + 40.0)
        var x := fposmod(sin(phase) * 620.0 + 640.0 + sin(_time * 0.6 + phase) * 24.0, view_size.x)
        var y := view_size.y + 20.0 - drift
        var alpha := 0.14 + 0.26 * (0.5 + 0.5 * sin(_time * 2.0 + phase))
        draw_circle(Vector2(x, y), 1.6 + float(index % 3) * 0.7, Color(ember.r, ember.g, ember.b, alpha))

func _draw_vignette(view_size: Vector2) -> void:
    var depth := 96.0
    var edge := Color(0.0, 0.0, 0.0, 0.55)
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
