extends Area2D

var direction := Vector2.RIGHT
var speed := 820.0
var damage := 10
var crit := false
var lifetime := 0.95
var hit := false
var source = null
var _trail_timer := 0.0

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    ArtFX.add_glow(self, Color(0.35, 1.0, 1.0), 20.0, 0.5, -1)
    queue_redraw()

func _physics_process(delta: float) -> void:
    global_position += direction * speed * delta
    lifetime -= delta
    _trail_timer -= delta
    if _trail_timer <= 0.0:
        _trail_timer = 0.045
        var trail_color := Color(1.0, 0.78, 0.3) if crit else Color(0.35, 1.0, 1.0)
        ArtFX.trail_at(get_parent(), global_position, trail_color, 12.0, 0.18)
    if lifetime <= 0.0:
        queue_free()

func _on_body_entered(body: Node) -> void:
    if hit:
        return
    if body.is_in_group("enemies") and body.has_method("take_damage"):
        hit = true
        body.take_damage(damage, crit)
        if is_instance_valid(source) and source.has_method("on_projectile_hit"):
            source.on_projectile_hit()
        queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 6.0, Color("#22d3ee"))
    draw_circle(Vector2.ZERO, 3.0, Color("#ecfeff"))
