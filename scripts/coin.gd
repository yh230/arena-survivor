extends Node2D

signal collected(value: int)

var value := 1
var player = null
var pickup_radius := 60.0
var lifetime := 25.0
var magnet_speed := 0.0
var _glow: Sprite2D
var _pulse := 0.0

func setup(coin_value: int, target_player, radius: float) -> void:
    value = coin_value
    player = target_player
    pickup_radius = radius
    add_to_group("coin")
    _glow = ArtFX.add_glow(self, Color(1.0, 0.78, 0.3), 20.0, 0.35, -1)
    queue_redraw()

func _physics_process(delta: float) -> void:
    _pulse += delta
    if _glow != null:
        _glow.modulate.a = 0.28 + 0.14 * sin(_pulse * 5.0)
    scale = Vector2.ONE * (1.0 + 0.07 * sin(_pulse * 6.0))
    lifetime -= delta
    if lifetime <= 0.0:
        queue_free()
        return
    if player == null or not is_instance_valid(player):
        return
    var offset: Vector2 = player.global_position - global_position
    var distance := offset.length()
    if distance <= pickup_radius and distance > 0.1:
        magnet_speed = move_toward(magnet_speed, 520.0, 1400.0 * delta)
        global_position += offset.normalized() * magnet_speed * delta
        if distance <= 18.0:
            Fx.burst(global_position, Color("#f0b94a"), 4)
            Fx.ring(global_position, Color("#fbbf24"), 16.0, 0.22, 1.5)
            collected.emit(value)
            queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 9.0, Color("#7c3f0a"))
    draw_circle(Vector2.ZERO, 8.0, Color("#e8a521"))
    draw_circle(Vector2.ZERO, 6.2, Color("#f8d878"))
    draw_rect(Rect2(-2.4, -2.4, 4.8, 4.8), Color("#8a4a0e"))
    draw_rect(Rect2(-2.4, -2.4, 4.8, 4.8), Color("#5c2e05"), false, 1.0)
    draw_arc(Vector2.ZERO, 6.6, -2.7, -0.9, 12, Color(1.0, 1.0, 0.88, 0.85), 1.2, true)
    draw_line(Vector2(-7.0, -6.0), Vector2(-4.0, -6.0), Color(1.0, 0.98, 0.8, 0.75), 1.0, true)
    draw_line(Vector2(-5.5, -7.5), Vector2(-5.5, -4.5), Color(1.0, 0.98, 0.8, 0.75), 1.0, true)
