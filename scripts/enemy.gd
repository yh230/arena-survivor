extends CharacterBody2D

@export var max_health := 30
@export var move_speed := 110.0
@export var contact_damage := 8
@export var contact_interval := 0.8
@export var contact_range := 36.0

var health := 30
var player = null
var contact_cooldown := 0.0
var active := true
var damage_flash := 0.0

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")
    queue_redraw()

func _physics_process(delta: float) -> void:
    if not active or player == null or not is_instance_valid(player):
        return
    if player.is_dead:
        return

    var offset: Vector2 = player.global_position - global_position
    if offset.length() > 1.0:
        velocity = offset.normalized() * move_speed
        move_and_slide()

    contact_cooldown = maxf(0.0, contact_cooldown - delta)
    damage_flash = maxf(0.0, damage_flash - delta)

    if offset.length() <= contact_range and contact_cooldown <= 0.0:
        if player.has_method("take_damage"):
            player.take_damage(contact_damage)
            contact_cooldown = contact_interval

    queue_redraw()

func take_damage(amount: int) -> void:
    health -= amount
    damage_flash = 0.12
    queue_redraw()
    if health <= 0:
        queue_free()

func stop() -> void:
    active = false
    velocity = Vector2.ZERO

func _draw() -> void:
    var body_color := Color("#f87171")
    if damage_flash > 0.0:
        body_color = Color.WHITE

    draw_circle(Vector2.ZERO, 16.0, body_color)
    draw_circle(Vector2.ZERO, 9.0, Color("#7f1d1d"))

    var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
    draw_rect(Rect2(-18.0, -28.0, 36.0, 5.0), Color(0.0, 0.0, 0.0, 0.65))
    draw_rect(Rect2(-18.0, -28.0, 36.0 * ratio, 5.0), Color("#fca5a5"))
