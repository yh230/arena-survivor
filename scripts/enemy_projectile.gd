extends Area2D

var direction := Vector2.RIGHT
var speed := 240.0
var damage := 6
var lifetime := 4.0
var _trail_timer := 0.0

func _ready() -> void:
    add_to_group("enemy_projectile")
    body_entered.connect(_on_body_entered)
    ArtFX.add_glow(self, Color(0.8, 0.42, 1.0), 22.0, 0.5, -1)
    queue_redraw()

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    _trail_timer -= delta
    if _trail_timer <= 0.0:
        _trail_timer = 0.16
        ArtFX.trail_at(get_parent(), global_position, Color(0.82, 0.45, 1.0), 14.0, 0.22)
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player") and body.has_method("take_damage"):
        body.take_damage(damage)
        Fx.ring(global_position, Color(0.8, 0.45, 1.0), 22.0, 0.22, 2.0)
        Fx.sparks(global_position, Color(0.8, 0.45, 1.0), 5, 160.0, 0.24)
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 7.0, Color("#a855f7"))
    draw_circle(Vector2.ZERO, 3.0, Color("#f5d0fe"))
