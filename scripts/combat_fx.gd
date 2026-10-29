extends Node2D

enum Kind { RING, SHOCK, SPARKS, SLASH, BOLT }

var kind := Kind.RING
var color := Color.WHITE
var radius := 40.0
var width := 3.0
var life := 0.3
var max_life := 0.3
var angle := 0.0
var arc_span := PI * 0.9
var points := PackedVector2Array()

var _sparks: Array = []

func _ready() -> void:
    z_index = 55
    material = ArtFX.additive_material()
    add_to_group("combat_fx")
    queue_redraw()

func setup_ring(pos: Vector2, col: Color, r: float, time := 0.28, w := 3.0) -> void:
    kind = Kind.RING
    global_position = pos
    color = col
    radius = maxf(1.0, r)
    life = maxf(0.05, time)
    max_life = life
    width = w
    queue_redraw()

func setup_shock(pos: Vector2, col: Color, r: float, time := 0.4) -> void:
    kind = Kind.SHOCK
    global_position = pos
    color = col
    radius = maxf(1.0, r)
    life = maxf(0.08, time)
    max_life = life
    width = 4.0
    _scatter(14, radius * 2.1)
    queue_redraw()

func setup_sparks(pos: Vector2, col: Color, count := 8, spread := 220.0, time := 0.32) -> void:
    kind = Kind.SPARKS
    global_position = pos
    color = col
    life = maxf(0.08, time)
    max_life = life
    radius = spread
    _scatter(count, spread)
    queue_redraw()

func setup_slash(pos: Vector2, facing_angle: float, col: Color, r := 42.0, time := 0.2, span := PI * 0.9) -> void:
    kind = Kind.SLASH
    global_position = pos
    color = col
    angle = facing_angle
    radius = maxf(8.0, r)
    arc_span = clampf(span, 0.3, TAU)
    life = maxf(0.05, time)
    max_life = life
    width = 4.0
    queue_redraw()

func setup_bolt(path: PackedVector2Array, col: Color, time := 0.2, w := 3.0) -> void:
    kind = Kind.BOLT
    points = path
    color = col
    life = maxf(0.05, time)
    max_life = life
    width = maxf(1.0, w)
    queue_redraw()

func _scatter(count: int, spread: float) -> void:
    # 修正：原实现从不清空 _sparks，只靠节点销毁兜底，一旦复用节点（对象池）粒子会跨次累积。
    _sparks.clear()
    for _index in range(maxi(0, count)):
        var direction := Vector2.from_angle(randf() * TAU)
        _sparks.append({
            "pos": direction * randf_range(2.0, 8.0),
            "vel": direction * randf_range(spread * 0.35, spread * 1.25),
            "size": randf_range(1.4, 3.4),
        })

func _process(delta: float) -> void:
    life -= delta
    for spark in _sparks:
        spark["pos"] += spark["vel"] * delta
        spark["vel"] *= 0.90
    queue_redraw()
    if life <= 0.0:
        queue_free()

func _draw() -> void:
    var t := clampf(1.0 - life / max_life, 0.0, 1.0)
    var fade := pow(1.0 - t, 1.35)
    match kind:
        Kind.RING:
            _draw_ring(t, fade)
        Kind.SHOCK:
            _draw_ring(t, fade)
            _draw_sparks(t, fade)
            draw_circle(Vector2.ZERO, radius * 0.42 * (1.0 - t), Color(color.r, color.g, color.b, 0.16 * fade))
        Kind.SPARKS:
            _draw_sparks(t, fade)
        Kind.SLASH:
            _draw_slash(t, fade)
        Kind.BOLT:
            _draw_bolt(fade)

func _draw_ring(t: float, fade: float) -> void:
    var eased := 1.0 - pow(1.0 - t, 2.0)
    var r := radius * (0.16 + 0.84 * eased)
    draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(color.r, color.g, color.b, color.a * fade), width, true)
    draw_arc(Vector2.ZERO, r * 0.68, 0.0, TAU, 40, Color(color.r, color.g, color.b, color.a * fade * 0.42), maxf(1.0, width * 0.45), true)

func _draw_sparks(t: float, fade: float) -> void:
    var alpha := pow(1.0 - t, 0.65)
    for spark in _sparks:
        var pos: Vector2 = spark["pos"]
        var vel: Vector2 = spark["vel"]
        var size: float = spark["size"]
        var trail := pos - vel * 0.035
        draw_line(trail, pos, Color(color.r, color.g, color.b, color.a * alpha * 0.5), maxf(1.0, size * 0.5), true)
        draw_circle(pos, size * (1.0 - t * 0.35), Color(color.r, color.g, color.b, color.a * alpha))

func _draw_slash(t: float, fade: float) -> void:
    var eased := 1.0 - pow(1.0 - t, 2.2)
    var r := radius * (0.7 + 0.3 * eased)
    var start := angle - arc_span * 0.5
    var end := angle + arc_span * 0.5
    draw_arc(Vector2.ZERO, r, start, end, 32, Color(color.r, color.g, color.b, color.a * fade * 0.32), width * 3.0, true)
    draw_arc(Vector2.ZERO, r, start, end, 32, Color(color.r, color.g, color.b, color.a * fade), width, true)
    var tip := Vector2.from_angle(end) * r
    draw_circle(tip, width * 1.6, Color(1.0, 1.0, 1.0, color.a * fade * 0.8))

func _draw_bolt(fade: float) -> void:
    if points.size() < 2:
        return
    draw_polyline(points, Color(color.r, color.g, color.b, color.a * 0.18 * fade), width * 3.2, true)
    draw_polyline(points, Color(color.r, color.g, color.b, color.a * fade), width, true)
    draw_polyline(points, Color(1.0, 1.0, 1.0, 0.55 * fade), maxf(1.0, width * 0.3), true)
