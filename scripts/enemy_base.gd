extends CharacterBody2D

signal died(drop_position: Vector2, coin_count: int)

const DAMAGE_MERGE_TIME := 0.16
const HIT_SOUND_INTERVAL := 0.07

@export var max_health := 30
@export var move_speed := 110.0
@export var contact_damage := 8
@export var contact_interval := 0.8
@export var contact_range := 36.0
@export var coin_drop := 1
@export var elite := false

var health := 30
var player = null
var active := true
var damage_flash := 0.0
var contact_cooldown := 0.0
var anim_time := 0.0

var art: Sprite2D
var art_texture: Texture2D
var status_radius := 24.0
var health_bar_width := 44.0
var health_bar_y := -38.0

var _art_glow: Sprite2D
var _art_shadow: Sprite2D
var _art_glow_strength := 0.2
var _art_glow_speed := 4.0
var _art_bob_speed := 8.0
var _art_bob_height := 1.5

var damage_number_color := Color("#fef3c7")
var damage_number_height := -26.0
var health_bar_color := Color("#fca5a5")
var death_color := Color("#f87171")
var death_burst := 8
var die_sound := "enemy_die"
var die_sound_db := -10.0
var hit_sound_db := -16.0

var _slow_factor := 1.0
var _slow_time := 0.0
var _stun_time := 0.0
var _mark_time := 0.0
var _mark_bonus := 0.0
var _pending_damage := 0
var _pending_crit := false
var _pending_damage_time := 0.0
var _hit_punch := 0.0
var _spawn_time := 0.0
var _impact_fx_timer := 0.0

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")
    _setup_art()
    Fx.ring(global_position, _art_glow_color(), maxf(22.0, _art_size() * 0.42), 0.32, 2.0)
    queue_redraw()

func _art_texture_path() -> String:
    return ""

func _art_size() -> float:
    return 60.0

func _art_glow_color() -> Color:
    return Color(1.0, 0.45, 0.2)

func _art_glow_radius() -> float:
    return 42.0

func _art_glow_power() -> float:
    return 0.2

func _art_faces_target() -> bool:
    return false

func _art_turns_to_target() -> bool:
    return false

func _art_glow_boost() -> float:
    return 1.0

func _art_flash_strength() -> float:
    return 0.5

func _art_glow_rate() -> float:
    return 4.0

func _art_bob_rate() -> float:
    return 8.0

func _art_bob_size() -> float:
    return 1.5

func _setup_art() -> void:
    var path := _art_texture_path()
    if path.is_empty():
        return
    art_texture = load(path)
    var size := _art_size()
    status_radius = minf(size * 0.55, 60.0)
    health_bar_y = -size * 0.64
    _art_shadow = ArtFX.add_shadow(self, size * 0.74, size * 0.28, size * 0.26, 0.34)
    _art_glow_strength = _art_glow_power()
    _art_glow_speed = _art_glow_rate()
    _art_bob_speed = _art_bob_rate()
    _art_bob_height = _art_bob_size()
    _art_glow = ArtFX.add_glow(self, _art_glow_color(), _art_glow_radius(), _art_glow_strength, -3)
    art = Sprite2D.new()
    art.texture = art_texture
    art.material = ArtFX.flash_material()
    art.z_index = -1
    art.z_as_relative = true
    add_child(art)

func _is_player_valid() -> bool:
    return player != null and is_instance_valid(player) and not player.is_dead

func _process(delta: float) -> void:
    if art == null:
        return
    var material := art.material as ShaderMaterial
    if material != null:
        material.set_shader_parameter("flash", clampf(damage_flash / 0.09, 0.0, 1.0) * _art_flash_strength())
    var spawn_t := clampf(_spawn_time / 0.24, 0.0, 1.0)
    var spawn_scale := 0.36 + 0.64 * (1.0 - pow(1.0 - spawn_t, 3.0))
    art.scale = Vector2(1.0 + _hit_punch * 0.16, 1.0 - _hit_punch * 0.10) * spawn_scale
    art.modulate.a = 0.35 + 0.65 * spawn_t
    art.position = Vector2(0.0, sin(anim_time * _art_bob_speed) * _art_bob_height - (1.0 - spawn_t) * 14.0)
    if _art_turns_to_target() and _is_player_valid():
        var target_angle: float = (player.global_position - global_position).angle()
        art.rotation = lerp_angle(art.rotation, target_angle, clampf(delta * 10.0, 0.0, 1.0))
    elif _art_faces_target() and _is_player_valid():
        art.flip_h = player.global_position.x < global_position.x
    if _art_glow != null:
        var pulse := 0.5 + 0.5 * sin(anim_time * _art_glow_speed)
        _art_glow.modulate.a = _art_glow_strength * (0.7 + pulse * 0.5) * _art_glow_boost()

func take_damage(amount: int, is_crit := false) -> void:
    if not active or health <= 0:
        return
    var final_amount := maxi(1, int(round(float(amount) * damage_taken_multiplier())))
    health -= final_amount
    damage_flash = 0.14 if is_crit else 0.09
    _hit_punch = 1.0
    _pending_damage += final_amount
    _pending_crit = _pending_crit or is_crit
    if _pending_damage_time <= 0.0:
        _flush_damage()
    _pending_damage_time = DAMAGE_MERGE_TIME
    if _impact_fx_timer <= 0.0:
        _impact_fx_timer = 0.16
        var impact_color := Color("#fbbf24") if is_crit else damage_number_color
        Fx.sparks(global_position + Vector2(0.0, -6.0), impact_color, 8 if is_crit else 4, 220.0, 0.26)
        if is_crit:
            Fx.ring(global_position, impact_color, 22.0, 0.2, 2.0)
    Audio.play_limited("hit", hit_sound_db, HIT_SOUND_INTERVAL)
    queue_redraw()
    if health <= 0:
        _die()

func _die() -> void:
    active = false
    Audio.play(die_sound, die_sound_db)
    Fx.burst(global_position, death_color, death_burst)
    Fx.ring(global_position, death_color, maxf(26.0, _art_size() * 0.5), 0.3, 2.0)
    Fx.sparks(global_position, death_color, mini(12, death_burst), 250.0, 0.34)
    ArtFX.flash_at(get_tree().current_scene, global_position, death_color, maxf(26.0, _art_size() * 0.55), 0.2)
    if elite:
        Fx.shake(5.0, 0.16)
    died.emit(global_position, coin_drop)
    queue_free()

func stop() -> void:
    active = false
    velocity = Vector2.ZERO

func apply_slow(duration: float, factor: float) -> void:
    _slow_factor = minf(_slow_factor, clampf(factor, 0.1, 1.0))
    _slow_time = maxf(_slow_time, duration)

func apply_stun(duration: float) -> void:
    _stun_time = maxf(_stun_time, duration)

func apply_mark(duration: float, bonus: float) -> void:
    _mark_bonus = maxf(_mark_bonus, bonus)
    _mark_time = maxf(_mark_time, duration)

func apply_knockback(direction: Vector2, distance: float) -> void:
    if direction.length_squared() < 0.001:
        return
    global_position += direction.normalized() * distance

func is_stunned() -> bool:
    return _stun_time > 0.0

func has_slow() -> bool:
    return _slow_time > 0.0

func speed_multiplier() -> float:
    if is_stunned():
        return 0.0
    return _slow_factor

func damage_taken_multiplier() -> float:
    if _mark_time > 0.0:
        return 1.0 + _mark_bonus
    return 1.0

func _tick_status(delta: float) -> void:
    anim_time += delta
    _spawn_time += delta
    _hit_punch = maxf(0.0, _hit_punch - delta * 7.0)
    _impact_fx_timer = maxf(0.0, _impact_fx_timer - delta)
    damage_flash = maxf(0.0, damage_flash - delta)
    contact_cooldown = maxf(0.0, contact_cooldown - delta)
    _slow_time = maxf(0.0, _slow_time - delta)
    if _slow_time <= 0.0:
        _slow_factor = 1.0
    _stun_time = maxf(0.0, _stun_time - delta)
    _mark_time = maxf(0.0, _mark_time - delta)
    if _mark_time <= 0.0:
        _mark_bonus = 0.0
    _pending_damage_time = maxf(0.0, _pending_damage_time - delta)
    if _pending_damage_time <= 0.0 and _pending_damage > 0:
        _flush_damage()

func _flush_damage() -> void:
    var color := Color("#fbbf24") if _pending_crit else damage_number_color
    var size := 24 if _pending_crit else 18
    Fx.damage_number(global_position + Vector2(0.0, damage_number_height), _pending_damage, color, size, _pending_crit)
    if _pending_crit:
        Fx.burst(global_position, Color("#fbbf24"), 4)
    _pending_damage = 0
    _pending_crit = false

func _try_contact_damage() -> void:
    if contact_cooldown > 0.0 or contact_range <= 0.0:
        return
    if player == null or not is_instance_valid(player) or player.is_dead:
        return
    if global_position.distance_to(player.global_position) <= contact_range:
        player.take_damage(contact_damage)
        contact_cooldown = contact_interval

func _draw_health_bar(width := 0.0, y := 0.0) -> void:
    if health >= max_health and not elite:
        return
    if width <= 0.0:
        width = health_bar_width
    if y == 0.0:
        y = health_bar_y
    var ratio := clampf(float(health) / float(maxi(1, max_health)), 0.0, 1.0)
    draw_rect(Rect2(-width * 0.5 - 1.0, y - 1.0, width + 2.0, 7.0), Color(0.02, 0.04, 0.05, 0.82))
    draw_rect(Rect2(-width * 0.5, y, width, 5.0), Color(0.0, 0.0, 0.0, 0.62))
    var fill := Rect2(-width * 0.5, y, width * ratio, 5.0)
    draw_rect(fill, health_bar_color)
    if ratio > 0.02:
        draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1.5)), health_bar_color.lightened(0.45))
    draw_line(Vector2(-width * 0.5 - 1.0, y + 6.0), Vector2(width * 0.5 + 1.0, y + 6.0), Color(0.85, 0.71, 0.42, 0.22), 1.0)

func _draw_status_marks() -> void:
    var ground_alpha := 0.30 if elite else 0.15
    draw_arc(Vector2.ZERO, status_radius * 1.04, 0.0, TAU, 32, Color(health_bar_color.r, health_bar_color.g, health_bar_color.b, ground_alpha), 1.0, true)
    if _mark_time > 0.0:
        var mark_rot := anim_time * 2.4
        for index in range(3):
            var start := mark_rot + TAU * float(index) / 3.0
            draw_arc(Vector2.ZERO, status_radius * 1.13, start, start + 0.6, 10, Color(0.55, 0.85, 1.0, 0.62), 2.0, true)
    if has_slow():
        draw_arc(Vector2.ZERO, status_radius, 0.0, TAU, 24, Color(0.35, 0.9, 1.0, 0.55), 1.5, true)
    if is_stunned():
        draw_arc(Vector2.ZERO, status_radius * 1.18, 0.0, TAU, 24, Color(1.0, 0.95, 0.4, 0.85), 2.0, true)
        for index in range(3):
            var star_angle := anim_time * 6.0 + TAU * float(index) / 3.0
            draw_circle(Vector2.from_angle(star_angle) * status_radius * 0.72 + Vector2(0.0, -8.0), 2.0, Color(1.0, 0.95, 0.45, 0.85))
