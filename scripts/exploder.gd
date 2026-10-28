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

func _art_texture_path() -> String:
    return "res://assets/sprites/exploder.png"

func _art_size() -> float:
    return 62.0

func _art_glow_color() -> Color:
    return Color(1.0, 0.5, 0.12)

func _art_glow_radius() -> float:
    return 40.0

func _art_glow_power() -> float:
    return 0.22

func _art_bob_rate() -> float:
    return 7.0

func _art_glow_boost() -> float:
    if fuse_timer >= 0.0:
        return 1.0 + (1.0 - clampf(fuse_timer / fuse_time, 0.0, 1.0)) * 1.4
    return 1.0

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
    Fx.burst(global_position, Color("#fb923c"), 16)
    Fx.ring(global_position, Color("#fb923c"), explosion_radius, 0.38, 5.0)
    Fx.shock(global_position, Color(1.0, 0.55, 0.15), explosion_radius, 0.4)
    Fx.sparks(global_position, Color(1.0, 0.6, 0.2), 10, 280.0, 0.34)
    ArtFX.flash_at(get_tree().current_scene, global_position, Color(1.0, 0.55, 0.15), 130.0, 0.38)
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

    var pulse := 0.5 + 0.5 * sin(anim_time * (8.0 if fuse_timer >= 0.0 else 3.0))
    if fuse_timer >= 0.0:
        var progress: float = 1.0 - clampf(fuse_timer / fuse_time, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 30.0 + progress * 12.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.1, 0.9), 3.0, true)
    else:
        draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 28, Color(1.0, 0.45, 0.1, 0.16 + pulse * 0.16), 1.5, true)

    _draw_status_marks()
    _draw_health_bar(42.0, -38.0)
