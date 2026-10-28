extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SHOOTER_SCENE := preload("res://scenes/shooter.tscn")
const EXPLODER_SCENE := preload("res://scenes/exploder.tscn")
const TREASURE_SCENE := preload("res://scenes/treasure_imp.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const COIN_SCRIPT := preload("res://scripts/coin.gd")

const STAGE_IDS := [
    "1-1", "1-2", "1-3", "1-4",
    "2-1", "2-2", "2-3", "2-4",
    "3-1", "3-2", "3-3", "3-4",
]
const CHAPTER_NAMES := ["第一章 · 熔炉工坊", "第二章 · 赤沙机关", "第三章 · 天工禁地"]
const STAGE_NAMES := [
    ["熔炉入口", "风蚀回廊", "齿轮深渊", "守卫核心"],
    ["赤沙门", "流沙阱", "风暴眼", "沙王座"],
    ["禁地门", "铜人阵", "天工台", "百炼殿"],
]
const CHAPTER_MULT := [1.0, 1.18, 1.38]
const WAVES_PER_STAGE := 16
const BOSS_WAVES := [8, 16]
const START_GOLD := 15
const CHAPTER_START_GOLD := 5
const REROLL_COST := 2
const SHOP_OFFER_COUNT := 4
const STARTER_WEAPON := "maple"
const SAVE_PATH := "user://arena_survivor.cfg"
const TEST_SAVE_PATH := "user://arena_survivor_test.cfg"

@onready var player = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var coins: Node2D = $Coins
@onready var hud = $HUD
@onready var weapon_manager = $Player/WeaponManager
@onready var camera: Camera2D = $Camera2D

var save_path := SAVE_PATH
var test_mode := false

var stage_id := ""
var stage_index := 0
var chapter := 1
var stage_number := 1
var is_endless := false
var menu_open := false
var shop_open := false
var game_over := false
var stage_clear := false

var wave := 1
var wave_active := false
var wave_total := 0
var wave_spawned := 0
var wave_killed := 0
var wave_remaining := 0
var spawn_timer := 0.0
var boss_spawn_timer := 0.0
var boss_spawned := false
var boss_wave := false
var treasure_spawned := false
var elite_spawned := false

var gold := START_GOLD
var pickup_radius := 60.0
var gold_mult := 1.0
var sell_mult := 1.0
var shop_free_rerolls := 0
var shop_message := ""
var shop_offers: Array = []
var last_heal_amount := 0
var next_stage_id := ""

var max_unlocked := 0
var endless_unlocked := false
var best_endless_wave := 0
var total_kills := 0

var shake_time := 0.0
var shake_strength := 0.0

func _ready() -> void:
    test_mode = OS.get_cmdline_user_args().has("--smoke-test") or OS.get_cmdline_user_args().has("--screenshot") or OS.get_cmdline_user_args().has("--playtest")
    if test_mode:
        save_path = TEST_SAVE_PATH
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

    hud.stage_selected.connect(_on_stage_selected)
    hud.endless_selected.connect(_on_endless_selected)
    hud.buy_offer.connect(_on_buy_offer)
    hud.reroll_shop.connect(_on_reroll_shop)
    hud.sell_weapon.connect(_on_sell_weapon)
    hud.sell_item.connect(_on_sell_item)
    hud.next_wave.connect(_on_next_wave)
    hud.next_stage.connect(_on_next_stage)
    hud.retry_stage.connect(_on_retry_stage)
    hud.stage_select.connect(_on_stage_select)
    hud.dash_requested.connect(player.try_dash)
    player.health_changed.connect(hud.set_health)
    Fx.shake_requested.connect(_on_shake_requested)

    _load_progress()
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.set_item_slots(weapon_manager.get_item_slots())

    if RunState.endless:
        _begin_run("", true)
    elif RunState.selected_stage != "":
        _begin_run(RunState.selected_stage, false)
    else:
        _show_stage_select()

    if OS.get_cmdline_user_args().has("--smoke-test"):
        call_deferred("_run_smoke_test")
    elif OS.get_cmdline_user_args().has("--screenshot"):
        call_deferred("_capture_screenshot")
    elif OS.get_cmdline_user_args().has("--playtest"):
        call_deferred("_start_playtest")

func _start_playtest() -> void:
    var bot: Node = load("res://scripts/playtest_bot.gd").new()
    add_child(bot)

func _process(delta: float) -> void:
    _update_shake(delta)
    if menu_open or shop_open or game_over or stage_clear:
        return
    if not wave_active:
        return
    if player.is_dead:
        _on_player_died()
        return

    hud.set_dash_state(player.can_dash(), player.get_dash_cooldown_remaining())

    if boss_wave:
        boss_spawn_timer -= delta
        if not boss_spawned and boss_spawn_timer <= 0.0:
            _spawn_boss()
        if boss_spawned and get_tree().get_first_node_in_group("boss") == null:
            _finish_wave()
            return
    else:
        if not elite_spawned and _is_elite_wave(wave):
            elite_spawned = true
            _spawn_elite()
        if not treasure_spawned and wave % 8 == 4:
            treasure_spawned = true
            _spawn_treasure()
        spawn_timer -= delta
        if wave_spawned < wave_total and spawn_timer <= 0.0 and enemies.get_child_count() < _enemy_cap():
            _spawn_enemy()
            spawn_timer = _spawn_interval()
        if wave_spawned >= wave_total and wave_killed >= wave_total:
            _finish_wave()
            return

    hud.set_enemy_count(enemies.get_child_count())
    hud.set_wave_progress(wave_remaining, wave_total, boss_wave)
    hud.set_gold(gold)

func _show_stage_select() -> void:
    menu_open = true
    player.visible = false
    player.set_physics_process(false)
    weapon_manager.visible = false
    _clear_arena()
    hud.show_stage_select(_stage_select_data())

func _begin_run(selected_stage: String, endless: bool) -> void:
    get_tree().paused = false
    menu_open = false
    is_endless = endless
    stage_id = selected_stage
    stage_index = _stage_index(stage_id) if not endless else -1
    chapter = 1
    stage_number = 1
    if not endless and stage_index >= 0:
        chapter = int(stage_index / 4) + 1
        stage_number = (stage_index % 4) + 1

    game_over = false
    stage_clear = false
    shop_open = false
    wave = 1
    gold = START_GOLD + (chapter - 1) * CHAPTER_START_GOLD
    shop_offers.clear()
    shop_message = ""
    last_heal_amount = 0
    total_kills = 0

    _clear_arena()
    player.visible = true
    player.set_physics_process(true)
    player.global_position = Vector2(640.0, 360.0)
    player.is_dead = false
    player.max_health = 100
    player.health = 100
    player.move_speed = 340.0
    player.health_changed.emit(player.health, player.max_health)
    weapon_manager.visible = true
    weapon_manager.reset_build()
    weapon_manager.buy_weapon(STARTER_WEAPON, mini(4, chapter))
    _apply_item_stats()
    hud.hide_stage_select()
    hud.hide_shop()
    hud.hide_end_panel()
    hud.set_stage(_stage_label())
    hud.set_best_wave(best_endless_wave)
    hud.set_gold(gold)
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.set_item_slots(weapon_manager.get_item_slots())
    _start_wave(1)

func _stage_label() -> String:
    if is_endless:
        return "无尽"
    return "%d-%d" % [chapter, stage_number]

func _stage_label_with_name() -> String:
    if is_endless:
        return "无尽试炼"
    return "%s · %s" % [_stage_label(), _stage_name(_stage_label())]

func _stage_name(id: String) -> String:
    var index := _stage_index(id)
    if index < 0:
        return ""
    var chapter_index := int(index / 4)
    var stage_index_local := index % 4
    return STAGE_NAMES[chapter_index][stage_index_local]

func _stage_index(id: String) -> int:
    return STAGE_IDS.find(id)

func _difficulty_mult() -> float:
    if is_endless:
        return 1.0 + float(wave) * 0.04
    return CHAPTER_MULT[chapter - 1] + float(stage_number - 1) * 0.065

func _wave_mult() -> float:
    var value := 1.0 + float(wave - 1) * 0.05
    if wave >= 12:
        value *= 1.15
    return value

func _quality_progress_for(stage_idx: int, endless: bool, wave_no: int) -> float:
    if endless:
        return clampf(float(wave_no) / 40.0, 0.0, 1.0)
    return clampf(float(stage_idx) / 11.0, 0.0, 1.0)

func _quality_progress() -> float:
    return _quality_progress_for(stage_index, is_endless, wave)

func _quality_chances(progress: float) -> Array:
    var p := clampf(progress, 0.0, 1.0)
    var q4 := 0.02 + 0.10 * p
    var q3 := 0.10 + 0.18 * p
    var q2 := 0.28 + 0.10 * p
    var q1 := 1.0 - q4 - q3 - q2
    return [q4, q3, q2, q1]

func _quality_for_roll(roll: float, progress: float) -> int:
    var chances: Array = _quality_chances(progress)
    var cumulative := 0.0
    for index in range(4):
        cumulative += float(chances[index])
        if roll < cumulative:
            return 4 - index
    return 1

func _coin_value_for(wave_no: int) -> int:
    return 1 + int(wave_no / 6)

func _wave_enemy_count_for(wave_no: int, chapter_no: int, endless: bool) -> int:
    if endless:
        return 12 + wave_no * 2
    return 10 + wave_no + (chapter_no - 1) * 2

func _enemy_cap_for(wave_no: int) -> int:
    if wave_no <= 2:
        return 12
    if wave_no <= 5:
        return 22
    return 32

func _spawn_interval_for(wave_no: int, chapter_no: int) -> float:
    var interval := maxf(0.42, 1.05 - float(wave_no) * 0.03 - float(chapter_no - 1) * 0.08)
    if wave_no <= 2:
        interval *= 1.35
    if wave_no >= 12:
        interval *= 0.8
    return interval

func _is_elite_wave(wave_no: int) -> bool:
    return wave_no == 6 or wave_no == 14

func _wave_heal_ratio(is_boss: bool) -> float:
    return 0.25 if is_boss else 0.10

func _start_wave(number: int) -> void:
    wave = number
    wave_active = true
    if is_endless and wave > best_endless_wave:
        best_endless_wave = wave
        hud.set_best_wave(best_endless_wave)
    boss_wave = (number % 8 == 0)
    boss_spawned = false
    boss_spawn_timer = 0.6
    treasure_spawned = false
    elite_spawned = false
    wave_total = _wave_enemy_count_for(number, chapter, is_endless)
    wave_spawned = 0
    wave_killed = 0
    wave_remaining = wave_total
    spawn_timer = 0.6
    hud.hide_boss_bar()
    hud.set_wave(wave, WAVES_PER_STAGE if not is_endless else 0)
    hud.set_stage(_stage_label())
    hud.set_gold(gold)
    hud.set_enemy_count(0)
    hud.set_wave_progress(wave_remaining, wave_total, boss_wave)
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.set_item_slots(weapon_manager.get_item_slots())
    Audio.play("wave_start", -12.0)

func _spawn_interval() -> float:
    return _spawn_interval_for(wave, chapter)

func _enemy_cap() -> int:
    return _enemy_cap_for(wave)

func _pick_enemy_type() -> String:
    if wave <= 2:
        return "chaser"
    var roll := randf()
    var shooter_chance := 0.20 + float(chapter - 1) * 0.04
    var exploder_chance := 0.0
    if wave >= 5:
        exploder_chance = 0.12 + float(chapter - 1) * 0.05
    if wave >= 12:
        shooter_chance += 0.04
        exploder_chance += 0.04
    if roll < exploder_chance:
        return "exploder"
    if roll < exploder_chance + shooter_chance:
        return "shooter"
    return "chaser"

func _edge_spawn_position() -> Vector2:
    var view_size := get_viewport_rect().size
    match randi() % 4:
        0:
            return Vector2(randf_range(0.0, view_size.x), -32.0)
        1:
            return Vector2(view_size.x + 32.0, randf_range(0.0, view_size.y))
        2:
            return Vector2(randf_range(0.0, view_size.x), view_size.y + 32.0)
        _:
            return Vector2(-32.0, randf_range(0.0, view_size.y))

func _spawn_enemy() -> void:
    var enemy_type := _pick_enemy_type()
    var scene: PackedScene = ENEMY_SCENE
    if enemy_type == "shooter":
        scene = SHOOTER_SCENE
    elif enemy_type == "exploder":
        scene = EXPLODER_SCENE

    var pos := _edge_spawn_position()

    var mult := _difficulty_mult() * _wave_mult()
    var enemy = scene.instantiate()
    if enemy_type == "shooter":
        enemy.max_health = int((18.0 + float(wave) * 5.0) * mult)
        enemy.contact_damage = 5
        enemy.move_speed = randf_range(85.0, 110.0)
        enemy.projectile_damage = 5 + int(wave / 4) + (chapter - 1) * 2
    elif enemy_type == "exploder":
        enemy.max_health = int((28.0 + float(wave) * 7.0) * mult)
        enemy.move_speed = randf_range(65.0, 90.0)
        enemy.explosion_damage = int(20.0 + float(wave) * 1.5 + float(chapter - 1) * 5.0)
    else:
        enemy.max_health = int((24.0 + float(wave) * 6.0) * mult)
        enemy.contact_damage = 6 + int(wave / 4) + (chapter - 1) * 2
        enemy.move_speed = randf_range(85.0, 125.0) + float(chapter) * 6.0

    enemies.add_child(enemy)
    enemy.global_position = pos
    enemy.died.connect(_on_enemy_died)
    wave_spawned += 1

func _spawn_treasure() -> void:
    var imp = TREASURE_SCENE.instantiate()
    var mult := _difficulty_mult() * _wave_mult()
    imp.max_health = int(50.0 * mult)
    imp.move_speed = 85.0
    enemies.add_child(imp)
    var view_size := get_viewport_rect().size
    imp.global_position = Vector2(
        randf_range(180.0, view_size.x - 180.0),
        randf_range(150.0, view_size.y - 150.0)
    )
    imp.died.connect(_on_enemy_died.bind(false))
    Fx.burst(imp.global_position, Color("#fbbf24"), 12)
    Audio.play("wave_start", -18.0)
    hud.show_notice("机关灵出现")

func _spawn_elite() -> void:
    var enemy = ENEMY_SCENE.instantiate()
    var mult := _difficulty_mult() * _wave_mult()
    enemy.max_health = int((24.0 + float(wave) * 6.0) * mult * 2.4)
    enemy.move_speed = 72.0
    enemy.contact_damage = int(float(6 + int(wave / 4) + (chapter - 1) * 2) * 1.3)
    enemy.coin_drop = 4
    enemy.elite = true
    enemy.scale = Vector2(1.7, 1.7)
    enemy.modulate = Color(1.0, 0.84, 0.55)
    enemies.add_child(enemy)
    enemy.global_position = _edge_spawn_position()
    enemy.add_to_group("elite")
    enemy.died.connect(_on_enemy_died)
    wave_spawned += 1
    Fx.burst(enemy.global_position, Color("#fbbf24"), 16)
    Audio.play("wave_start", -16.0)
    hud.show_notice("精英机关兵来袭")

func _spawn_boss() -> void:
    var boss = BOSS_SCENE.instantiate()
    var mult := _difficulty_mult() * (1.4 if wave >= 16 else 1.0)
    boss.max_health = int(1000.0 * mult)
    boss.move_speed = 55.0
    boss.contact_damage = 22 + (chapter - 1) * 3
    enemies.add_child(boss)
    boss.global_position = Vector2(get_viewport_rect().size.x * 0.5, -90.0)
    boss.health_changed.connect(hud.set_boss_health)
    boss.defeated.connect(_on_boss_defeated)
    boss.minion_spawned.connect(_on_boss_minion_spawned)
    hud.show_boss_bar(boss.health, boss.max_health)
    Audio.play("boss_spawn", -4.0)
    boss_spawned = true

func _on_boss_minion_spawned(minion) -> void:
    minion.died.connect(_on_enemy_died)
    var mult := _difficulty_mult() * _wave_mult()
    minion.max_health = int(24.0 * mult)
    minion.health = minion.max_health
    minion.contact_damage = 8 + int(wave / 3)

func _on_boss_defeated() -> void:
    var boss = get_tree().get_first_node_in_group("boss")
    if boss != null:
        _on_enemy_died(boss.global_position, 10)
    hud.hide_boss_bar()

func _on_enemy_died(drop_position: Vector2, coin_count: int, counts_toward_wave := true) -> void:
    total_kills += 1
    if counts_toward_wave and wave_active and not boss_wave:
        wave_killed = mini(wave_total, wave_killed + 1)
        wave_remaining = maxi(0, wave_total - wave_killed)
        hud.set_wave_progress(wave_remaining, wave_total, false)
    var base_value := _coin_value_for(wave)
    for index in range(coin_count):
        var coin = COIN_SCRIPT.new()
        coins.add_child(coin)
        coin.global_position = drop_position + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
        coin.setup(base_value, player, pickup_radius)
        coin.collected.connect(_on_coin_collected)

func _on_coin_collected(value: int) -> void:
    gold += int(float(value) * gold_mult)
    hud.set_gold(gold)

func _finish_wave() -> void:
    wave_active = false
    _collect_all_coins()
    _clear_enemies()
    _heal_after_wave()
    if not is_endless and wave >= WAVES_PER_STAGE:
        _on_stage_clear()
        return
    _open_shop()

func _heal_after_wave() -> void:
    var amount := int(ceil(float(player.max_health) * _wave_heal_ratio(boss_wave)))
    if amount <= 0:
        return
    var before: int = int(player.health)
    player.health = mini(int(player.max_health), int(player.health) + amount)
    if player.health != before:
        last_heal_amount = player.health - before
        player.health_changed.emit(player.health, player.max_health)
        hud.show_heal_feedback(last_heal_amount)

func _open_shop() -> void:
    shop_open = true
    get_tree().paused = true
    var stats: Dictionary = weapon_manager.get_item_stats()
    shop_free_rerolls = int(stats["free_rerolls"])
    var heal_note := ""
    if last_heal_amount > 0:
        heal_note = "生命恢复 +%d · " % last_heal_amount
    shop_message = heal_note + "花费金币，然后开始下一波"
    _generate_offers()
    if wave == 1:
        _ensure_starter_offer()
    _ensure_weapon_offer()
    hud.show_shop(_shop_data())
    last_heal_amount = 0

func _ensure_starter_offer() -> void:
    for offer in shop_offers:
        if offer["kind"] == "weapon" and int(offer["quality"]) == 1:
            return
    var weapon_types: Array = weapon_manager.get_weapon_types()
    var candidates: Array = []
    for weapon_type in weapon_types:
        if weapon_manager.can_buy_weapon(str(weapon_type), 1):
            candidates.append(str(weapon_type))
    var chosen := str(weapon_types[randi() % weapon_types.size()])
    if not candidates.is_empty():
        chosen = str(candidates[randi() % candidates.size()])
    var starter := {
        "kind": "weapon",
        "id": chosen,
        "quality": 1,
        "price": _offer_price("weapon", 1),
        "bought": false,
    }
    if shop_offers.is_empty():
        shop_offers.append(starter)
    else:
        shop_offers[shop_offers.size() - 1] = starter

func _ensure_weapon_offer() -> void:
    var weapon_count := 0
    for slot in weapon_manager.get_weapon_slots():
        if not slot.is_empty():
            weapon_count += 1
    if weapon_count >= 4:
        return
    for offer in shop_offers:
        if offer["kind"] == "weapon" and weapon_manager.can_buy_weapon(str(offer["id"]), int(offer["quality"])):
            return
    if shop_offers.is_empty():
        return
    var weapon_types: Array = weapon_manager.get_weapon_types()
    var candidates: Array = []
    for weapon_type in weapon_types:
        if weapon_manager.can_buy_weapon(str(weapon_type), 1):
            candidates.append(str(weapon_type))
    if candidates.is_empty():
        return
    shop_offers[shop_offers.size() - 1] = {
        "kind": "weapon",
        "id": str(candidates[randi() % candidates.size()]),
        "quality": 1,
        "price": _offer_price("weapon", 1),
        "bought": false,
    }

func _generate_offers() -> void:
    shop_offers.clear()
    var used := {}
    var attempts := 0
    while shop_offers.size() < SHOP_OFFER_COUNT and attempts < 40:
        attempts += 1
        var kind := "weapon" if randf() < 0.55 else "item"
        var id := ""
        if kind == "weapon":
            id = _pick_weapon_type()
        else:
            var item_ids: Array = weapon_manager.get_item_ids()
            id = item_ids[randi() % item_ids.size()]
        var quality := _roll_quality()
        var key := "%s:%s:%d" % [kind, id, quality]
        if used.has(key):
            continue
        used[key] = true
        var price := _offer_price(kind, quality)
        shop_offers.append({
            "kind": kind,
            "id": id,
            "quality": quality,
            "price": price,
            "bought": false,
        })

func _pick_weapon_type() -> String:
    var all_types: Array = weapon_manager.get_weapon_types()
    if randf() < 0.35:
        var owned_types: Array = []
        for weapon_type in all_types:
            var quality: int = weapon_manager.get_weapon_quality(str(weapon_type))
            if quality > 0 and quality < 4:
                owned_types.append(str(weapon_type))
        if not owned_types.is_empty():
            return str(owned_types[randi() % owned_types.size()])
    return str(all_types[randi() % all_types.size()])

func _roll_quality() -> int:
    return _quality_for_roll(randf(), _quality_progress())

func _offer_price(kind: String, quality: int) -> int:
    var prices := [0, 10, 22, 48, 96] if kind == "weapon" else [0, 8, 18, 38, 76]
    return prices[quality]

func _shop_data() -> Dictionary:
    var offers: Array = []
    for offer in shop_offers:
        var can_buy := false
        var title := ""
        var desc := ""
        var reason := ""
        var owned := 0
        if offer["kind"] == "weapon":
            can_buy = weapon_manager.can_buy_weapon(offer["id"], offer["quality"])
            title = weapon_manager.get_weapon_title(offer["id"])
            desc = weapon_manager.get_weapon_desc(offer["id"])
            owned = weapon_manager.get_weapon_quality(offer["id"])
        else:
            can_buy = weapon_manager.can_buy_item(offer["id"], offer["quality"])
            title = weapon_manager.get_item_title(offer["id"])
            desc = weapon_manager.get_item_desc(offer["id"])
            owned = weapon_manager.get_item_quality(offer["id"])
        if offer["bought"]:
            reason = "已售"
        elif can_buy and gold < int(offer["price"]):
            reason = "金币不足"
        elif not can_buy:
            if owned == 0:
                reason = "槽位已满"
            elif owned >= 4:
                reason = "已满级"
            else:
                reason = "需要同品质或更高"
        offers.append({
            "title": title,
            "desc": desc,
            "legendary_desc": weapon_manager.get_weapon_legendary_desc(offer["id"]) if offer["kind"] == "weapon" else "",
            "quality": int(offer["quality"]),
            "quality_name": weapon_manager.get_quality_name(offer["quality"]),
            "quality_color": weapon_manager.get_quality_color(offer["quality"]),
            "price": offer["price"],
            "bought": offer["bought"],
            "disabled": offer["bought"] or not can_buy or gold < int(offer["price"]),
            "reason": reason,
            "owned": owned,
            "kind": offer["kind"],
            "id": offer["id"],
        })
    var weapons: Array = weapon_manager.get_weapon_slots()
    for slot in weapons:
        if not slot.is_empty():
            slot["sell_price"] = int(float(_offer_price("weapon", int(slot["quality"]))) * 0.5 * sell_mult)
    var items: Array = weapon_manager.get_item_slots()
    for slot in items:
        if not slot.is_empty():
            slot["sell_price"] = int(float(_offer_price("item", int(slot["quality"]))) * 0.5 * sell_mult)
    return {
        "gold": gold,
        "health": player.health,
        "max_health": player.max_health,
        "heal_amount": last_heal_amount,
        "offers": offers,
        "weapons": weapons,
        "items": items,
        "reroll_cost": REROLL_COST,
        "free_rerolls": shop_free_rerolls,
        "message": shop_message,
        "wave": wave,
    }

func _on_buy_offer(index: int) -> void:
    if not shop_open or index < 0 or index >= shop_offers.size():
        return
    var offer: Dictionary = shop_offers[index]
    if offer["bought"] or gold < int(offer["price"]):
        shop_message = "金币不足"
        hud.refresh_shop(_shop_data())
        return

    var result: Dictionary
    if offer["kind"] == "weapon":
        result = weapon_manager.buy_weapon(offer["id"], offer["quality"])
    else:
        result = weapon_manager.buy_item(offer["id"], offer["quality"])
    if not result.get("ok", false):
        shop_message = "槽位已满或无法升品"
        hud.refresh_shop(_shop_data())
        return

    gold -= int(offer["price"])
    offer["bought"] = true
    var final_quality := int(result.get("quality", offer["quality"]))
    var quality_name: String = weapon_manager.get_quality_name(final_quality)
    var title: String = weapon_manager.get_weapon_title(offer["id"]) if offer["kind"] == "weapon" else weapon_manager.get_item_title(offer["id"])
    shop_message = ("获得 " if bool(result.get("new", false)) else "升品为 ") + quality_name + " " + title
    _apply_item_stats()
    hud.set_gold(gold)
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.set_item_slots(weapon_manager.get_item_slots())
    if _all_offers_bought():
        shop_message = "商店已刷新"
        _generate_offers()
    hud.refresh_shop(_shop_data())

func _all_offers_bought() -> bool:
    for offer in shop_offers:
        if not offer["bought"]:
            return false
    return true

func _on_reroll_shop() -> void:
    if not shop_open:
        return
    if shop_free_rerolls > 0:
        shop_free_rerolls -= 1
        shop_message = "免费刷新"
    elif gold >= REROLL_COST:
        gold -= REROLL_COST
        shop_message = "已刷新"
    else:
        shop_message = "金币不足"
        hud.refresh_shop(_shop_data())
        return
    _generate_offers()
    hud.set_gold(gold)
    hud.refresh_shop(_shop_data())

func _on_sell_weapon(weapon_id: String) -> void:
    if not shop_open:
        return
    var quality: int = weapon_manager.get_weapon_quality(weapon_id)
    if quality <= 0:
        return
    var price := int(float(_offer_price("weapon", quality)) * 0.5 * sell_mult)
    weapon_manager.sell_weapon(weapon_id)
    gold += price
    shop_message = "已出售，获得 %d 金币" % price
    _apply_item_stats()
    hud.set_gold(gold)
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.refresh_shop(_shop_data())

func _on_sell_item(item_id: String) -> void:
    if not shop_open:
        return
    var quality: int = weapon_manager.get_item_quality(item_id)
    if quality <= 0:
        return
    var price := int(float(_offer_price("item", quality)) * 0.5 * sell_mult)
    weapon_manager.sell_item(item_id)
    gold += price
    shop_message = "已出售，获得 %d 金币" % price
    _apply_item_stats()
    hud.set_gold(gold)
    hud.set_item_slots(weapon_manager.get_item_slots())
    hud.refresh_shop(_shop_data())

func _on_next_wave() -> void:
    if not shop_open:
        return
    shop_open = false
    get_tree().paused = false
    hud.hide_shop()
    wave += 1
    _start_wave(wave)

func _apply_item_stats() -> void:
    var stats: Dictionary = weapon_manager.get_item_stats()
    pickup_radius = float(stats["pickup_radius"])
    gold_mult = float(stats["gold_mult"])
    sell_mult = float(stats["sell_mult"])
    player.move_speed = 340.0 + float(stats["move_speed_bonus"])
    var new_max := 100 + int(stats["max_health_bonus"])
    if new_max != player.max_health:
        var gained: int = new_max - int(player.max_health)
        player.max_health = new_max
        if gained > 0:
            player.health += gained
        player.health = clampi(player.health, 0, new_max)
    player.health_changed.emit(player.health, player.max_health)
    hud.set_health(player.health, player.max_health)

func _on_stage_clear() -> void:
    stage_clear = true
    get_tree().paused = true
    if stage_index >= 0:
        if stage_index + 1 < STAGE_IDS.size():
            max_unlocked = maxi(max_unlocked, stage_index + 1)
        else:
            max_unlocked = STAGE_IDS.size()
        if stage_id == "3-1":
            endless_unlocked = true
        _save_progress()
        next_stage_id = STAGE_IDS[stage_index + 1] if stage_index + 1 < STAGE_IDS.size() else ""
    else:
        next_stage_id = ""
    var clear_text := "波次 %d / %d\n金币 %d\n%s" % [wave, WAVES_PER_STAGE, gold, _build_summary()]
    var next_label := ""
    if next_stage_id != "":
        next_label = "下一关 · %s %s" % [next_stage_id, _stage_name(next_stage_id)]
    else:
        next_label = "全关通关 · 无尽试炼已解锁"
    hud.show_stage_clear(
        _stage_label_with_name(),
        next_stage_id != "",
        clear_text,
        next_label
    )

func _build_summary() -> String:
    var weapons := 0
    for slot in weapon_manager.get_weapon_slots():
        if not slot.is_empty():
            weapons += 1
    var items := 0
    for slot in weapon_manager.get_item_slots():
        if not slot.is_empty():
            items += 1
    return "构筑 %d 武器 · %d 道具" % [weapons, items]

func _on_player_died() -> void:
    if game_over:
        return
    game_over = true
    wave_active = false
    if is_endless:
        best_endless_wave = maxi(best_endless_wave, wave)
        _save_progress()
    var died_text := ""
    if is_endless:
        died_text = "抵达第 %d 波\n金币 %d\n无尽最佳 %d" % [wave, gold, best_endless_wave]
    else:
        died_text = "抵达第 %d 波\n金币 %d\n%s" % [wave, gold, _build_summary()]
    hud.show_game_over(_stage_label_with_name(), died_text)
    Fx.clear_effects()
    weapon_manager.visible = false
    for projectile in projectiles.get_children():
        projectile.queue_free()
    get_tree().paused = true

func _on_stage_selected(id: String) -> void:
    RunState.selected_stage = id
    RunState.endless = false
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_endless_selected() -> void:
    RunState.selected_stage = ""
    RunState.endless = true
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_next_stage() -> void:
    if next_stage_id == "":
        return
    RunState.selected_stage = next_stage_id
    RunState.endless = false
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_retry_stage() -> void:
    RunState.selected_stage = stage_id
    RunState.endless = is_endless
    get_tree().paused = false
    get_tree().reload_current_scene()

func _on_stage_select() -> void:
    RunState.clear()
    get_tree().paused = false
    get_tree().reload_current_scene()

func _stage_select_data() -> Dictionary:
    var stages: Array = []
    for index in range(STAGE_IDS.size()):
        var parts: PackedStringArray = STAGE_IDS[index].split("-")
        var chapter_no := int(parts[0])
        var stage_no := int(parts[1])
        stages.append({
            "id": STAGE_IDS[index],
            "label": STAGE_IDS[index],
            "name": STAGE_NAMES[chapter_no - 1][stage_no - 1],
            "chapter": chapter_no,
            "stage": stage_no,
            "locked": index > max_unlocked,
            "cleared": index < max_unlocked,
        })
    var current_index := -1
    if max_unlocked < STAGE_IDS.size():
        current_index = max_unlocked
    return {
        "stages": stages,
        "chapter_names": CHAPTER_NAMES,
        "current_index": current_index,
        "cleared_count": mini(max_unlocked, STAGE_IDS.size()),
        "endless_unlocked": endless_unlocked,
        "best_endless": best_endless_wave,
    }

func _load_progress() -> void:
    var config := ConfigFile.new()
    if config.load(save_path) == OK:
        max_unlocked = int(config.get_value("campaign", "max_unlocked", 0))
        endless_unlocked = bool(config.get_value("campaign", "endless_unlocked", false))
        best_endless_wave = int(config.get_value("campaign", "best_endless_wave", 0))

func _save_progress() -> void:
    var config := ConfigFile.new()
    config.set_value("campaign", "max_unlocked", max_unlocked)
    config.set_value("campaign", "endless_unlocked", endless_unlocked)
    config.set_value("campaign", "best_endless_wave", best_endless_wave)
    config.save(save_path)

func _collect_all_coins() -> void:
    for coin in get_tree().get_nodes_in_group("coin"):
        if is_instance_valid(coin):
            gold += int(float(coin.value) * gold_mult)
            coin.queue_free()
    hud.set_gold(gold)

func _clear_arena() -> void:
    for enemy in enemies.get_children():
        enemy.queue_free()
    for projectile in projectiles.get_children():
        projectile.queue_free()
    for coin in get_tree().get_nodes_in_group("coin"):
        coin.queue_free()

func _clear_enemies() -> void:
    for enemy in enemies.get_children():
        enemy.queue_free()
    for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
        projectile.queue_free()

func _on_shake_requested(strength: float, duration: float) -> void:
    shake_strength = maxf(shake_strength, strength)
    shake_time = maxf(shake_time, duration)

func _update_shake(delta: float) -> void:
    if shake_time <= 0.0:
        return
    shake_time -= delta
    if shake_time <= 0.0:
        camera.offset = Vector2.ZERO
        shake_strength = 0.0
    else:
        camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength

func _draw() -> void:
    var view_size := get_viewport_rect().size
    var grid_color := Color(0.10, 0.18, 0.20, 0.55)
    var step := 80.0
    var x := 0.0
    while x <= view_size.x:
        draw_line(Vector2(x, 0.0), Vector2(x, view_size.y), grid_color, 1.0)
        x += step
    var y := 0.0
    while y <= view_size.y:
        draw_line(Vector2(0.0, y), Vector2(view_size.x, y), grid_color, 1.0)
        y += step
    draw_rect(Rect2(20.0, 20.0, view_size.x - 40.0, view_size.y - 40.0), Color(0.15, 0.75, 0.70, 0.45), false, 3.0)

func _capture_screenshot() -> void:
    await get_tree().create_timer(0.6).timeout
    max_unlocked = 1
    hud.show_stage_select(_stage_select_data())
    await get_tree().create_timer(0.5).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_stage_select.png")

    _begin_run("1-1", false)
    await get_tree().create_timer(1.6).timeout
    weapon_manager.buy_weapon("peony", 2)
    weapon_manager.buy_weapon("maple", 2)
    weapon_manager.buy_weapon("justice", 1)
    weapon_manager.buy_weapon("vigil", 3)
    weapon_manager.buy_item("magnet", 1)
    weapon_manager.buy_item("boots", 2)
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.set_item_slots(weapon_manager.get_item_slots())
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_battle.png")

    gold = 100
    hud.set_gold(gold)
    _test_finish_wave()
    await get_tree().create_timer(0.5).timeout
    if shop_open:
        shop_offers = [
            {"kind": "item", "id": "boots", "quality": 2, "price": 16, "bought": false},
            {"kind": "item", "id": "magnet", "quality": 2, "price": 18, "bought": false},
            {"kind": "weapon", "id": "peony", "quality": 4, "price": 96, "bought": false},
            {"kind": "weapon", "id": "hammer", "quality": 1, "price": 10, "bought": false},
        ]
        hud.refresh_shop(_shop_data())
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_shop.png")

    shop_open = false
    get_tree().paused = false
    hud.hide_shop()
    _start_wave(4)
    await get_tree().create_timer(0.8).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_treasure.png")

    _start_wave(6)
    await get_tree().create_timer(0.5).timeout
    var elite = get_tree().get_first_node_in_group("elite")
    if elite != null:
        elite.global_position = Vector2(640.0, 300.0)
    await get_tree().create_timer(0.25).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_elite.png")
    _clear_arena()

    _start_wave(8)
    await get_tree().create_timer(1.0).timeout
    var boss = get_tree().get_first_node_in_group("boss")
    if boss != null:
        boss.max_health = 99999
        boss.health = 99999
        hud.set_boss_health(99999, 99999)
    await get_tree().create_timer(3.0).timeout
    if boss != null and is_instance_valid(boss):
        boss.global_position = Vector2(640.0, 250.0)
        boss.velocity = Vector2.ZERO
    await get_tree().create_timer(0.25).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_boss.png")

    for enemy in enemies.get_children():
        enemy.queue_free()
    weapon_manager.visible = false
    Fx.clear_effects()
    stage_clear = true
    get_tree().paused = true
    hud.show_stage_clear("1-1 · 熔炉入口", true, "波次 16 / 16\n金币 100\n构筑 4 武器 · 2 道具", "下一关 · 1-2 风蚀回廊")
    await get_tree().create_timer(0.5).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_clear.png")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    print("SCREENSHOT_SAVED m5_stage_select.png m5_battle.png m5_shop.png m5_treasure.png m5_elite.png m5_boss.png m5_clear.png")
    get_tree().quit(0)

func _save_screenshot(path: String) -> Error:
    var image := get_viewport().get_texture().get_image()
    var error := image.save_png(path)
    if error != OK:
        push_error("SCREENSHOT_FAILED " + path + ": " + str(error))
    return error

func _run_smoke_test() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if not hud.is_stage_select_visible():
        _fail_test("stage select missing")
        return
    if hud.get_stage_button("1-1") == null:
        _fail_test("stage 1-1 button missing")
        return
    var balance_error := _check_balance_rules()
    if balance_error != "":
        _fail_test(balance_error)
        return
    var wave_error := _check_wave_rules()
    if wave_error != "":
        _fail_test(wave_error)
        return

    _begin_run("1-1", false)
    await get_tree().process_frame
    await get_tree().process_frame
    if player == null or not player.visible:
        _fail_test("player not active")
        return
    if wave != 1 or shop_open or get_tree().paused:
        _fail_test("run did not start at wave 1")
        return
    if weapon_manager.get_weapon_quality(STARTER_WEAPON) < 1:
        _fail_test("starter weapon missing")
        return
    if wave_total != 11 or wave_remaining != 11:
        _fail_test("wave quota not initialised")
        return
    if not hud.has_method("get_wave_remaining_text"):
        _fail_test("wave remaining HUD missing")
        return
    if hud.get_wave_remaining_text() != "剩余 11 / 11":
        _fail_test("wave remaining HUD wrong")
        return
    if absf(player.move_speed - 340.0) > 0.01:
        _fail_test("base move speed not tuned")
        return

    var joystick = get_tree().get_first_node_in_group("virtual_joystick")
    if joystick == null:
        _fail_test("virtual joystick missing")
        return
    if not joystick.has_method("_vector_for_offset"):
        _fail_test("joystick response helper missing")
        return
    if joystick._vector_for_offset(Vector2(3.0, 0.0)).length_squared() != 0.0:
        _fail_test("joystick dead zone too large")
        return
    if joystick._vector_for_offset(Vector2(72.0, 0.0)).length() < 0.95:
        _fail_test("joystick response curve too slow")
        return
    var input_mode := "windowed"
    if DisplayServer.get_name() == "headless":
        input_mode = "headless_vector"
        var start_position: Vector2 = player.global_position
        joystick.set_test_vector(Vector2.RIGHT)
        await get_tree().create_timer(0.35).timeout
        joystick.set_test_vector(Vector2.ZERO)
        if player.global_position.x <= start_position.x + 20.0:
            _fail_test("headless vector movement failed")
            return
    else:
        var joystick_rect: Rect2 = joystick.get_global_rect()
        if joystick_rect.size.x < 10.0:
            _fail_test("virtual joystick layout missing")
            return
        var joystick_center := joystick_rect.position + joystick_rect.size * 0.5
        var mouse_start: Vector2 = player.global_position
        await _simulate_drag(joystick_center, Vector2(90.0, 0.0), false)
        if player.global_position.x <= mouse_start.x + 20.0:
            _fail_test("mouse joystick did not move player")
            return
        var touch_start: Vector2 = player.global_position
        await _simulate_drag(joystick_center, Vector2(90.0, 0.0), true)
        if player.global_position.x <= touch_start.x + 20.0:
            _fail_test("touch joystick did not move player")
            return
        var keyboard_start: Vector2 = player.global_position
        var key_press := InputEventKey.new()
        key_press.keycode = KEY_D
        key_press.physical_keycode = KEY_D
        key_press.pressed = true
        Input.parse_input_event(key_press)
        await get_tree().create_timer(0.25).timeout
        var key_release := InputEventKey.new()
        key_release.keycode = KEY_D
        key_release.physical_keycode = KEY_D
        key_release.pressed = false
        Input.parse_input_event(key_release)
        await get_tree().process_frame
        if player.global_position.x <= keyboard_start.x + 10.0:
            _fail_test("keyboard did not move player")
            return

    var dash_button: Button = hud.get_node("Root/DashButton")
    var dash_start: Vector2 = player.global_position
    await _click_button(dash_button)
    await get_tree().create_timer(0.2).timeout
    if player.get_dash_cooldown_remaining() <= 0.0:
        _fail_test("dash cooldown did not start")
        return
    if not dash_button.disabled:
        _fail_test("dash button did not enter cooldown")
        return
    if player.global_position.distance_to(dash_start) <= 20.0:
        _fail_test("dash did not move player")
        return

    spawn_timer = 1.0e9
    _clear_enemies()
    player.global_position = Vector2(640.0, 360.0)
    player.health = player.max_health
    player.health_changed.emit(player.health, player.max_health)

    var gold_before_coin := gold
    _on_enemy_died(player.global_position, 1)
    await get_tree().create_timer(0.5).timeout
    if gold <= gold_before_coin:
        _fail_test("coin pickup did not grant gold")
        return

    var shooter = SHOOTER_SCENE.instantiate()
    shooter.max_health = 500
    shooter.move_speed = 80.0
    shooter.projectile_damage = 6
    enemies.add_child(shooter)
    shooter.global_position = Vector2(890.0, 360.0)
    await get_tree().create_timer(3.5).timeout
    if shooter.shots_fired <= 0:
        _fail_test("shooter did not fire")
        return
    if player.health >= player.max_health:
        _fail_test("shooter projectile did not hit player")
        return
    if hud.get_health_text() == "%d / %d" % [player.max_health, player.max_health]:
        _fail_test("health HUD did not update")
        return
    shooter.queue_free()
    for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
        projectile.queue_free()
    await get_tree().process_frame

    player.global_position = Vector2(640.0, 360.0)
    player.health = player.max_health
    player.health_changed.emit(player.health, player.max_health)
    var exploder = EXPLODER_SCENE.instantiate()
    exploder.max_health = 500
    exploder.move_speed = 80.0
    exploder.explosion_damage = 20
    enemies.add_child(exploder)
    exploder.global_position = Vector2(940.0, 360.0)
    await get_tree().create_timer(4.5).timeout
    if player.health >= player.max_health:
        _fail_test("exploder did not damage player")
        return
    if is_instance_valid(exploder) and not exploder.is_queued_for_deletion():
        exploder.queue_free()
    for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
        projectile.queue_free()
    await get_tree().process_frame
    player.health = 30
    player.health_changed.emit(player.health, player.max_health)

    _clear_enemies()
    spawn_timer = 1.0e9
    wave_spawned = wave_total
    wave_killed = wave_total - 1
    wave_remaining = 1
    await get_tree().create_timer(0.4).timeout
    if shop_open:
        _fail_test("wave finished with enemies remaining")
        return
    _spawn_enemy()
    await get_tree().process_frame
    for enemy in enemies.get_children():
        enemy.take_damage(999999)
    await get_tree().create_timer(0.5).timeout
    if not shop_open or not hud.is_shop_visible():
        _fail_test("shop did not open after wave")
        return
    if player.health <= 30:
        _fail_test("wave heal missing")
        return
    var has_starter := false
    for offer in shop_offers:
        if offer["kind"] == "weapon" and int(offer["quality"]) == 1:
            has_starter = true
            break
    if not has_starter:
        _fail_test("starter weapon offer missing")
        return

    gold = 100
    hud.set_gold(gold)
    shop_offers[0] = {
        "kind": "weapon",
        "id": "maple",
        "quality": 1,
        "price": 10,
        "bought": false,
    }
    hud.refresh_shop(_shop_data())
    if hud.get_shop_offer_badge(0) != "可升品":
        _fail_test("merge badge missing")
        return
    var offer_button: Button = null
    for index in range(4):
        var button: Button = hud.get_shop_offer_button(index)
        if button != null and button.visible and not button.disabled:
            offer_button = button
            break
    if offer_button == null:
        _fail_test("no buyable shop offer")
        return
    var gold_before_buy := gold
    var build_before_buy: String = weapon_manager.get_build_signature()
    await _click_button(offer_button)
    await get_tree().create_timer(0.2).timeout
    if gold >= gold_before_buy:
        _fail_test("shop purchase did not cost gold")
        return
    if weapon_manager.get_build_signature() == build_before_buy:
        _fail_test("shop purchase did not change build")
        return

    var merge_type := ""
    for weapon_type in weapon_manager.get_weapon_types():
        if weapon_manager.get_weapon_quality(str(weapon_type)) == 0:
            merge_type = str(weapon_type)
            break
    if merge_type == "":
        _fail_test("no weapon type available for merge test")
        return
    weapon_manager.buy_weapon(merge_type, 1)
    weapon_manager.buy_weapon(merge_type, 1)
    if weapon_manager.get_weapon_quality(merge_type) < 2:
        _fail_test("weapon merge did not upgrade quality")
        return
    weapon_manager.sell_weapon(merge_type)
    if weapon_manager.get_weapon_quality(merge_type) != 0:
        _fail_test("weapon sell failed")
        return

    var item_type := ""
    for candidate in ["jade", "magnet", "boots", "holy_fire"]:
        if weapon_manager.get_item_quality(candidate) == 0:
            item_type = candidate
            break
    if item_type == "":
        _fail_test("no item available for effect test")
        return
    var item_before: Dictionary = weapon_manager.get_item_stats()
    weapon_manager.buy_item(item_type, 1)
    _apply_item_stats()
    if weapon_manager.get_item_quality(item_type) < 1:
        _fail_test("item purchase failed")
        return
    if item_type == "jade" and gold_mult <= 1.0:
        _fail_test("jade effect did not apply")
        return
    if item_type == "magnet" and pickup_radius <= float(item_before["pickup_radius"]):
        _fail_test("magnet effect did not apply")
        return
    if item_type == "boots" and player.move_speed <= 340.0:
        _fail_test("boots effect did not apply")
        return
    if item_type == "holy_fire":
        if player.max_health <= 100:
            _fail_test("holy fire effect did not apply")
            return
        if player.health != player.max_health:
            _fail_test("holy fire did not heal")
            return
    weapon_manager.sell_item(item_type)
    _apply_item_stats()

    var gold_before_reroll := gold
    await _click_button(hud.get_reroll_button())
    await get_tree().create_timer(0.2).timeout
    if gold != gold_before_reroll - REROLL_COST:
        _fail_test("shop reroll did not cost gold")
        return

    await _click_button(hud.get_next_wave_button())
    await get_tree().create_timer(0.3).timeout
    if shop_open or get_tree().paused:
        _fail_test("next wave did not leave shop")
        return
    if wave != 2:
        _fail_test("next wave did not advance")
        return

    _start_wave(4)
    await get_tree().create_timer(0.4).timeout
    var treasures := get_tree().get_nodes_in_group("treasure")
    if treasures.is_empty():
        _fail_test("wave 4 treasure imp missing")
        return
    var gold_before_treasure := gold
    treasures[0].take_damage(999999)
    await get_tree().create_timer(0.2).timeout
    if coins.get_child_count() < 6 and gold <= gold_before_treasure:
        _fail_test("treasure imp coin drop missing")
        return
    _clear_arena()

    _start_wave(6)
    await get_tree().create_timer(0.4).timeout
    var elites := get_tree().get_nodes_in_group("elite")
    if elites.is_empty():
        _fail_test("wave 6 elite missing")
        return
    var gold_before_elite := gold
    var elite = elites[0]
    elite.take_damage(999999)
    await get_tree().create_timer(0.2).timeout
    if coins.get_child_count() < 4 and gold <= gold_before_elite:
        _fail_test("elite coin drop missing")
        return
    _clear_arena()

    _start_wave(8)
    await get_tree().create_timer(0.9).timeout
    var boss = get_tree().get_first_node_in_group("boss")
    if boss == null or not hud.is_boss_bar_visible():
        _fail_test("wave 8 boss missing")
        return
    boss._spawn_minions()
    await get_tree().process_frame
    var minion_hooked := false
    for node in enemies.get_children():
        if node == boss or not node.has_signal("died"):
            continue
        if node.died.get_connections().size() > 0:
            minion_hooked = true
            break
    if not minion_hooked:
        _fail_test("boss minion coin hook missing")
        return
    boss.take_damage(999999)
    await get_tree().create_timer(0.6).timeout
    if not shop_open:
        _fail_test("shop missing after wave 8 boss")
        return
    await _click_button(hud.get_next_wave_button())
    await get_tree().create_timer(0.3).timeout
    if wave != 9:
        _fail_test("wave 9 did not start")
        return

    _start_wave(16)
    await get_tree().create_timer(0.9).timeout
    boss = get_tree().get_first_node_in_group("boss")
    if boss == null:
        _fail_test("wave 16 boss missing")
        return
    boss.take_damage(999999)
    await get_tree().create_timer(0.6).timeout
    if not stage_clear or not hud.is_end_panel_visible():
        _fail_test("stage clear panel missing")
        return
    if max_unlocked < 1 or next_stage_id != "1-2":
        _fail_test("stage unlock missing")
        return

    stage_id = "3-1"
    stage_index = 8
    _on_stage_clear()
    if not endless_unlocked:
        _fail_test("endless not unlocked after 3-1")
        return
    stage_id = "3-4"
    stage_index = STAGE_IDS.size() - 1
    _on_stage_clear()
    if max_unlocked != STAGE_IDS.size():
        _fail_test("final stage clear not recorded")
        return
    var config := ConfigFile.new()
    if config.load(save_path) != OK:
        _fail_test("campaign save missing")
        return
    if not bool(config.get_value("campaign", "endless_unlocked", false)):
        _fail_test("campaign save content wrong")
        return

    _begin_run("", true)
    await get_tree().process_frame
    await get_tree().process_frame
    if not is_endless or wave != 1:
        _fail_test("endless run did not start")
        return
    _test_finish_wave()
    await get_tree().create_timer(0.5).timeout
    if not shop_open:
        _fail_test("endless shop missing")
        return
    await _click_button(hud.get_next_wave_button())
    await get_tree().create_timer(0.3).timeout
    if wave != 2:
        _fail_test("endless wave did not advance")
        return

    player.take_damage(999999)
    await get_tree().create_timer(0.3).timeout
    if not hud.is_end_panel_visible():
        _fail_test("game over panel missing")
        return
    if hud.get_retry_button() == null:
        _fail_test("game over retry button missing")
        return

    if Audio.get_sound_names().size() < 17:
        _fail_test("audio sounds missing")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    print("SMOKE_TEST_PASS input=%s stage_select=true shop=true merge=true coins=true enemies=true boss8=true stage_clear=true endless=true build=%s" % [input_mode, weapon_manager.get_build_signature()])
    get_tree().quit(0)

func _check_balance_rules() -> String:
    if not has_method("_quality_for_roll"):
        return "quality helper missing"
    if _quality_for_roll(0.0, 1.0) != 4:
        return "quality q4 boundary wrong"
    if _quality_for_roll(0.13, 1.0) != 3:
        return "quality q3 boundary wrong"
    if _quality_for_roll(0.45, 1.0) != 2:
        return "quality q2 boundary wrong"
    if _quality_for_roll(0.95, 1.0) != 1:
        return "quality q1 boundary wrong"
    if not has_method("_quality_chances"):
        return "quality chances helper missing"
    var chances: Array = _quality_chances(1.0)
    if float(chances[0]) >= float(chances[1]):
        return "legendary must be rarer than epic"
    if not is_equal_approx(_quality_progress_for(0, false, 1), 0.0):
        return "campaign quality progress start wrong"
    if not is_equal_approx(_quality_progress_for(11, false, 1), 1.0):
        return "campaign quality progress end wrong"
    if not is_equal_approx(_quality_progress_for(0, true, 50), 1.0):
        return "endless quality progress cap wrong"
    if _offer_price("weapon", 1) != 10 or _offer_price("weapon", 4) != 96:
        return "weapon prices wrong"
    if _offer_price("item", 1) != 8 or _offer_price("item", 4) != 76:
        return "item prices wrong"
    if _coin_value_for(16) != 3:
        return "coin value wrong"
    if _enemy_cap_for(16) != 32:
        return "enemy cap wrong"
    if _spawn_interval_for(16, 3) > 0.34:
        return "late spawn interval wrong"
    if not _is_elite_wave(6) or _is_elite_wave(7) or not _is_elite_wave(14):
        return "elite schedule wrong"
    if not is_equal_approx(_wave_heal_ratio(false), 0.10):
        return "normal wave heal wrong"
    if not is_equal_approx(_wave_heal_ratio(true), 0.25):
        return "boss wave heal wrong"
    return ""

func _check_wave_rules() -> String:
    if not has_method("_wave_enemy_count_for"):
        return "wave quota helper missing"
    if _wave_enemy_count_for(1, 1, false) != 11:
        return "wave 1 quota wrong"
    if _wave_enemy_count_for(16, 1, false) != 26:
        return "wave 16 quota wrong"
    if _wave_enemy_count_for(16, 3, false) != 30:
        return "chapter quota scaling wrong"
    if _wave_enemy_count_for(1, 1, true) != 14:
        return "endless quota wrong"
    return ""

func _test_finish_wave() -> void:
    spawn_timer = 1.0e9
    wave_spawned = wave_total
    wave_killed = wave_total
    wave_remaining = 0
    _clear_enemies()

func _fail_test(reason: String) -> void:
    push_error("SMOKE_TEST_FAIL: " + reason)
    get_tree().quit(1)

func _click_button(button: Button, use_touch := false) -> void:
    if DisplayServer.get_name() == "headless":
        button.pressed.emit()
        await get_tree().process_frame
        return
    var rect := button.get_global_rect()
    var center := rect.position + rect.size * 0.5
    if use_touch:
        var touch_press := InputEventScreenTouch.new()
        touch_press.index = 0
        touch_press.pressed = true
        touch_press.position = center
        Input.parse_input_event(touch_press)
        await get_tree().process_frame
        await get_tree().process_frame
        var touch_release := InputEventScreenTouch.new()
        touch_release.index = 0
        touch_release.pressed = false
        touch_release.position = center
        Input.parse_input_event(touch_release)
        await get_tree().process_frame
        await get_tree().process_frame
        return
    var motion := InputEventMouseMotion.new()
    motion.position = center
    Input.parse_input_event(motion)
    await get_tree().process_frame
    await get_tree().process_frame
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT
    press.pressed = true
    press.position = center
    Input.parse_input_event(press)
    await get_tree().process_frame
    await get_tree().process_frame
    var release := InputEventMouseButton.new()
    release.button_index = MOUSE_BUTTON_LEFT
    release.pressed = false
    release.position = center
    Input.parse_input_event(release)
    await get_tree().process_frame
    await get_tree().process_frame

func _simulate_drag(center: Vector2, offset: Vector2, is_touch: bool) -> void:
    if is_touch:
        var touch_press := InputEventScreenTouch.new()
        touch_press.index = 0
        touch_press.pressed = true
        touch_press.position = center
        Input.parse_input_event(touch_press)
    else:
        var mouse_press := InputEventMouseButton.new()
        mouse_press.button_index = MOUSE_BUTTON_LEFT
        mouse_press.pressed = true
        mouse_press.position = center
        Input.parse_input_event(mouse_press)
    await get_tree().process_frame
    if is_touch:
        var touch_drag := InputEventScreenDrag.new()
        touch_drag.index = 0
        touch_drag.position = center + offset
        touch_drag.relative = offset
        Input.parse_input_event(touch_drag)
    else:
        var mouse_drag := InputEventMouseMotion.new()
        mouse_drag.position = center + offset
        mouse_drag.relative = offset
        mouse_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
        Input.parse_input_event(mouse_drag)
    await get_tree().create_timer(0.35).timeout
    if is_touch:
        var touch_release := InputEventScreenTouch.new()
        touch_release.index = 0
        touch_release.pressed = false
        touch_release.position = center + offset
        Input.parse_input_event(touch_release)
    else:
        var mouse_release := InputEventMouseButton.new()
        mouse_release.button_index = MOUSE_BUTTON_LEFT
        mouse_release.pressed = false
        mouse_release.position = center + offset
        Input.parse_input_event(mouse_release)
    await get_tree().process_frame
