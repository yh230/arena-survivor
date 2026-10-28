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

func _art_texture_path() -> String:
    return "res://assets/sprites/shooter.png"

func _art_size() -> float:
    return 74.0

func _art_glow_color() -> Color:
    return Color(0.78, 0.42, 1.0)

func _art_glow_radius() -> float:
    return 50.0

func _art_glow_power() -> float:
    return 0.18

func _art_turns_to_target() -> bool:
    return true

func _art_bob_rate() -> float:
    return 5.0

func _art_bob_size() -> float:
    return 1.2

func _art_glow_boost() -> float:
    if windup > 0.0:
        return 1.0 + (1.0 - clampf(windup / 0.35, 0.0, 1.0)) * 1.8
    return 1.0

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
    ArtFX.flash_at(get_tree().current_scene, global_position + direction * 30.0, Color(0.8, 0.45, 1.0), 26.0, 0.14)

func _draw() -> void:
    var aim := Vector2.RIGHT
    if _is_player_valid():
        aim = (player.global_position - global_position).normalized()

    if windup > 0.0:
        var charge := 1.0 - clampf(windup / 0.35, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.2, 0.45 + charge * 0.4), 2.5, true)
        draw_circle(aim * 30.0, 3.0 + charge * 3.5, Color(1.0, 0.9, 0.35, 0.85))
    _draw_status_marks()
    _draw_health_bar()
