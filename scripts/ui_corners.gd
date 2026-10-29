extends Control

## 中式回纹角饰（原为科技感直角 L 标）。
## 外层为主干折角，内层为缩进半格的副线，构成「回」字的层次，
## 替代原来的单线 L，去掉军事仪表盘观感。

@export var color := Color("#c9a227")
@export var length := 12.0
@export var width := 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _draw() -> void:
    var w := size.x
    var h := size.y
    var inner := Color(color.r, color.g, color.b, color.a * 0.5)
    var inset := length * 0.5
    var deep := length >= 9.0

    # 左上
    draw_polyline(PackedVector2Array([Vector2(0.0, length), Vector2(0.0, 0.0), Vector2(length, 0.0)]), color, width, true)
    if deep:
        draw_polyline(PackedVector2Array([Vector2(inset, length - 1.0), Vector2(inset, inset), Vector2(length - 1.0, inset)]), inner, width * 0.8, true)

    # 右上
    draw_polyline(PackedVector2Array([Vector2(w - length, 0.0), Vector2(w, 0.0), Vector2(w, length)]), color, width, true)
    if deep:
        draw_polyline(PackedVector2Array([Vector2(w - length + 1.0, inset), Vector2(w - inset, inset), Vector2(w - inset, length - 1.0)]), inner, width * 0.8, true)

    # 左下
    draw_polyline(PackedVector2Array([Vector2(0.0, h - length), Vector2(0.0, h), Vector2(length, h)]), color, width, true)
    if deep:
        draw_polyline(PackedVector2Array([Vector2(inset, h - length + 1.0), Vector2(inset, h - inset), Vector2(length - 1.0, h - inset)]), inner, width * 0.8, true)

    # 右下
    draw_polyline(PackedVector2Array([Vector2(w - length, h), Vector2(w, h), Vector2(w, h - length)]), color, width, true)
    if deep:
        draw_polyline(PackedVector2Array([Vector2(w - length + 1.0, h - inset), Vector2(w - inset, h - inset), Vector2(w - inset, h - length + 1.0)]), inner, width * 0.8, true)
