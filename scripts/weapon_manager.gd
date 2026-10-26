extends Node2D

const MAX_SLOTS := 4
const MAX_LEVEL := 3
const WEAPON_ORDER := ["turret", "orbiter", "chain", "pierce"]
const WEAPON_DATA := {
    "turret": {
        "title": "TURRET",
        "desc": "auto turret",
        "evolutions": [
            {"id": "turret:twin", "title": "TWIN TURRETS - 2 turrets", "desc": "Deploy two turrets"},
            {"id": "turret:laser", "title": "LASER TURRET - pierce beam", "desc": "Piercing laser beam"},
        ],
    },
    "orbiter": {
        "title": "ORBITER",
        "desc": "orbiting blade",
        "evolutions": [
            {"id": "orbiter:fire", "title": "FIRE TRAIL - burn ground", "desc": "Leave burning ground"},
            {"id": "orbiter:giant", "title": "GIANT RING - huge orbit", "desc": "Much larger orbit"},
        ],
    },
    "chain": {
        "title": "CHAIN",
        "desc": "chain lightning",
        "evolutions": [
            {"id": "chain:storm", "title": "STORM - more targets", "desc": "More chain targets"},
            {"id": "chain:single", "title": "HEAVY BOLT - one big hit", "desc": "One massive hit"},
        ],
    },
    "pierce": {
        "title": "PIERCE",
        "desc": "piercing shot",
        "evolutions": [
            {"id": "pierce:railgun", "title": "RAILGUN - long beam", "desc": "Long piercing beam"},
            {"id": "pierce:explosive", "title": "EXPLOSIVE - area blast", "desc": "Impact explosion"},
        ],
    },
}

var player = null
var levels := {}
var evolutions := {}
var equipped_order: Array = []
var awaiting_evolution := {}

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
    _update_effects(delta)
    queue_redraw()

func _update_turrets(delta: float) -> void:
    var level: int = _level("turret")
    if level <= 0:
        return

    turret_timer -= delta
    if turret_timer <= 0.0:
        turret_timer = _turret_deploy_interval()
        _deploy_turrets()

    for index in range(turrets.size() - 1, -1, -1):
        var turret: Dictionary = turrets[index]
        turret["life"] -= delta
        turret["fire"] -= delta
        if turret["life"] <= 0.0:
            turrets.remove_at(index)
            continue
        if turret["fire"] <= 0.0:
            var target = _nearest_enemy(turret["pos"], _turret_range())
            if target != null:
                _turret_fire(turret, target)
                turret["fire"] = _turret_fire_interval()

func _deploy_turrets() -> void:
    var max_turrets := _turret_max()
    if turrets.size() >= max_turrets:
        return
    var count := 2 if _evolution("turret") == "turret:twin" else 1
    for index in range(count):
        if turrets.size() >= max_turrets:
            break
        var offset := Vector2(0.0, 46.0)
        if count > 1:
            offset = Vector2(-44.0 if index == 0 else 44.0, 34.0)
        turrets.append({
            "pos": player.global_position + offset,
            "life": _turret_lifetime(),
            "fire": 0.12 + float(index) * 0.2,
        })

func _turret_fire(turret: Dictionary, target) -> void:
    var from: Vector2 = turret["pos"]
    var to: Vector2 = target.global_position
    if _evolution("turret") == "turret:laser":
        var direction := (to - from).normalized()
        var end := from + direction * _turret_range()
        for enemy in _line_hits(from, end, 24.0, 99):
            _damage_enemy(enemy, _turret_damage())
        _add_beam([from, end], Color(1.0, 0.35, 0.65, 0.9), 5.0, 0.10)
    else:
        _damage_enemy(target, _turret_damage())
        _add_beam([from, to], Color(0.45, 1.0, 1.0, 0.85), 3.0, 0.07)
    Audio.play("turret", -24.0)

func _update_orbiter(delta: float) -> void:
    var level: int = _level("orbiter")
    if level <= 0:
        return

    orbiter_angle += _orbiter_speed() * delta
    orbiter_global_position = player.global_position + Vector2.from_angle(orbiter_angle) * _orbiter_radius()
    orbiter_sfx_timer = maxf(0.0, orbiter_sfx_timer - delta)

    orbiter_tick -= delta
    if orbiter_tick <= 0.0:
        orbiter_tick = _orbiter_tick_interval()
        var hit_enemies: Array = _enemies_in_radius(orbiter_global_position, _orbiter_hit_radius())
        for enemy in hit_enemies:
            _damage_enemy(enemy, _orbiter_damage())
        if not hit_enemies.is_empty() and orbiter_sfx_timer <= 0.0:
            Audio.play("orbiter", -28.0)
            orbiter_sfx_timer = 0.8

    if _evolution("orbiter") == "orbiter:fire":
        trail_timer -= delta
        if trail_timer <= 0.0:
            trail_timer = 0.55
            fire_patches.append({
                "pos": orbiter_global_position,
                "life": 2.6,
                "tick": 0.15,
            })

func _update_chain(delta: float) -> void:
    var level: int = _level("chain")
    if level <= 0:
        return

    chain_timer -= delta
    if chain_timer > 0.0:
        return
    chain_timer = _chain_cooldown()
    var first = _nearest_enemy(player.global_position, _chain_range())
    if first == null:
        return

    var targets := _chain_targets(first)
    var points: Array = [player.global_position]
    for enemy in targets:
        points.append(enemy.global_position)
        _damage_enemy(enemy, _chain_damage())
    chain_points = points
    chain_life = 0.16
    Audio.play("chain", -20.0)

func _chain_targets(first) -> Array:
    var targets: Array = [first]
    var current = first
    var count: int = _chain_count()
    for _index in range(1, count):
        var next = _nearest_enemy_excluding(current.global_position, _chain_jump(), targets)
        if next == null:
            break
        targets.append(next)
        current = next
    return targets

func _update_pierce(delta: float) -> void:
    var level: int = _level("pierce")
    if level <= 0:
        return

    pierce_timer -= delta
    if pierce_timer > 0.0:
        return
    pierce_timer = _pierce_cooldown()

    var start: Vector2 = player.global_position
    var target = _nearest_enemy(start, _pierce_range())
    var direction: Vector2 = player.facing
    if target != null:
        direction = (target.global_position - start).normalized()
    if direction.length_squared() < 0.01:
        direction = Vector2.RIGHT
    var end := start + direction * _pierce_range()
    var hits := _line_hits(start, end, _pierce_width(), _pierce_count())
    for enemy in hits:
        _damage_enemy(enemy, _pierce_damage())

    if _evolution("pierce") == "pierce:explosive" and not hits.is_empty():
        var impact = hits[0].global_position
        for enemy in _enemies_in_radius(impact, 80.0):
            if enemy != hits[0]:
                _damage_enemy(enemy, 35)
        _add_beam([start, impact], Color(1.0, 0.55, 0.15, 0.9), 6.0, 0.12)
    else:
        var color := Color(0.55, 0.85, 1.0, 0.9)
        if _evolution("pierce") == "pierce:railgun":
            color = Color(0.85, 0.8, 1.0, 0.95)
        _add_beam([start, end], color, 4.0, 0.10)
    Audio.play("pierce", -20.0)

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
            draw_line(
                to_local(points[index]),
                to_local(points[index + 1]),
                beam["color"],
                beam["width"],
                true
            )

    for turret in turrets:
        var pos := to_local(turret["pos"])
        var body := Color("#67e8f9")
        if _evolution("turret") == "turret:laser":
            body = Color("#f472b6")
        draw_circle(pos, 15.0, Color(0.04, 0.16, 0.18, 0.9))
        draw_rect(Rect2(pos - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), body, true)
        draw_line(pos, pos + Vector2(0.0, -22.0), body, 5.0, true)

    var orbiter_level: int = _level("orbiter")
    if orbiter_level > 0:
        var orbiter_pos := to_local(orbiter_global_position)
        var orbiter_color := Color("#f97316") if _evolution("orbiter") == "orbiter:fire" else Color("#22d3ee")
        if _evolution("orbiter") == "orbiter:giant":
            draw_arc(to_local(player.global_position), _orbiter_radius(), 0.0, TAU, 64, Color(0.3, 0.9, 1.0, 0.25), 2.0, true)
        draw_circle(orbiter_pos, 12.0, Color(0.03, 0.12, 0.16, 0.9))
        draw_circle(orbiter_pos, 8.0, orbiter_color)
        draw_circle(orbiter_pos, 3.0, Color("#ecfeff"))

    for patch in fire_patches:
        var patch_pos := to_local(patch["pos"])
        var alpha: float = clampf(float(patch["life"]) / 2.6, 0.0, 1.0)
        draw_circle(patch_pos, 30.0, Color(1.0, 0.35, 0.05, 0.12 * alpha))
        draw_circle(patch_pos, 17.0, Color(1.0, 0.65, 0.15, 0.22 * alpha))

    if chain_life > 0.0 and chain_points.size() > 1:
        for index in range(chain_points.size() - 1):
            draw_line(
                to_local(chain_points[index]),
                to_local(chain_points[index + 1]),
                Color(0.55, 1.0, 1.0, 0.9),
                4.0,
                true
            )

func _level(weapon_type: String) -> int:
    return int(levels.get(weapon_type, 0))

func _evolution(weapon_type: String) -> String:
    return str(evolutions.get(weapon_type, ""))

func _turret_damage() -> int:
    var level: int = _level("turret")
    if _evolution("turret") == "turret:laser":
        return 28
    if _evolution("turret") == "turret:twin":
        return 12
    return [10, 15, 20][level - 1]

func _turret_deploy_interval() -> float:
    if _evolution("turret") == "turret:twin":
        return 3.8
    if _evolution("turret") == "turret:laser":
        return 4.5
    return [5.0, 4.5, 4.0][_level("turret") - 1]

func _turret_max() -> int:
    return 2 if _evolution("turret") == "turret:twin" else 1

func _turret_fire_interval() -> float:
    if _evolution("turret") == "turret:twin":
        return 0.65
    if _evolution("turret") == "turret:laser":
        return 0.9
    return [0.9, 0.75, 0.6][_level("turret") - 1]

func _turret_lifetime() -> float:
    if _evolution("turret") == "turret:laser":
        return 9.0
    return [7.0, 8.0, 9.0][_level("turret") - 1]

func _turret_range() -> float:
    if _evolution("turret") == "turret:laser":
        return 620.0
    return [420.0, 460.0, 500.0][_level("turret") - 1]

func _orbiter_radius() -> float:
    if _evolution("orbiter") == "orbiter:giant":
        return 130.0
    return 65.0 + float(_level("orbiter") - 1) * 12.0

func _orbiter_speed() -> float:
    if _evolution("orbiter") == "orbiter:giant":
        return 2.2
    return 3.2 + float(_level("orbiter") - 1) * 0.3

func _orbiter_tick_interval() -> float:
    if _evolution("orbiter") == "orbiter:giant":
        return 0.28
    return 0.4 - float(_level("orbiter") - 1) * 0.04

func _orbiter_damage() -> int:
    if _evolution("orbiter") == "orbiter:giant":
        return 20
    return [8, 12, 16][_level("orbiter") - 1]

func _orbiter_hit_radius() -> float:
    if _evolution("orbiter") == "orbiter:giant":
        return 42.0
    return 28.0 + float(_level("orbiter") - 1) * 3.0

func _chain_count() -> int:
    if _evolution("chain") == "chain:storm":
        return 8
    if _evolution("chain") == "chain:single":
        return 1
    return [3, 4, 5][_level("chain") - 1]

func _chain_jump() -> float:
    if _evolution("chain") == "chain:storm":
        return 240.0
    if _evolution("chain") == "chain:single":
        return 0.0
    return [180.0, 190.0, 200.0][_level("chain") - 1]

func _chain_damage() -> int:
    if _evolution("chain") == "chain:storm":
        return 20
    if _evolution("chain") == "chain:single":
        return 85
    return [12, 18, 24][_level("chain") - 1]

func _chain_cooldown() -> float:
    if _evolution("chain") == "chain:storm":
        return 1.7
    if _evolution("chain") == "chain:single":
        return 1.8
    return [2.2, 2.0, 1.9][_level("chain") - 1]

func _chain_range() -> float:
    if _evolution("chain") in ["chain:storm", "chain:single"]:
        return 520.0
    return [420.0, 450.0, 480.0][_level("chain") - 1]

func _pierce_damage() -> int:
    if _evolution("pierce") == "pierce:railgun":
        return 90
    if _evolution("pierce") == "pierce:explosive":
        return 40
    return [18, 26, 36][_level("pierce") - 1]

func _pierce_count() -> int:
    if _evolution("pierce") == "pierce:railgun":
        return 99
    if _evolution("pierce") == "pierce:explosive":
        return 1
    return [3, 4, 5][_level("pierce") - 1]

func _pierce_cooldown() -> float:
    if _evolution("pierce") == "pierce:railgun":
        return 1.8
    if _evolution("pierce") == "pierce:explosive":
        return 1.6
    return [1.5, 1.4, 1.3][_level("pierce") - 1]

func _pierce_range() -> float:
    if _evolution("pierce") == "pierce:railgun":
        return 900.0
    if _evolution("pierce") == "pierce:explosive":
        return 600.0
    return [600.0, 650.0, 700.0][_level("pierce") - 1]

func _pierce_width() -> float:
    if _evolution("pierce") == "pierce:railgun":
        return 16.0
    if _evolution("pierce") == "pierce:explosive":
        return 26.0
    return [18.0, 20.0, 22.0][_level("pierce") - 1]

func get_equipped_count() -> int:
    return equipped_order.size()

func add_weapon(weapon_type: String) -> bool:
    if not WEAPON_DATA.has(weapon_type):
        return false
    if levels.has(weapon_type) or equipped_order.size() >= MAX_SLOTS:
        return false
    levels[weapon_type] = 1
    equipped_order.append(weapon_type)
    return true

func upgrade_weapon(weapon_type: String) -> Dictionary:
    if not levels.has(weapon_type) or awaiting_evolution.has(weapon_type):
        return {}
    var current: int = int(levels[weapon_type])
    if current >= MAX_LEVEL:
        return {}
    levels[weapon_type] = current + 1
    if levels[weapon_type] >= MAX_LEVEL:
        awaiting_evolution[weapon_type] = true
        return {
            "type": weapon_type,
            "title": WEAPON_DATA[weapon_type]["title"],
            "choices": WEAPON_DATA[weapon_type]["evolutions"],
        }
    return {"type": weapon_type, "title": WEAPON_DATA[weapon_type]["title"], "choices": []}

func apply_evolution(weapon_type: String, evolution_id: String) -> bool:
    if not awaiting_evolution.has(weapon_type) or not WEAPON_DATA.has(weapon_type):
        return false
    var valid := false
    for evolution in WEAPON_DATA[weapon_type]["evolutions"]:
        if evolution["id"] == evolution_id:
            valid = true
            break
    if not valid:
        return false
    evolutions[weapon_type] = evolution_id
    awaiting_evolution.erase(weapon_type)
    return true

func get_cards() -> Array:
    var cards: Array = []
    if equipped_order.size() < MAX_SLOTS:
        for weapon_type in WEAPON_ORDER:
            if not levels.has(weapon_type):
                cards.append({
                    "id": "weapon:" + weapon_type,
                    "title": "NEW %s - %s" % [WEAPON_DATA[weapon_type]["title"], WEAPON_DATA[weapon_type]["desc"]],
                    "kind": "weapon_new",
                })
    for weapon_type in equipped_order:
        if awaiting_evolution.has(weapon_type):
            continue
        var current: int = int(levels[weapon_type])
        if current >= MAX_LEVEL:
            continue
        var next_level: int = current + 1
        var title: String = WEAPON_DATA[weapon_type]["title"] + " Lv" + str(next_level)
        if next_level == MAX_LEVEL:
            title += " EVOLVE"
        cards.append({
            "id": "upgrade:" + weapon_type,
            "title": title,
            "kind": "weapon_upgrade",
        })
    return cards

func get_slots() -> Array:
    var slots: Array = []
    for weapon_type in equipped_order:
        slots.append({
            "type": weapon_type,
            "title": WEAPON_DATA[weapon_type]["title"],
            "level": int(levels.get(weapon_type, 0)),
            "evolution": str(evolutions.get(weapon_type, "")),
        })
    while slots.size() < MAX_SLOTS:
        slots.append({})
    return slots

func get_state_snapshot() -> Dictionary:
    return {
        "levels": levels.duplicate(),
        "evolutions": evolutions.duplicate(),
        "order": equipped_order.duplicate(),
    }

func get_build_signature() -> String:
    var result := ""
    for weapon_type in equipped_order:
        if result != "":
            result += "|"
        result += "%s:L%d:%s" % [
            weapon_type,
            int(levels.get(weapon_type, 0)),
            str(evolutions.get(weapon_type, "")),
        ]
    return result

func get_evolution_title(weapon_type: String) -> String:
    if not WEAPON_DATA.has(weapon_type):
        return ""
    return WEAPON_DATA[weapon_type]["title"]
