extends Control

@export var segments := 10
@export var color := Color(0.02, 0.06, 0.07, 0.35)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _draw() -> void:
    for index in range(1, segments):
        var x := size.x * float(index) / float(segments)
        draw_line(Vector2(x, 1.0), Vector2(x, size.y - 1.0), color, 1.0)
