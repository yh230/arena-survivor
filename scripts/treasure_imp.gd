extends "res://scripts/enemy_base.gd"

@export var lifetime := 20.0

var wander_direction := Vector2.RIGHT
var wander_timer := 0.0

# 性能：_draw 只有状态环与血条（均静态），无需每物理帧重绘
var _was_status_visual := false

func _ready() -> void:
    super._ready()
    add_to_group("treasure")
    coin_drop = 6
    contact_range = 0.0
    damage_number_color = Color("#fde68a")
    health_bar_color = Color("#fde68a")
    death_color = Color("#fbbf24")
    death_burst = 18
    die_sound_db = -6.0
    wander_direction = Vector2.from_angle(randf_range(0.0, TAU))
    wander_timer = randf_range(0.4, 1.0)

func _art_texture_path() -> String:
    return "res://assets/sprites/treasure.png"

func _art_size() -> float:
    return 70.0

func _art_glow_color() -> Color:
    return Color(1.0, 0.78, 0.25)

func _art_glow_radius() -> float:
    return 48.0

func _art_glow_power() -> float:
    return 0.22

func _art_glow_rate() -> float:
    return 3.0

func _art_bob_rate() -> float:
    return 3.0

func _art_bob_size() -> float:
    return 2.5

func _process(delta: float) -> void:
    super._process(delta)
    if art != null:
        art.rotation = sin(anim_time * 1.6) * 0.06

func _physics_process(delta: float) -> void:
    if not active:
        return

    _tick_status(delta)
    lifetime -= delta
    if lifetime <= 0.0:
        _escape()
        return

    wander_timer -= delta
    if wander_timer <= 0.0:
        wander_timer = randf_range(0.5, 1.2)
        wander_direction = Vector2.from_angle(randf_range(0.0, TAU))

    if player != null and is_instance_valid(player):
        var away: Vector2 = global_position - player.global_position
        if away.length() < 220.0 and away.length() > 1.0:
            wander_direction = away.normalized()

    if is_stunned():
        velocity = Vector2.ZERO
        move_and_slide()
    else:
        velocity = wander_direction * move_speed * speed_multiplier()
        move_and_slide()
        _clamp_to_arena()
    var status_visual := _mark_time > 0.0 or has_slow() or is_stunned()
    if status_visual or _was_status_visual:
        queue_redraw()
    _was_status_visual = status_visual

func _clamp_to_arena() -> void:
    var view_size := get_viewport_rect().size
    var margin := 50.0
    global_position.x = clampf(global_position.x, margin, view_size.x - margin)
    global_position.y = clampf(global_position.y, margin, view_size.y - margin)

func _escape() -> void:
    active = false
    Fx.burst(global_position, Color(1.0, 0.85, 0.3, 0.6), 6)
    ArtFX.flash_at(get_tree().current_scene, global_position, Color(1.0, 0.85, 0.35), 44.0, 0.24)
    queue_free()

func _draw() -> void:
    _draw_status_marks()
    _draw_health_bar(40.0, -40.0)
