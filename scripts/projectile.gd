extends Area2D

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 10
var lifetime := 0.95
var hit := false

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    queue_redraw()

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if hit:
        return
    if body.is_in_group("enemies") and body.has_method("take_damage"):
        hit = true
        body.take_damage(damage)
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 6.0, Color("#22d3ee"))
    draw_circle(Vector2.ZERO, 3.0, Color("#ecfeff"))
