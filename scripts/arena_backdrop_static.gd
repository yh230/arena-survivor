extends Node2D

## 背景静态层：关卡底图 + 中心暗涌 + 暗角 + 金线回纹边框。
## 独立成节点是因为这些内容任一帧都不变，只在 set_chapter() 时重绘一次。
## 美术调性：青绿山水（石青石绿 + 泥金），去掉原「青色矩形 HUD 框 + 角部斜杠」的仪表盘观感。

const BACKGROUND_PATHS := [
    "res://assets/art/bg_ch1.jpg",
    "res://assets/art/bg_ch2.jpg",
    "res://assets/art/bg_ch3.jpg",
]
const CENTER_SHADE_RADIUS := 300.0
const CENTER_SHADE_ALPHA := 0.12

## 泥金（与 UI.BRASS 同源，此处不能 preload ui_forge 以免循环依赖）
const GOLD := Color(0.788, 0.635, 0.153)
## 墨青，代替纯黑做出「宣纸边缘沉墨」的过渡
const INK_EDGE := Color(0.020, 0.045, 0.055)

var chapter := 1
var _background: Texture2D

func _ready() -> void:
    # 必须低于 arena_backdrop.gd 的 z_index(-10)
    z_index = -11

func set_chapter(value: int) -> void:
    chapter = clampi(value, 1, BACKGROUND_PATHS.size())
    # 性能：原实现一次性预载 3 张 1280x720 未压缩 JPG（约 11MB 常驻），实际只用 1 张。
    _background = load(BACKGROUND_PATHS[chapter - 1])
    queue_redraw()

func _draw() -> void:
    var view_size := get_viewport_rect().size
    if _background != null:
        # 性能：原为「贴图 + 全屏 30% 压暗矩形」两次全屏混合，
        # 合并为一次带 modulate 的贴图绘制（乘 0.7 ≈ 原压暗效果），省一次 921k 像素混合。
        # 调性：偏冷压暗会让青绿变脏，改为按色相轻微提青、压暖（0.66/0.74/0.72）。
        draw_texture_rect(_background, Rect2(Vector2.ZERO, view_size), false, Color(0.66, 0.74, 0.72, 1.0))
    else:
        draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.039, 0.078, 0.094, 1.0))

    _draw_center_shade(view_size)
    _draw_vignette(view_size)
    _draw_frame(view_size)

func _draw_center_shade(view_size: Vector2) -> void:
    # 性能：原为 6 个同心 draw_circle（约 761k 像素/帧），改为 1 个径向渐变 quad（约 360k）。
    var center := Vector2(view_size.x * 0.5, view_size.y * 0.5 - 6.0)
    var radius := CENTER_SHADE_RADIUS
    draw_texture_rect(
        ArtFX.glow_texture(),
        Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
        false,
        Color(0.078, 0.118, 0.110, CENTER_SHADE_ALPHA)
    )

func _draw_vignette(view_size: Vector2) -> void:
    var depth := 112.0
    var edge := Color(INK_EDGE.r, INK_EDGE.g, INK_EDGE.b, 0.62)
    var clear := Color(INK_EDGE.r, INK_EDGE.g, INK_EDGE.b, 0.0)
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

func _draw_frame(view_size: Vector2) -> void:
    # 双线金框替代原「2px 青框」，四角回纹替代原四条 45° 斜杠。
    var rect := Rect2(22.0, 22.0, view_size.x - 44.0, view_size.y - 44.0)
    draw_rect(rect, Color(GOLD.r, GOLD.g, GOLD.b, 0.30), false, 1.5)
    draw_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size - Vector2(8.0, 8.0)), Color(GOLD.r, GOLD.g, GOLD.b, 0.13), false, 1.0)
    var key := 20.0
    var inner := Color(GOLD.r, GOLD.g, GOLD.b, 0.16)
    _corner_key(rect.position, Vector2(1.0, 1.0), key, inner)
    _corner_key(Vector2(rect.position.x + rect.size.x, rect.position.y), Vector2(-1.0, 1.0), key, inner)
    _corner_key(Vector2(rect.position.x, rect.position.y + rect.size.y), Vector2(1.0, -1.0), key, inner)
    _corner_key(rect.end, Vector2(-1.0, -1.0), key, inner)

func _corner_key(at: Vector2, dir: Vector2, length: float, color: Color) -> void:
    var h := Vector2(dir.x, 0.0) * length
    var v := Vector2(0.0, dir.y) * length
    var inset := Vector2(dir.x, dir.y) * length * 0.6
    draw_line(at, at + h, color, 1.5, true)
    draw_line(at, at + v, color, 1.5, true)
    draw_line(at + inset, at + h * 0.95, Color(color.r, color.g, color.b, color.a * 0.55), 1.0, true)
    draw_line(at + inset, at + v * 0.95, Color(color.r, color.g, color.b, color.a * 0.55), 1.0, true)
