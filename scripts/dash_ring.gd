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
    var now := float(Time.get_ticks_msec()) * 0.001
    draw_circle(center, radius, Color(0.03, 0.07, 0.08, 0.94))
    draw_circle(center, radius - 9.0, Color(0.05, 0.11, 0.12, 0.82))
    draw_arc(center, radius, 0.0, TAU, 64, Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.58), 1.5, true)
    draw_arc(center, radius - 9.0, 0.0, TAU, 64, Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.18), 1.0, true)
    for index in range(12):
        var angle := TAU * float(index) / 12.0 + now * 0.08
        var inner := center + Vector2.from_angle(angle) * (radius - 10.0)
        var outer := center + Vector2.from_angle(angle) * (radius - 4.0)
        draw_line(inner, outer, Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.3), 1.0, true)
    if ratio > 0.001:
        draw_arc(center, radius - 2.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, Color(UI.TEAL.r, UI.TEAL.g, UI.TEAL.b, 0.2), 9.0, true)
        draw_arc(center, radius - 2.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, UI.TEAL, 5.0, true)
    if ratio >= 0.999:
        var pulse := 0.5 + 0.5 * sin(now * 3.2)
        draw_arc(center, radius - 6.0, 0.0, TAU, 64, Color(UI.TEAL.r, UI.TEAL.g, UI.TEAL.b, 0.12 + 0.14 * pulse), 2.0, true)
        draw_circle(center, 4.0, Color(UI.TEAL.r, UI.TEAL.g, UI.TEAL.b, 0.3 + 0.2 * pulse))
