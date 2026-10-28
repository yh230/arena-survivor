extends Node2D

var target := Vector2.ZERO
var damage := 0
var radius := 110.0
var slow_duration := 1.5
var slow_factor := 0.65
var knockback := 60.0
var fuse := 0.6
var _start := Vector2.ZERO
var _time := 0.0
var _prev := Vector2.ZERO
var _direction := Vector2.ZERO
var _trail_timer := 0.0
var _glow: Sprite2D

func _ready() -> void:
    _glow = ArtFX.add_glow(self, Color(0.35, 1.0, 0.85), 34.0, 0.32, -1)

func setup(target_pos: Vector2, amount: int, blast_radius: float, slow_time: float, slow_amount: float, push_distance: float, fuse_time: float) -> void:
    target = target_pos
    damage = amount
    radius = blast_radius
    slow_duration = slow_time
    slow_factor = 1.0 - clampf(slow_amount, 0.0, 0.9)
    knockback = push_distance
    fuse = maxf(0.05, fuse_time)
    _start = global_position
    _prev = global_position
    queue_redraw()

func _process(delta: float) -> void:
    _time += delta
    var progress := clampf(_time / fuse, 0.0, 1.0)
    _prev = global_position
    global_position = _start.lerp(target, progress) + Vector2(0.0, -sin(progress * PI) * 46.0)
    _direction = (global_position - _prev).normalized()
    if _glow != null:
        _glow.modulate.a = 0.24 + 0.12 * sin(_time * 24.0)
    _trail_timer -= delta
    if _trail_timer <= 0.0 and _time < fuse:
        _trail_timer = 0.05
        ArtFX.trail_at(get_parent(), global_position, Color(0.35, 1.0, 0.85), 12.0, 0.2)
    if _time >= fuse:
        _explode()
    queue_redraw()

func _explode() -> void:
    var center := global_position
    for node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            continue
        if center.distance_to(node.global_position) > radius:
            continue
        if node.has_method("take_damage"):
            node.take_damage(damage)
        if node.has_method("apply_slow"):
            node.apply_slow(slow_duration, slow_factor)
        if node.has_method("apply_knockback") and knockback > 0.0:
            node.apply_knockback(node.global_position - center, knockback)

    Fx.ring(center, Color(0.25, 0.95, 0.75), radius, 0.42, 4.0)
    Fx.ring(center, Color(0.95, 0.78, 0.38), radius * 1.22, 0.52, 2.0)
    Fx.shock(center, Color(0.4, 1.0, 0.84), radius * 0.95, 0.5)
    Fx.sparks(center, Color(0.45, 1.0, 0.85), 14, 320.0, 0.46)
    Fx.burst(center, Color(0.35, 1.0, 0.85), 20)
    for index in range(5):
        var bolt_angle := TAU * float(index) / 5.0 + randf_range(-0.2, 0.2)
        var bolt_end := center + Vector2.from_angle(bolt_angle) * radius * randf_range(0.72, 1.05)
        var bolt_path := PackedVector2Array([center])
        for segment in range(1, 4):
            var point := center.lerp(bolt_end, float(segment) / 3.0)
            if segment < 3:
                point += Vector2.from_angle(bolt_angle + PI * 0.5) * randf_range(-24.0, 24.0) * (1.0 - float(segment) * 0.2)
            bolt_path.append(point)
        Fx.bolt(bolt_path, Color(0.5, 1.0, 0.9), 0.26, 2.2)
    ArtFX.flash_at(get_tree().current_scene, center, Color(0.28, 1.0, 0.82), radius * 0.55, 0.28)
    Fx.shake(8.0, 0.22)
    Audio.play("explode", -6.0)
    queue_free()

func _draw() -> void:
    var progress := clampf(_time / fuse, 0.0, 1.0)
    var target_local := to_local(target)
    draw_arc(target_local, radius, 0.0, TAU, 64, Color(0.3, 1.0, 0.85, 0.16), 2.0, true)
    for index in range(8):
        var tick_angle := TAU * float(index) / 8.0
        draw_line(
            target_local + Vector2.from_angle(tick_angle) * (radius - 7.0),
            target_local + Vector2.from_angle(tick_angle) * radius,
            Color(0.3, 1.0, 0.85, 0.34), 2.0, true
        )
    draw_arc(target_local, radius * maxf(0.02, progress), -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(0.45, 1.0, 0.88, 0.55), 2.5, true)

    if _direction.length_squared() > 0.01:
        for index in range(4):
            draw_circle(-_direction * (9.0 + float(index) * 6.5), 6.0 - float(index) * 1.1, Color(0.35, 1.0, 0.85, 0.24 - float(index) * 0.05))

    var spin := _time * 9.0
    draw_circle(Vector2.ZERO, 11.0, Color(0.03, 0.14, 0.14, 0.95))
    draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 28, Color(0.85, 0.71, 0.42, 0.85), 2.0, true)
    draw_circle(Vector2.ZERO, 7.5, Color(0.12, 0.5, 0.46, 1.0))
    draw_circle(Vector2.ZERO, 4.5, Color(0.4, 1.0, 0.9))
    draw_circle(Vector2.ZERO, 2.0, Color(0.92, 1.0, 0.98))
    for index in range(3):
        var spark_angle := spin + TAU * float(index) / 3.0
        draw_line(Vector2.from_angle(spark_angle) * 13.0, Vector2.from_angle(spark_angle) * 17.0, Color(0.45, 1.0, 0.9, 0.7), 1.5, true)
    draw_arc(Vector2.ZERO, 15.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color(0.85, 0.71, 0.42, 0.55), 1.5, true)
