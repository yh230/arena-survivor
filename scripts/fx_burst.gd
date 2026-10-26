extends Node2D

var _particles: Array = []
var _life := 0.45
var _color := Color.WHITE

func _ready() -> void:
    add_to_group("fx_burst")

func setup(position: Vector2, color: Color, count: int) -> void:
    global_position = position
    _color = color
    z_index = 50
    for _index in range(count):
        _particles.append({
            "offset": Vector2.ZERO,
            "velocity": Vector2.from_angle(randf() * TAU) * randf_range(80.0, 230.0),
            "size": randf_range(2.0, 5.0),
        })
    queue_redraw()

func _process(delta: float) -> void:
    _life -= delta
    for particle in _particles:
        particle["offset"] += particle["velocity"] * delta
        particle["velocity"] *= 0.92
    queue_redraw()
    if _life <= 0.0:
        queue_free()

func _draw() -> void:
    var alpha: float = clampf(_life / 0.45, 0.0, 1.0)
    for particle in _particles:
        draw_circle(
            particle["offset"],
            particle["size"],
            Color(_color.r, _color.g, _color.b, alpha)
        )
