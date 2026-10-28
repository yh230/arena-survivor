extends "res://scripts/enemy_base.gd"

signal health_changed(current: int, maximum: int)
signal defeated
signal minion_spawned(minion)
signal enrage_started

const MINION_SCENE := preload("res://scenes/enemy.tscn")

@export var minion_interval := 6.0
@export var enrage_ratio := 0.5
@export var enrage_speed_mult := 1.35

var minion_timer := 3.0
var enraged := false

func _ready() -> void:
    super._ready()
    add_to_group("boss")
    coin_drop = 10
    contact_range = 78.0
    damage_number_height = -84.0
    damage_number_color = Color("#fecaca")
    health_bar_color = Color("#fca5a5")
    death_color = Color("#ef4444")
    death_burst = 24
    die_sound = "boss_die"
    die_sound_db = -2.0
    minion_timer = 3.0

func _art_texture_path() -> String:
    return "res://assets/sprites/boss.png"

func _art_size() -> float:
    return 196.0

func _art_glow_color() -> Color:
    return Color(1.0, 0.3, 0.16)

func _art_glow_radius() -> float:
    return 132.0

func _art_glow_power() -> float:
    return 0.14

func _art_glow_rate() -> float:
    return 2.2

func _art_flash_strength() -> float:
    return 0.15

func _art_bob_rate() -> float:
    return 2.0

func _art_bob_size() -> float:
    return 2.0

func _art_glow_boost() -> float:
    return 1.0 + (0.8 if enraged else 0.0)

func _process(delta: float) -> void:
    super._process(delta)
    if art != null:
        art.rotation += delta * 0.18

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
        if health > 0 and not enraged and health <= int(float(max_health) * enrage_ratio):
            _enrage()

func _enrage() -> void:
    enraged = true
    move_speed *= enrage_speed_mult
    minion_interval = maxf(2.4, minion_interval * 0.65)
    minion_timer = 0.5
    enrage_started.emit()
    Audio.play("boss_spawn", -10.0)
    Fx.burst(global_position, Color(1.0, 0.45, 0.2), 22)
    Fx.shock(global_position, Color(1.0, 0.42, 0.18), 230.0, 0.55)
    Fx.ring(global_position, Color(1.0, 0.55, 0.25), 210.0, 0.5, 6.0)
    Fx.sparks(global_position, Color(1.0, 0.55, 0.2), 20, 340.0, 0.5)
    ArtFX.flash_at(get_tree().current_scene, global_position, Color(1.0, 0.4, 0.2), 220.0, 0.4)
    Fx.shake(10.0, 0.3)
    queue_redraw()

func apply_stun(_duration: float) -> void:
    pass

func apply_slow(duration: float, factor: float) -> void:
    super.apply_slow(duration, 1.0 - (1.0 - factor) * 0.5)

func _die() -> void:
    active = false
    defeated.emit()
    Audio.play("boss_die", -2.0)
    Fx.burst(global_position, Color("#ef4444"), 30)
    Fx.shock(global_position, Color(1.0, 0.45, 0.2), 320.0, 0.7)
    Fx.sparks(global_position, Color(1.0, 0.55, 0.25), 24, 380.0, 0.6)
    ArtFX.flash_at(get_tree().current_scene, global_position, Color(1.0, 0.4, 0.2), 300.0, 0.5)
    Fx.shake(14.0, 0.35)
    queue_free()

func _spawn_minions() -> void:
    for index in range(2):
        var angle := TAU * float(index) / 2.0 + randf_range(-0.4, 0.4)
        var minion := MINION_SCENE.instantiate()
        get_parent().add_child(minion)
        minion.global_position = global_position + Vector2.from_angle(angle) * 90.0
        minion.move_speed = 120.0
        ArtFX.flash_at(get_tree().current_scene, minion.global_position, Color(1.0, 0.35, 0.15), 34.0, 0.22)
        minion_spawned.emit(minion)

func _draw() -> void:
    if minion_timer < 1.2 and active:
        var ratio := 1.0 - clampf(minion_timer / 1.2, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 112.0 + ratio * 12.0, 0.0, TAU, 48, Color(1.0, 0.45, 0.25, 0.3 + ratio * 0.35), 3.0, true)
        for index in range(6):
            var tick_angle := TAU * float(index) / 6.0 + anim_time * 0.8
            draw_line(
                Vector2.from_angle(tick_angle) * (118.0 + ratio * 8.0),
                Vector2.from_angle(tick_angle) * (128.0 + ratio * 10.0),
                Color(1.0, 0.55, 0.25, 0.35 + ratio * 0.3), 2.0, true
            )
    if enraged and active:
        var pulse := 0.5 + 0.5 * sin(anim_time * 5.5)
        draw_arc(Vector2.ZERO, 116.0 + pulse * 5.0, 0.0, TAU, 64, Color(1.0, 0.36, 0.14, 0.34 + pulse * 0.18), 4.0, true)
        draw_arc(Vector2.ZERO, 104.0, -anim_time * 1.2, -anim_time * 1.2 + TAU * 0.7, 48, Color(1.0, 0.55, 0.2, 0.4), 2.0, true)
        for index in range(8):
            var rune_angle := anim_time * 0.9 + TAU * float(index) / 8.0
            draw_line(
                Vector2.from_angle(rune_angle) * 122.0,
                Vector2.from_angle(rune_angle) * 132.0,
                Color(1.0, 0.45, 0.18, 0.45 + pulse * 0.25), 2.0, true
            )
    _draw_status_marks()
