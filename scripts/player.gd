extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

@export var move_speed := 340.0
@export var dash_speed := 900.0
@export var dash_duration := 0.14
@export var dash_cooldown := 2.5
@export var max_health := 100
@export var attack_interval := 0.40
@export var attack_range := 520.0
@export var projectile_damage := 10
@export var projectile_scene: PackedScene
const CRIT_CHANCE := 0.12
const CRIT_MULT := 1.8

var health := 100
var is_dead := false
var attack_cooldown := 0.0
var hit_flash := 0.0
var joystick = null
var facing := Vector2.UP
var projectile_count := 1
var lifesteal := 0
var dash_time := 0.0
var dash_cooldown_left := 0.0
var dash_direction := Vector2.UP
var _anim := 0.0
var _dust_timer := 0.0

func _ready() -> void:
    health = max_health
    add_to_group("player")
    queue_redraw()

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
    _anim += delta
    _dust_timer = maxf(0.0, _dust_timer - delta)
    if Input.is_key_pressed(KEY_SPACE):
        try_dash()

    if dash_time > 0.0:
        velocity = dash_direction * dash_speed
        move_and_slide()
        _clamp_to_arena()
        dash_time = maxf(0.0, dash_time - delta)
        facing = dash_direction
        if dash_time == 0.0:
            velocity = Vector2.ZERO
    else:
        var direction: Vector2 = _get_move_direction()
        velocity = direction * move_speed
        move_and_slide()
        _clamp_to_arena()
        if direction.length_squared() > 0.01:
            facing = direction.normalized()
            if _dust_timer <= 0.0:
                _dust_timer = 0.24
                Fx.burst(global_position - facing * 12.0 + Vector2(0.0, 16.0), Color(0.45, 0.68, 0.64, 0.35), 2)

    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    hit_flash = maxf(0.0, hit_flash - delta)
    if attack_cooldown <= 0.0:
        _try_auto_attack()

    queue_redraw()

func _get_move_direction() -> Vector2:
    if joystick == null:
        joystick = get_tree().get_first_node_in_group("virtual_joystick")

    var direction := Vector2.ZERO
    if joystick != null and joystick.has_method("get_vector"):
        direction = joystick.get_vector()

    if direction.length_squared() < 0.01:
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
            direction.x -= 1.0
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
            direction.x += 1.0
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
            direction.y -= 1.0
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
            direction.y += 1.0

    if direction.length_squared() > 1.0:
        direction = direction.normalized()
    return direction

func _clamp_to_arena() -> void:
    var view_size := get_viewport_rect().size
    var margin := 28.0
    global_position.x = clampf(global_position.x, margin, view_size.x - margin)
    global_position.y = clampf(global_position.y, margin, view_size.y - margin)

func _try_auto_attack() -> void:
    var target = _find_nearest_enemy()
    if target == null:
        return

    var distance: float = global_position.distance_to(target.global_position)
    if distance > attack_range or projectile_scene == null:
        return

    var base_direction: Vector2 = (target.global_position - global_position).normalized()
    var shots := maxi(1, projectile_count)
    var spread := deg_to_rad(6.0)
    for index in range(shots):
        var angle_offset := (float(index) - (float(shots) - 1.0) * 0.5) * spread
        var shot_direction := base_direction.rotated(angle_offset)
        var is_crit := randf() < CRIT_CHANCE
        var damage := int(round(float(projectile_damage) * (CRIT_MULT if is_crit else 1.0)))
        var projectile = projectile_scene.instantiate()
        get_parent().get_node("Projectiles").add_child(projectile)
        projectile.global_position = global_position + shot_direction * 24.0
        projectile.direction = shot_direction
        projectile.damage = damage
        projectile.crit = is_crit
        projectile.source = self
    Audio.play("shoot", -18.0)
    attack_cooldown = attack_interval

func _find_nearest_enemy():
    var nearest = null
    var best_distance := INF
    for node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(node):
            continue
        var distance: float = global_position.distance_squared_to(node.global_position)
        if distance < best_distance:
            best_distance = distance
            nearest = node
    return nearest

func take_damage(amount: int) -> void:
    if is_dead or dash_time > 0.0:
        return
    health = maxi(0, health - amount)
    hit_flash = 0.15
    Audio.play("hurt", -8.0)
    Fx.damage_number(global_position + Vector2(0.0, -30.0), amount, Color("#fca5a5"))
    Fx.shake(7.0, 0.16)
    health_changed.emit(health, max_health)
    if health <= 0:
        _die()

func _die() -> void:
    is_dead = true
    velocity = Vector2.ZERO
    queue_redraw()
    died.emit()

func try_dash() -> void:
    if is_dead or dash_cooldown_left > 0.0 or dash_time > 0.0:
        return
    var direction: Vector2 = _get_move_direction()
    if direction.length_squared() < 0.01:
        direction = facing
    if direction.length_squared() < 0.01:
        direction = Vector2.UP
    dash_direction = direction.normalized()
    facing = dash_direction
    dash_time = dash_duration
    dash_cooldown_left = dash_cooldown
    Audio.play("dash", -8.0)
    queue_redraw()

func can_dash() -> bool:
    return not is_dead and dash_time <= 0.0 and dash_cooldown_left <= 0.0

func get_dash_cooldown_remaining() -> float:
    return dash_cooldown_left

func can_apply_upgrade(id: String) -> bool:
    match id:
        "attack_speed":
            return attack_interval > 0.181
        "projectiles":
            return projectile_count < 4
        _:
            return true

func apply_upgrade(id: String) -> void:
    match id:
        "damage":
            projectile_damage += 5
        "attack_speed":
            attack_interval = maxf(0.18, attack_interval * 0.8)
        "move_speed":
            move_speed += 30.0
        "max_health":
            max_health += 25
            health += 25
            health_changed.emit(health, max_health)
        "projectiles":
            projectile_count = mini(4, projectile_count + 1)
        "lifesteal":
            lifesteal += 2

func on_projectile_hit() -> void:
    if is_dead or lifesteal <= 0:
        return
    var previous := health
    health = mini(max_health, health + lifesteal)
    if health != previous:
        health_changed.emit(health, max_health)

func _draw() -> void:
    if is_dead:
        draw_circle(Vector2(0.0, 14.0), 20.0, Color(0.0, 0.0, 0.0, 0.3))
        draw_circle(Vector2.ZERO, 20.0, Color(0.32, 0.36, 0.40, 0.9))
        return

    if dash_time > 0.0:
        for index in range(1, 5):
            var ghost := -dash_direction * float(index) * 14.0
            draw_circle(ghost, 19.0 - float(index) * 3.0, Color(0.20, 0.95, 0.85, 0.14))
        draw_circle(Vector2.ZERO, 30.0, Color(0.25, 1.0, 0.90, 0.22))

    draw_set_transform(Vector2(0.0, 17.0), 0.0, Vector2(1.0, 0.42))
    draw_circle(Vector2.ZERO, 21.0, Color(0.0, 0.0, 0.0, 0.30))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    var bob := sin(_anim * 3.4) * 1.4
    var spin := _anim * 0.8
    draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)

    var scarf_wave := sin(_anim * 6.0) * 3.0
    var back := -facing * 15.0
    draw_line(back, back - facing * 9.0 + Vector2(scarf_wave, 7.0), Color(0.16, 0.78, 0.71, 0.75), 5.0, true)
    draw_line(back - facing * 9.0, back - facing * 18.0 + Vector2(scarf_wave * 1.6, 11.0), Color(0.10, 0.55, 0.52, 0.65), 3.0, true)

    _draw_ring(Vector2.ZERO, 23.0, 10, Color("#d8b56b"), spin)
    draw_circle(Vector2.ZERO, 18.0, Color("#0a2224"))
    draw_arc(Vector2.ZERO, 17.0, spin + 0.4, spin + 2.4, 14, Color("#f1d99b"), 3.0, true)
    draw_arc(Vector2.ZERO, 13.5, spin + 3.4, spin + 5.0, 12, Color("#8a6a34"), 2.0, true)
    draw_circle(Vector2.ZERO, 11.0, Color("#0d9488"))
    draw_circle(Vector2.ZERO, 7.5, Color("#5eead4"))
    draw_circle(Vector2.ZERO, 3.6, Color("#ecfeff"))

    var blade_end := facing * 30.0
    draw_line(facing * 12.0, blade_end, Color("#14b8a6"), 5.0, true)
    draw_line(facing * 13.0, blade_end * 0.9, Color("#b9fff4"), 1.6, true)
    draw_circle(blade_end, 3.4, Color("#f1d99b"))

    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    if hit_flash > 0.0:
        draw_circle(Vector2.ZERO, 26.0, Color(1.0, 1.0, 1.0, 0.28))

func _draw_ring(center: Vector2, radius: float, teeth: int, color: Color, rotation: float) -> void:
    draw_arc(center, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.9), 2.0, true)
    for index in range(teeth):
        var angle := rotation + TAU * float(index) / float(teeth)
        var inner := center + Vector2.from_angle(angle) * (radius - 2.0)
        var outer := center + Vector2.from_angle(angle) * (radius + 4.0)
        draw_line(inner, outer, Color(color.r, color.g, color.b, 0.85), 3.0, true)
