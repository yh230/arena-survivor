extends CharacterBody2D

@export var max_health := 36
@export var move_speed := 75.0
@export var explosion_damage := 24
@export var explosion_radius := 95.0
@export var trigger_range := 90.0
@export var fuse_time := 0.85

var health := 36
var player = null
var active := true
var damage_flash := 0.0
var fuse_timer := -1.0
var exploding := false
var explosion_timer := 0.0

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")
    queue_redraw()

func _physics_process(delta: float) -> void:
    if not active:
        return

    if exploding:
        explosion_timer -= delta
        if explosion_timer <= 0.0:
            queue_free()
        queue_redraw()
        return

    if player == null or not is_instance_valid(player):
        return
    if player.is_dead:
        return

    if fuse_timer >= 0.0:
        fuse_timer -= delta
        velocity = Vector2.ZERO
        if fuse_timer <= 0.0:
            _explode()
    else:
        var offset: Vector2 = player.global_position - global_position
        if offset.length() > trigger_range:
            velocity = offset.normalized() * move_speed
            move_and_slide()
        else:
            fuse_timer = fuse_time
            velocity = Vector2.ZERO

    damage_flash = maxf(0.0, damage_flash - delta)
    queue_redraw()

func _explode() -> void:
    exploding = true
    if player != null and is_instance_valid(player):
        if global_position.distance_to(player.global_position) <= explosion_radius:
            if player.has_method("take_damage"):
                player.take_damage(explosion_damage)
    Audio.play("explode", -4.0)
    Fx.burst(global_position, Color("#fb923c"), 14)
    Fx.shake(10.0, 0.22)
    explosion_timer = 0.3
    queue_redraw()

func take_damage(amount: int) -> void:
    if exploding or not active:
        return
    health -= amount
    damage_flash = 0.12
    Audio.play("hit", -16.0)
    Fx.damage_number(global_position + Vector2(0.0, -36.0), amount, Color("#fed7aa"))
    queue_redraw()
    if health <= 0:
        Audio.play("enemy_die", -10.0)
        Fx.burst(global_position, Color("#fb923c"), 10)
        queue_free()

func stop() -> void:
    active = false
    velocity = Vector2.ZERO

func _draw() -> void:
    if exploding:
        var alpha: float = clampf(explosion_timer / 0.3, 0.0, 1.0)
        draw_circle(Vector2.ZERO, explosion_radius, Color(1.0, 0.30, 0.05, 0.22 * alpha))
        draw_arc(Vector2.ZERO, explosion_radius, 0.0, TAU, 64, Color(1.0, 0.45, 0.1, 0.8 * alpha), 4.0, true)
        return

    var body_color := Color("#f97316")
    if damage_flash > 0.0:
        body_color = Color.WHITE
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -18.0),
            Vector2(16.0, -5.0),
            Vector2(13.0, 14.0),
            Vector2(-13.0, 14.0),
            Vector2(-16.0, -5.0),
        ]),
        body_color
    )
    draw_circle(Vector2.ZERO, 7.0, Color("#7c2d12"))
    draw_circle(Vector2.ZERO, 3.0, Color("#fde68a"))

    if fuse_timer >= 0.0:
        var progress: float = 1.0 - clampf(fuse_timer / fuse_time, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 24.0 + progress * 10.0, 0.0, TAU, 32, Color(1.0, 0.2, 0.1, 0.9), 3.0, true)

    var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
    draw_rect(Rect2(-18.0, -34.0, 36.0, 5.0), Color(0.0, 0.0, 0.0, 0.65))
    draw_rect(Rect2(-18.0, -34.0, 36.0 * ratio, 5.0), Color("#fdba74"))
