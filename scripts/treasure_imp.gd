extends CharacterBody2D

signal died(drop_position: Vector2, coin_count: int)

@export var max_health := 50
@export var move_speed := 85.0
@export var lifetime := 20.0

var health := 50
var player = null
var wander_direction := Vector2.RIGHT
var wander_timer := 0.0
var damage_flash := 0.0
var pulse := 0.0
var active := true

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    add_to_group("treasure")
    player = get_tree().get_first_node_in_group("player")
    wander_direction = Vector2.from_angle(randf_range(0.0, TAU))
    wander_timer = randf_range(0.4, 1.0)
    queue_redraw()

func _physics_process(delta: float) -> void:
    if not active:
        return

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

    velocity = wander_direction * move_speed
    move_and_slide()
    _clamp_to_arena()
    damage_flash = maxf(0.0, damage_flash - delta)
    queue_redraw()

func _clamp_to_arena() -> void:
    var view_size := get_viewport_rect().size
    var margin := 50.0
    global_position.x = clampf(global_position.x, margin, view_size.x - margin)
    global_position.y = clampf(global_position.y, margin, view_size.y - margin)

func take_damage(amount: int) -> void:
    if not active:
        return
    health -= amount
    damage_flash = 0.12
    Audio.play("hit", -14.0)
    Fx.damage_number(global_position + Vector2(0.0, -30.0), amount, Color("#fde68a"))
    queue_redraw()
    if health <= 0:
        active = false
        Audio.play("enemy_die", -6.0)
        Fx.burst(global_position, Color("#fbbf24"), 18)
        died.emit(global_position, 6)
        queue_free()

func _escape() -> void:
    active = false
    Fx.burst(global_position, Color(1.0, 0.85, 0.3, 0.6), 6)
    queue_free()

func _draw() -> void:
    var body := Color("#fbbf24")
    if damage_flash > 0.0:
        body = Color.WHITE

    draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.14, 0.02, 0.55))
    draw_circle(Vector2.ZERO, 15.0, body)
    draw_circle(Vector2.ZERO, 9.0, Color("#fef3c7"))
    draw_circle(Vector2(-5.0, -3.0), 2.5, Color("#78350f"))
    draw_circle(Vector2(5.0, -3.0), 2.5, Color("#78350f"))
    var aura := 0.5 + 0.5 * sin(pulse * 4.0)
    draw_arc(Vector2.ZERO, 24.0 + aura * 3.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.3, 0.35 + aura * 0.3), 2.0, true)

    var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
    draw_rect(Rect2(-18.0, -32.0, 36.0, 4.0), Color(0.0, 0.0, 0.0, 0.6))
    draw_rect(Rect2(-18.0, -32.0, 36.0 * ratio, 4.0), Color("#fde68a"))
