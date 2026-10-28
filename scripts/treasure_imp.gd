extends "res://scripts/enemy_base.gd"

@export var lifetime := 20.0

var wander_direction := Vector2.RIGHT
var wander_timer := 0.0
var pulse := 0.0

func _ready() -> void:
    super._ready()
    add_to_group("treasure")
    coin_drop = 6
    contact_range = 0.0
    damage_number_color = Color("#fde68a")
    health_bar_color = Color("#fde68a")
    death_color = Color("#fbbf24")
    death_burst = 18
    die_sound_db = -6.0
    wander_direction = Vector2.from_angle(randf_range(0.0, TAU))
    wander_timer = randf_range(0.4, 1.0)

func _physics_process(delta: float) -> void:
    if not active:
        return

    _tick_status(delta)
    lifetime -= delta
    if lifetime <= 0.0:
        _escape()
        return

    pulse += delta
    wander_timer -= delta
    if wander_timer <= 0.0:
        wander_timer = randf_range(0.5, 1.2)
        wander_direction = Vector2.from_angle(randf_range(0.0, TAU))

    if player != null and is_instance_valid(player):
        var away: Vector2 = global_position - player.global_position
        if away.length() < 220.0 and away.length() > 1.0:
            wander_direction = away.normalized()

    if is_stunned():
        velocity = Vector2.ZERO
        move_and_slide()
    else:
        velocity = wander_direction * move_speed * speed_multiplier()
        move_and_slide()
        _clamp_to_arena()
    queue_redraw()

func _clamp_to_arena() -> void:
    var view_size := get_viewport_rect().size
    var margin := 50.0
    global_position.x = clampf(global_position.x, margin, view_size.x - margin)
    global_position.y = clampf(global_position.y, margin, view_size.y - margin)

func _escape() -> void:
    active = false
    Fx.burst(global_position, Color(1.0, 0.85, 0.3, 0.6), 6)
    queue_free()

func _draw() -> void:
    var body := Color("#fbbf24")
    if damage_flash > 0.0:
        body = Color.WHITE

    var bob := sin(pulse * 3.0) * 2.0
    draw_set_transform(Vector2(0.0, 20.0), 0.0, Vector2(1.0, 0.4))
    draw_circle(Vector2.ZERO, 18.0, Color(0.0, 0.0, 0.0, 0.25))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    var aura := 0.5 + 0.5 * sin(pulse * 4.0)
    draw_circle(Vector2(0.0, bob), 24.0 + aura * 3.0, Color(1.0, 0.85, 0.3, 0.10 + aura * 0.06))
    draw_arc(Vector2(0.0, bob), 24.0 + aura * 3.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.3, 0.35 + aura * 0.3), 2.0, true)

    var flap := sin(pulse * 9.0) * 4.0
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(-12.0, bob),
            Vector2(-27.0, bob - 10.0 - flap),
            Vector2(-22.0, bob + 4.0),
        ]),
        Color(1.0, 0.92, 0.55, 0.55)
    )
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(12.0, bob),
            Vector2(27.0, bob - 10.0 - flap),
            Vector2(22.0, bob + 4.0),
        ]),
        Color(1.0, 0.92, 0.55, 0.55)
    )

    draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
    _draw_gear(Vector2.ZERO, 17.0, 8, Color(0.85, 0.68, 0.25, 0.8), anim_time * 0.8)
    draw_circle(Vector2.ZERO, 14.0, body)
    draw_circle(Vector2.ZERO, 9.0, Color("#fef3c7"))
    draw_circle(Vector2(-5.0, -3.0), 2.5, Color("#78350f"))
    draw_circle(Vector2(5.0, -3.0), 2.5, Color("#78350f"))
    draw_line(Vector2(0.0, -14.0), Vector2(0.0, -20.0), Color("#d8b56b"), 2.0, true)
    draw_circle(Vector2(0.0, -21.0), 2.5, Color("#f1d99b"))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    _draw_status_marks()
    _draw_health_bar(36.0, -32.0)
