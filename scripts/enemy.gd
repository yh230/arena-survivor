extends "res://scripts/enemy_base.gd"

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
    queue_redraw()

func _draw() -> void:
    if elite:
        draw_arc(Vector2.ZERO, status_radius + 1.0, 0.0, TAU, 40, Color("#fbbf24"), 2.5, true)
    _draw_status_marks()
    _draw_health_bar()
