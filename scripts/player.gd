extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

@export var move_speed := 320.0
@export var max_health := 100
@export var attack_interval := 0.45
@export var attack_range := 520.0
@export var projectile_damage := 10
@export var projectile_scene: PackedScene

var health := 100
var is_dead := false
var attack_cooldown := 0.0
var hit_flash := 0.0
var joystick = null
var facing := Vector2.UP

func _ready() -> void:
    health = max_health
    add_to_group("player")
    queue_redraw()

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    var direction: Vector2 = _get_move_direction()
    velocity = direction * move_speed
    move_and_slide()
    _clamp_to_arena()

    if direction.length_squared() > 0.01:
        facing = direction.normalized()

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

    var direction: Vector2 = (target.global_position - global_position).normalized()
    var projectile = projectile_scene.instantiate()
    get_parent().get_node("Projectiles").add_child(projectile)
    projectile.global_position = global_position + direction * 24.0
    projectile.direction = direction
    projectile.damage = projectile_damage
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
    if is_dead:
        return
    health = maxi(0, health - amount)
    hit_flash = 0.15
    health_changed.emit(health, max_health)
    if health <= 0:
        _die()

func _die() -> void:
    is_dead = true
    velocity = Vector2.ZERO
    queue_redraw()
    died.emit()

func _draw() -> void:
    if is_dead:
        draw_circle(Vector2.ZERO, 20.0, Color(0.32, 0.36, 0.40, 0.9))
        return

    if hit_flash > 0.0:
        draw_circle(Vector2.ZERO, 25.0, Color(1.0, 1.0, 1.0, 0.30))
    draw_circle(Vector2.ZERO, 20.0, Color("#0d9488"))
    draw_circle(Vector2.ZERO, 13.0, Color("#ecfeff"))
    draw_line(Vector2.ZERO, facing * 27.0, Color("#14b8a6"), 5.0, true)
    draw_circle(Vector2.ZERO, 5.0, Color("#0f766e"))
