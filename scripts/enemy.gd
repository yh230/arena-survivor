extends "res://scripts/enemy_base.gd"

var _was_status_visual := false

func _ready() -> void:
    super._ready()
    damage_number_color = Color("#fef3c7")
    health_bar_color = Color("#fca5a5")
    death_color = Color("#f87171")

func _art_texture_path() -> String:
    return "res://assets/sprites/chaser.png"

func _art_size() -> float:
    return 66.0

func _art_glow_color() -> Color:
    return Color(1.0, 0.45, 0.16)

func _art_glow_radius() -> float:
    return 40.0

func _art_glow_power() -> float:
    return 0.2

func _art_faces_target() -> bool:
    return true

func _art_bob_rate() -> float:
    return 9.0

func _physics_process(delta: float) -> void:
    _tick_status(delta)
    if not active or player == null or not is_instance_valid(player) or player.is_dead:
        return

    var offset: Vector2 = player.global_position - global_position
    if is_stunned():
        velocity = Vector2.ZERO
        move_and_slide()
    elif offset.length() > 1.0:
        velocity = offset.normalized() * move_speed * speed_multiplier()
        move_and_slide()
    else:
        velocity = Vector2.ZERO

    _try_contact_damage()
    # 性能：非精英、无状态效果时 _draw 内容（地面环 / 血条）完全静态，
    # 血量变化已由 enemy_base.take_damage() 内的 queue_redraw() 兜底。
    # 注意 status_visual 由真变假的那一帧也要重绘一次，否则减速/标记/眩晕弧会残留。
    var status_visual := elite or _mark_time > 0.0 or has_slow() or is_stunned()
    if status_visual or _was_status_visual:
        queue_redraw()
    _was_status_visual = status_visual

func _draw() -> void:
    if elite:
        var pulse := 0.6 + 0.4 * sin(anim_time * 4.0)
        draw_arc(Vector2.ZERO, status_radius + 1.0, 0.0, TAU, 40, Color(1.0, 0.82, 0.25, 0.5 + pulse * 0.25), 2.5, true)
        var spin := anim_time * 0.9
        for index in range(3):
            var start := spin + TAU * float(index) / 3.0
            draw_arc(Vector2.ZERO, status_radius + 7.0, start, start + 0.7, 12, Color(1.0, 0.85, 0.3, 0.5), 2.0, true)
        var crown_y := -status_radius - 16.0
        draw_colored_polygon(PackedVector2Array([
            Vector2(-8.0, crown_y), Vector2(-5.0, crown_y + 8.0), Vector2(0.0, crown_y + 3.0),
            Vector2(5.0, crown_y + 8.0), Vector2(8.0, crown_y),
        ]), Color(1.0, 0.8, 0.25, 0.9))
    _draw_status_marks()
    _draw_health_bar()
