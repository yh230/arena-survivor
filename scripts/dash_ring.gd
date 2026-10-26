extends Control

const UI := preload("res://scripts/ui_forge.gd")

var ratio := 1.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func set_ratio(value: float) -> void:
    ratio = clampf(value, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.5 - 3.0
    draw_circle(center, radius, Color(0.035, 0.08, 0.09, 0.92))
    draw_arc(center, radius, 0.0, TAU, 64, Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.55), 1.5, true)
    if ratio > 0.001:
        draw_arc(center, radius - 2.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, UI.TEAL, 5.0, true)
    draw_circle(center, maxf(0.0, radius - 8.0), Color(0.055, 0.12, 0.13, 0.78))
