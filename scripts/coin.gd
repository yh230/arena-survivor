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
            collected.emit(value)
            queue_free()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 8.0, Color("#f59e0b"))
    draw_circle(Vector2.ZERO, 5.0, Color("#fde68a"))
    draw_circle(Vector2.ZERO, 2.0, Color("#fffbeb"))
