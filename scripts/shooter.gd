extends "res://scripts/enemy_base.gd"

@export var preferred_range := 300.0
@export var fire_interval := 2.4
@export var projectile_damage := 6
@export var projectile_scene: PackedScene

var fire_cooldown := 1.0
var windup := 0.0
var strafe_sign := 1.0
var shots_fired := 0

func _ready() -> void:
    super._ready()
    fire_cooldown = randf_range(0.6, 1.6)
    strafe_sign = 1.0 if randf() > 0.5 else -1.0
    contact_range = 32.0
    damage_number_color = Color("#e9d5ff")
    health_bar_color = Color("#e9d5ff")
    death_color = Color("#c084fc")

func _physics_process(delta: float) -> void:
    _tick_status(delta)
    if not active or player == null or not is_instance_valid(player) or player.is_dead:
        return

    if is_stunned():
        windup = 0.0
        velocity = Vector2.ZERO
        move_and_slide()
        queue_redraw()
        return

    var offset: Vector2 = player.global_position - global_position
    var distance := offset.length()
    var direction := offset.normalized() if distance > 1.0 else Vector2.RIGHT
    var speed := move_speed * speed_multiplier()

    if windup > 0.0:
        windup -= delta
        velocity = Vector2.ZERO
        if windup <= 0.0:
            _shoot(direction)
    else:
        var movement := Vector2.ZERO
        if distance > preferred_range + 50.0:
            movement = direction * speed
        elif distance < preferred_range - 60.0:
            movement = -direction * speed * 0.9
        else:
            movement = direction.orthogonal() * speed * 0.4 * strafe_sign
            movement += direction * (preferred_range - distance) * 0.5
        velocity = movement
        move_and_slide()

        fire_cooldown -= delta
        if fire_cooldown <= 0.0:
            fire_cooldown = fire_interval
            windup = 0.35

    _try_contact_damage()
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

func _draw() -> void:
    var body_color := Color("#a855f7")
    if damage_flash > 0.0:
        body_color = Color.WHITE

    draw_set_transform(Vector2(0.0, 15.0), 0.0, Vector2(1.0, 0.4))
    draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.26))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    var aim := Vector2.RIGHT
    if player != null and is_instance_valid(player):
        aim = (player.global_position - global_position).normalized()
    var barrel := aim * (25.0 - windup * 8.0)
    draw_line(Vector2.ZERO, barrel, Color("#e9d5ff"), 4.0, true)
    draw_circle(barrel, 3.4, Color("#f5d0fe"))

    _draw_gear(Vector2.ZERO, 18.0, 10, Color(0.62, 0.38, 0.78, 0.85), anim_time * 0.9)
    draw_colored_polygon(
        PackedVector2Array([
            Vector2(0.0, -15.0),
            Vector2(13.0, 0.0),
            Vector2(0.0, 15.0),
            Vector2(-13.0, 0.0),
        ]),
        body_color
    )
    draw_circle(Vector2.ZERO, 6.0, Color("#f5d0fe"))
    draw_circle(Vector2.ZERO, 3.0, Color("#6b21a8"))

    if windup > 0.0:
        var charge := 1.0 - clampf(windup / 0.35, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 23.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.2, 0.9), 3.0, true)
        draw_circle(aim * 25.0, 4.0 * charge, Color(1.0, 0.9, 0.35, 0.85))
    _draw_status_marks()
    _draw_health_bar(36.0, -30.0)
