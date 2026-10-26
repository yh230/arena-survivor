extends Control

@export var base_radius := 100.0
@export var knob_radius := 42.0
@export var dead_zone := 0.12

var _vector := Vector2.ZERO
var _active := false
var _touch_index := -1
var _center := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    resized.connect(_refresh_center)
    _refresh_center()

func _refresh_center() -> void:
    _center = size * 0.5
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed and not _active:
        _active = true
        _touch_index = event.index
        _update_from_position(event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _active:
        _active = true
        _touch_index = -1
        _update_from_position(event.position)
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

func _to_local(viewport_position: Vector2) -> Vector2:
    return get_global_transform_with_canvas().affine_inverse() * viewport_position

func _update_from_position(local_position: Vector2) -> void:
    var offset := local_position - _center
    var length := offset.length()
    if length > base_radius:
        offset = offset.normalized() * base_radius

    _vector = offset / base_radius
    if _vector.length() < dead_zone:
        _vector = Vector2.ZERO
    queue_redraw()

func _release() -> void:
    _active = false
    _touch_index = -1
    _vector = Vector2.ZERO
    queue_redraw()

func get_vector() -> Vector2:
    return _vector

func set_test_vector(value: Vector2) -> void:
    _vector = value.limit_length(1.0)
    queue_redraw()

func release() -> void:
    _release()

func _draw() -> void:
    if _center == Vector2.ZERO:
        _center = size * 0.5

    draw_circle(_center, base_radius, Color(0.06, 0.16, 0.18, 0.65))
    draw_arc(_center, base_radius, 0.0, TAU, 64, Color(0.30, 0.90, 0.85, 0.55), 3.0, true)

    var knob_position := _center + _vector * base_radius
    draw_circle(knob_position, knob_radius, Color(0.12, 0.70, 0.65, 0.70))
    draw_circle(knob_position, knob_radius * 0.45, Color(0.85, 1.0, 1.0, 0.85))
