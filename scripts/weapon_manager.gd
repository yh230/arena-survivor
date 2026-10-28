extends Node2D

const UI := preload("res://scripts/ui_forge.gd")
const EMPLACEMENTS := [
    Vector2(783.0, 258.0),
    Vector2(783.0, 422.0),
    Vector2(640.0, 505.0),
    Vector2(497.0, 422.0),
    Vector2(497.0, 258.0),
    Vector2(640.0, 175.0),
]
const EMPLACEMENT_NAMES := ["东北台", "东南台", "南台", "西南台", "西北台", "北台"]
const WEAPON_DAMAGE_SCALE := 1.15
const OVERCLOCK_MULT := 1.30
const MAX_WEAPON_SLOTS := 6
const MAX_ITEM_SLOTS := 6
const MAX_QUALITY := 4
const QUALITY_NAMES := ["", "普通", "稀有", "史诗", "传说"]
const QUALITY_DAMAGE := [0.0, 1.0, 1.35, 1.8, 2.4]
const QUALITY_COOLDOWN := [0.0, 1.0, 0.92, 0.84, 0.76]
const WEAPON_ORDER := ["peony", "maple", "justice", "vigil", "hammer", "elixir"]
const CRIT_CHANCE := 0.12
const CRIT_MULT := 1.8
const WEAPON_DATA := {
    "peony": {"title": "牡丹炮台", "desc": "自动部署炮台", "legendary": "传说：炮台发射贯穿激光"},
    "maple": {"title": "枫叶环刃", "desc": "环绕飞刃", "legendary": "传说：环绕刃留下火焰轨迹"},
    "justice": {"title": "正义连锁", "desc": "连锁闪电", "legendary": "传说：连锁目标提升至 8 个"},
    "vigil": {"title": "守夜炮", "desc": "穿透射线", "legendary": "传说：射线穿透全部敌人"},
    "hammer": {"title": "爆裂重锤", "desc": "范围重击", "legendary": "传说：冲击范围扩大并增伤"},
    "elixir": {"title": "致命灵药", "desc": "持续毒雾", "legendary": "传说：毒雾范围扩大并增伤"},
}
const ITEM_ORDER := ["magnet", "boots", "holy_fire", "lucky_cat", "anvil", "jade"]
const ITEM_DATA := {
    "magnet": {"title": "磁铁", "desc": "拾取范围 +30/级"},
    "boots": {"title": "疾行靴", "desc": "移动速度 +22/级"},
    "holy_fire": {"title": "圣火", "desc": "生命上限 +20/级"},
    "lucky_cat": {"title": "招财猫", "desc": "售价 +8% / 金币 +4% 每级"},
    "anvil": {"title": "铁砧", "desc": "每级 1 次免费刷新 · 机关伤害 +6%"},
    "jade": {"title": "翡翠", "desc": "金币收益 +10%/级 · 暴击率 +4%/级"},
}

var player = null
var weapon_qualities := {}
var weapon_order: Array = []
var weapon_slots := {}
var slot_owners := {}
var item_qualities := {}
var item_order: Array = []
var wave_power := 1.0
var character_damage_mult := WEAPON_DAMAGE_SCALE
var overclock_time := 0.0
var item_stats_cache := {}

var turret_timer := 0.0
var turrets: Array = []
var orbiter_angle := 0.0
var orbiter_tick := 0.0
var orbiter_sfx_timer := 0.0
var orbiter_positions: Array[Vector2] = []
var trail_timer := 0.0
var fire_patches: Array = []
var chain_timer := 0.0
var chain_paths: Array = []
var chain_life := 0.0
var chain_total := 0.0
var pierce_timer := 0.0
var hammer_timer := 0.0
var hammer_effects: Array = []
var elixir_timer := 0.0
var poison_fields: Array = []
var beams: Array = []
var orbiter_glows: Array = []
var turret_glows: Array = []
var _deployed_weapons := {}

func _ready() -> void:
    player = get_parent()
    _refresh_item_cache()
    for _index in range(3):
        var glow := ArtFX.add_glow(self, Color(0.3, 0.95, 1.0), 26.0, 0.24, 1)
        glow.visible = false
        orbiter_glows.append(glow)
    for _index in range(2):
        var glow := ArtFX.add_glow(self, Color(0.45, 1.0, 1.0), 24.0, 0.22, 1)
        glow.visible = false
        turret_glows.append(glow)

func _process(delta: float) -> void:
    if player == null or player.is_dead:
        _hide_glows()
        return
    if not get_tree().paused:
        _announce_deployments()
    overclock_time = maxf(0.0, overclock_time - delta)
    _update_turrets(delta)
    _update_orbiter(delta)
    _update_chain(delta)
    _update_pierce(delta)
    _update_hammer(delta)
    _update_elixir(delta)
    _update_effects(delta)
    _sync_glows()
    queue_redraw()

func _hide_glows() -> void:
    for glow in orbiter_glows:
        glow.visible = false
    for glow in turret_glows:
        glow.visible = false

func _announce_deployments() -> void:
    for weapon_type in weapon_order:
        var quality := _q(weapon_type)
        var slot := get_weapon_slot(weapon_type)
        if slot < 0 or slot >= EMPLACEMENTS.size():
            continue
        if int(_deployed_weapons.get(weapon_type, -1)) == quality:
            continue
        var upgraded := _deployed_weapons.has(weapon_type)
        _deployed_weapons[weapon_type] = quality
        var quality_color := get_quality_color(quality)
        var at: Vector2 = EMPLACEMENTS[slot]
        Fx.ring(at, quality_color, 30.0 + 6.0 * float(quality), 0.38, 3.0)
        Fx.sparks(at, quality_color, 10, 170.0, 0.4)
        ArtFX.flash_at(get_tree().current_scene, at, quality_color, 42.0, 0.3)
        if upgraded:
            Fx.ring(at, Color(1.0, 0.85, 0.45), 50.0, 0.45, 2.0)

func _sync_glows() -> void:
    var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
    var orbiter_color := Color(1.0, 0.55, 0.22) if _legendary("maple") else Color(0.3, 0.95, 1.0)
    for index in range(orbiter_glows.size()):
        var glow: Sprite2D = orbiter_glows[index]
        if index < orbiter_positions.size():
            glow.visible = true
            glow.position = to_local(orbiter_positions[index])
            glow.modulate = Color(orbiter_color.r, orbiter_color.g, orbiter_color.b, 0.18 + pulse * 0.1)
        else:
            glow.visible = false

    var turret_color := Color(1.0, 0.45, 0.75) if _legendary("peony") else Color(0.45, 1.0, 1.0)
    for index in range(turret_glows.size()):
        var glow: Sprite2D = turret_glows[index]
        if index < turrets.size():
            glow.visible = true
            glow.position = to_local(turrets[index]["pos"])
            glow.modulate = Color(turret_color.r, turret_color.g, turret_color.b, 0.16 + pulse * 0.08)
        else:
            glow.visible = false

func _update_turrets(delta: float) -> void:
    var quality := _q("peony")
    if quality <= 0:
        return

    turret_timer -= delta
    if turret_timer <= 0.0:
        turret_timer = _turret_deploy_interval(quality)
        if turrets.size() < _turret_cap(quality):
            var anchor := _anchor_for("peony")
            var deploy_target = _nearest_enemy(anchor, _turret_range(quality))
            var deploy_pos := anchor + Vector2(0.0, 42.0)
            if deploy_target != null:
                deploy_pos = anchor + (deploy_target.global_position - anchor).normalized() * 34.0
            deploy_pos = Vector2(clampf(deploy_pos.x, 48.0, 1232.0), clampf(deploy_pos.y, 110.0, 520.0))
            turrets.append({
                "pos": deploy_pos,
                "life": _turret_lifetime(quality),
                "fire": 0.12,
                "aim": Vector2.UP,
                "deploy": 0.0,
                "recoil": 0.0,
            })
            var deploy_color := Color(1.0, 0.45, 0.75) if _legendary("peony") else Color(0.45, 1.0, 1.0)
            Fx.ring(deploy_pos, deploy_color, 30.0, 0.3, 2.5)
            Fx.sparks(deploy_pos, deploy_color, 6, 130.0, 0.26)

    for index in range(turrets.size() - 1, -1, -1):
        var turret: Dictionary = turrets[index]
        turret["life"] -= delta
        turret["fire"] -= delta
        turret["deploy"] = minf(1.0, float(turret.get("deploy", 1.0)) + delta * 4.0)
        turret["recoil"] = maxf(0.0, float(turret.get("recoil", 0.0)) - delta * 7.0)
        if turret["life"] <= 0.0:
            turrets.remove_at(index)
            continue
        if turret["fire"] <= 0.0:
            var target = _nearest_enemy(turret["pos"], _turret_range(quality))
            if target != null:
                _turret_fire(turret, target, quality)
                turret["fire"] = _turret_fire_interval(quality)

func _turret_fire(turret: Dictionary, target, quality: int) -> void:
    var from: Vector2 = turret["pos"]
    var to: Vector2 = target.global_position
    var aim := (to - from).normalized()
    turret["aim"] = aim
    turret["recoil"] = 1.0
    var damage := _turret_damage(quality)
    var flash_color := Color(1.0, 0.4, 0.72) if quality >= MAX_QUALITY else Color(0.45, 1.0, 1.0)
    if quality >= MAX_QUALITY:
        var end := from + aim * _turret_range(quality)
        var hits := _line_hits(from, end, 24.0, 99)
        for index in range(hits.size()):
            _damage_enemy(hits[index], damage)
            if index < 3:
                Fx.sparks(hits[index].global_position, flash_color, 5, 200.0, 0.22)
                Fx.ring(hits[index].global_position, flash_color, 18.0, 0.16, 2.0)
        _add_beam([from, end], flash_color, 7.0, 0.16)
        Fx.ring(from + aim * 20.0, flash_color, 28.0, 0.2, 3.0)
        Fx.shake(2.2, 0.08)
    else:
        _damage_enemy(target, damage)
        _add_beam([from, to], flash_color, 3.6, 0.12)
        Fx.sparks(to, flash_color, 6, 180.0, 0.22)
        Fx.ring(to, flash_color, 16.0, 0.16, 2.0)
    ArtFX.flash_at(get_tree().current_scene, from + aim * 22.0, flash_color, 26.0, 0.1)
    Audio.play("turret", -22.0)

func _update_orbiter(delta: float) -> void:
    var quality := _q("maple")
    if quality <= 0:
        orbiter_positions.clear()
        return

    orbiter_angle += _orbiter_speed(quality) * delta
    var blades := _orbiter_blade_count(quality)
    var anchor := _anchor_for("maple")
    orbiter_positions.clear()
    for index in range(blades):
        var angle := orbiter_angle + TAU * float(index) / float(blades)
        orbiter_positions.append(anchor + Vector2.from_angle(angle) * _orbiter_radius(quality))
    orbiter_sfx_timer = maxf(0.0, orbiter_sfx_timer - delta)

    orbiter_tick -= delta
    if orbiter_tick <= 0.0:
        orbiter_tick = _orbiter_tick_interval(quality)
        var hit_any := false
        var shake_done := false
        var blade_color := Color(1.0, 0.55, 0.2) if quality >= MAX_QUALITY else Color(0.3, 0.95, 1.0)
        for index in range(orbiter_positions.size()):
            var blade_position: Vector2 = orbiter_positions[index]
            var blade_angle := orbiter_angle + TAU * float(index) / float(maxi(1, orbiter_positions.size()))
            var hit_enemies: Array = _enemies_in_radius(blade_position, _orbiter_hit_radius(quality))
            if not hit_enemies.is_empty():
                ArtFX.flash_at(get_tree().current_scene, blade_position, blade_color, 16.0, 0.1)
                Fx.slash(blade_position, blade_angle + PI * 0.5, blade_color, 32.0, 0.16, PI * 0.72)
                Fx.sparks(blade_position, blade_color, 4, 160.0, 0.2)
            for enemy in hit_enemies:
                _damage_enemy(enemy, _orbiter_damage(quality))
                _apply_knockback(enemy, blade_position, 14.0)
                hit_any = true
                if not shake_done:
                    shake_done = true
                    Fx.shake(1.5, 0.06)
        if hit_any and orbiter_sfx_timer <= 0.0:
            Audio.play("orbiter", -26.0)
            orbiter_sfx_timer = 0.7

    if quality >= MAX_QUALITY:
        trail_timer -= delta
        if trail_timer <= 0.0:
            trail_timer = 0.55
            for blade_position in orbiter_positions:
                fire_patches.append({
                    "pos": blade_position,
                    "life": 2.6,
                    "tick": 0.15,
                })

func _update_chain(delta: float) -> void:
    var quality := _q("justice")
    if quality <= 0:
        return

    chain_timer -= delta
    if chain_timer > 0.0:
        return
    chain_timer = _chain_cooldown(quality)
    var anchor := _anchor_for("justice")
    var first = _nearest_enemy(anchor, _chain_range(quality))
    if first == null:
        return

    var targets := _chain_targets(first, quality)
    chain_paths.clear()
    var slow_factor := 0.55 if quality >= MAX_QUALITY else 0.7
    var previous := anchor
    for enemy in targets:
        var to: Vector2 = enemy.global_position
        chain_paths.append(_jagged_path(previous, to, 6, 17.0))
        if quality >= MAX_QUALITY:
            var branch_origin := previous.lerp(to, randf_range(0.3, 0.7))
            var branch_dir := (to - previous).normalized().orthogonal() * randf_range(-1.0, 1.0)
            chain_paths.append(_jagged_path(branch_origin, branch_origin + branch_dir * randf_range(24.0, 54.0), 3, 6.0))
        _damage_enemy(enemy, _chain_damage(quality))
        _apply_slow(enemy, 1.2, slow_factor)
        Fx.sparks(to, Color(0.55, 1.0, 1.0), 5, 170.0, 0.2)
        Fx.ring(to, Color(0.55, 1.0, 1.0), 17.0, 0.16, 2.0)
        previous = to
    chain_life = 0.3
    chain_total = 0.3
    Fx.ring(anchor, Color(0.55, 1.0, 1.0), 22.0, 0.2, 2.5)
    Fx.shake(2.0, 0.08)
    Audio.play("chain", -18.0)

func _chain_targets(first, quality: int) -> Array:
    var targets: Array = [first]
    var current = first
    for _index in range(1, _chain_count(quality)):
        var next = _nearest_enemy_excluding(current.global_position, _chain_jump(quality), targets)
        if next == null:
            break
        targets.append(next)
        current = next
    return targets

func _update_pierce(delta: float) -> void:
    var quality := _q("vigil")
    if quality <= 0:
        return

    pierce_timer -= delta
    if pierce_timer > 0.0:
        return
    pierce_timer = _pierce_cooldown(quality)

    var start: Vector2 = _anchor_for("vigil")
    var target = _nearest_enemy(start, _pierce_range(quality))
    var direction: Vector2 = player.facing
    if target != null:
        direction = (target.global_position - start).normalized()
    if direction.length_squared() < 0.01:
        direction = Vector2.RIGHT
    var end := start + direction * _pierce_range(quality)
    var mark_bonus := 0.30 if quality >= MAX_QUALITY else 0.20
    var color := Color(0.55, 0.85, 1.0, 0.9)
    if quality >= MAX_QUALITY:
        color = Color(0.85, 0.8, 1.0, 0.95)
    var hits := _line_hits(start, end, _pierce_width(quality), _pierce_count(quality))
    for enemy in hits:
        _damage_enemy(enemy, _pierce_damage(quality))
        _apply_mark(enemy, 2.0, mark_bonus)
        Fx.sparks(enemy.global_position, color, 5, 200.0, 0.2)
    _add_beam([start, end], color, 6.0 if quality >= MAX_QUALITY else 5.0, 0.2)
    Fx.ring(start + direction * 24.0, color, 32.0, 0.22, 2.5)
    Fx.sparks(end, color, 6, 140.0, 0.24)
    Fx.shake(2.2, 0.08)
    ArtFX.flash_at(get_tree().current_scene, start + direction * 34.0, color, 30.0, 0.12)
    Audio.play("pierce", -18.0)

func _update_hammer(delta: float) -> void:
    var quality := _q("hammer")
    if quality <= 0:
        return
    hammer_timer -= delta
    if hammer_timer > 0.0:
        return
    hammer_timer = 2.2 * QUALITY_COOLDOWN[quality]
    var anchor := _anchor_for("hammer")
    var target = _nearest_enemy(anchor, _hammer_target_range(quality))
    var impact: Vector2 = anchor + player.facing * 120.0
    if target != null:
        impact = target.global_position
    var radius := _hammer_radius(quality)
    var damage := int(20.0 * QUALITY_DAMAGE[quality])
    if quality >= MAX_QUALITY:
        damage = int(float(damage) * 1.5)
    for enemy in _enemies_in_radius(impact, radius):
        _damage_enemy(enemy, damage)
        _apply_knockback(enemy, impact, 35.0)
        _apply_stun(enemy, 0.4)
    hammer_effects.append({
        "pos": impact,
        "life": 0.46,
        "max_life": 0.46,
        "radius": radius,
        "cracks": _make_cracks(radius),
    })
    Fx.shock(impact, Color(1.0, 0.8, 0.38), radius * 1.05, 0.45)
    Fx.ring(impact, Color(1.0, 0.9, 0.55), radius * 0.55, 0.28, 4.0)
    Fx.sparks(impact, Color(0.95, 0.7, 0.35), 14, 300.0, 0.4)
    ArtFX.flash_at(get_tree().current_scene, impact, Color(1.0, 0.75, 0.3), radius * 0.9, 0.22)
    Fx.shake(6.5, 0.16)
    Audio.play("explode", -18.0)

func _update_elixir(delta: float) -> void:
    var quality := _q("elixir")
    if quality <= 0:
        return
    elixir_timer -= delta
    if elixir_timer > 0.0:
        return
    elixir_timer = 2.6 * QUALITY_COOLDOWN[quality]
    var anchor := _anchor_for("elixir")
    var target = _nearest_enemy(anchor, _elixir_target_range(quality))
    var pos: Vector2 = anchor + player.facing * 120.0
    if target != null:
        pos = target.global_position
    var radius := _elixir_radius(quality)
    var damage := int(5.0 * QUALITY_DAMAGE[quality])
    if quality >= MAX_QUALITY:
        damage = int(9.0 * QUALITY_DAMAGE[quality])
    poison_fields.append({
        "pos": pos,
        "life": 4.0,
        "max_life": 4.0,
        "tick": 0.15,
        "radius": radius,
        "damage": damage,
        "seed": randf() * TAU,
    })
    Fx.ring(pos, Color(0.45, 1.0, 0.35), radius * 0.8, 0.3, 3.0)
    Fx.sparks(pos, Color(0.5, 1.0, 0.4), 8, 130.0, 0.34)
    ArtFX.flash_at(get_tree().current_scene, pos, Color(0.45, 1.0, 0.35), radius * 0.7, 0.24)
    Audio.play("orbiter", -24.0)

func _update_effects(delta: float) -> void:
    for index in range(beams.size() - 1, -1, -1):
        beams[index]["life"] -= delta
        if beams[index]["life"] <= 0.0:
            beams.remove_at(index)

    if chain_life > 0.0:
        chain_life -= delta
        if chain_life <= 0.0:
            chain_paths.clear()

    for index in range(fire_patches.size() - 1, -1, -1):
        var patch: Dictionary = fire_patches[index]
        patch["life"] -= delta
        patch["tick"] -= delta
        if patch["tick"] <= 0.0:
            patch["tick"] = 0.32
            for enemy in _enemies_in_radius(patch["pos"], 30.0):
                _damage_enemy(enemy, 4)
        if patch["life"] <= 0.0:
            fire_patches.remove_at(index)

    for index in range(hammer_effects.size() - 1, -1, -1):
        hammer_effects[index]["life"] -= delta
        if hammer_effects[index]["life"] <= 0.0:
            hammer_effects.remove_at(index)

    for index in range(poison_fields.size() - 1, -1, -1):
        var field: Dictionary = poison_fields[index]
        field["life"] -= delta
        field["tick"] -= delta
        if field["tick"] <= 0.0:
            field["tick"] = 0.5
            var hit_any := false
            for enemy in _enemies_in_radius(field["pos"], field["radius"]):
                _damage_enemy(enemy, field["damage"])
                _apply_slow(enemy, 0.6, 0.7)
                hit_any = true
            if hit_any:
                Fx.sparks(field["pos"] + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0)), Color(0.5, 1.0, 0.4), 3, 90.0, 0.3)
        if field["life"] <= 0.0:
            poison_fields.remove_at(index)

func _add_beam(points: Array, color: Color, width: float, life: float) -> void:
    beams.append({"points": points, "color": color, "width": width, "life": life, "max_life": maxf(0.01, life)})

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

func _nearest_enemy_excluding(from: Vector2, max_range: float, excluded: Array):
    var best = null
    var best_distance := max_range
    for node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            continue
        if excluded.has(node):
            continue
        var distance: float = from.distance_to(node.global_position)
        if distance < best_distance:
            best_distance = distance
            best = node
    return best

func _enemies_in_radius(center: Vector2, radius: float) -> Array:
    var result: Array = []
    for node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            continue
        if center.distance_to(node.global_position) <= radius:
            result.append(node)
    return result

func _line_hits(start: Vector2, end: Vector2, width: float, limit: int) -> Array:
    var candidates: Array = []
    for node in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(node) or node.is_queued_for_deletion():
            continue
        var closest := Geometry2D.get_closest_point_to_segment(node.global_position, start, end)
        if node.global_position.distance_to(closest) <= width:
            candidates.append({
                "enemy": node,
                "distance": start.distance_to(closest),
            })
    candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
    var result: Array = []
    for index in range(min(limit, candidates.size())):
        result.append(candidates[index]["enemy"])
    return result

func _jagged_path(from: Vector2, to: Vector2, segments: int, amplitude: float) -> PackedVector2Array:
    var path := PackedVector2Array()
    var safe_segments := maxi(2, segments)
    var normal := (to - from).normalized().orthogonal()
    for index in range(safe_segments + 1):
        var ratio := float(index) / float(safe_segments)
        var offset := 0.0
        if index > 0 and index < safe_segments:
            offset = randf_range(-amplitude, amplitude)
        path.append(from.lerp(to, ratio) + normal * offset)
    return path

func _make_cracks(radius: float) -> Array:
    var cracks: Array = []
    for index in range(8):
        var angle := TAU * float(index) / 8.0 + randf_range(-0.26, 0.26)
        var p0 := Vector2.from_angle(angle) * radius * randf_range(0.08, 0.22)
        var p1 := Vector2.from_angle(angle + randf_range(-0.22, 0.22)) * radius * randf_range(0.42, 0.66)
        var p2 := Vector2.from_angle(angle + randf_range(-0.34, 0.34)) * radius * randf_range(0.82, 1.0)
        cracks.append(PackedVector2Array([p0, p1, p2]))
    return cracks

func _damage_enemy(enemy, base_damage: int) -> void:
    if enemy == null or not is_instance_valid(enemy):
        return
    var crit_chance := CRIT_CHANCE + float(item_stats_cache.get("crit_bonus", 0.0))
    var is_crit := randf() < crit_chance
    var scale := character_damage_mult * float(item_stats_cache.get("weapon_damage_mult", 1.0))
    if overclock_time > 0.0:
        scale *= OVERCLOCK_MULT
    var amount := int(round(float(base_damage) * wave_power * scale * (CRIT_MULT if is_crit else 1.0)))
    if enemy.has_method("take_damage"):
        enemy.take_damage(amount, is_crit)

func _apply_slow(enemy, duration: float, factor: float) -> void:
    if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_slow"):
        enemy.apply_slow(duration, factor)

func _apply_stun(enemy, duration: float) -> void:
    if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_stun"):
        enemy.apply_stun(duration)

func _apply_mark(enemy, duration: float, bonus: float) -> void:
    if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_mark"):
        enemy.apply_mark(duration, bonus)

func _apply_knockback(enemy, origin: Vector2, distance: float) -> void:
    if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("apply_knockback"):
        return
    enemy.apply_knockback(enemy.global_position - origin, distance)

func _power_for(wave_no: int, chapter_no: int) -> float:
    return 1.0 + 0.05 * float(wave_no - 1) + 0.12 * float(chapter_no - 1)

func set_wave_power(wave_no: int, chapter_no: int) -> void:
    wave_power = _power_for(wave_no, chapter_no)

func _damage_with_roll(base_damage: int, roll: float) -> int:
    var multiplier := CRIT_MULT if roll < CRIT_CHANCE else 1.0
    return int(round(float(base_damage) * wave_power * multiplier))

func _orbiter_blade_count(quality: int) -> int:
    var blades := 1
    if quality >= 2:
        blades += 1
    if quality >= MAX_QUALITY:
        blades += 1
    return blades

func _turret_cap(quality: int) -> int:
    return 2 if quality >= 3 else 1

func _draw_emplacements() -> void:
    var font := UI.regular_font()
    var now := float(Time.get_ticks_msec()) * 0.001
    for index in range(EMPLACEMENTS.size()):
        var pos := to_local(EMPLACEMENTS[index])
        var owner := str(slot_owners.get(index, ""))
        var owned := owner != ""
        var quality := _q(owner)
        var accent := get_quality_color(quality) if owned else Color(0.82, 0.7, 0.44)
        var pulse := 0.5 + 0.5 * sin(now * 1.7 + float(index) * 1.3)

        draw_circle(pos + Vector2(0.0, 7.0), 29.0, Color(0.0, 0.0, 0.0, 0.26))
        var plate := PackedVector2Array()
        for corner in range(8):
            plate.append(pos + Vector2.from_angle(TAU * float(corner) / 8.0 + PI / 8.0) * 28.0)
        draw_colored_polygon(plate, Color(0.045, 0.075, 0.082, 0.9))
        var outline := plate.duplicate()
        outline.append(plate[0])
        draw_polyline(outline, Color(0.85, 0.71, 0.42, 0.38 if owned else 0.16), 1.5, true)

        draw_circle(pos, 22.0, Color(0.02, 0.045, 0.05, 0.94))
        draw_arc(pos, 22.0, 0.0, TAU, 40, Color(0.85, 0.71, 0.42, 0.42 if owned else 0.18), 1.0, true)
        for bolt in range(4):
            var bolt_angle := TAU * float(bolt) / 4.0 + PI / 4.0
            draw_circle(pos + Vector2.from_angle(bolt_angle) * 24.0, 1.8, Color(0.85, 0.71, 0.42, 0.55 if owned else 0.22))

        if not owned:
            draw_line(pos + Vector2(-5.0, 0.0), pos + Vector2(5.0, 0.0), Color(0.6, 0.75, 0.74, 0.22), 1.0, true)
            draw_line(pos + Vector2(0.0, -5.0), pos + Vector2(0.0, 5.0), Color(0.6, 0.75, 0.74, 0.22), 1.0, true)
        else:
            var spin := now * 0.45 * (1.0 if index % 2 == 0 else -1.0)
            for tooth in range(12):
                var tooth_angle := spin + TAU * float(tooth) / 12.0
                draw_line(
                    pos + Vector2.from_angle(tooth_angle) * 23.0,
                    pos + Vector2.from_angle(tooth_angle) * 26.5,
                    Color(accent.r, accent.g, accent.b, 0.34 + pulse * 0.18), 1.4, true
                )
            draw_circle(pos, 17.0, Color(accent.r, accent.g, accent.b, 0.09 + pulse * 0.04))
            draw_arc(pos, 17.0 + pulse * 1.5, 0.0, TAU, 36, Color(accent.r, accent.g, accent.b, 0.45), 2.0, true)
            draw_circle(pos, 3.5, accent.lightened(0.25))
            draw_string(font, pos + Vector2(-20.0, 6.0), _weapon_glyph(owner), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 15, accent.lightened(0.2))

            var range_radius := _weapon_range(owner, quality)
            draw_arc(pos, range_radius, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.055), 1.0, true)
            for tick in range(4):
                var tick_angle := spin + TAU * float(tick) / 4.0
                draw_line(
                    pos + Vector2.from_angle(tick_angle) * (range_radius - 6.0),
                    pos + Vector2.from_angle(tick_angle) * range_radius,
                    Color(accent.r, accent.g, accent.b, 0.14), 1.0, true
                )

        var plate_pos := pos + Vector2(-28.0, 34.0)
        draw_rect(Rect2(plate_pos, Vector2(56.0, 14.0)), Color(0.015, 0.035, 0.04, 0.78))
        draw_rect(Rect2(plate_pos, Vector2(56.0, 14.0)), Color(accent.r, accent.g, accent.b, 0.3 if owned else 0.13), false, 1.0)
        draw_string(font, plate_pos + Vector2(0.0, 11.0), str(EMPLACEMENT_NAMES[index]), HORIZONTAL_ALIGNMENT_CENTER, 56.0, 9, Color(0.8, 0.9, 0.89, 0.55 if owned else 0.3))

func _draw() -> void:
    _draw_emplacements()

    for beam in beams:
        var points: Array = beam["points"]
        var life_left := float(beam["life"])
        var total := float(beam.get("max_life", maxf(0.01, life_left)))
        var fade := clampf(life_left / total, 0.0, 1.0)
        var col: Color = beam["color"]
        var beam_width := float(beam["width"])
        for index in range(points.size() - 1):
            var head := to_local(points[index])
            var tail := to_local(points[index + 1])
            draw_line(head, tail, Color(col.r, col.g, col.b, col.a * 0.16 * fade), beam_width * 3.4, true)
            draw_line(head, tail, Color(col.r, col.g, col.b, col.a * 0.82 * fade), beam_width, true)
            draw_line(head, tail, Color(1.0, 1.0, 1.0, 0.9 * fade), maxf(1.0, beam_width * 0.38), true)
        var tip := to_local(points[points.size() - 1])
        draw_circle(tip, beam_width * 1.5, Color(col.r, col.g, col.b, 0.42 * fade))

    var now := float(Time.get_ticks_msec()) * 0.001
    for turret in turrets:
        var pos := to_local(turret["pos"])
        var aim: Vector2 = turret.get("aim", Vector2.UP)
        var quality := _q("peony")
        var body := Color("#67e8f9")
        if _legendary("peony"):
            body = Color("#f472b6")
        var trim := Color(0.85, 0.71, 0.42, 0.78)
        var deploy := clampf(float(turret.get("deploy", 1.0)), 0.0, 1.0)
        var recoil := clampf(float(turret.get("recoil", 0.0)), 0.0, 1.0)
        var body_scale := 0.55 + 0.45 * deploy
        var life_ratio := clampf(float(turret["life"]) / _turret_lifetime(quality), 0.0, 1.0)
        var base := pos - aim * recoil * 4.0

        draw_circle(pos + Vector2(0.0, 10.0), 16.0 * body_scale, Color(0.0, 0.0, 0.0, 0.28))
        var plate := PackedVector2Array()
        for corner in range(8):
            plate.append(base + Vector2.from_angle(TAU * float(corner) / 8.0 + PI / 8.0) * 17.0 * body_scale)
        draw_colored_polygon(plate, Color(0.045, 0.11, 0.12, 0.98))
        var outline := plate.duplicate()
        outline.append(plate[0])
        draw_polyline(outline, trim, 1.5, true)
        draw_circle(base, 12.5 * body_scale, Color(0.02, 0.075, 0.085, 0.98))
        draw_arc(base, 12.5 * body_scale, 0.0, TAU, 28, Color(body.r, body.g, body.b, 0.85), 2.0 * body_scale, true)
        for bolt in range(4):
            var bolt_angle := TAU * float(bolt) / 4.0 + PI / 4.0
            draw_circle(base + Vector2.from_angle(bolt_angle) * 14.5 * body_scale, 1.8 * body_scale, trim)
        for tooth in range(6):
            var tooth_angle := now * 0.9 + TAU * float(tooth) / 6.0
            draw_line(
                base + Vector2.from_angle(tooth_angle) * 10.0 * body_scale,
                base + Vector2.from_angle(tooth_angle) * 14.0 * body_scale,
                Color(trim.r, trim.g, trim.b, 0.55), 2.0 * body_scale, true
            )

        var barrel := base + aim * (20.0 * body_scale - recoil * 3.0)
        draw_line(base, barrel, Color(0.02, 0.07, 0.08, 1.0), 8.0 * body_scale, true)
        draw_line(base, barrel, body.darkened(0.12), 5.5 * body_scale, true)
        draw_line(base, barrel, body.lightened(0.4), 1.8 * body_scale, true)
        draw_circle(barrel, 4.0 * body_scale, body.lightened(0.35))
        if recoil > 0.45:
            draw_circle(barrel, 6.5 * recoil, Color(1.0, 1.0, 1.0, 0.45 * recoil))
            draw_circle(barrel, 10.5 * recoil, Color(body.r, body.g, body.b, 0.24 * recoil))

        draw_circle(base, 6.0 * body_scale, Color("#0d9488"))
        draw_circle(base, 3.0 * body_scale, Color("#ecfeff"))
        draw_arc(base, 15.5 * body_scale, -PI * 0.5, -PI * 0.5 + TAU * life_ratio, 32, Color(body.r, body.g, body.b, 0.55), 2.0 * body_scale, true)
        if deploy < 1.0:
            draw_arc(base, 18.0 + 14.0 * (1.0 - deploy), 0.0, TAU, 32, Color(body.r, body.g, body.b, 0.5 * (1.0 - deploy)), 2.0, true)

    if _q("maple") > 0:
        var orbiter_color := Color("#f97316") if _legendary("maple") else Color("#22d3ee")
        var anchor_local := to_local(_anchor_for("maple"))
        draw_arc(anchor_local, _orbiter_radius(_q("maple")), 0.0, TAU, 64, Color(orbiter_color.r, orbiter_color.g, orbiter_color.b, 0.08), 1.0, true)
        for index in range(orbiter_positions.size()):
            var blade_position: Vector2 = orbiter_positions[index]
            var orbiter_pos := to_local(blade_position)
            var blade_angle := orbiter_angle + TAU * float(index) / float(maxi(1, orbiter_positions.size()))
            var tangent := blade_angle + PI * 0.5
            var forward := Vector2.from_angle(tangent)
            var radial := Vector2.from_angle(blade_angle)
            for trail in range(3):
                var trail_pos := orbiter_pos - forward * (6.0 + float(trail) * 5.5)
                draw_arc(
                    trail_pos, 9.0 - float(trail) * 1.5, tangent - 1.5, tangent + 1.5, 12,
                    Color(orbiter_color.r, orbiter_color.g, orbiter_color.b, 0.22 - float(trail) * 0.06), 2.0, true
                )
            draw_arc(orbiter_pos, 12.0, tangent - 1.9, tangent + 1.9, 20, Color(orbiter_color.r, orbiter_color.g, orbiter_color.b, 0.22), 7.0, true)
            draw_arc(orbiter_pos, 12.0, tangent - 1.9, tangent + 1.9, 20, orbiter_color, 3.2, true)
            draw_arc(orbiter_pos, 12.0, tangent - 1.15, tangent + 1.15, 16, Color(1.0, 1.0, 1.0, 0.9), 1.0, true)
            draw_line(orbiter_pos - radial * 5.0, orbiter_pos + radial * 6.0, Color(0.03, 0.12, 0.16, 0.9), 3.0, true)
            draw_circle(orbiter_pos + radial * 2.0, 3.0, Color("#ecfeff"))

    for patch in fire_patches:
        var patch_pos := to_local(patch["pos"])
        var alpha: float = clampf(float(patch["life"]) / 2.6, 0.0, 1.0)
        draw_circle(patch_pos, 31.0, Color(1.0, 0.32, 0.04, 0.09 * alpha))
        draw_circle(patch_pos, 22.0, Color(1.0, 0.48, 0.08, 0.10 * alpha))
        for flame in range(3):
            var sway := Vector2(sin(now * 6.0 + float(flame) * 2.1) * 5.0, -4.0 + sin(now * 4.0 + float(flame)) * 3.0)
            draw_circle(patch_pos + sway, 9.0 - float(flame) * 2.2, Color(1.0, 0.55 + 0.1 * float(flame), 0.12, 0.28 * alpha))
        var tip := patch_pos + Vector2(sin(now * 7.0) * 3.0, -18.0 - 5.0 * sin(now * 3.0 + patch_pos.x * 0.01))
        draw_colored_polygon(
            PackedVector2Array([patch_pos + Vector2(-6.0, 2.0), tip, patch_pos + Vector2(6.0, 2.0)]),
            Color(1.0, 0.62, 0.16, 0.22 * alpha)
        )

    for effect in hammer_effects:
        var effect_pos := to_local(effect["pos"])
        var total := float(effect.get("max_life", 0.46))
        var progress: float = 1.0 - clampf(float(effect["life"]) / total, 0.0, 1.0)
        var fade: float = clampf(float(effect["life"]) / total * 1.8, 0.0, 1.0)
        var effect_radius := float(effect["radius"])
        for crack in effect.get("cracks", []):
            var local_crack := PackedVector2Array()
            for point in crack:
                local_crack.append(effect_pos + point)
            draw_polyline(local_crack, Color(0.05, 0.03, 0.02, 0.62 * fade), 3.0, true)
            draw_polyline(local_crack, Color(1.0, 0.62, 0.22, 0.3 * fade), 1.2, true)
        var shock_radius := effect_radius * (1.0 - pow(1.0 - progress, 2.0))
        draw_arc(effect_pos, shock_radius, 0.0, TAU, 64, Color(1.0, 0.82, 0.4, 0.52 * fade), 5.0 * (1.0 - progress) + 1.0, true)
        draw_arc(effect_pos, shock_radius * 0.62, 0.0, TAU, 48, Color(1.0, 0.9, 0.6, 0.3 * fade), 2.0, true)
        draw_circle(effect_pos, effect_radius * (0.16 + 0.32 * progress), Color(1.0, 0.6, 0.25, 0.06 * fade))

    for field in poison_fields:
        var field_pos := to_local(field["pos"])
        var alpha: float = clampf(float(field["life"]) / 4.0, 0.0, 1.0)
        var field_radius := float(field["radius"])
        var seed := float(field.get("seed", 0.0))
        draw_circle(field_pos, field_radius, Color(0.3, 0.75, 0.22, 0.08 * alpha))
        for blob in range(4):
            var blob_angle := TAU * float(blob) / 4.0 + now * 0.45 + seed
            var blob_distance := field_radius * 0.36 * (0.72 + 0.28 * sin(now * 1.5 + float(blob)))
            draw_circle(field_pos + Vector2.from_angle(blob_angle) * blob_distance, field_radius * 0.34, Color(0.36, 0.95, 0.3, 0.10 * alpha))
        for dash in range(20):
            var dash_angle := TAU * float(dash) / 20.0 + now * 0.1
            draw_arc(field_pos, field_radius, dash_angle, dash_angle + 0.17, 6, Color(0.45, 1.0, 0.35, 0.3 * alpha), 2.0, true)
        for bubble in range(6):
            var bubble_angle := TAU * float(bubble) / 6.0 + seed
            var bubble_distance := field_radius * 0.55 * float(bubble % 3 + 1) / 3.0
            var rise := fposmod(now * 16.0 + float(bubble) * 11.0, field_radius * 0.9)
            var bubble_pos := field_pos + Vector2.from_angle(bubble_angle) * bubble_distance + Vector2(0.0, field_radius * 0.45 - rise)
            draw_circle(bubble_pos, 1.5 + float(bubble % 2), Color(0.55, 1.0, 0.4, 0.42 * alpha))

    if chain_life > 0.0 and not chain_paths.is_empty():
        var flicker := 0.72 + 0.28 * sin(now * 50.0)
        var chain_alpha: float = clampf(chain_life / maxf(0.01, chain_total), 0.0, 1.0) * flicker
        for path in chain_paths:
            var local_path := PackedVector2Array()
            for point in path:
                local_path.append(to_local(point))
            draw_polyline(local_path, Color(0.25, 1.0, 1.0, 0.16 * chain_alpha), 14.0, true)
            draw_polyline(local_path, Color(0.55, 1.0, 1.0, 0.78 * chain_alpha), 4.2, true)
            draw_polyline(local_path, Color(0.92, 1.0, 1.0, 0.95 * chain_alpha), 1.8, true)
            var end_point: Vector2 = local_path[local_path.size() - 1]
            draw_circle(end_point, 4.5, Color(0.7, 1.0, 1.0, 0.85 * chain_alpha))

func _q(weapon_type: String) -> int:
    return int(weapon_qualities.get(weapon_type, 0))

func _legendary(weapon_type: String) -> bool:
    return _q(weapon_type) >= MAX_QUALITY

func _turret_damage(quality: int) -> int:
    var damage := int(10.0 * QUALITY_DAMAGE[quality])
    return int(15.0 * QUALITY_DAMAGE[quality]) if quality >= MAX_QUALITY else damage

func _turret_deploy_interval(quality: int) -> float:
    return 5.0 * QUALITY_COOLDOWN[quality]

func _turret_fire_interval(quality: int) -> float:
    return (0.8 if quality >= MAX_QUALITY else 0.9) * QUALITY_COOLDOWN[quality]

func _turret_lifetime(quality: int) -> float:
    return 8.0 + float(quality) * 0.5

func _turret_range(quality: int) -> float:
    return 620.0 if quality >= MAX_QUALITY else 420.0 + float(quality) * 30.0

func _orbiter_radius(quality: int) -> float:
    return 150.0 + float(quality - 1) * 15.0

func _orbiter_speed(_quality: int) -> float:
    return 3.2

func _orbiter_tick_interval(quality: int) -> float:
    return 0.4 * QUALITY_COOLDOWN[quality]

func _orbiter_damage(quality: int) -> int:
    return int(8.0 * QUALITY_DAMAGE[quality])

func _orbiter_hit_radius(quality: int) -> float:
    return 28.0 + float(quality - 1) * 4.0

func _chain_count(quality: int) -> int:
    return 8 if quality >= MAX_QUALITY else 2 + quality

func _chain_jump(quality: int) -> float:
    return 240.0 if quality >= MAX_QUALITY else 180.0 + float(quality - 1) * 30.0

func _chain_damage(quality: int) -> int:
    return int(12.0 * QUALITY_DAMAGE[quality])

func _chain_cooldown(quality: int) -> float:
    return (1.8 if quality >= MAX_QUALITY else 2.2) * QUALITY_COOLDOWN[quality]

func _chain_range(quality: int) -> float:
    return 420.0 + float(quality) * 40.0

func _pierce_damage(quality: int) -> int:
    return int((30.0 if quality >= MAX_QUALITY else 18.0) * QUALITY_DAMAGE[quality])

func _pierce_count(quality: int) -> int:
    return 99 if quality >= MAX_QUALITY else 2 + quality

func _pierce_cooldown(quality: int) -> float:
    return (1.8 if quality >= MAX_QUALITY else 1.5) * QUALITY_COOLDOWN[quality]

func _pierce_range(quality: int) -> float:
    return 900.0 if quality >= MAX_QUALITY else 600.0 + float(quality) * 50.0

func _pierce_width(quality: int) -> float:
    return 16.0 if quality >= MAX_QUALITY else 18.0

func _hammer_target_range(quality: int) -> float:
    return 260.0 + float(quality - 1) * 25.0

func _hammer_radius(quality: int) -> float:
    return 160.0 if quality >= MAX_QUALITY else 85.0 + float(quality - 1) * 15.0

func _elixir_target_range(quality: int) -> float:
    return 480.0 + float(quality - 1) * 20.0

func _elixir_radius(quality: int) -> float:
    return 115.0 if quality >= MAX_QUALITY else 65.0 + float(quality - 1) * 15.0

func _weapon_range(weapon_type: String, quality: int) -> float:
    match weapon_type:
        "peony":
            return _turret_range(quality)
        "maple":
            return _orbiter_radius(quality) + _orbiter_hit_radius(quality)
        "justice":
            return _chain_range(quality)
        "vigil":
            return _pierce_range(quality)
        "hammer":
            return _hammer_target_range(quality) + _hammer_radius(quality)
        "elixir":
            return _elixir_target_range(quality) + _elixir_radius(quality)
        _:
            return 0.0

func _weapon_glyph(weapon_type: String) -> String:
    match weapon_type:
        "peony":
            return "炮"
        "maple":
            return "刃"
        "justice":
            return "链"
        "vigil":
            return "穿"
        "hammer":
            return "锤"
        "elixir":
            return "毒"
        _:
            return ""

func _first_empty_slot() -> int:
    for index in range(EMPLACEMENTS.size()):
        if not slot_owners.has(index):
            return index
    return -1

func _anchor_for(weapon_type: String) -> Vector2:
    var slot := int(weapon_slots.get(weapon_type, -1))
    if slot >= 0 and slot < EMPLACEMENTS.size():
        return EMPLACEMENTS[slot]
    if player != null and is_instance_valid(player):
        return player.global_position
    return Vector2.ZERO

func get_emplacement_count() -> int:
    return EMPLACEMENTS.size()

func get_emplacement_position(index: int) -> Vector2:
    if index < 0 or index >= EMPLACEMENTS.size():
        return Vector2.ZERO
    return EMPLACEMENTS[index]

func get_weapon_slot(weapon_type: String) -> int:
    return int(weapon_slots.get(weapon_type, -1))

func get_slot_name(weapon_type: String) -> String:
    var slot := get_weapon_slot(weapon_type)
    if slot < 0 or slot >= EMPLACEMENT_NAMES.size():
        return ""
    return str(EMPLACEMENT_NAMES[slot])

func get_next_emplacement_name() -> String:
    var slot := _first_empty_slot()
    if slot < 0:
        return "无空位"
    return str(EMPLACEMENT_NAMES[slot])

func set_character_damage_mult(value: float) -> void:
    character_damage_mult = maxf(0.0, value)

func get_weapon_damage_scale() -> float:
    return character_damage_mult

func set_overclock(duration: float) -> void:
    overclock_time = maxf(overclock_time, duration)
    for index in slot_owners.keys():
        ArtFX.flash_at(get_tree().current_scene, EMPLACEMENTS[int(index)], Color(1.0, 0.78, 0.3), 46.0, 0.24)

func reset_build() -> void:
    weapon_qualities.clear()
    weapon_order.clear()
    weapon_slots.clear()
    slot_owners.clear()
    item_qualities.clear()
    item_order.clear()
    overclock_time = 0.0
    turret_timer = 0.0
    orbiter_angle = 0.0
    orbiter_tick = 0.0
    trail_timer = 0.0
    chain_timer = 0.0
    chain_life = 0.0
    pierce_timer = 0.0
    hammer_timer = 0.0
    elixir_timer = 0.0
    _deployed_weapons.clear()
    _clear_transient_effects()
    item_stats_cache = get_item_stats()

func _clear_transient_effects() -> void:
    turrets.clear()
    fire_patches.clear()
    poison_fields.clear()
    hammer_effects.clear()
    beams.clear()
    chain_paths.clear()
    orbiter_positions.clear()
    chain_life = 0.0
    chain_total = 0.0

func get_weapon_types() -> Array:
    return WEAPON_ORDER.duplicate()

func get_item_ids() -> Array:
    return ITEM_ORDER.duplicate()

func get_quality_name(quality: int) -> String:
    if quality < 1 or quality >= QUALITY_NAMES.size():
        return ""
    return QUALITY_NAMES[quality]

func get_quality_color(quality: int) -> Color:
    match quality:
        1:
            return Color("#9ca3af")
        2:
            return Color("#60a5fa")
        3:
            return Color("#c084fc")
        4:
            return Color("#fbbf24")
        _:
            return Color.WHITE

func get_weapon_title(weapon_type: String) -> String:
    if not WEAPON_DATA.has(weapon_type):
        return ""
    return WEAPON_DATA[weapon_type]["title"]

func get_weapon_desc(weapon_type: String) -> String:
    if not WEAPON_DATA.has(weapon_type):
        return ""
    return WEAPON_DATA[weapon_type]["desc"]

func get_weapon_legendary_desc(weapon_type: String) -> String:
    if not WEAPON_DATA.has(weapon_type):
        return ""
    return str(WEAPON_DATA[weapon_type].get("legendary", ""))

func get_item_title(item_id: String) -> String:
    if not ITEM_DATA.has(item_id):
        return ""
    return ITEM_DATA[item_id]["title"]

func get_item_desc(item_id: String) -> String:
    if not ITEM_DATA.has(item_id):
        return ""
    return ITEM_DATA[item_id]["desc"]

func get_weapon_quality(weapon_type: String) -> int:
    return _q(weapon_type)

func get_item_quality(item_id: String) -> int:
    return int(item_qualities.get(item_id, 0))

func can_buy_weapon(weapon_type: String, quality: int) -> bool:
    if not WEAPON_DATA.has(weapon_type) or quality < 1 or quality > MAX_QUALITY:
        return false
    if not weapon_qualities.has(weapon_type):
        return weapon_order.size() < MAX_WEAPON_SLOTS and _first_empty_slot() >= 0
    var current := _q(weapon_type)
    return current < MAX_QUALITY and quality >= current

func buy_weapon(weapon_type: String, quality: int) -> Dictionary:
    if not can_buy_weapon(weapon_type, quality):
        return {"ok": false, "reason": "cannot buy"}
    if not weapon_qualities.has(weapon_type):
        var slot := _first_empty_slot()
        if slot < 0:
            return {"ok": false, "reason": "no emplacement"}
        weapon_qualities[weapon_type] = quality
        weapon_order.append(weapon_type)
        weapon_slots[weapon_type] = slot
        slot_owners[slot] = weapon_type
        return {"ok": true, "new": true, "quality": quality, "slot": slot, "slot_name": str(EMPLACEMENT_NAMES[slot])}
    var current := _q(weapon_type)
    var next_quality := current
    if quality == current:
        next_quality = current + 1
    elif quality > current:
        next_quality = quality
    weapon_qualities[weapon_type] = mini(MAX_QUALITY, next_quality)
    return {"ok": true, "new": false, "quality": int(weapon_qualities[weapon_type])}

func sell_weapon(weapon_type: String) -> bool:
    if not weapon_qualities.has(weapon_type):
        return false
    var slot := get_weapon_slot(weapon_type)
    weapon_qualities.erase(weapon_type)
    weapon_order.erase(weapon_type)
    weapon_slots.erase(weapon_type)
    _deployed_weapons.erase(weapon_type)
    if slot >= 0:
        slot_owners.erase(slot)
    _clear_transient_effects()
    return true

func can_buy_item(item_id: String, quality: int) -> bool:
    if not ITEM_DATA.has(item_id) or quality < 1 or quality > MAX_QUALITY:
        return false
    if not item_qualities.has(item_id):
        return item_order.size() < MAX_ITEM_SLOTS
    var current := int(item_qualities[item_id])
    return current < MAX_QUALITY and quality >= current

func buy_item(item_id: String, quality: int) -> Dictionary:
    if not can_buy_item(item_id, quality):
        return {"ok": false, "reason": "cannot buy"}
    if not item_qualities.has(item_id):
        item_qualities[item_id] = quality
        item_order.append(item_id)
        _refresh_item_cache()
        return {"ok": true, "new": true, "quality": quality}
    var current := int(item_qualities[item_id])
    var next_quality := current
    if quality == current:
        next_quality = current + 1
    elif quality > current:
        next_quality = quality
    item_qualities[item_id] = mini(MAX_QUALITY, next_quality)
    _refresh_item_cache()
    return {"ok": true, "new": false, "quality": int(item_qualities[item_id])}

func sell_item(item_id: String) -> bool:
    if not item_qualities.has(item_id):
        return false
    item_qualities.erase(item_id)
    item_order.erase(item_id)
    _refresh_item_cache()
    return true

func _refresh_item_cache() -> void:
    item_stats_cache = get_item_stats()

func get_item_stats() -> Dictionary:
    var stats := {
        "pickup_radius": 60.0,
        "move_speed_bonus": 0.0,
        "max_health_bonus": 0,
        "gold_mult": 1.0,
        "sell_mult": 1.0,
        "free_rerolls": 0,
        "weapon_damage_mult": 1.0,
        "crit_bonus": 0.0,
    }
    for item_id in item_order:
        var quality := int(item_qualities.get(item_id, 0))
        if quality <= 0:
            continue
        match item_id:
            "magnet":
                stats["pickup_radius"] += 30.0 * float(quality)
            "boots":
                stats["move_speed_bonus"] += 22.0 * float(quality)
            "holy_fire":
                stats["max_health_bonus"] += 20 * quality
            "lucky_cat":
                stats["sell_mult"] += 0.08 * float(quality)
                stats["gold_mult"] += 0.04 * float(quality)
            "anvil":
                stats["free_rerolls"] += quality
                stats["weapon_damage_mult"] += 0.06 * float(quality)
            "jade":
                stats["gold_mult"] += 0.10 * float(quality)
                stats["crit_bonus"] += 0.04 * float(quality)
    return stats

func get_weapon_slots() -> Array:
    var slots: Array = []
    for weapon_type in weapon_order:
        slots.append({
            "id": weapon_type,
            "title": get_weapon_title(weapon_type),
            "quality": _q(weapon_type),
            "legendary": _legendary(weapon_type),
            "slot": get_weapon_slot(weapon_type),
            "slot_name": get_slot_name(weapon_type),
        })
    while slots.size() < MAX_WEAPON_SLOTS:
        slots.append({})
    return slots

func get_item_slots() -> Array:
    var slots: Array = []
    for item_id in item_order:
        slots.append({
            "id": item_id,
            "title": get_item_title(item_id),
            "quality": int(item_qualities.get(item_id, 0)),
        })
    while slots.size() < MAX_ITEM_SLOTS:
        slots.append({})
    return slots

func get_build_signature() -> String:
    var parts: Array = []
    for weapon_type in weapon_order:
        parts.append("W:%s:%d" % [weapon_type, _q(weapon_type)])
    for item_id in item_order:
        parts.append("I:%s:%d" % [item_id, int(item_qualities.get(item_id, 0))])
    var result := ""
    for part in parts:
        if result != "":
            result += ","
        result += str(part)
    return result
