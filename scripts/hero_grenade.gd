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

func setup(target_pos: Vector2, amount: int, blast_radius: float, slow_time: float, slow_amount: float, push_distance: float, fuse_time: float) -> void:
    target = target_pos
    damage = amount
    radius = blast_radius
    slow_duration = slow_time
    slow_factor = 1.0 - clampf(slow_amount, 0.0, 0.9)
    knockback = push_distance
    fuse = maxf(0.05, fuse_time)
    _start = global_position
    queue_redraw()

func _process(delta: float) -> void:
    _time += delta
    var progress := clampf(_time / fuse, 0.0, 1.0)
    global_position = _start.lerp(target, progress) + Vector2(0.0, -sin(progress * PI) * 40.0)
    if _time >= fuse:
        _explode()
    queue_redraw()

func _explode() -> void:
    for node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            continue
        if global_position.distance_to(node.global_position) > radius:
            continue
        if node.has_method("take_damage"):
            node.take_damage(damage)
        if node.has_method("apply_slow"):
            node.apply_slow(slow_duration, slow_factor)
        if node.has_method("apply_knockback") and knockback > 0.0:
            node.apply_knockback(node.global_position - global_position, knockback)
    ArtFX.flash_at(get_tree().current_scene, global_position, Color(0.35, 1.0, 0.85), radius * 1.2, 0.35)
    Fx.burst(global_position, Color(0.35, 1.0, 0.85), 18)
    Fx.shake(7.0, 0.18)
    Audio.play("explode", -8.0)
    queue_free()

func _draw() -> void:
    var progress := clampf(_time / fuse, 0.0, 1.0)
    draw_circle(Vector2.ZERO, 9.0, Color(0.04, 0.18, 0.18, 0.95))
    draw_circle(Vector2.ZERO, 5.0, Color(0.35, 1.0, 0.85))
    draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, Color(0.85, 0.71, 0.42, 0.8), 1.5, true)
    draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 48, Color(0.35, 1.0, 0.85, 0.22), 1.0, true)
