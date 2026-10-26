extends Node2D

const MAX_WEAPON_SLOTS := 6
const MAX_ITEM_SLOTS := 6
const MAX_QUALITY := 4
const QUALITY_NAMES := ["", "COMMON", "RARE", "EPIC", "LEGENDARY"]
const QUALITY_DAMAGE := [0.0, 1.0, 1.35, 1.8, 2.4]
const QUALITY_COOLDOWN := [0.0, 1.0, 0.92, 0.84, 0.76]
const WEAPON_ORDER := ["peony", "maple", "justice", "vigil", "hammer", "elixir"]
const WEAPON_DATA := {
    "peony": {"title": "PEONY TURRET", "desc": "deploy auto turrets"},
    "maple": {"title": "MAPLE ORBITER", "desc": "orbiting blades"},
    "justice": {"title": "JUSTICE CHAIN", "desc": "chain lightning"},
    "vigil": {"title": "VIGIL CANNON", "desc": "piercing shots"},
    "hammer": {"title": "BLAST HAMMER", "desc": "area slam"},
    "elixir": {"title": "DEADLY ELIXIR", "desc": "poison fields"},
}
const ITEM_ORDER := ["magnet", "boots", "holy_fire", "lucky_cat", "anvil", "jade"]
const ITEM_DATA := {
    "magnet": {"title": "MAGNET", "desc": "larger pickup radius"},
    "boots": {"title": "BOOTS", "desc": "more move speed"},
    "holy_fire": {"title": "HOLY FIRE", "desc": "more max HP"},
    "lucky_cat": {"title": "LUCKY CAT", "desc": "better selling"},
    "anvil": {"title": "ANVIL", "desc": "free shop rerolls"},
    "jade": {"title": "JADE", "desc": "more gold"},
}

var player = null
var weapon_qualities := {}
var weapon_order: Array = []
var item_qualities := {}
var item_order: Array = []

var turret_timer := 0.0
var turrets: Array = []
var orbiter_angle := 0.0
var orbiter_tick := 0.0
var orbiter_sfx_timer := 0.0
var orbiter_global_position := Vector2.ZERO
var trail_timer := 0.0
var fire_patches: Array = []
var chain_timer := 0.0
var chain_points: Array = []
var chain_life := 0.0
var pierce_timer := 0.0
var hammer_timer := 0.0
var hammer_effects: Array = []
var elixir_timer := 0.0
var poison_fields: Array = []
var beams: Array = []

func _ready() -> void:
    player = get_parent()

func _process(delta: float) -> void:
    if player == null or player.is_dead:
        return
    _update_turrets(delta)
    _update_orbiter(delta)
    _update_chain(delta)
    _update_pierce(delta)
    _update_hammer(delta)
    _update_elixir(delta)
    _update_effects(delta)
    queue_redraw()

func _update_turrets(delta: float) -> void:
    var quality := _q("peony")
    if quality <= 0:
        return

    turret_timer -= delta
    if turret_timer <= 0.0:
        turret_timer = _turret_deploy_interval(quality)
        if turrets.size() < 1:
            turrets.append({
                "pos": player.global_position + Vector2(0.0, 46.0),
                "life": _turret_lifetime(quality),
                "fire": 0.12,
            })

    for index in range(turrets.size() - 1, -1, -1):
        var turret: Dictionary = turrets[index]
        turret["life"] -= delta
        turret["fire"] -= delta
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
    var damage := _turret_damage(quality)
    if quality >= MAX_QUALITY:
        var direction := (to - from).normalized()
        var end := from + direction * _turret_range(quality)
        for enemy in _line_hits(from, end, 24.0, 99):
            _damage_enemy(enemy, damage)
        _add_beam([from, end], Color(1.0, 0.35, 0.65, 0.9), 5.0, 0.10)
    else:
        _damage_enemy(target, damage)
        _add_beam([from, to], Color(0.45, 1.0, 1.0, 0.85), 3.0, 0.07)
    Audio.play("turret", -24.0)

func _update_orbiter(delta: float) -> void:
    var quality := _q("maple")
    if quality <= 0:
        return

    orbiter_angle += _orbiter_speed(quality) * delta
    orbiter_global_position = player.global_position + Vector2.from_angle(orbiter_angle) * _orbiter_radius(quality)
    orbiter_sfx_timer = maxf(0.0, orbiter_sfx_timer - delta)

    orbiter_tick -= delta
    if orbiter_tick <= 0.0:
        orbiter_tick = _orbiter_tick_interval(quality)
        var hit_enemies: Array = _enemies_in_radius(orbiter_global_position, _orbiter_hit_radius(quality))
        for enemy in hit_enemies:
            _damage_enemy(enemy, _orbiter_damage(quality))
        if not hit_enemies.is_empty() and orbiter_sfx_timer <= 0.0:
            Audio.play("orbiter", -28.0)
            orbiter_sfx_timer = 0.8

    if quality >= MAX_QUALITY:
        trail_timer -= delta
        if trail_timer <= 0.0:
            trail_timer = 0.55
            fire_patches.append({
                "pos": orbiter_global_position,
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
    var first = _nearest_enemy(player.global_position, _chain_range(quality))
    if first == null:
        return

    var targets := _chain_targets(first, quality)
    var points: Array = [player.global_position]
    for enemy in targets:
        points.append(enemy.global_position)
        _damage_enemy(enemy, _chain_damage(quality))
    chain_points = points
    chain_life = 0.16
    Audio.play("chain", -20.0)

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

    var start: Vector2 = player.global_position
    var target = _nearest_enemy(start, _pierce_range(quality))
    var direction: Vector2 = player.facing
    if target != null:
        direction = (target.global_position - start).normalized()
    if direction.length_squared() < 0.01:
        direction = Vector2.RIGHT
    var end := start + direction * _pierce_range(quality)
    for enemy in _line_hits(start, end, _pierce_width(quality), _pierce_count(quality)):
        _damage_enemy(enemy, _pierce_damage(quality))

    var color := Color(0.55, 0.85, 1.0, 0.9)
    if quality >= MAX_QUALITY:
        color = Color(0.85, 0.8, 1.0, 0.95)
    _add_beam([start, end], color, 4.0, 0.10)
    Audio.play("pierce", -20.0)

func _update_hammer(delta: float) -> void:
    var quality := _q("hammer")
    if quality <= 0:
        return
    hammer_timer -= delta
    if hammer_timer > 0.0:
        return
    hammer_timer = 2.2 * QUALITY_COOLDOWN[quality]
    var radius := 160.0 if quality >= MAX_QUALITY else 85.0 + float(quality - 1) * 15.0
    var damage := int(20.0 * QUALITY_DAMAGE[quality])
    if quality >= MAX_QUALITY:
        damage = int(float(damage) * 1.5)
    for enemy in _enemies_in_radius(player.global_position, radius):
        _damage_enemy(enemy, damage)
    hammer_effects.append({
        "pos": player.global_position,
        "life": 0.30,
        "radius": radius,
    })
    Fx.shake(4.0, 0.12)
    Audio.play("explode", -22.0)

func _update_elixir(delta: float) -> void:
    var quality := _q("elixir")
    if quality <= 0:
        return
    elixir_timer -= delta
    if elixir_timer > 0.0:
        return
    elixir_timer = 2.6 * QUALITY_COOLDOWN[quality]
    var target = _nearest_enemy(player.global_position, 650.0)
    var pos: Vector2 = player.global_position + player.facing * 120.0
    if target != null:
        pos = target.global_position
    var radius := 115.0 if quality >= MAX_QUALITY else 65.0 + float(quality - 1) * 15.0
    var damage := int(5.0 * QUALITY_DAMAGE[quality])
    if quality >= MAX_QUALITY:
        damage = int(9.0 * QUALITY_DAMAGE[quality])
    poison_fields.append({
        "pos": pos,
        "life": 4.0,
        "tick": 0.15,
        "radius": radius,
        "damage": damage,
    })
    Audio.play("orbiter", -26.0)

func _update_effects(delta: float) -> void:
    for index in range(beams.size() - 1, -1, -1):
        beams[index]["life"] -= delta
        if beams[index]["life"] <= 0.0:
            beams.remove_at(index)

    if chain_life > 0.0:
        chain_life -= delta
        if chain_life <= 0.0:
            chain_points.clear()

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
            for enemy in _enemies_in_radius(field["pos"], field["radius"]):
                _damage_enemy(enemy, field["damage"])
        if field["life"] <= 0.0:
            poison_fields.remove_at(index)

func _add_beam(points: Array, color: Color, width: float, life: float) -> void:
    beams.append({"points": points, "color": color, "width": width, "life": life})

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

func _damage_enemy(enemy, amount: int) -> void:
    if enemy == null or not is_instance_valid(enemy):
        return
    if enemy.has_method("take_damage"):
        enemy.take_damage(amount)

func _draw() -> void:
    for beam in beams:
        var points: Array = beam["points"]
        for index in range(points.size() - 1):
            draw_line(to_local(points[index]), to_local(points[index + 1]), beam["color"], beam["width"], true)

    for turret in turrets:
        var pos := to_local(turret["pos"])
        var body := Color("#67e8f9")
        if _legendary("peony"):
            body = Color("#f472b6")
        draw_circle(pos, 15.0, Color(0.04, 0.16, 0.18, 0.9))
        draw_rect(Rect2(pos - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), body, true)
        draw_line(pos, pos + Vector2(0.0, -22.0), body, 5.0, true)

    if _q("maple") > 0:
        var orbiter_pos := to_local(orbiter_global_position)
        var orbiter_color := Color("#f97316") if _legendary("maple") else Color("#22d3ee")
        if _legendary("maple"):
            draw_arc(to_local(player.global_position), _orbiter_radius(MAX_QUALITY), 0.0, TAU, 64, Color(0.3, 0.9, 1.0, 0.25), 2.0, true)
        draw_circle(orbiter_pos, 12.0, Color(0.03, 0.12, 0.16, 0.9))
        draw_circle(orbiter_pos, 8.0, orbiter_color)
        draw_circle(orbiter_pos, 3.0, Color("#ecfeff"))

    for patch in fire_patches:
        var patch_pos := to_local(patch["pos"])
        var alpha: float = clampf(float(patch["life"]) / 2.6, 0.0, 1.0)
        draw_circle(patch_pos, 30.0, Color(1.0, 0.35, 0.05, 0.12 * alpha))
        draw_circle(patch_pos, 17.0, Color(1.0, 0.65, 0.15, 0.22 * alpha))

    for effect in hammer_effects:
        var effect_pos := to_local(effect["pos"])
        var progress: float = 1.0 - clampf(float(effect["life"]) / 0.30, 0.0, 1.0)
        draw_arc(effect_pos, effect["radius"] * progress, 0.0, TAU, 64, Color(1.0, 0.75, 0.3, 0.7), 5.0, true)

    for field in poison_fields:
        var field_pos := to_local(field["pos"])
        var alpha: float = clampf(float(field["life"]) / 4.0, 0.0, 1.0)
        draw_circle(field_pos, field["radius"], Color(0.35, 0.85, 0.25, 0.10 * alpha))
        draw_arc(field_pos, field["radius"], 0.0, TAU, 48, Color(0.45, 1.0, 0.35, 0.35 * alpha), 2.0, true)

    if chain_life > 0.0 and chain_points.size() > 1:
        for index in range(chain_points.size() - 1):
            draw_line(to_local(chain_points[index]), to_local(chain_points[index + 1]), Color(0.55, 1.0, 1.0, 0.9), 4.0, true)

func _q(weapon_type: String) -> int:
    return int(weapon_qualities.get(weapon_type, 0))

func _legendary(weapon_type: String) -> bool:
    return _q(weapon_type) >= MAX_QUALITY

func _turret_damage(quality: int) -> int:
    var damage := int(10.0 * QUALITY_DAMAGE[quality])
    return int(30.0 * QUALITY_DAMAGE[quality]) if quality >= MAX_QUALITY else damage

func _turret_deploy_interval(quality: int) -> float:
    return 5.0 * QUALITY_COOLDOWN[quality]

func _turret_fire_interval(quality: int) -> float:
    return (0.8 if quality >= MAX_QUALITY else 0.9) * QUALITY_COOLDOWN[quality]

func _turret_lifetime(quality: int) -> float:
    return 8.0 + float(quality) * 0.5

func _turret_range(quality: int) -> float:
    return 620.0 if quality >= MAX_QUALITY else 420.0 + float(quality) * 30.0

func _orbiter_radius(quality: int) -> float:
    return 80.0 if quality >= MAX_QUALITY else 65.0 + float(quality - 1) * 12.0

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
    return int((60.0 if quality >= MAX_QUALITY else 18.0) * QUALITY_DAMAGE[quality])

func _pierce_count(quality: int) -> int:
    return 99 if quality >= MAX_QUALITY else 2 + quality

func _pierce_cooldown(quality: int) -> float:
    return (1.8 if quality >= MAX_QUALITY else 1.5) * QUALITY_COOLDOWN[quality]

func _pierce_range(quality: int) -> float:
    return 900.0 if quality >= MAX_QUALITY else 600.0 + float(quality) * 50.0

func _pierce_width(quality: int) -> float:
    return 16.0 if quality >= MAX_QUALITY else 18.0

func reset_build() -> void:
    weapon_qualities.clear()
    weapon_order.clear()
    item_qualities.clear()
    item_order.clear()
    turrets.clear()
    fire_patches.clear()
    poison_fields.clear()
    beams.clear()
    chain_points.clear()

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
        return weapon_order.size() < MAX_WEAPON_SLOTS
    var current := _q(weapon_type)
    return current < MAX_QUALITY and quality >= current

func buy_weapon(weapon_type: String, quality: int) -> Dictionary:
    if not can_buy_weapon(weapon_type, quality):
        return {"ok": false, "reason": "cannot buy"}
    if not weapon_qualities.has(weapon_type):
        weapon_qualities[weapon_type] = quality
        weapon_order.append(weapon_type)
        return {"ok": true, "new": true, "quality": quality}
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
    weapon_qualities.erase(weapon_type)
    weapon_order.erase(weapon_type)
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
        return {"ok": true, "new": true, "quality": quality}
    var current := int(item_qualities[item_id])
    var next_quality := current
    if quality == current:
        next_quality = current + 1
    elif quality > current:
        next_quality = quality
    item_qualities[item_id] = mini(MAX_QUALITY, next_quality)
    return {"ok": true, "new": false, "quality": int(item_qualities[item_id])}

func sell_item(item_id: String) -> bool:
    if not item_qualities.has(item_id):
        return false
    item_qualities.erase(item_id)
    item_order.erase(item_id)
    return true

func get_item_stats() -> Dictionary:
    var stats := {
        "pickup_radius": 60.0,
        "move_speed_bonus": 0.0,
        "max_health_bonus": 0,
        "gold_mult": 1.0,
        "sell_mult": 1.0,
        "free_rerolls": 0,
    }
    for item_id in item_order:
        var quality := int(item_qualities.get(item_id, 0))
        if quality <= 0:
            continue
        match item_id:
            "magnet":
                stats["pickup_radius"] += 40.0 * float(quality)
            "boots":
                stats["move_speed_bonus"] += 30.0 * float(quality)
            "holy_fire":
                stats["max_health_bonus"] += 20 * quality
            "lucky_cat":
                stats["sell_mult"] += 0.15 * float(quality)
                stats["gold_mult"] += 0.05 * float(quality)
            "anvil":
                stats["free_rerolls"] += quality
            "jade":
                stats["gold_mult"] += 0.15 * float(quality)
    return stats

func get_weapon_slots() -> Array:
    var slots: Array = []
    for weapon_type in weapon_order:
        slots.append({
            "id": weapon_type,
            "title": get_weapon_title(weapon_type),
            "quality": _q(weapon_type),
            "legendary": _legendary(weapon_type),
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
