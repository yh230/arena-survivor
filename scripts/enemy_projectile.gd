extends Area2D

var direction := Vector2.RIGHT
var speed := 240.0
var damage := 6
var lifetime := 4.0

func _ready() -> void:
    add_to_group("enemy_projectile")
    body_entered.connect(_on_body_entered)
    queue_redraw()

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player") and body.has_method("take_damage"):
        body.take_damage(damage)
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 7.0, Color("#a855f7"))
    draw_circle(Vector2.ZERO, 3.0, Color("#f5d0fe"))
