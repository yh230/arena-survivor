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

func _ready() -> void:
    health = max_health
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")
    queue_redraw()

func take_damage(amount: int, is_crit := false) -> void:
    if not active or health <= 0:
        return
    var final_amount := maxi(1, int(round(float(amount) * damage_taken_multiplier())))
    health -= final_amount
    damage_flash = 0.12
    _pending_damage += final_amount
    _pending_crit = _pending_crit or is_crit
    if _pending_damage_time <= 0.0:
        _flush_damage()
    _pending_damage_time = DAMAGE_MERGE_TIME
    Audio.play_limited("hit", hit_sound_db, HIT_SOUND_INTERVAL)
    queue_redraw()
    if health <= 0:
        _die()

func _die() -> void:
    active = false
    Audio.play(die_sound, die_sound_db)
    Fx.burst(global_position, death_color, death_burst)
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
    var size := 24 if _pending_crit else 20
    Fx.damage_number(global_position + Vector2(0.0, damage_number_height), _pending_damage, color, size)
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

func _draw_health_bar(width := 36.0, y := -28.0) -> void:
    var ratio := clampf(float(health) / float(maxi(1, max_health)), 0.0, 1.0)
    draw_rect(Rect2(-width * 0.5, y, width, 5.0), Color(0.0, 0.0, 0.0, 0.65))
    draw_rect(Rect2(-width * 0.5, y, width * ratio, 5.0), health_bar_color)

func _draw_gear(center: Vector2, radius: float, teeth: int, color: Color, rotation: float, thickness := 2.5) -> void:
    draw_arc(center, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, color.a), thickness, true)
    for index in range(teeth):
        var angle := rotation + TAU * float(index) / float(teeth)
        var inner := center + Vector2.from_angle(angle) * (radius - 1.5)
        var outer := center + Vector2.from_angle(angle) * (radius + 5.0)
        draw_line(inner, outer, Color(color.r, color.g, color.b, color.a), thickness + 0.5, true)

func _draw_status_marks() -> void:
    if has_slow():
        draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 24, Color(0.35, 0.9, 1.0, 0.55), 1.5, true)
    if is_stunned():
        draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.4, 0.85), 2.0, true)
