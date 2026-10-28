extends "res://scripts/enemy_base.gd"

func _ready() -> void:
    super._ready()
    damage_number_color = Color("#fef3c7")
    health_bar_color = Color("#fca5a5")
    death_color = Color("#f87171")

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
    queue_redraw()

func _draw() -> void:
    var body_color := Color("#f87171")
    if damage_flash > 0.0:
        body_color = Color.WHITE

    draw_set_transform(Vector2(0.0, 16.0), 0.0, Vector2(1.0, 0.4))
    draw_circle(Vector2.ZERO, 18.0, Color(0.0, 0.0, 0.0, 0.28))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    var step := sin(anim_time * 9.0) * 4.0
    draw_line(Vector2(-9.0, 8.0), Vector2(-15.0 + step, 20.0), Color("#8f3a36"), 2.5, true)
    draw_line(Vector2(9.0, 8.0), Vector2(15.0 - step, 20.0), Color("#8f3a36"), 2.5, true)
    draw_line(Vector2(-6.0, 4.0), Vector2(-11.0 - step, 15.0), Color("#6f2a28"), 2.0, true)
    draw_line(Vector2(6.0, 4.0), Vector2(11.0 + step, 15.0), Color("#6f2a28"), 2.0, true)

    _draw_gear(Vector2.ZERO, 17.0, 8, Color(0.72, 0.30, 0.27, 0.9), anim_time * 1.5)
    draw_circle(Vector2.ZERO, 12.5, body_color)
    draw_circle(Vector2.ZERO, 8.0, Color("#7f1d1d"))
    draw_circle(Vector2(0.0, -2.0), 3.2, Color("#fecaca"))
    draw_circle(Vector2(0.0, -2.0), 1.4, Color("#450a0a"))
    if elite:
        draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 40, Color("#fbbf24"), 2.5, true)
    _draw_status_marks()
    _draw_health_bar()
