extends Node2D

## 背景动态层：山岚雾气 + 地面法阵 + 萤火 + 浮尘。
## 调性：青绿山水。原「暖橙熔炉光柱 + 黄铜机械地纹」改为「青白雾气 + 泥金法阵」。
## 静态内容（底图/暗角/边框）已拆至 arena_backdrop_static.gd。

const EMBER_COUNT := 26
const DUST_COUNT := 18
const BACKGROUND_PATHS := [
    "res://assets/art/bg_ch1.jpg",
    "res://assets/art/bg_ch2.jpg",
    "res://assets/art/bg_ch3.jpg",
]
## 萤火三色：石绿 / 泥金 / 淡青
const EMBERS := [
    Color("#7fd4a8"),
    Color("#e8c76a"),
    Color("#a8cec0"),
]
const GOLD := Color(0.788, 0.635, 0.153)
const JADE := Color(0.42, 0.72, 0.58)
const BRAZIERS := [
    Vector2(126.0, 92.0),
    Vector2(1154.0, 104.0),
    Vector2(132.0, 626.0),
    Vector2(1152.0, 638.0),
]

var chapter := 1
var _time := 0.0
var _glows: Array = []
var _glow_base: Array = []

func _ready() -> void:
    z_index = -10
    # 四角灯：由「熔炉暖橙」改为「石绿灯火」，强度下调以免在青绿底上过曝。
    for index in range(BRAZIERS.size()):
        var strength := 0.062 + float(index % 2) * 0.010
        var glow := ArtFX.add_glow(self, Color(0.55, 0.86, 0.72), 92.0, strength, 1)
        glow.position = BRAZIERS[index]
        _glows.append(glow)
        _glow_base.append(strength)
    var center_glow := ArtFX.add_glow(self, Color(0.78, 0.72, 0.42), 300.0, 0.042, 1)
    center_glow.position = Vector2(640.0, 390.0)
    _glows.append(center_glow)
    _glow_base.append(0.042)

func set_chapter(value: int) -> void:
    chapter = clampi(value, 1, BACKGROUND_PATHS.size())
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
    _draw_light_shafts(view_size)
    var center := Vector2(view_size.x * 0.5, view_size.y * 0.5 - 6.0)
    _draw_floor_runes(center)
    _draw_embers(view_size)
    _draw_dust(view_size)

func _draw_light_shafts(view_size: Vector2) -> void:
    # 原为三道暖橙直射光（熔炉感）。改为青白雾带：色相偏冷、alpha 略降，
    # 让它读作「山间流岚」而不是「射灯」。
    for index in range(3):
        var x := 170.0 + float(index) * 390.0
        var sway := sin(_time * 0.18 + float(index) * 1.8) * 34.0
        var alpha := 0.026 + 0.010 * sin(_time * 0.55 + float(index))
        draw_polygon(
            PackedVector2Array([
                Vector2(x, 0.0),
                Vector2(x + 118.0, 0.0),
                Vector2(x + 262.0 + sway, view_size.y),
                Vector2(x + 30.0 + sway, view_size.y),
            ]),
            PackedColorArray([
                Color(0.82, 0.90, 0.84, alpha),
                Color(0.80, 0.88, 0.84, alpha * 0.6),
                Color(0.78, 0.86, 0.84, 0.0),
                Color(0.78, 0.86, 0.84, 0.0),
            ])
        )

func _draw_floor_runes(center: Vector2) -> void:
    # 法阵：8 条放射（对应八卦）替代原 12 条等分刻度，去掉「仪表盘刻度」观感。
    var slow := _time * 0.045
    var fast := -_time * 0.07
    var gold_faint := Color(GOLD.r, GOLD.g, GOLD.b, 0.038)
    var jade_faint := Color(JADE.r, JADE.g, JADE.b, 0.032)
    draw_arc(center, 302.0, slow, slow + TAU * 0.72, 64, gold_faint, 2.0, true)
    draw_arc(center, 296.0, slow + PI, slow + PI + TAU * 0.18, 24, gold_faint, 1.0, true)
    draw_arc(center, 268.0, fast, fast + TAU * 0.5, 64, jade_faint, 1.5, true)
    for index in range(8):
        var angle := slow * 1.6 + TAU * float(index) / 8.0
        var inner := center + Vector2.from_angle(angle) * 304.0
        var outer := center + Vector2.from_angle(angle) * 314.0
        draw_line(inner, outer, Color(GOLD.r, GOLD.g, GOLD.b, 0.052), 1.0, true)
    for index in range(4):
        var diamond_angle := fast * 2.0 + TAU * float(index) / 4.0
        var at := center + Vector2.from_angle(diamond_angle) * 302.0
        var size := 5.0
        draw_colored_polygon(
            PackedVector2Array([at + Vector2(0.0, -size), at + Vector2(size, 0.0), at + Vector2(0.0, size), at + Vector2(-size, 0.0)]),
            Color(GOLD.r, GOLD.g, GOLD.b, 0.052)
        )

func _draw_embers(view_size: Vector2) -> void:
    var ember: Color = EMBERS[chapter - 1]
    for index in range(EMBER_COUNT):
        var phase := float(index) * 2.399
        var drift := fposmod(_time * (14.0 + float(index % 5) * 6.0) + float(index) * 47.0, view_size.y + 40.0)
        var x := fposmod(sin(phase) * 620.0 + 640.0 + sin(_time * 0.6 + phase) * 24.0, view_size.x)
        var y := view_size.y + 20.0 - drift
        var alpha := 0.12 + 0.22 * (0.5 + 0.5 * sin(_time * 2.0 + phase))
        var size := 1.6 + float(index % 3) * 0.7
        draw_circle(Vector2(x, y), size * 2.4, Color(ember.r, ember.g, ember.b, alpha * 0.18))
        draw_circle(Vector2(x, y), size, Color(ember.r, ember.g, ember.b, alpha))

func _draw_dust(view_size: Vector2) -> void:
    for index in range(DUST_COUNT):
        var phase := float(index) * 1.7
        var x := fposmod(float(index) * 79.0 + _time * (7.0 + float(index % 4) * 4.0) + sin(phase) * 40.0, view_size.x)
        var y := fposmod(float(index) * 53.0 + sin(_time * 0.5 + phase) * 28.0, view_size.y)
        var alpha := 0.030 + 0.030 * (0.5 + 0.5 * sin(_time * 1.3 + phase))
        draw_circle(Vector2(x, y), 1.0 + float(index % 2) * 0.6, Color(0.82, 0.86, 0.78, alpha))
