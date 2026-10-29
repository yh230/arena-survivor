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
    _glow = ArtFX.add_glow(self, Color(0.38, 0.76, 0.60), 34.0, 0.32, -1)

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
        ArtFX.trail_at(get_parent(), global_position, Color(0.38, 0.76, 0.60), 12.0, 0.2)
    if _time >= fuse:
        _explode()
    queue_redraw()

func _explode() -> void:
    var center := global_position
    var hit_count := 0
    for node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            continue
        if center.distance_to(node.global_position) > radius:
            continue
        if node.has_method("take_damage"):
            node.take_damage(damage)
            hit_count += 1
            var scene := get_tree().current_scene
            if scene != null and scene.has_method("_record_skill_damage"):
                scene._record_skill_damage(damage)
        if node.has_method("apply_slow"):
            node.apply_slow(slow_duration, slow_factor)
        if node.has_method("apply_knockback") and knockback > 0.0:
            node.apply_knockback(node.global_position - center, knockback)

    Fx.ring(center, Color(0.33, 0.72, 0.55), radius, 0.42, 4.0)
    Fx.ring(center, Color(0.95, 0.78, 0.38), radius * 1.22, 0.52, 2.0)
    Fx.shock(center, Color(0.42, 0.76, 0.60), radius * 0.95, 0.5)
    Fx.sparks(center, Color(0.44, 0.78, 0.62), 14, 320.0, 0.46)
    Fx.burst(center, Color(0.38, 0.76, 0.60), 20)
    for index in range(5):
        var bolt_angle := TAU * float(index) / 5.0 + randf_range(-0.2, 0.2)
        var bolt_end := center + Vector2.from_angle(bolt_angle) * radius * randf_range(0.72, 1.05)
        var bolt_path := PackedVector2Array([center])
        for segment in range(1, 4):
            var point := center.lerp(bolt_end, float(segment) / 3.0)
            if segment < 3:
                point += Vector2.from_angle(bolt_angle + PI * 0.5) * randf_range(-24.0, 24.0) * (1.0 - float(segment) * 0.2)
            bolt_path.append(point)
        Fx.bolt(bolt_path, Color(0.46, 0.78, 0.66), 0.26, 2.2)
    ArtFX.flash_at(get_tree().current_scene, center, Color(0.36, 0.74, 0.58), radius * 0.55, 0.28)
    Fx.shake(8.0, 0.22)
    Audio.play("explode", -6.0)
    # 时间维度：整屏顿一下（45ms，内部自带预算与嵌套保护）。
    Hitstop.request("grenade_blast")
    _layer_blast(center, hit_count)
    queue_free()

## 命中人数越多，视觉上多一层"更慢、更大"的外环 + 一次极轻的推镜，
## 让多杀和单杀在时间/尺度的读感上区分开，而不是只靠粒子数量。
func _layer_blast(center: Vector2, hit_count: int) -> void:
    var min_hits := int(Hitstop.feel("blast", "layer_min_hits", 3))
    if hit_count < min_hits:
        return
    var ring_scale := float(Hitstop.feel("blast", "layer_ring_scale", 1.35))
    var ring_life := float(Hitstop.feel("blast", "layer_ring_life", 0.95))
    var ring_width := float(Hitstop.feel("blast", "layer_ring_width", 1.6))
    Fx.ring(center, Color(0.62, 0.94, 0.80, 0.55), radius * ring_scale, ring_life, ring_width)
    var scene := get_tree().current_scene
    if scene != null and scene.has_method("pulse_camera_zoom"):
        var amount := float(Hitstop.feel("blast", "zoom_pulse", 0.02))
        var duration := float(Hitstop.feel("blast", "zoom_pulse_ms", 120.0)) / 1000.0
        scene.pulse_camera_zoom(amount, duration)

func _draw() -> void:
    var progress := clampf(_time / fuse, 0.0, 1.0)
    var target_local := to_local(target)
    draw_arc(target_local, radius, 0.0, TAU, 64, Color(0.38, 0.76, 0.60, 0.16), 2.0, true)
    for index in range(8):
        var tick_angle := TAU * float(index) / 8.0
        draw_line(
            target_local + Vector2.from_angle(tick_angle) * (radius - 7.0),
            target_local + Vector2.from_angle(tick_angle) * radius,
            Color(0.38, 0.76, 0.60, 0.34), 2.0, true
        )
    draw_arc(target_local, radius * maxf(0.02, progress), -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(0.44, 0.78, 0.64, 0.55), 2.5, true)

    if _direction.length_squared() > 0.01:
        for index in range(4):
            draw_circle(-_direction * (9.0 + float(index) * 6.5), 6.0 - float(index) * 1.1, Color(0.38, 0.76, 0.60, 0.24 - float(index) * 0.05))

    var spin := _time * 9.0
    draw_circle(Vector2.ZERO, 11.0, Color(0.055, 0.118, 0.110, 0.95))
    draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 28, Color(0.788, 0.635, 0.153, 0.85), 2.0, true)
    draw_circle(Vector2.ZERO, 7.5, Color(0.12, 0.5, 0.46, 1.0))
    draw_circle(Vector2.ZERO, 4.5, Color(0.48, 0.88, 0.76))
    draw_circle(Vector2.ZERO, 2.0, Color(0.92, 1.0, 0.98))
    for index in range(3):
        var spark_angle := spin + TAU * float(index) / 3.0
        draw_line(Vector2.from_angle(spark_angle) * 13.0, Vector2.from_angle(spark_angle) * 17.0, Color(0.62, 0.92, 0.80, 0.7), 1.5, true)
    draw_arc(Vector2.ZERO, 15.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, Color(0.788, 0.635, 0.153, 0.55), 1.5, true)
