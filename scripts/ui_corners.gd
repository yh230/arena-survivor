extends Control

@export var color := Color("#d8b56b")
@export var length := 12.0
@export var width := 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _draw() -> void:
    var w := size.x
    var h := size.y
    draw_line(Vector2(0.0, 0.0), Vector2(length, 0.0), color, width, true)
    draw_line(Vector2(0.0, 0.0), Vector2(0.0, length), color, width, true)
    draw_line(Vector2(w - length, 0.0), Vector2(w, 0.0), color, width, true)
    draw_line(Vector2(w, 0.0), Vector2(w, length), color, width, true)
    draw_line(Vector2(0.0, h - length), Vector2(0.0, h), color, width, true)
    draw_line(Vector2(0.0, h), Vector2(length, h), color, width, true)
    draw_line(Vector2(w - length, h), Vector2(w, h), color, width, true)
    draw_line(Vector2(w, h - length), Vector2(w, h), color, width, true)
