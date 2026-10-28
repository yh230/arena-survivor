extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

const GRENADE_SCRIPT := preload("res://scripts/hero_grenade.gd")
const SKILL_COOLDOWN := 8.0
const SKILL_RANGE := 620.0
const SKILL_RADIUS := 110.0
const SKILL_FUSE := 0.6
const SKILL_SLOW := 0.35
const SKILL_KNOCKBACK := 60.0
const INVULN_TIME := 0.5

@export var move_speed := 360.0
@export var max_health := 120

var health := 120
var is_dead := false
var hit_flash := 0.0
var invuln_time := 0.0
var skill_cooldown_left := 0.0
var joystick = null
var facing := Vector2.UP
var art: Sprite2D
var art_texture: Texture2D
var core_glow: Sprite2D
var aura: Sprite2D
var _shadow: Sprite2D
var _anim := 0.0
var _dust_timer := 0.0
var _wave := 1
var _chapter := 1

func _ready() -> void:
    health = max_health
    add_to_group("player")
    _setup_art()
    queue_redraw()

func _setup_art() -> void:
    art_texture = load("res://assets/sprites/player.png")
    _shadow = ArtFX.add_shadow(self, 68.0, 26.0, 28.0, 0.4)
    aura = ArtFX.add_glow(self, Color(0.2, 0.95, 0.85), 82.0, 0.17, -3)
    art = Sprite2D.new()
    art.texture = art_texture
    art.material = ArtFX.flash_material()
    art.z_index = -1
    art.z_as_relative = true
    add_child(art)
    core_glow = ArtFX.add_glow(self, Color(0.4, 1.0, 0.95), 33.0, 0.34, 1)

func _update_art(delta: float) -> void:
    if art == null:
        return
    var material := art.material as ShaderMaterial
    if material != null:
        material.set_shader_parameter("flash", clampf(hit_flash / 0.15, 0.0, 1.0) * 0.6)
    if is_dead:
        return

    var target_tilt := clampf(facing.x, -1.0, 1.0) * 0.16
    art.rotation = lerp_angle(art.rotation, target_tilt, clampf(delta * 12.0, 0.0, 1.0))
    art.flip_h = facing.x < -0.01
    art.position.y = sin(_anim * 4.2) * 1.6
    var pulse := 0.5 + 0.5 * sin(_anim * 3.6)
    if core_glow != null:
        core_glow.modulate.a = 0.24 + pulse * 0.16
    if aura != null:
        aura.modulate.a = 0.12 + pulse * 0.07

func _physics_process(delta: float) -> void:
    if is_dead:
        return

    invuln_time = maxf(0.0, invuln_time - delta)
    skill_cooldown_left = maxf(0.0, skill_cooldown_left - delta)
    _anim += delta
    _dust_timer = maxf(0.0, _dust_timer - delta)
    if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E):
        try_cast_skill()

    var direction: Vector2 = _get_move_direction()
    velocity = direction * move_speed
    move_and_slide()
    _clamp_to_arena()
    if direction.length_squared() > 0.01:
        facing = direction.normalized()
        if _dust_timer <= 0.0:
            _dust_timer = 0.24
            Fx.burst(global_position - facing * 12.0 + Vector2(0.0, 16.0), Color(0.45, 0.68, 0.64, 0.35), 2)

    hit_flash = maxf(0.0, hit_flash - delta)
    _update_art(delta)
    queue_redraw()

func _get_move_direction() -> Vector2:
    if joystick == null:
        joystick = get_tree().get_first_node_in_group("virtual_joystick")

    var direction := Vector2.ZERO
    if joystick != null and joystick.has_method("get_vector"):
        direction = joystick.get_vector()

    if direction.length_squared() < 0.01:
        if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
            direction.x -= 1.0
        if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
            direction.x += 1.0
        if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
            direction.y -= 1.0
        if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
            direction.y += 1.0

    if direction.length_squared() > 1.0:
        direction = direction.normalized()
    return direction

func _clamp_to_arena() -> void:
    var view_size := get_viewport_rect().size
    var margin := 28.0
    global_position.x = clampf(global_position.x, margin, view_size.x - margin)
    global_position.y = clampf(global_position.y, margin, view_size.y - margin)

func set_wave_info(wave_no: int, chapter_no: int) -> void:
    _wave = wave_no
    _chapter = chapter_no

func reset_for_run() -> void:
    is_dead = false
    max_health = 120
    health = 120
    move_speed = 360.0
    invuln_time = 0.0
    skill_cooldown_left = 0.0
    hit_flash = 0.0
    health_changed.emit(health, max_health)

func can_cast_skill() -> bool:
    return not is_dead and skill_cooldown_left <= 0.0

func get_skill_cooldown_remaining() -> float:
    return skill_cooldown_left

func get_skill_cooldown_total() -> float:
    return SKILL_COOLDOWN

func try_cast_skill() -> bool:
    if not can_cast_skill():
        return false
    var target = _nearest_enemy(global_position, SKILL_RANGE)
    var target_pos: Vector2 = global_position + facing * 220.0
    if target != null:
        target_pos = target.global_position
    var damage := 80 + 8 * _wave + 15 * (_chapter - 1)
    var grenade = GRENADE_SCRIPT.new()
    grenade.z_index = 6
    get_tree().current_scene.add_child(grenade)
    grenade.global_position = global_position + facing * 24.0
    grenade.setup(target_pos, damage, SKILL_RADIUS, 1.5, SKILL_SLOW, SKILL_KNOCKBACK, SKILL_FUSE)
    skill_cooldown_left = SKILL_COOLDOWN
    var manager = get_node_or_null("WeaponManager")
    if manager != null and manager.has_method("set_overclock"):
        manager.set_overclock(4.0)
    Audio.play("dash", -8.0)
    ArtFX.flash_at(get_tree().current_scene, global_position, Color(0.3, 1.0, 0.9), 36.0, 0.18)
    return true

func _nearest_enemy(from: Vector2, max_range: float):
    var best = null
    var best_distance := max_range
    for node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            continue
        var distance: float = from.distance_to(node.global_position)
        if distance < best_distance:
            best_distance = distance
            best = node
    return best

func take_damage(amount: int) -> void:
    if is_dead or invuln_time > 0.0:
        return
    health = maxi(0, health - amount)
    invuln_time = INVULN_TIME
    hit_flash = 0.15
    Audio.play("hurt", -8.0)
    Fx.damage_number(global_position + Vector2(0.0, -30.0), amount, Color("#fca5a5"))
    Fx.shake(7.0, 0.16)
    health_changed.emit(health, max_health)
    if health <= 0:
        _die()

func _die() -> void:
    is_dead = true
    velocity = Vector2.ZERO
    if art != null:
        art.modulate = Color(0.42, 0.45, 0.48, 1.0)
        art.rotation = 0.0
        art.position = Vector2.ZERO
    if core_glow != null:
        core_glow.visible = false
    if aura != null:
        aura.modulate.a = 0.0
    Fx.burst(global_position, Color("#5eead4"), 12)
    queue_redraw()
    died.emit()

func _draw() -> void:
    if is_dead:
        return
    draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 36, Color(0.85, 0.71, 0.42, 0.32), 1.5, true)
    draw_arc(Vector2.ZERO, 20.0, -PI * 0.25, PI * 0.25, 24, Color(0.25, 0.95, 0.85, 0.42), 2.0, true)
