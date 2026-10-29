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
const CHAPTER_NAMES := ["第一章 · 青炉洞天", "第二章 · 赤沙古渡", "第三章 · 天工禁地"]
const STAGE_NAMES := [
    ["青炉入口", "风蚀回廊", "机枢深渊", "玄枢秘境"],
    ["赤沙门", "流沙阱", "风暴眼", "沙王座"],
    ["禁地门", "铜人阵", "天工台", "百炼殿"],
]
const CHAPTER_MULT := [1.0, 1.22, 1.48]
const STAGE_MULT := 0.05
const HERO_ATTRIBUTE_WEAPON_DAMAGE := 1.15
const HERO_DAMAGE_PER_LEVEL := 0.02
const HERO_MAX_LEVEL := 20
const HERO_XP_BASE := 6
const HERO_XP_STEP := 2
const WAVES_PER_STAGE := 16
const BOSS_WAVES := [8, 16]
const START_GOLD := 15
const CHAPTER_START_GOLD := 5
const REROLL_COST := 2
const SHOP_OFFER_COUNT := 4
const STARTER_WEAPON := "maple"
const SECOND_STARTERS := ["peony", "justice", "elixir"]
const SAVE_PATH := "user://arena_survivor.cfg"
const TEST_SAVE_PATH := "user://arena_survivor_test.cfg"
const PLAYTEST_SAVE_PATH := "user://arena_survivor_playtest.cfg"
const REPORT_PATH := "user://run_report.json"
const TEST_REPORT_PATH := "user://arena_survivor_report_test.json"
const WAVE_PLAN_PATH := "res://data/waves.json"
const WAVE_PATTERNS := ["ring", "two_sides", "one_side", "cone"]
const WAVE_PLAN_KINDS := ["chaser", "shooter", "exploder"]

@onready var player = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var coins: Node2D = $Coins
@onready var hud = $HUD
@onready var weapon_manager = $Player/WeaponManager
@onready var camera: Camera2D = $Camera2D

var save_path := SAVE_PATH
var test_mode := false

var _cli_args: Array = []
var _debug_invuln := false

var _survival_sec := 0.0
var _idle_sec := 0.0
var _last_frame_usec := 0
var _wave_start_sec := 0.0
var _wave_durations: Array = []
var _damage_taken_log: Array = []
var _skill_casts := 0
var _skill_damage := 0.0
var _report_gold_earned := 0
var _report_gold_spent := 0

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
var hero_level := 1
var hero_xp := 0
var hero_xp_to_next := 6
var pickup_radius := 60.0
var gold_mult := 1.0
var sell_mult := 1.0
var shop_free_rerolls := 0
var shop_message := ""
var shop_offers: Array = []
var last_heal_amount := 0
var next_stage_id := ""

var _wave_plans: Dictionary = {}
var _plan_side_chosen := false
var _plan_side := 0

var max_unlocked := 0
var endless_unlocked := false
var best_endless_wave := 0
var total_kills := 0
var backdrop = null
var backdrop_static = null

var shake_time := 0.0
var shake_strength := 0.0
var _zoom_base := Vector2.ONE
var _zoom_pulse_ms := 0.0
var _zoom_pulse_amount := 0.0
var _zoom_pulse_start_ms := 0

func _ready() -> void:
    _cli_args = _cmdline_flags()
    test_mode = _cli_args.has("--smoke-test") or _cli_args.has("--screenshot") or _cli_args.has("--playtest")
    if test_mode:
        save_path = PLAYTEST_SAVE_PATH if _cli_args.has("--playtest") else TEST_SAVE_PATH
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
        DirAccess.remove_absolute(ProjectSettings.globalize_path(_report_path()))

    # 性能：背景拆静态/动态两层。静态层只在 set_chapter 时重绘一次，
    # 动态层只保留光柱/地纹/余烬/浮尘这些真正逐帧变化的内容。
    backdrop_static = load("res://scripts/arena_backdrop_static.gd").new()
    add_child(backdrop_static)
    move_child(backdrop_static, 0)
    backdrop_static.set_chapter(1)

    backdrop = load("res://scripts/arena_backdrop.gd").new()
    add_child(backdrop)
    move_child(backdrop, 1)
    backdrop.set_chapter(1)

    # 性能：--perf 时挂上帧预算探针（不传该参数则完全不创建，零开销）
    if _cli_args.has("--perf"):
        add_child(load("res://scripts/perf_probe.gd").new())

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
    hud.skill_requested.connect(player.try_cast_skill)
    player.health_changed.connect(hud.set_health)
    player.skill_cast.connect(_on_skill_cast)
    Fx.shake_requested.connect(_on_shake_requested)

    _load_wave_plans()
    _load_progress()
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.set_item_slots(weapon_manager.get_item_slots())

    if RunState.endless:
        _begin_run("", true)
    elif RunState.selected_stage != "":
        _begin_run(RunState.selected_stage, false)
    else:
        _show_stage_select()

    _post_ready()

## 兼容两种写法：`godot --path . -- --smoke-test`（Godot 官方约定，取 user_args）
## 和 `godot --path . --smoke-test`（CI/脚本习惯，参数落在 cmdline_args）。
## 只做补读，不改任何测试分支的判定逻辑。
func _cmdline_flags() -> Array:
    var args := OS.get_cmdline_user_args()
    for arg in OS.get_cmdline_args():
        if arg == "--smoke-test" or arg == "--playtest" or arg == "--screenshot" or arg == "--perf":
            if not args.has(arg):
                args.append(arg)
    return args

## 调试热键仅在 debug 构建且非测试/截图/回放模式下生效；
## 发布导出（OS.is_debug_build() == false）下整套按键完全惰性。
func _debug_keys_enabled() -> bool:
    return OS.is_debug_build() and not (
        _cli_args.has("--smoke-test") or _cli_args.has("--playtest") or _cli_args.has("--screenshot"))

func _unhandled_input(event: InputEvent) -> void:
    if not _debug_keys_enabled():
        return
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_F1:
            _debug_next_wave()
        KEY_F2:
            _debug_clear_enemies()
        KEY_F3:
            _debug_toggle_invuln()
        KEY_F4:
            _debug_add_gold(100)
        KEY_F5:
            _debug_toggle_shop()
        KEY_F6:
            _debug_cycle_time_scale()
        KEY_F7:
            _debug_force_boss()
        KEY_F8:
            _debug_random_legendary()
        KEY_F10:
            _export_run_report()

func _debug_next_wave() -> void:
    if menu_open or game_over or stage_clear:
        return
    if shop_open:
        _on_next_wave()
        return
    _clear_enemies()
    wave += 1
    _start_wave(wave)

func _debug_clear_enemies() -> void:
    _clear_enemies()

func _debug_toggle_invuln() -> void:
    _debug_invuln = not _debug_invuln
    hud.set_debug_invuln(_debug_invuln)
    if _debug_invuln:
        hud.show_notice("调试无敌已开启")

func _debug_add_gold(amount: int) -> void:
    gold += amount
    _report_gold_earned += amount
    hud.set_gold(gold)

func _debug_toggle_shop() -> void:
    if wave_active or game_over or stage_clear or menu_open:
        return
    if shop_open:
        _on_next_wave()
    else:
        _open_shop()

func _debug_cycle_time_scale() -> void:
    var next_scale := 1.0
    if is_equal_approx(Engine.time_scale, 1.0):
        next_scale = 2.0
    elif is_equal_approx(Engine.time_scale, 2.0):
        next_scale = 4.0
    Engine.time_scale = next_scale
    hud.show_notice("时间倍率 ×%d" % int(next_scale))

func _debug_force_boss() -> void:
    if menu_open or game_over or stage_clear:
        return
    if shop_open:
        shop_open = false
        get_tree().paused = false
        hud.hide_shop()
    _clear_enemies()
    _start_wave(8)

func _debug_random_legendary() -> void:
    if menu_open or shop_open or game_over or stage_clear or not wave_active:
        return
    var candidates: Array = []
    for weapon_type in weapon_manager.get_weapon_types():
        if weapon_manager.get_weapon_quality(str(weapon_type)) == 0:
            candidates.append(str(weapon_type))
    if candidates.is_empty():
        hud.show_notice("无空台位")
        return
    var chosen := str(candidates[randi() % candidates.size()])
    var result: Dictionary = weapon_manager.buy_weapon(chosen, 4)
    if not result.get("ok", false):
        hud.show_notice("台位装配失败")
        return
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.show_notice("传说 %s 已部署" % weapon_manager.get_weapon_title(chosen))

func _report_path() -> String:
    return TEST_REPORT_PATH if test_mode else REPORT_PATH

func _on_skill_cast() -> void:
    _skill_casts += 1

func _record_skill_damage(amount: int) -> void:
    _skill_damage += float(amount)

func _record_damage_taken(amount: int, source: String) -> void:
    _damage_taken_log.append({"wave": wave, "t": snappedf(_survival_sec, 0.01), "amount": amount, "source": source})

func _export_run_report() -> Dictionary:
    var weapons := {}
    for weapon_id in weapon_manager.get_weapon_types():
        weapons[str(weapon_id)] = {"damage": 0.0, "hits": 0}
    var damage_report: Dictionary = weapon_manager.get_weapon_damage_report()
    for weapon_id in damage_report.keys():
        var entry: Dictionary = damage_report[weapon_id]
        weapons[str(weapon_id)] = {
            "damage": float(entry.get("damage", 0.0)),
            "hits": int(entry.get("hits", 0)),
        }
    var report := {
        "stage": "endless" if is_endless else stage_id,
        "wave_reached": wave,
        "survival_sec": snappedf(_survival_sec, 0.01),
        "hero_level": hero_level,
        "gold": {
            "earned": _report_gold_earned,
            "spent": _report_gold_spent,
            "remaining": gold,
        },
        "weapons": weapons,
        "skill": {"casts": _skill_casts, "damage": _skill_damage},
        "damage_taken": _damage_taken_log.duplicate(true),
        "waves": _wave_durations.duplicate(),
        "idle_sec": snappedf(_idle_sec, 0.01),
    }
    var file := FileAccess.open(_report_path(), FileAccess.WRITE)
    if file == null:
        push_warning("run report write failed: %s" % _report_path())
        return report
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    print("RUN_REPORT_WRITTEN path=%s wave=%d survival_sec=%.1f" % [_report_path(), wave, _survival_sec])
    return report

func _process(delta: float) -> void:
    _update_shake(delta)
    _update_zoom_pulse()
    var now_usec := Time.get_ticks_usec()
    if _last_frame_usec > 0 and wave_active:
        var wall_delta := float(now_usec - _last_frame_usec) / 1000000.0
        _survival_sec += wall_delta
        if player.get_move_input().length() < 0.1:
            _idle_sec += wall_delta
    _last_frame_usec = now_usec
    if _debug_invuln and not player.is_dead:
        player.invuln_time = maxf(player.invuln_time, 0.25)
    if menu_open or shop_open or game_over or stage_clear:
        return
    if not wave_active:
        return
    if player.is_dead:
        _on_player_died()
        return

    hud.set_skill_state(player.can_cast_skill(), player.get_skill_cooldown_remaining(), player.get_skill_cooldown_total())

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
    if backdrop != null:
        backdrop.set_chapter(chapter)
    if backdrop_static != null:
        backdrop_static.set_chapter(chapter)
    shop_offers.clear()
    shop_message = ""
    last_heal_amount = 0
    total_kills = 0
    _survival_sec = 0.0
    _idle_sec = 0.0
    _last_frame_usec = 0
    _wave_start_sec = 0.0
    _wave_durations.clear()
    _damage_taken_log.clear()
    _skill_casts = 0
    _skill_damage = 0.0
    _report_gold_earned = 0
    _report_gold_spent = 0

    _clear_arena()
    player.visible = true
    player.set_physics_process(true)
    player.global_position = Vector2(640.0, 360.0)
    player.reset_for_run()
    hero_level = 1
    hero_xp = 0
    hero_xp_to_next = _hero_xp_needed(hero_level)
    weapon_manager.visible = true
    weapon_manager.reset_build()
    _apply_hero_level()
    weapon_manager.buy_weapon(STARTER_WEAPON, mini(4, chapter))
    var second_starter := _pick_second_starter()
    if second_starter != "":
        weapon_manager.buy_weapon(second_starter, 1)
    player.set_wave_info(1, chapter)
    _apply_item_stats()
    hud.hide_stage_select()
    hud.hide_shop()
    hud.hide_end_panel()
    hud.set_stage(_stage_label())
    hud.set_chapter_art(chapter)
    hud.set_best_wave(best_endless_wave)
    hud.set_gold(gold)
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.set_item_slots(weapon_manager.get_item_slots())
    _start_wave(1)

func _pick_second_starter() -> String:
    return str(SECOND_STARTERS[randi() % SECOND_STARTERS.size()])

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
        return 1.0
    return _stage_hp_mult_for(chapter, stage_number)

func _wave_mult() -> float:
    return _wave_hp_mult_for(wave, is_endless)

func _stage_hp_mult_for(chapter_no: int, stage_no: int) -> float:
    return CHAPTER_MULT[chapter_no - 1] + float(stage_no - 1) * STAGE_MULT

func _wave_hp_mult_for(wave_no: int, endless: bool) -> float:
    if endless:
        return pow(1.055, float(wave_no - 1))
    var value := pow(1.045, float(wave_no - 1))
    if wave_no >= 12:
        value *= 1.10
    return value

func _base_enemy_hp(kind: String, wave_no: int) -> float:
    match kind:
        "shooter":
            return 18.0 + 4.0 * float(wave_no)
        "exploder":
            return 28.0 + 5.0 * float(wave_no)
        _:
            return 24.0 + 4.5 * float(wave_no)

func _enemy_hp_for(kind: String, wave_no: int, chapter_no: int, stage_no: int, endless: bool) -> int:
    var chapter_mult := 1.0 if endless else _stage_hp_mult_for(chapter_no, stage_no)
    return int(_base_enemy_hp(kind, wave_no) * chapter_mult * _wave_hp_mult_for(wave_no, endless))

func _contact_damage_for(wave_no: int, chapter_no: int) -> int:
    return 6 + int(wave_no / 5.0) + int(float(chapter_no - 1) * 1.5)

func _shooter_damage_for(wave_no: int, chapter_no: int) -> int:
    return 5 + int(wave_no / 5.0) + int(float(chapter_no - 1) * 1.5)

func _exploder_damage_for(wave_no: int, chapter_no: int) -> int:
    return 18 + wave_no + (chapter_no - 1) * 3

func _boss_contact_for(chapter_no: int) -> int:
    return 20 + (chapter_no - 1) * 2

func _chapter_gold_mult() -> float:
    if is_endless:
        return 1.0
    return _chapter_gold_mult_for(chapter)

func _chapter_gold_mult_for(chapter_no: int) -> float:
    if chapter_no <= 0:
        return 1.0
    return [1.0, 1.15, 1.3][mini(chapter_no, 3) - 1]

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
    return 0.35 if is_boss else 0.15

func _start_wave(number: int) -> void:
    wave = number
    while _wave_durations.size() < number:
        _wave_durations.append(0.0)
    _wave_start_sec = _survival_sec
    weapon_manager.set_wave_power(number, chapter)
    player.set_wave_info(number, chapter)
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
    _plan_side_chosen = false
    _plan_side = 0
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

## 波次计划（data/waves.json）：只约束敌人组合与出怪方向，不改数量/数值。
## 任何一步读取或校验失败都返回空字典，_pick_enemy_type/_edge_spawn_position 自动回退原有随机逻辑。
func _wave_plan_for(wave_no: int) -> Dictionary:
    var plan: Variant = _wave_plans.get(wave_no, {})
    if plan is Dictionary:
        return plan
    return {}

func _load_wave_plans() -> void:
    _wave_plans = {}
    if not FileAccess.file_exists(WAVE_PLAN_PATH):
        push_warning("data/waves.json 缺失，波次计划回退随机逻辑")
        return
    var file := FileAccess.open(WAVE_PLAN_PATH, FileAccess.READ)
    if file == null:
        push_warning("data/waves.json 打开失败，波次计划回退随机逻辑")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if not (parsed is Dictionary):
        push_warning("data/waves.json 解析失败，波次计划回退随机逻辑")
        return
    for key in parsed.keys():
        if not (key is String) or not (key as String).is_valid_int():
            continue
        var wave_no := int(key)
        if wave_no < 1 or wave_no > WAVES_PER_STAGE:
            continue
        var raw: Variant = parsed[key]
        if not (raw is Dictionary):
            push_warning("waves.json 第 %d 波计划格式错误，回退随机逻辑" % wave_no)
            continue
        var plan := _validated_plan(wave_no, raw)
        if not plan.is_empty():
            _wave_plans[wave_no] = plan

func _validated_plan(wave_no: int, raw: Dictionary) -> Dictionary:
    var pattern := str(raw.get("pattern", ""))
    if not WAVE_PATTERNS.has(pattern):
        push_warning("waves.json 第 %d 波 pattern 无效，回退随机逻辑" % wave_no)
        return {}
    var weights := _validated_weights(raw.get("weights", null))
    if weights.is_empty():
        push_warning("waves.json 第 %d 波 weights 无效，回退随机逻辑" % wave_no)
        return {}
    var plan := {"pattern": pattern, "weights": weights}
    plan["burst"] = clampi(int(raw.get("burst", 1)), 1, 8)
    var edges_raw: Variant = raw.get("edges", [])
    var clean_edges: Array = []
    if edges_raw is Array:
        for edge in edges_raw:
            var edge_index := _edge_index(str(edge))
            if edge_index >= 0:
                clean_edges.append(["top", "right", "bottom", "left"][edge_index])
    if clean_edges.size() > 0:
        plan["edges"] = clean_edges
    if bool(raw.get("diagonal", false)):
        plan["diagonal"] = true
    var sides_raw: Variant = raw.get("sides", [])
    var clean_sides: Array = []
    if sides_raw is Array:
        for side in sides_raw:
            var side_weights := _validated_weights(side)
            if not side_weights.is_empty():
                clean_sides.append(side_weights)
    if clean_sides.size() == 2 and pattern == "two_sides":
        plan["sides"] = clean_sides
    return plan

func _validated_weights(raw: Variant) -> Dictionary:
    if not (raw is Dictionary):
        return {}
    var weights := {}
    var total := 0
    for kind in WAVE_PLAN_KINDS:
        var value: Variant = raw.get(kind, 0)
        if not (value is int or value is float):
            return {}
        var weight := maxi(0, int(value))
        weights[kind] = weight
        total += weight
    if total <= 0:
        return {}
    return weights

func _pick_enemy_type() -> String:
    var plan := _wave_plan_for(wave)
    if not plan.is_empty():
        var weights: Dictionary = plan.get("weights", {})
        if str(plan.get("pattern", "")) == "two_sides":
            var sides: Array = plan.get("sides", [])
            if sides.size() == 2:
                var side_weights: Variant = sides[wave_spawned % 2]
                if side_weights is Dictionary and not (side_weights as Dictionary).is_empty():
                    weights = side_weights
        var planned_kind := _weighted_enemy_type(weights)
        if planned_kind != "":
            return planned_kind
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

func _weighted_enemy_type(weights: Dictionary) -> String:
    if not (weights is Dictionary) or weights.is_empty():
        return ""
    var total := 0
    for kind in WAVE_PLAN_KINDS:
        var value: Variant = weights.get(kind, 0)
        if not (value is int or value is float):
            return ""
        total += maxi(0, int(value))
    if total <= 0:
        return ""
    var roll := randf() * float(total)
    var cumulative := 0
    for kind in WAVE_PLAN_KINDS:
        cumulative += maxi(0, int(weights.get(kind, 0)))
        if roll < float(cumulative):
            return kind
    return "chaser"

func _edge_spawn_position() -> Vector2:
    var plan := _wave_plan_for(wave)
    if plan.is_empty():
        return _random_edge_spawn_position()
    match str(plan.get("pattern", "")):
        "ring":
            return _random_edge_spawn_position()
        "one_side":
            return _edge_position_on(_planned_edge_index(), false)
        "cone":
            return _edge_position_on(_planned_edge_index(), true)
        "two_sides":
            if bool(plan.get("diagonal", false)):
                return _corner_position(wave_spawned % 2)
            var side_index := wave_spawned % 2
            var edges: Array = plan.get("edges", [])
            if edges.size() == 2:
                return _edge_position_on(_edge_index(str(edges[side_index])), false)
            if not _plan_side_chosen:
                _plan_side = randi() % 2
                _plan_side_chosen = true
            if _plan_side == 0:
                return _edge_position_on(1 if side_index == 0 else 3, false)
            return _edge_position_on(0 if side_index == 0 else 2, false)
    return _random_edge_spawn_position()

func _planned_edge_index() -> int:
    if not _plan_side_chosen:
        var plan := _wave_plan_for(wave)
        var edges: Array = plan.get("edges", []) if not plan.is_empty() else []
        if edges.size() > 0:
            _plan_side = _edge_index(str(edges[randi() % edges.size()]))
        else:
            _plan_side = randi() % 4
        _plan_side_chosen = true
    return _plan_side

func _edge_index(name: String) -> int:
    match name:
        "top":
            return 0
        "right":
            return 1
        "bottom":
            return 2
        "left":
            return 3
    return -1

func _random_edge_spawn_position() -> Vector2:
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

func _edge_position_on(edge: int, concentrated: bool) -> Vector2:
    var view_size := get_viewport_rect().size
    var span_start := 0.0
    var span_end := 1.0
    if concentrated:
        span_start = 0.28
        span_end = 0.72
    var t := randf_range(span_start, span_end)
    match edge:
        0:
            return Vector2(view_size.x * t, -32.0)
        1:
            return Vector2(view_size.x + 32.0, view_size.y * t)
        2:
            return Vector2(view_size.x * t, view_size.y + 32.0)
        _:
            return Vector2(-32.0, view_size.y * t)

func _corner_position(corner: int) -> Vector2:
    var view_size := get_viewport_rect().size
    var t := randf_range(0.0, 0.32)
    if corner == 0:
        if randi() % 2 == 0:
            return Vector2(view_size.x * t, -32.0)
        return Vector2(-32.0, view_size.y * t)
    if randi() % 2 == 0:
        return Vector2(view_size.x * (1.0 - t), view_size.y + 32.0)
    return Vector2(view_size.x + 32.0, view_size.y * (1.0 - t))

func _spawn_enemy() -> void:
    var burst := 1
    var plan := _wave_plan_for(wave)
    if not plan.is_empty():
        burst = clampi(int(plan.get("burst", 1)), 1, 8)
    burst = clampi(burst, 1, maxi(1, wave_total - wave_spawned))
    for burst_index in range(burst):
        _spawn_one_enemy(_pick_enemy_type(), _edge_spawn_position())

func _spawn_one_enemy(enemy_type: String, pos: Vector2) -> void:
    var scene: PackedScene = ENEMY_SCENE
    if enemy_type == "shooter":
        scene = SHOOTER_SCENE
    elif enemy_type == "exploder":
        scene = EXPLODER_SCENE

    var enemy = scene.instantiate()
    if enemy_type == "shooter":
        enemy.max_health = _enemy_hp_for("shooter", wave, chapter, stage_number, is_endless)
        enemy.contact_damage = 5
        enemy.move_speed = randf_range(85.0, 110.0)
        enemy.projectile_damage = _shooter_damage_for(wave, chapter)
    elif enemy_type == "exploder":
        enemy.max_health = _enemy_hp_for("exploder", wave, chapter, stage_number, is_endless)
        enemy.move_speed = randf_range(65.0, 90.0)
        enemy.explosion_damage = _exploder_damage_for(wave, chapter)
    else:
        enemy.max_health = _enemy_hp_for("chaser", wave, chapter, stage_number, is_endless)
        enemy.contact_damage = _contact_damage_for(wave, chapter)
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
    ArtFX.flash_at(get_tree().current_scene, imp.global_position, Color(1.0, 0.85, 0.35), 64.0, 0.32)
    Audio.play("wave_start", -18.0)
    hud.show_notice("机关灵出现")

func _spawn_elite() -> void:
    var enemy = ENEMY_SCENE.instantiate()
    enemy.max_health = int(float(_enemy_hp_for("chaser", wave, chapter, stage_number, is_endless)) * 7.0)
    enemy.move_speed = 72.0
    enemy.contact_damage = int(float(_contact_damage_for(wave, chapter)) * 1.3)
    enemy.coin_drop = 6
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
    var base_hp := _enemy_hp_for("chaser", wave, chapter, stage_number, is_endless)
    boss.max_health = int(float(base_hp) * 18.0 * (1.3 if wave >= 16 else 1.0))
    boss.move_speed = 55.0
    boss.contact_damage = _boss_contact_for(chapter)
    enemies.add_child(boss)
    boss.global_position = Vector2(get_viewport_rect().size.x * 0.5, -90.0)
    boss.health_changed.connect(hud.set_boss_health)
    boss.defeated.connect(_on_boss_defeated)
    boss.minion_spawned.connect(_on_boss_minion_spawned)
    boss.enrage_started.connect(_on_boss_enraged)
    hud.show_boss_bar(boss.health, boss.max_health)
    Audio.play("boss_spawn", -4.0)
    boss_spawned = true

func _on_boss_minion_spawned(minion) -> void:
    minion.died.connect(_on_enemy_died)
    var mult := _difficulty_mult() * _wave_mult()
    minion.max_health = int(24.0 * mult)
    minion.health = minion.max_health
    minion.contact_damage = 8 + int(wave / 3)

func _on_boss_enraged() -> void:
    hud.show_notice("首领狂暴")

func _on_boss_defeated() -> void:
    var boss = get_tree().get_first_node_in_group("boss")
    if boss != null:
        _on_enemy_died(boss.global_position, 10)
    hud.hide_boss_bar()

func _on_enemy_died(drop_position: Vector2, coin_count: int, counts_toward_wave := true) -> void:
    total_kills += 1
    # 击杀顿感：内部限流为每 120ms 最多一次，且与其它 hitstop 共用 90ms/1s 预算。
    Hitstop.request("kill")
    _gain_hero_xp(coin_count)
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
    var gained := int(float(value) * gold_mult * _chapter_gold_mult())
    gold += gained
    _report_gold_earned += gained
    hud.set_gold(gold)

func _finish_wave() -> void:
    wave_active = false
    if wave >= 1 and wave <= _wave_durations.size():
        _wave_durations[wave - 1] = snappedf(_survival_sec - _wave_start_sec, 0.01)
    _collect_all_coins()
    _clear_enemies()
    _heal_after_wave()
    if not is_endless and wave >= WAVES_PER_STAGE:
        _on_stage_clear()
        return
    _open_shop()

func _heal_after_wave() -> void:
    var amount := int(ceil(float(player.max_health) * _wave_heal_ratio(boss_wave))) + 5
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
    # 暂停期间 _process 停跑：重置挂钟戳，恢复后的首帧不会把商店耗时算进 survival_sec。
    _last_frame_usec = 0
    var stats: Dictionary = weapon_manager.get_item_stats()
    shop_free_rerolls = int(stats["free_rerolls"])
    var heal_note := ""
    if last_heal_amount > 0:
        heal_note = "生命恢复 +%d · " % last_heal_amount
    var clear_note := "清剿完毕 · " if not boss_wave and wave_remaining == 0 else ""
    shop_message = clear_note + heal_note + "花费金币，然后开始下一波"
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
        if offer["kind"] == "weapon" and owned == 0:
            desc += " · 部署：" + weapon_manager.get_next_emplacement_name()
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
        "chapter": chapter,
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
    _report_gold_spent += int(offer["price"])
    offer["bought"] = true
    var final_quality := int(result.get("quality", offer["quality"]))
    var quality_name: String = weapon_manager.get_quality_name(final_quality)
    var title: String = weapon_manager.get_weapon_title(offer["id"]) if offer["kind"] == "weapon" else weapon_manager.get_item_title(offer["id"])
    if bool(result.get("new", false)):
        if offer["kind"] == "weapon":
            shop_message = "获得 %s %s · 部署至%s" % [quality_name, title, str(result.get("slot_name", ""))]
        else:
            shop_message = "获得 %s %s" % [quality_name, title]
    else:
        shop_message = "升品为 %s %s" % [quality_name, title]
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
        _report_gold_spent += REROLL_COST
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
    _report_gold_earned += price
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
    _report_gold_earned += price
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
    player.move_speed = 360.0 + float(stats["move_speed_bonus"])
    var new_max := 120 + int(stats["max_health_bonus"])
    if new_max != player.max_health:
        var gained: int = new_max - int(player.max_health)
        player.max_health = new_max
        if gained > 0:
            player.health += gained
        player.health = clampi(player.health, 0, new_max)
    player.health_changed.emit(player.health, player.max_health)
    hud.set_health(player.health, player.max_health)

func _hero_xp_needed(level_no: int) -> int:
    return HERO_XP_BASE + HERO_XP_STEP * (maxi(1, level_no) - 1)

func _hero_damage_pct() -> int:
    var mult := HERO_ATTRIBUTE_WEAPON_DAMAGE + HERO_DAMAGE_PER_LEVEL * float(hero_level - 1)
    return int(round((mult - 1.0) * 100.0))

func _apply_hero_level() -> void:
    var mult := HERO_ATTRIBUTE_WEAPON_DAMAGE + HERO_DAMAGE_PER_LEVEL * float(hero_level - 1)
    weapon_manager.set_character_damage_mult(mult)
    player.set_hero_level(hero_level)
    var shown_xp := hero_xp
    if hero_level >= HERO_MAX_LEVEL:
        shown_xp = hero_xp_to_next
    hud.set_hero_progress(hero_level, shown_xp, hero_xp_to_next, _hero_damage_pct())

func _gain_hero_xp(amount: int) -> void:
    if amount <= 0 or hero_level >= HERO_MAX_LEVEL:
        return
    hero_xp += amount
    var leveled := false
    while hero_level < HERO_MAX_LEVEL and hero_xp >= hero_xp_to_next:
        hero_xp -= hero_xp_to_next
        hero_level += 1
        hero_xp_to_next = _hero_xp_needed(hero_level)
        leveled = true
    _apply_hero_level()
    if leveled:
        hud.show_notice("机关术精进 · Lv.%d" % hero_level)
        Audio.play("upgrade", -10.0)
        Fx.burst(player.global_position, Color(0.788, 0.635, 0.153), 14)
        ArtFX.flash_at(get_tree().current_scene, player.global_position, Color(1.0, 0.85, 0.45), 56.0, 0.28)

func _on_stage_clear() -> void:
    stage_clear = true
    get_tree().paused = true
    _export_run_report()
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
    _export_run_report()
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
            var gained := int(float(coin.value) * gold_mult * _chapter_gold_mult())
            gold += gained
            _report_gold_earned += gained
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

## 相机 zoom 脉冲：1.0 → 1.0+amount → 1.0。
## 现有相机逻辑只写 camera.offset（屏震），zoom 全工程无第二处写入，因此无冲突。
## 用挂钟计时而不用 Tween：hitstop 期间 time_scale 塌缩会把 Tween 一起拖慢，
## 这个脉冲必须无视时间缩放，才能在 45ms 的停顿里完成"呼吸"。
func pulse_camera_zoom(amount := 0.02, duration := 0.12) -> void:
    if camera == null or amount <= 0.0:
        return
    _zoom_pulse_amount = amount
    # 基准 zoom 只在「没有脉冲在跑」时采样：连着两次脉冲时，第二次若把被抬高过的
    # zoom 当成基准归位，相机会永久停在放大值上。
    if _zoom_pulse_ms <= 0.0:
        _zoom_base = camera.zoom
    _zoom_pulse_ms = maxf(10.0, duration * 1000.0)
    _zoom_pulse_start_ms = Time.get_ticks_msec()

func _update_zoom_pulse() -> void:
    if _zoom_pulse_ms <= 0.0 or camera == null:
        return
    var elapsed := float(Time.get_ticks_msec() - _zoom_pulse_start_ms)
    var t := clampf(elapsed / _zoom_pulse_ms, 0.0, 1.0)
    camera.zoom = _zoom_base * (1.0 + _zoom_pulse_amount * sin(PI * t))
    if t >= 1.0:
        camera.zoom = _zoom_base
        _zoom_pulse_ms = 0.0
        _zoom_pulse_amount = 0.0


## 由 main.gd 覆写，用来挂冒烟/截图/回放入口；游戏主体不引用任何测试符号。
func _post_ready() -> void:
    pass
