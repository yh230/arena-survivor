extends CharacterBody2D

@export var max_health := 30
@export var move_speed := 95.0
@export var contact_damage := 5
@export var contact_interval := 1.0
@export var contact_range := 32.0
@export var preferred_range := 300.0
@export var fire_interval := 2.4
@export var projectile_damage := 6
@export var projectile_scene: PackedScene

var health := 30
var player = null
var contact_cooldown := 0.0
var fire_cooldown := 1.0
var windup := 0.0
var active := true
var damage_flash := 0.0
var strafe_sign := 1.0
var shots_fired := 0

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")
    fire_cooldown = randf_range(0.6, 1.6)
    strafe_sign = 1.0 if randf() > 0.5 else -1.0
    queue_redraw()

func _physics_process(delta: float) -> void:
    if not active or player == null or not is_instance_valid(player):
        return
    if player.is_dead:
        return

    var offset: Vector2 = player.global_position - global_position
    var distance := offset.length()
    var direction := offset.normalized() if distance > 1.0 else Vector2.RIGHT

    if windup > 0.0:
        windup -= delta
        velocity = Vector2.ZERO
        if windup <= 0.0:
            _shoot(direction)
    else:
        var movement := Vector2.ZERO
        if distance > preferred_range + 50.0:
            movement = direction * move_speed
        elif distance < preferred_range - 60.0:
            movement = -direction * move_speed * 0.9
        else:
            movement = direction.orthogonal() * move_speed * 0.4 * strafe_sign
            movement += direction * (preferred_range - distance) * 0.5
        velocity = movement
        move_and_slide()

        fire_cooldown -= delta
        if fire_cooldown <= 0.0:
            fire_cooldown = fire_interval
            windup = 0.35

    contact_cooldown = maxf(0.0, contact_cooldown - delta)
    damage_flash = maxf(0.0, damage_flash - delta)
    if distance <= contact_range and contact_cooldown <= 0.0:
        if player.has_method("take_damage"):
            player.take_damage(contact_damage)
            contact_cooldown = contact_interval

    queue_redraw()

func _shoot(direction: Vector2) -> void:
    if projectile_scene == null:
        return
    var container = get_tree().get_first_node_in_group("projectile_container")
    if container == null:
        container = get_parent()
    var projectile = projectile_scene.instantiate()
    container.add_child(projectile)
    projectile.global_position = global_position + direction * 24.0
    projectile.direction = direction
    projectile.damage = projectile_damage
    shots_fired += 1
    Audio.play("enemy_shot", -22.0)

func take_damage(amount: int) -> void:
    if not active:
        return
    health -= amount
    damage_flash = 0.12
    Audio.play("hit", -16.0)
    Fx.damage_number(global_position + Vector2(0.0, -32.0), amount, Color("#e9d5ff"))
    queue_redraw()
    if health <= 0:
        Audio.play("enemy_die", -10.0)
        Fx.burst(global_position, Color("#c084fc"), 8)
        queue_free()

func stop() -> void:
    active = false
    velocity = Vector2.ZERO

func _draw() -> void:
    var body_color := Color("#a855f7")
    if damage_flash > 0.0:
        body_color = Color.WHITE

    var aim := Vector2.RIGHT
    if player != null and is_instance_valid(player):
        aim = (player.global_position - global_position).normalized()
    draw_line(Vector2.ZERO, aim * 25.0, Color("#e9d5ff"), 2.0, true)
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -16.0),
            Vector2(14.0, 0.0),
            Vector2(0.0, 16.0),
            Vector2(-14.0, 0.0),
        ]),
        body_color
    )
    draw_circle(Vector2.ZERO, 5.0, Color("#f5d0fe"))

    if windup > 0.0:
        draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.2, 0.9), 3.0, true)

    var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
    draw_rect(Rect2(-18.0, -30.0, 36.0, 5.0), Color(0.0, 0.0, 0.0, 0.65))
    draw_rect(Rect2(-18.0, -30.0, 36.0 * ratio, 5.0), Color("#e9d5ff"))
