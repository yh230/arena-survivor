extends Control

const UI := preload("res://scripts/ui_forge.gd")
const RESPONSE_CURVE := 0.72
const RESPONSE_GAIN := 1.18
const EDGE_MARGIN := 16.0

@export var base_radius := 90.0
@export var knob_radius := 38.0
@export var dead_zone := 0.06
@export var anchor_center := Vector2(142.0, 578.0)

var _vector := Vector2.ZERO
var _active := false
var _touch_index := -1
var _center := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _center = anchor_center
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed and not _active:
        _activate(event.index, event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _active:
        _activate(-1, event.position)
        accept_event()

func _input(event: InputEvent) -> void:
    if not _active:
        return

    if event is InputEventScreenDrag and event.index == _touch_index:
        _update_from_position(_to_local(event.position))
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
        _release()
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and _touch_index == -1:
        _update_from_position(_to_local(event.position))
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _touch_index == -1:
        _release()
        get_viewport().set_input_as_handled()

func _activate(index: int, local_position: Vector2) -> void:
    _active = true
    _touch_index = index
    _center = _clamp_center(local_position)
    _update_from_position(local_position)
    queue_redraw()

func _clamp_center(local_position: Vector2) -> Vector2:
    var view_size := get_viewport_rect().size
    var margin := base_radius + EDGE_MARGIN
    return Vector2(
        clampf(local_position.x, margin, view_size.x - margin),
        clampf(local_position.y, margin, view_size.y - margin)
    )

func _to_local(viewport_position: Vector2) -> Vector2:
    return get_global_transform_with_canvas().affine_inverse() * viewport_position

func _update_from_position(local_position: Vector2) -> void:
    _vector = _vector_for_offset(local_position - _center)
    queue_redraw()

func _vector_for_offset(offset: Vector2) -> Vector2:
    var length := offset.length()
    if length < 1.0:
        return Vector2.ZERO
    if length > base_radius:
        offset = offset.normalized() * base_radius
        length = base_radius
    var travel := length / base_radius
    if travel <= dead_zone:
        return Vector2.ZERO
    var magnitude := (travel - dead_zone) / (1.0 - dead_zone)
    magnitude = clampf(pow(magnitude, RESPONSE_CURVE) * RESPONSE_GAIN, 0.0, 1.0)
    return offset.normalized() * magnitude

func _release() -> void:
    _active = false
    _touch_index = -1
    _vector = Vector2.ZERO
    _center = anchor_center
    queue_redraw()

func get_vector() -> Vector2:
    return _vector

func set_test_vector(value: Vector2) -> void:
    _vector = value.limit_length(1.0)
    queue_redraw()

func release() -> void:
    _release()

func _draw() -> void:
    var center := _center if _active else anchor_center
    var alpha := 0.92 if _active else 0.62
    draw_circle(center, base_radius, Color(0.035, 0.085, 0.095, alpha * 0.82))
    draw_arc(center, base_radius, 0.0, TAU, 64, Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.5 + alpha * 0.35), 1.5, true)
    draw_arc(center, base_radius - 7.0, 0.0, TAU, 64, Color(0.20, 0.32, 0.30, 0.42), 1.0, true)
    for index in range(12):
        var angle := TAU * float(index) / 12.0
        var inner := center + Vector2.from_angle(angle) * (base_radius - 5.0)
        var outer := center + Vector2.from_angle(angle) * (base_radius - 12.0)
        draw_line(inner, outer, Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.22 + alpha * 0.22), 1.0, true)

    var knob_position := center + _vector * base_radius
    var knob_size := knob_radius * (1.06 if _active else 1.0)
    draw_circle(knob_position, knob_size + 3.0, Color(0.0, 0.0, 0.0, 0.28))
    draw_circle(knob_position, knob_size, Color(0.14, 0.34, 0.28, 0.92))
    draw_circle(knob_position, knob_size * 0.72, Color(0.35, 0.62, 0.48, 0.95))
    draw_circle(knob_position, knob_size * 0.34, Color(0.86, 0.94, 0.82, 0.92))
    draw_arc(knob_position, knob_size, 0.0, TAU, 48, Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.65), 1.2, true)
    draw_string(
        UI.regular_font(),
        Vector2(center.x - base_radius, center.y + base_radius + 20.0),
        "移动",
        HORIZONTAL_ALIGNMENT_CENTER,
        base_radius * 2.0,
        10,
        Color(0.58, 0.64, 0.60, 0.75)
    )
