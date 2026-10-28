extends "res://scripts/enemy_base.gd"

signal health_changed(current: int, maximum: int)
signal defeated
signal minion_spawned(minion)

const MINION_SCENE := preload("res://scenes/enemy.tscn")

@export var minion_interval := 6.0

var minion_timer := 3.0

func _ready() -> void:
    super._ready()
    add_to_group("boss")
    coin_drop = 10
    contact_range = 78.0
    damage_number_height = -72.0
    damage_number_color = Color("#fecaca")
    health_bar_color = Color("#fca5a5")
    death_color = Color("#ef4444")
    death_burst = 24
    die_sound = "boss_die"
    die_sound_db = -2.0
    minion_timer = 3.0

func _physics_process(delta: float) -> void:
    _tick_status(delta)
    if not active or player == null or not is_instance_valid(player) or player.is_dead:
        return

    if is_stunned():
        velocity = Vector2.ZERO
        move_and_slide()
    else:
        var offset: Vector2 = player.global_position - global_position
        if offset.length() > 1.0:
            velocity = offset.normalized() * move_speed * speed_multiplier()
            move_and_slide()

    minion_timer -= delta
    if minion_timer <= 0.0:
        _spawn_minions()
        minion_timer = minion_interval

    _try_contact_damage()
    queue_redraw()

func take_damage(amount: int, is_crit := false) -> void:
    if health <= 0:
        return
    super.take_damage(amount, is_crit)
    if active:
        health_changed.emit(maxi(health, 0), max_health)

func apply_stun(_duration: float) -> void:
    pass

func apply_slow(duration: float, factor: float) -> void:
    super.apply_slow(duration, 1.0 - (1.0 - factor) * 0.5)

func _die() -> void:
    active = false
    defeated.emit()
    Audio.play("boss_die", -2.0)
    Fx.burst(global_position, Color("#ef4444"), 24)
    Fx.shake(14.0, 0.35)
    queue_free()

func _spawn_minions() -> void:
    for index in range(2):
        var angle := TAU * float(index) / 2.0 + randf_range(-0.4, 0.4)
        var minion := MINION_SCENE.instantiate()
        get_parent().add_child(minion)
        minion.global_position = global_position + Vector2.from_angle(angle) * 90.0
        minion.move_speed = 120.0
        minion_spawned.emit(minion)

func _draw() -> void:
    var body_color := Color("#ef4444")
    if damage_flash > 0.0:
        body_color = Color("#ffb4a8")

    draw_set_transform(Vector2(0.0, 56.0), 0.0, Vector2(1.0, 0.36))
    draw_circle(Vector2.ZERO, 66.0, Color(0.0, 0.0, 0.0, 0.30))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

    var pulse := 0.5 + 0.5 * sin(anim_time * 2.4)
    draw_circle(Vector2.ZERO, 76.0 + pulse * 4.0, Color(1.0, 0.22, 0.12, 0.08 + pulse * 0.05))
    _draw_gear(Vector2.ZERO, 64.0, 16, Color(0.78, 0.26, 0.22, 0.75), anim_time * 0.35, 4.0)
    _draw_gear(Vector2.ZERO, 50.0, 12, Color(0.62, 0.18, 0.16, 0.85), -anim_time * 0.55, 3.0)

    for index in range(6):
        var angle := anim_time * 0.25 + TAU * float(index) / 6.0
        var arm_start := Vector2.from_angle(angle) * 30.0
        var arm_end := Vector2.from_angle(angle) * 54.0
        draw_line(arm_start, arm_end, Color("#8f2f28"), 7.0, true)
        draw_circle(arm_end, 5.0, Color("#fca5a5"))

    draw_circle(Vector2.ZERO, 36.0, Color("#5b1611"))
    draw_circle(Vector2.ZERO, 30.0, body_color)
    draw_circle(Vector2.ZERO, 20.0 + pulse * 2.0, Color("#b91c1c"))
    draw_circle(Vector2.ZERO, 12.0, Color("#f87171"))
    draw_circle(Vector2.ZERO, 5.0, Color("#fff1f2"))

    draw_circle(Vector2(-16.0, -8.0), 7.0, Color("#fef08a"))
    draw_circle(Vector2(16.0, -8.0), 7.0, Color("#fef08a"))
    draw_circle(Vector2(-16.0, -8.0), 3.0, Color("#450a0a"))
    draw_circle(Vector2(16.0, -8.0), 3.0, Color("#450a0a"))

    if minion_timer < 1.2 and active:
        var ratio := 1.0 - clampf(minion_timer / 1.2, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 78.0 + ratio * 10.0, 0.0, TAU, 48, Color(1.0, 0.45, 0.25, 0.35 + ratio * 0.35), 3.0, true)
    _draw_status_marks()
