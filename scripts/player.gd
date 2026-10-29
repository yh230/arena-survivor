extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died
signal skill_cast

const GRENADE_SCRIPT := preload("res://scripts/hero_grenade.gd")
const SKILL_COOLDOWN := 8.0
const SKILL_RANGE := 620.0
const SKILL_RADIUS := 110.0
const SKILL_FUSE := 0.6
const SKILL_SLOW := 0.35
const SKILL_KNOCKBACK := 60.0
const SKILL_DAMAGE_PER_LEVEL := 0.025
const INVULN_TIME := 0.5
## 受击方向弧：只在屏幕边缘画一条 0.25s 的红弧，不延长无敌、不改伤害。
const HURT_ARC_TIME := 0.25
const HURT_ARC_MIN_DISTANCE := 8.0

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
var _flash_overlay: Sprite2D
var _anim := 0.0
var _dust_timer := 0.0
var _wave := 1
var _chapter := 1
var hero_level := 1
## 受击弧画在独立 CanvasLayer 上：世界相机抖动不会带着它一起晃，
## 也不会被敌人/特效的 z_index 盖住。
var _hurt_layer: CanvasLayer = null
var _hurt_arc = null
var _move_input := Vector2.ZERO

func _ready() -> void:
    health = max_health
    add_to_group("player")
    _setup_art()
    _setup_hurt_arc()
    queue_redraw()

func _setup_hurt_arc() -> void:
    _hurt_layer = CanvasLayer.new()
    _hurt_layer.name = "HurtIndicator"
    _hurt_layer.layer = 5
    add_child(_hurt_layer)
    _hurt_arc = HurtArc.new()
    _hurt_arc.name = "Arc"
    _hurt_layer.add_child(_hurt_arc)

func _setup_art() -> void:
    art_texture = load("res://assets/sprites/player.png")
    _shadow = ArtFX.add_shadow(self, 68.0, 26.0, 28.0, 0.4)
    aura = ArtFX.add_glow(self, Color(0.2, 0.95, 0.85), 82.0, 0.17, -3)
    art = Sprite2D.new()
    art.texture = art_texture
    art.z_index = -1
    art.z_as_relative = true
    add_child(art)
    _flash_overlay = ArtFX.add_flash_overlay(art, art_texture)
    core_glow = ArtFX.add_glow(self, Color(0.45, 0.88, 0.80), 33.0, 0.34, 1)

func _update_art(delta: float) -> void:
    if art == null:
        return
    ArtFX.drive_flash_overlay(_flash_overlay, clampf(hit_flash / 0.15, 0.0, 1.0) * 0.6, 1.0)
    if is_dead:
        return

    if invuln_time > 0.0:
        art.modulate.a = 0.55 + 0.45 * absf(sin(invuln_time * 34.0))
    elif art.modulate.a != 1.0:
        art.modulate.a = 1.0

    var target_tilt := clampf(facing.x, -1.0, 1.0) * 0.16
    art.rotation = lerp_angle(art.rotation, target_tilt, clampf(delta * 12.0, 0.0, 1.0))
    art.flip_h = facing.x < -0.01
    if _flash_overlay != null:
        _flash_overlay.flip_h = art.flip_h
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
    _move_input = direction
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

func get_move_input() -> Vector2:
    return _move_input

func _clamp_to_arena() -> void:
    var view_size := get_viewport_rect().size
    var margin := 28.0
    global_position.x = clampf(global_position.x, margin, view_size.x - margin)
    global_position.y = clampf(global_position.y, margin, view_size.y - margin)

func set_wave_info(wave_no: int, chapter_no: int) -> void:
    _wave = wave_no
    _chapter = chapter_no

func set_hero_level(level: int) -> void:
    hero_level = maxi(1, level)

func get_skill_damage_mult() -> float:
    return 1.0 + SKILL_DAMAGE_PER_LEVEL * float(hero_level - 1)

func reset_for_run() -> void:
    is_dead = false
    max_health = 120
    health = 120
    move_speed = 360.0
    invuln_time = 0.0
    skill_cooldown_left = 0.0
    hit_flash = 0.0
    hero_level = 1
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
    var damage := int(round(float(80 + 8 * _wave + 15 * (_chapter - 1)) * get_skill_damage_mult()))
    var grenade = GRENADE_SCRIPT.new()
    grenade.z_index = 6
    get_tree().current_scene.add_child(grenade)
    grenade.global_position = global_position + facing * 24.0
    grenade.setup(target_pos, damage, SKILL_RADIUS, 1.5, SKILL_SLOW, SKILL_KNOCKBACK, SKILL_FUSE)
    skill_cooldown_left = SKILL_COOLDOWN
    var manager = get_node_or_null("WeaponManager")
    if manager != null and manager.has_method("set_overclock"):
        manager.set_overclock(4.0)
    Audio.play("chain", -10.0)
    ArtFX.flash_at(get_tree().current_scene, global_position, Color(0.40, 0.84, 0.74), 48.0, 0.2)
    Fx.ring(global_position, Color(0.42, 0.76, 0.64), 60.0, 0.32, 3.0)
    Fx.sparks(global_position, Color(0.52, 0.90, 0.78), 10, 180.0, 0.28)
    skill_cast.emit()
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
    take_damage_from(amount, Vector2.INF)

## 带来源的受击入口（新增，不改 take_damage 签名）：来源位置只用于画受击方向弧。
## 未知来源时传 Vector2.INF，内部退回"最近的敌人/弹体"估算。
func take_damage_from(amount: int, from_position: Vector2) -> void:
    if is_dead or invuln_time > 0.0:
        return
    health = maxi(0, health - amount)
    invuln_time = INVULN_TIME
    hit_flash = 0.15
    Audio.play("hurt", -8.0)
    Fx.damage_number(global_position + Vector2(0.0, -30.0), amount, Color("#fca5a5"))
    Fx.ring(global_position, Color("#fca5a5"), 38.0, 0.24, 2.5)
    Fx.sparks(global_position, Color("#fca5a5"), 7, 190.0, 0.26)
    _show_hurt_arc(from_position)
    Fx.shake(3.0, 0.1)
    Hitstop.request("player_hit")
    health_changed.emit(health, max_health)
    if health <= 0:
        _die()

func _show_hurt_arc(from_position: Vector2) -> void:
    if _hurt_arc == null:
        return
    var offset := Vector2.ZERO
    if from_position.is_finite():
        offset = from_position - global_position
    if offset.length() < HURT_ARC_MIN_DISTANCE:
        var threat := _nearest_threat_position()
        if threat.is_finite():
            offset = threat - global_position
    if offset.length_squared() < 0.01:
        offset = -facing
    _hurt_arc.begin(offset.normalized(), HURT_ARC_TIME)

func _nearest_threat_position() -> Vector2:
    var best := Vector2.INF
    var best_distance := 1.0e9
    for group in ["enemies", "enemy_projectile"]:
        for node in get_tree().get_nodes_in_group(group):
            if not is_instance_valid(node) or node.is_queued_for_deletion():
                continue
            if not (node is Node2D):
                continue
            var distance: float = global_position.distance_to(node.global_position)
            if distance < best_distance:
                best_distance = distance
                best = node.global_position
    return best

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
    Fx.burst(global_position, Color("#79cdb5"), 18)
    Fx.shock(global_position, Color("#79cdb5"), 90.0, 0.5)
    ArtFX.flash_at(get_tree().current_scene, global_position, Color("#79cdb5"), 120.0, 0.4)
    Fx.shake(12.0, 0.3)
    queue_redraw()
    died.emit()

func _draw() -> void:
    if is_dead:
        return
    var pulse := 0.5 + 0.5 * sin(_anim * 3.6)
    var spin := _anim * 0.32
    var gold := Color(0.788, 0.635, 0.153)
    # 外法阵：双层细金环（缓慢异向旋转），替代原「单圈断弧」的能量环造型
    draw_arc(Vector2.ZERO, 29.0, spin, spin + TAU * 0.74, 44, Color(gold.r, gold.g, gold.b, 0.26), 1.5, true)
    draw_arc(Vector2.ZERO, 33.5, -spin * 0.8, -spin * 0.8 + TAU * 0.46, 36, Color(gold.r, gold.g, gold.b, 0.13), 1.0, true)
    # 八方卦划（原为 4 条等分刻度线，读起来像仪表盘刻度）
    for index in range(8):
        var notch := -_anim * 0.5 + TAU * float(index) / 8.0
        var dir := Vector2.from_angle(notch)
        draw_line(dir * 30.5, dir * 35.0, Color(gold.r, gold.g, gold.b, 0.30), 1.4, true)
    # 内环：石绿灵气（呼吸）
    draw_arc(Vector2.ZERO, 22.0, -PI * 0.25 + _anim * 0.2, PI * 0.25 + _anim * 0.2, 28, Color(0.38, 0.74, 0.60, 0.28 + 0.16 * pulse), 2.0, true)
    if can_cast_skill():
        draw_arc(Vector2.ZERO, 36.0, -PI * 0.5, -PI * 0.5 + TAU * (0.55 + 0.1 * pulse), 48, Color(0.42, 0.76, 0.62, 0.07 + 0.08 * pulse), 2.5, true)

## 受击方向弧：屏幕边缘的一段红弧 + 指向内侧的箭头，0.25s 内线性淡出。
## 独立 CanvasLayer 承载，屏幕坐标绘制，因此既不进入世界 Camera2D 的屏震，也不被 z_index 遮挡。
class HurtArc extends Node2D:
    var life := 0.0
    var total := 0.25
    var direction := Vector2.RIGHT

    func begin(dir: Vector2, duration: float) -> void:
        direction = dir
        total = maxf(0.05, duration)
        life = total
        queue_redraw()

    func _process(delta: float) -> void:
        if life <= 0.0:
            return
        life = maxf(0.0, life - delta)
        queue_redraw()

    func _draw() -> void:
        if life <= 0.0:
            return
        var dir := direction.normalized()
        if dir.length_squared() < 0.5:
            return
        var view := get_viewport_rect().size
        var center := view * 0.5
        var half := view * 0.5
        var edge := 1.0e9
        if absf(dir.x) > 0.001:
            edge = minf(edge, half.x / absf(dir.x))
        if absf(dir.y) > 0.001:
            edge = minf(edge, half.y / absf(dir.y))
        var radius := maxf(60.0, edge - 38.0)
        var angle := dir.angle()
        var span := 0.5
        var alpha := pow(clampf(life / total, 0.0, 1.0), 0.75)
        var color := Color(0.97, 0.28, 0.28)
        # 外晕 + 主弧 + 内侧细弧，三层叠出"从那一侧打过来"的指向感
        draw_arc(center, radius, angle - span, angle + span, 28, Color(color.r, color.g, color.b, 0.16 * alpha), 13.0, true)
        draw_arc(center, radius, angle - span, angle + span, 28, Color(color.r, color.g, color.b, 0.88 * alpha), 5.0, true)
        draw_arc(center, radius - 9.0, angle - span * 0.6, angle + span * 0.6, 22, Color(color.r, color.g, color.b, 0.42 * alpha), 1.6, true)
        var tangent := Vector2.from_angle(angle + PI * 0.5)
        var base := center + Vector2.from_angle(angle) * (radius - 14.0)
        var tip := center + Vector2.from_angle(angle) * (radius - 28.0)
        draw_colored_polygon(
            PackedVector2Array([base + tangent * 10.0, base - tangent * 10.0, tip]),
            Color(color.r, color.g, color.b, 0.82 * alpha)
        )
