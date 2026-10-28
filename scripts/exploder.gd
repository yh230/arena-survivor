extends "res://scripts/enemy_base.gd"

@export var explosion_damage := 24
@export var explosion_radius := 95.0
@export var trigger_range := 90.0
@export var fuse_time := 0.85

var fuse_timer := -1.0
var exploding := false
var explosion_timer := 0.0

func _ready() -> void:
    super._ready()
    coin_drop = 2
    contact_range = 0.0
    damage_number_color = Color("#fed7aa")
    health_bar_color = Color("#fdba74")
    death_color = Color("#fb923c")
    death_burst = 10

func _physics_process(delta: float) -> void:
    _tick_status(delta)
    if not active:
        return

    if exploding:
        explosion_timer -= delta
        if explosion_timer <= 0.0:
            queue_free()
        queue_redraw()
        return

    if player == null or not is_instance_valid(player) or player.is_dead:
        return

    if is_stunned():
        velocity = Vector2.ZERO
        move_and_slide()
        queue_redraw()
        return

    if fuse_timer >= 0.0:
        fuse_timer -= delta
        velocity = Vector2.ZERO
        if fuse_timer <= 0.0:
            _explode()
    else:
        var offset: Vector2 = player.global_position - global_position
        if offset.length() > trigger_range:
            velocity = offset.normalized() * move_speed * speed_multiplier()
            move_and_slide()
        else:
            fuse_timer = fuse_time
            velocity = Vector2.ZERO

    queue_redraw()

func take_damage(amount: int, is_crit := false) -> void:
    if exploding or not active:
        return
    super.take_damage(amount, is_crit)

func _explode() -> void:
    exploding = true
    if player != null and is_instance_valid(player):
        if global_position.distance_to(player.global_position) <= explosion_radius:
            if player.has_method("take_damage"):
                player.take_damage(explosion_damage)
    Audio.play("explode", -4.0)
    Fx.burst(global_position, Color("#fb923c"), 14)
    Fx.shake(10.0, 0.22)
    died.emit(global_position, coin_drop)
    explosion_timer = 0.3
    queue_redraw()

func _draw() -> void:
    if exploding:
        var alpha: float = clampf(explosion_timer / 0.3, 0.0, 1.0)
        draw_circle(Vector2.ZERO, explosion_radius, Color(1.0, 0.30, 0.05, 0.22 * alpha))
        draw_arc(Vector2.ZERO, explosion_radius, 0.0, TAU, 64, Color(1.0, 0.45, 0.1, 0.8 * alpha), 4.0, true)
        return

    var body_color := Color("#f97316")
    if damage_flash > 0.0:
        body_color = Color.WHITE

    draw_set_transform(Vector2(0.0, 16.0), 0.0, Vector2(1.0, 0.4))
    draw_circle(Vector2.ZERO, 18.0, Color(0.0, 0.0, 0.0, 0.28))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    var pulse := 0.5 + 0.5 * sin(anim_time * (8.0 if fuse_timer >= 0.0 else 3.0))
    draw_circle(Vector2.ZERO, 22.0 + pulse * 2.0, Color(1.0, 0.35, 0.08, 0.10 + pulse * 0.08))
    _draw_gear(Vector2.ZERO, 18.0, 8, Color(0.72, 0.38, 0.16, 0.8), -anim_time * 1.2)
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -17.0),
            Vector2(15.0, -5.0),
            Vector2(12.0, 13.0),
            Vector2(-12.0, 13.0),
            Vector2(-15.0, -5.0),
        ]),
        body_color
    )
    draw_circle(Vector2.ZERO, 8.0, Color("#7c2d12"))
    draw_circle(Vector2.ZERO, 4.0, Color("#fde68a"))

    var spark := Vector2(9.0, -22.0) + Vector2(sin(anim_time * 12.0) * 2.0, cos(anim_time * 9.0) * 2.0)
    draw_line(Vector2(5.0, -14.0), spark, Color("#92400e"), 2.0, true)
    draw_circle(spark, 3.0 + pulse * 1.5, Color(1.0, 0.85, 0.25, 0.85))

    if fuse_timer >= 0.0:
        var progress: float = 1.0 - clampf(fuse_timer / fuse_time, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 24.0 + progress * 10.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.1, 0.9), 3.0, true)

    _draw_status_marks()
    _draw_health_bar(36.0, -34.0)
