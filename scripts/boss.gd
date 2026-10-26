extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal defeated

const MINION_SCENE := preload("res://scenes/enemy.tscn")

@export var max_health := 900
@export var move_speed := 55.0
@export var contact_damage := 22
@export var contact_interval := 0.9
@export var contact_range := 78.0
@export var minion_interval := 6.0

var health := 900
var player = null
var contact_cooldown := 0.0
var minion_timer := 3.0
var active := true
var damage_flash := 0.0

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    add_to_group("boss")
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
    minion_timer -= delta

    if minion_timer <= 0.0:
        _spawn_minions()
        minion_timer = minion_interval

    if offset.length() <= contact_range and contact_cooldown <= 0.0:
        if player.has_method("take_damage"):
            player.take_damage(contact_damage)
            contact_cooldown = contact_interval

    queue_redraw()

func _spawn_minions() -> void:
    for index in range(2):
        var angle := TAU * float(index) / 2.0 + randf_range(-0.4, 0.4)
        var minion := MINION_SCENE.instantiate()
        get_parent().add_child(minion)
        minion.global_position = global_position + Vector2.from_angle(angle) * 90.0
        minion.move_speed = 120.0

func take_damage(amount: int) -> void:
    if health <= 0:
        return
    health -= amount
    damage_flash = 0.10
    Audio.play("hit", -14.0)
    health_changed.emit(maxi(health, 0), max_health)
    queue_redraw()
    if health <= 0:
        _die()

func _die() -> void:
    active = false
    defeated.emit()
    Audio.play("boss_die", -2.0)
    queue_free()

func stop() -> void:
    active = false
    velocity = Vector2.ZERO

func _draw() -> void:
    var body_color := Color("#ef4444")
    if damage_flash > 0.0:
        body_color = Color.WHITE

    draw_circle(Vector2.ZERO, 64.0, Color(0.27, 0.04, 0.04, 1.0))
    draw_circle(Vector2.ZERO, 56.0, body_color)
    draw_circle(Vector2.ZERO, 34.0, Color("#7f1d1d"))
    draw_circle(Vector2(-18.0, -10.0), 8.0, Color("#fef08a"))
    draw_circle(Vector2(18.0, -10.0), 8.0, Color("#fef08a"))
    draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 64, Color("#fca5a5"), 4.0, true)
