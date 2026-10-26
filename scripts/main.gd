extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SHOOTER_SCENE := preload("res://scenes/shooter.tscn")
const EXPLODER_SCENE := preload("res://scenes/exploder.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const TOTAL_WAVES := 10
const WAVE_COUNTS := [8, 10, 12, 14, 16, 18, 20, 22, 24, 1]
const WAVE_INTERVALS := [1.15, 1.05, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 0.0]
const WAVE_HEALTH := [30, 38, 46, 54, 62, 70, 78, 86, 94, 0]
const WAVE_CONTACT_DAMAGE := [8, 9, 10, 11, 12, 13, 14, 15, 16, 0]
const WAVE_SPEED_MIN := [85.0, 90.0, 95.0, 100.0, 105.0, 110.0, 115.0, 120.0, 125.0, 0.0]
const WAVE_SPEED_MAX := [120.0, 125.0, 130.0, 135.0, 140.0, 145.0, 150.0, 155.0, 160.0, 0.0]
const BOSS_HEALTH := 1600
const MAX_ENEMIES := 20
const SAVE_PATH := "user://arena_survivor.cfg"
const TEST_SAVE_PATH := "user://arena_survivor_test.cfg"
const UPGRADE_POOL := {
    "damage": {"title": "DAMAGE +5"},
    "attack_speed": {"title": "ATTACK SPEED +20%"},
    "move_speed": {"title": "MOVE SPEED +30"},
    "max_health": {"title": "MAX HP +25"},
    "projectiles": {"title": "PROJECTILES +1"},
    "lifesteal": {"title": "LIFESTEAL +2"},
}

@onready var player = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var hud = $HUD
@onready var weapon_manager = $Player/WeaponManager
@onready var camera: Camera2D = $Camera2D

var wave := 1
var wave_active := false
var enemies_remaining_to_spawn := 0
var spawn_timer := 0.0
var elapsed := 0.0
var game_over := false
var victory := false
var choosing_upgrade := false
var best_wave := 0
var test_mode := false
var save_path := SAVE_PATH
var pending_evolution_type := ""
var forced_spawn_type := ""
var shake_time := 0.0
var shake_strength := 0.0

func _ready() -> void:
    test_mode = OS.get_cmdline_user_args().has("--smoke-test") or OS.get_cmdline_user_args().has("--screenshot")
    if test_mode:
        save_path = TEST_SAVE_PATH
        DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    get_viewport().size_changed.connect(queue_redraw)
    player.health_changed.connect(hud.set_health)
    player.died.connect(_on_player_died)
    hud.restart_requested.connect(_restart)
    hud.upgrade_selected.connect(_on_upgrade_selected)
    hud.evolution_selected.connect(_on_evolution_selected)
    hud.dash_requested.connect(player.try_dash)
    Fx.shake_requested.connect(_on_shake_requested)
    _load_best_wave()
    hud.set_health(player.health, player.max_health)
    hud.set_best_wave(best_wave)
    hud.set_weapon_slots(weapon_manager.get_slots())
    _start_wave(1)

    if OS.get_cmdline_user_args().has("--smoke-test"):
        call_deferred("_run_smoke_test")
    elif OS.get_cmdline_user_args().has("--screenshot"):
        call_deferred("_capture_screenshot")

func _process(delta: float) -> void:
    _update_shake(delta)
    if game_over or victory or choosing_upgrade or not wave_active:
        return

    elapsed += delta
    spawn_timer -= delta

    if enemies_remaining_to_spawn > 0 and spawn_timer <= 0.0 and enemies.get_child_count() < MAX_ENEMIES:
        _spawn_enemy()
        enemies_remaining_to_spawn -= 1
        spawn_timer = WAVE_INTERVALS[wave - 1]

    var alive := enemies.get_child_count()
    hud.set_enemy_count(alive)
    hud.set_remaining(enemies_remaining_to_spawn)
    hud.set_time(elapsed)
    hud.set_dash_state(player.can_dash(), player.get_dash_cooldown_remaining())

    if enemies_remaining_to_spawn == 0 and alive == 0:
        _complete_wave()

func _start_wave(number: int) -> void:
    if number > TOTAL_WAVES:
        return
    wave = number
    wave_active = true
    choosing_upgrade = false
    forced_spawn_type = ""
    if wave == 3:
        forced_spawn_type = "shooter"
    elif wave == 5:
        forced_spawn_type = "exploder"
    enemies_remaining_to_spawn = WAVE_COUNTS[wave - 1]
    spawn_timer = 0.35
    _record_wave(wave)
    hud.set_wave(wave, TOTAL_WAVES)
    hud.set_enemy_count(0)
    hud.set_remaining(enemies_remaining_to_spawn)
    hud.set_time(elapsed)
    hud.set_dash_state(player.can_dash(), player.get_dash_cooldown_remaining())
    hud.set_weapon_slots(weapon_manager.get_slots())
    Audio.play("wave_start", -12.0)

func _spawn_enemy() -> void:
    if wave == TOTAL_WAVES:
        _spawn_boss()
        return

    var enemy_type := forced_spawn_type
    if enemy_type != "":
        forced_spawn_type = ""
    else:
        enemy_type = _pick_enemy_type()

    var view_size := get_viewport_rect().size
    var spawn_position := Vector2.ZERO
    match randi() % 4:
        0:
            spawn_position = Vector2(randf_range(0.0, view_size.x), -32.0)
        1:
            spawn_position = Vector2(view_size.x + 32.0, randf_range(0.0, view_size.y))
        2:
            spawn_position = Vector2(randf_range(0.0, view_size.x), view_size.y + 32.0)
        _:
            spawn_position = Vector2(-32.0, randf_range(0.0, view_size.y))

    var scene: PackedScene = ENEMY_SCENE
    if enemy_type == "shooter":
        scene = SHOOTER_SCENE
    elif enemy_type == "exploder":
        scene = EXPLODER_SCENE

    var enemy = scene.instantiate()
    if enemy_type == "shooter":
        enemy.max_health = 22 + (wave - 1) * 4
        enemy.contact_damage = 5
        enemy.move_speed = randf_range(90.0, 110.0)
        enemy.projectile_damage = 6 + wave
    elif enemy_type == "exploder":
        enemy.max_health = 30 + (wave - 1) * 6
        enemy.move_speed = randf_range(65.0, 85.0)
        enemy.explosion_damage = 20 + wave * 2
    else:
        enemy.max_health = WAVE_HEALTH[wave - 1]
        enemy.contact_damage = WAVE_CONTACT_DAMAGE[wave - 1]
        enemy.move_speed = randf_range(WAVE_SPEED_MIN[wave - 1], WAVE_SPEED_MAX[wave - 1])
    enemies.add_child(enemy)
    enemy.global_position = spawn_position

func _pick_enemy_type() -> String:
    if wave <= 2:
        return "chaser"
    var roll := randf()
    if wave <= 4:
        if roll < 0.25:
            return "shooter"
        return "chaser"
    if wave <= 6:
        if roll < 0.15:
            return "exploder"
        if roll < 0.40:
            return "shooter"
        return "chaser"
    if roll < 0.25:
        return "exploder"
    if roll < 0.55:
        return "shooter"
    return "chaser"

func _spawn_boss() -> void:
    var boss = BOSS_SCENE.instantiate()
    boss.max_health = BOSS_HEALTH
    boss.move_speed = 55.0
    boss.contact_damage = 22
    enemies.add_child(boss)
    boss.global_position = Vector2(get_viewport_rect().size.x * 0.5, -90.0)
    boss.health_changed.connect(hud.set_boss_health)
    boss.defeated.connect(_on_boss_defeated)
    hud.show_boss_bar(boss.health, boss.max_health)
    Audio.play("boss_spawn", -4.0)

func _on_boss_defeated() -> void:
    hud.hide_boss_bar()

func _complete_wave() -> void:
    wave_active = false
    Fx.clear_effects()
    if wave >= TOTAL_WAVES:
        victory = true
        weapon_manager.visible = false
        for projectile in projectiles.get_children():
            projectile.queue_free()
        hud.show_victory(elapsed, TOTAL_WAVES, best_wave)
        Audio.play("victory", -4.0)
        get_tree().paused = true
        return

    choosing_upgrade = true
    hud.show_upgrade_choices(_build_choices())
    get_tree().paused = true

func _on_upgrade_selected(id: String) -> void:
    if id.begins_with("stat:"):
        player.apply_upgrade(id.substr(5))
    elif id.begins_with("weapon:"):
        weapon_manager.add_weapon(id.substr(7))
    elif id.begins_with("upgrade:"):
        var weapon_type := id.substr(8)
        var result: Dictionary = weapon_manager.upgrade_weapon(weapon_type)
        if not result.is_empty() and not result["choices"].is_empty():
            pending_evolution_type = str(result["type"])
            hud.set_weapon_slots(weapon_manager.get_slots())
            hud.show_evolution_choices(str(result["title"]), result["choices"])
            return
    else:
        push_warning("Unknown upgrade choice: " + id)

    hud.set_weapon_slots(weapon_manager.get_slots())
    hud.close_upgrade_choices()
    choosing_upgrade = false
    get_tree().paused = false
    _start_wave(wave + 1)

func _on_evolution_selected(id: String) -> void:
    if pending_evolution_type != "":
        weapon_manager.apply_evolution(pending_evolution_type, id)
    pending_evolution_type = ""
    hud.set_weapon_slots(weapon_manager.get_slots())
    hud.close_upgrade_choices()
    choosing_upgrade = false
    get_tree().paused = false
    _start_wave(wave + 1)

func _on_player_died() -> void:
    game_over = true
    wave_active = false
    choosing_upgrade = false
    Fx.clear_effects()
    for enemy in enemies.get_children():
        if enemy.has_method("stop"):
            enemy.stop()
    weapon_manager.visible = false
    for projectile in projectiles.get_children():
        projectile.queue_free()
    hud.show_game_over(elapsed, wave, TOTAL_WAVES, best_wave)
    Audio.play("game_over", -4.0)
    get_tree().paused = true

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

func _restart() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
    if (game_over or victory) and event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R or event.keycode == KEY_ENTER:
            _restart()

func _build_choices() -> Array:
    var weapon_cards: Array = weapon_manager.get_cards()
    var stat_cards := _stat_cards()
    var choices: Array = []
    var used_ids := {}

    if not weapon_cards.is_empty():
        var new_cards: Array = []
        for card in weapon_cards:
            if card["kind"] == "weapon_new":
                new_cards.append(card)
        var guaranteed: Dictionary
        if weapon_manager.get_equipped_count() < 2 and not new_cards.is_empty():
            guaranteed = new_cards.pick_random()
        else:
            guaranteed = weapon_cards.pick_random()
        choices.append(guaranteed)
        used_ids[guaranteed["id"]] = true

    var pool: Array = []
    for card in weapon_cards:
        if not used_ids.has(card["id"]):
            pool.append(card)
    for card in stat_cards:
        pool.append(card)
    pool.shuffle()

    for card in pool:
        if choices.size() >= 3:
            break
        if used_ids.has(card["id"]):
            continue
        choices.append(card)
        used_ids[card["id"]] = true

    return choices

func _stat_cards() -> Array:
    var cards: Array = []
    for key in UPGRADE_POOL.keys():
        var id := str(key)
        if player.can_apply_upgrade(id):
            cards.append({
                "id": "stat:" + id,
                "title": UPGRADE_POOL[id]["title"],
                "kind": "stat",
            })
    return cards

func _load_best_wave() -> void:
    var config := ConfigFile.new()
    if config.load(save_path) == OK:
        best_wave = int(config.get_value("progress", "best_wave", 0))

func _record_wave(value: int) -> void:
    if value <= best_wave:
        return
    best_wave = value
    hud.set_best_wave(best_wave)
    var config := ConfigFile.new()
    config.set_value("progress", "best_wave", best_wave)
    var error := config.save(save_path)
    if error != OK:
        push_warning("Failed to save best wave: %s" % error)

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

    draw_rect(
        Rect2(20.0, 20.0, view_size.x - 40.0, view_size.y - 40.0),
        Color(0.15, 0.75, 0.70, 0.45),
        false,
        3.0
    )

func _run_smoke_test() -> void:
    await get_tree().process_frame
    await get_tree().process_frame

    if player == null:
        _fail_smoke_test("player missing")
        return
    if not Audio.has_sound("shoot") or Audio.get_sound_names().size() < 11:
        _fail_smoke_test("audio sounds missing")
        return

    # Keep wave 1 open while input tests run; the test enemy closes it later.
    enemies_remaining_to_spawn = 1
    spawn_timer = 1.0e9
    for enemy in enemies.get_children():
        enemy.queue_free()
    await get_tree().process_frame

    var joystick = get_tree().get_first_node_in_group("virtual_joystick")
    if joystick == null:
        _fail_smoke_test("virtual joystick missing")
        return

    var input_mode := "windowed"
    if DisplayServer.get_name() == "headless":
        input_mode = "headless_vector"
        var start_position: Vector2 = player.global_position
        joystick.set_test_vector(Vector2.RIGHT)
        await get_tree().create_timer(0.35).timeout
        joystick.set_test_vector(Vector2.ZERO)
        if player.global_position.x <= start_position.x + 20.0:
            _fail_smoke_test("headless vector movement failed")
            return
    else:
        var joystick_rect: Rect2 = joystick.get_global_rect()
        if joystick_rect.size.x < 10.0:
            _fail_smoke_test("virtual joystick layout missing")
            return
        var joystick_center := joystick_rect.position + joystick_rect.size * 0.5

        var mouse_start: Vector2 = player.global_position
        await _simulate_drag(joystick_center, Vector2(90.0, 0.0), false)
        if player.global_position.x <= mouse_start.x + 20.0:
            _fail_smoke_test("mouse joystick did not move player")
            return

        var touch_start: Vector2 = player.global_position
        await _simulate_drag(joystick_center, Vector2(90.0, 0.0), true)
        if player.global_position.x <= touch_start.x + 20.0:
            _fail_smoke_test("touch joystick did not move player")
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
            _fail_smoke_test("keyboard did not move player")
            return

    var dash_button: Button = hud.get_node("Root/DashButton")
    var dash_start: Vector2 = player.global_position
    await _click_button(dash_button)
    await get_tree().create_timer(0.2).timeout
    if player.get_dash_cooldown_remaining() <= 0.0:
        _fail_smoke_test("dash cooldown did not start")
        return
    if player.global_position.distance_to(dash_start) <= 20.0:
        _fail_smoke_test("dash did not move player")
        return

    player.global_position = Vector2(640.0, 360.0)
    player.health = player.max_health
    player.health_changed.emit(player.health, player.max_health)
    var shooter = SHOOTER_SCENE.instantiate()
    shooter.max_health = 500
    shooter.move_speed = 80.0
    shooter.projectile_damage = 6
    enemies.add_child(shooter)
    shooter.global_position = Vector2(890.0, 360.0)
    await get_tree().create_timer(3.5).timeout
    if shooter.shots_fired <= 0:
        _fail_smoke_test("shooter did not fire")
        return
    if player.health >= player.max_health:
        _fail_smoke_test("shooter projectile did not hit player")
        return
    shooter.queue_free()
    for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
        if is_instance_valid(projectile):
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
        _fail_smoke_test("exploder did not damage player")
        return
    if is_instance_valid(exploder) and not exploder.is_queued_for_deletion():
        exploder.queue_free()
    for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
        if is_instance_valid(projectile):
            projectile.queue_free()
    await get_tree().process_frame
    player.health = player.max_health
    player.health_changed.emit(player.health, player.max_health)

    player.global_position = Vector2(640.0, 360.0)
    enemies_remaining_to_spawn = 0
    var test_enemy := ENEMY_SCENE.instantiate()
    enemies.add_child(test_enemy)
    test_enemy.global_position = Vector2(750.0, 360.0)
    await get_tree().create_timer(2.2).timeout

    if is_instance_valid(test_enemy) and not test_enemy.is_queued_for_deletion():
        _fail_smoke_test("auto attack did not kill test enemy")
        return

    var upgrade_count := 0
    var evolution_count := 0
    var click_retries := 0
    for expected_wave in range(1, TOTAL_WAVES):
        if expected_wave > 1:
            _force_clear_wave()
            await get_tree().process_frame
            await get_tree().process_frame

        await get_tree().process_frame
        if not choosing_upgrade:
            _fail_smoke_test("wave %d upgrade choice missing" % expected_wave)
            return
        if not get_tree().paused:
            _fail_smoke_test("tree not paused during upgrade")
            return
        if not hud.is_upgrade_panel_visible():
            _fail_smoke_test("upgrade panel missing")
            return

        var choice_ids: Array = hud.get_choice_ids()
        if choice_ids.is_empty():
            _fail_smoke_test("wave %d has no choices" % expected_wave)
            return
        var available_weapon_cards: Array = weapon_manager.get_cards()
        if not available_weapon_cards.is_empty():
            var has_weapon_choice := false
            for choice_id in choice_ids:
                var id_text := str(choice_id)
                if id_text.begins_with("weapon:") or id_text.begins_with("upgrade:"):
                    has_weapon_choice = true
                    break
            if not has_weapon_choice:
                _fail_smoke_test("wave %d has no guaranteed weapon card" % expected_wave)
                return

        var chosen_index := 0
        for index in range(choice_ids.size()):
            var id_text := str(choice_ids[index])
            if id_text.begins_with("weapon:") or id_text.begins_with("upgrade:"):
                chosen_index = index
                break

        var before_stats := _upgrade_snapshot()
        var before_build: String = weapon_manager.get_build_signature()
        await _click_upgrade_choice(chosen_index, expected_wave % 2 == 0)
        await get_tree().process_frame

        if get_tree().paused and hud.is_evolution_mode():
            evolution_count += 1
            await _click_upgrade_choice(0, expected_wave % 2 == 0)
            await get_tree().process_frame
            if get_tree().paused:
                click_retries += 1
                await get_tree().create_timer(0.15).timeout
                await _click_upgrade_choice(0, expected_wave % 2 == 0)
                await get_tree().process_frame
        elif get_tree().paused:
            click_retries += 1
            await get_tree().create_timer(0.15).timeout
            await _click_upgrade_choice(chosen_index, expected_wave % 2 == 0)
            await get_tree().process_frame

        if get_tree().paused:
            _fail_smoke_test("wave %d still paused after upgrade" % expected_wave)
            return
        if wave != expected_wave + 1:
            _fail_smoke_test("wave %d did not start" % (expected_wave + 1))
            return
        if _upgrade_snapshot() == before_stats and weapon_manager.get_build_signature() == before_build:
            _fail_smoke_test("wave %d upgrade had no effect" % expected_wave)
            return
        upgrade_count += 1

    if wave != TOTAL_WAVES:
        _fail_smoke_test("boss wave not reached")
        return

    await get_tree().create_timer(0.8).timeout
    var boss = get_tree().get_first_node_in_group("boss")
    if boss == null:
        _fail_smoke_test("boss missing")
        return
    if not hud.is_boss_bar_visible():
        _fail_smoke_test("boss bar missing")
        return

    var boss_health_before: int = boss.health
    boss.take_damage(100)
    await get_tree().process_frame
    if boss.health >= boss_health_before:
        _fail_smoke_test("boss did not take damage")
        return
    boss.take_damage(999999)
    await get_tree().process_frame
    await get_tree().process_frame

    if hud.is_boss_bar_visible():
        _fail_smoke_test("boss bar not hidden after death")
        return
    if not victory:
        _fail_smoke_test("victory missing")
        return
    if not get_tree().paused:
        _fail_smoke_test("tree not paused on victory")
        return
    if not hud.is_end_panel_visible():
        _fail_smoke_test("end panel missing on victory")
        return

    var saved_config := ConfigFile.new()
    if saved_config.load(save_path) != OK:
        _fail_smoke_test("best wave save missing")
        return
    if int(saved_config.get_value("progress", "best_wave", 0)) != TOTAL_WAVES:
        _fail_smoke_test("best wave not saved")
        return
    best_wave = 0
    _load_best_wave()
    if best_wave != TOTAL_WAVES:
        _fail_smoke_test("best wave not loaded")
        return

    get_tree().paused = false
    player.take_damage(999)
    await get_tree().process_frame
    if not game_over:
        _fail_smoke_test("game over state missing")
        return
    if not hud.is_end_panel_visible():
        _fail_smoke_test("end panel missing on game over")
        return

    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    var final_build: String = weapon_manager.get_build_signature()
    print("SMOKE_TEST_PASS input=%s dash=true enemies=true waves=10 upgrades=%d evolutions=%d retries=%d build=%s boss=true victory=true death=true audio=true save_load=true" % [input_mode, upgrade_count, evolution_count, click_retries, final_build])
    get_tree().quit(0)

func _fail_smoke_test(reason: String) -> void:
    push_error("SMOKE_TEST_FAIL: " + reason)
    get_tree().quit(1)

func _upgrade_snapshot() -> Array:
    return [
        player.projectile_damage,
        player.attack_interval,
        player.move_speed,
        player.max_health,
        player.projectile_count,
        player.lifesteal,
    ]

func _force_clear_wave() -> void:
    enemies_remaining_to_spawn = 0
    for enemy in enemies.get_children():
        enemy.queue_free()
    for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
        if is_instance_valid(projectile):
            projectile.queue_free()

func _click_upgrade_choice(index: int, use_touch := false) -> void:
    var button: Button = hud.get_node("Root/UpgradePanel/Center/VBox/Choices/Choice%d" % (index + 1))
    await get_tree().create_timer(0.1).timeout
    await _click_button(button, use_touch)

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

func _capture_screenshot() -> void:
    await get_tree().create_timer(2.5).timeout
    await RenderingServer.frame_post_draw
    var first_error := _save_screenshot("res://screenshots/m4_screenshot.png")

    _force_clear_wave()
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.3).timeout
    await RenderingServer.frame_post_draw
    var second_error := _save_screenshot("res://screenshots/m4_upgrade_screenshot.png")

    choosing_upgrade = false
    victory = false
    get_tree().paused = false
    hud.close_upgrade_choices()

    weapon_manager.add_weapon("turret")
    weapon_manager.upgrade_weapon("turret")
    var turret_evolution: Dictionary = weapon_manager.upgrade_weapon("turret")
    hud.set_weapon_slots(weapon_manager.get_slots())
    hud.show_evolution_choices("TURRET", turret_evolution["choices"])
    get_tree().paused = true
    await get_tree().create_timer(0.2).timeout
    await RenderingServer.frame_post_draw
    var third_error := _save_screenshot("res://screenshots/m4_evolution_screenshot.png")
    weapon_manager.apply_evolution("turret", "turret:laser")

    _add_evolved_weapon("orbiter", "orbiter:fire")
    _add_evolved_weapon("chain", "chain:storm")
    _add_evolved_weapon("pierce", "pierce:railgun")
    hud.set_weapon_slots(weapon_manager.get_slots())
    hud.close_upgrade_choices()
    get_tree().paused = false
    wave_active = false

    _start_wave(7)
    await get_tree().create_timer(0.5).timeout
    var demo_shooter = SHOOTER_SCENE.instantiate()
    demo_shooter.max_health = 2000
    demo_shooter.move_speed = 80.0
    enemies.add_child(demo_shooter)
    demo_shooter.global_position = Vector2(380.0, 240.0)
    var demo_exploder = EXPLODER_SCENE.instantiate()
    demo_exploder.max_health = 2000
    demo_exploder.move_speed = 70.0
    enemies.add_child(demo_exploder)
    demo_exploder.global_position = Vector2(900.0, 240.0)
    await get_tree().create_timer(2.8).timeout
    await RenderingServer.frame_post_draw
    var fourth_error := _save_screenshot("res://screenshots/m4_enemies_screenshot.png")

    _start_wave(TOTAL_WAVES)
    await get_tree().create_timer(0.8).timeout
    var boss = get_tree().get_first_node_in_group("boss")
    if boss != null:
        boss.max_health = 99999
        boss.health = 99999
        hud.set_boss_health(99999, 99999)
    await get_tree().create_timer(3.4).timeout
    await RenderingServer.frame_post_draw
    var fifth_error := _save_screenshot("res://screenshots/m4_build_screenshot.png")

    choosing_upgrade = false
    victory = false
    wave_active = false
    for enemy in enemies.get_children():
        enemy.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    victory = true
    weapon_manager.visible = false
    Fx.clear_effects()
    for projectile in projectiles.get_children():
        projectile.queue_free()
    get_tree().paused = true
    hud.set_wave(TOTAL_WAVES, TOTAL_WAVES)
    hud.set_enemy_count(0)
    hud.set_remaining(0)
    hud.set_time(120.0)
    hud.set_best_wave(TOTAL_WAVES)
    hud.show_victory(120.0, TOTAL_WAVES, TOTAL_WAVES)
    await get_tree().create_timer(0.2).timeout
    await RenderingServer.frame_post_draw
    var sixth_error := _save_screenshot("res://screenshots/m4_end_screenshot.png")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

    if first_error == OK and second_error == OK and third_error == OK and fourth_error == OK and fifth_error == OK and sixth_error == OK:
        print("SCREENSHOT_SAVED m4_screenshot.png m4_upgrade_screenshot.png m4_evolution_screenshot.png m4_enemies_screenshot.png m4_build_screenshot.png m4_end_screenshot.png")
        get_tree().quit(0)
    else:
        get_tree().quit(1)

func _add_evolved_weapon(weapon_type: String, evolution_id: String) -> void:
    weapon_manager.add_weapon(weapon_type)
    weapon_manager.upgrade_weapon(weapon_type)
    var result: Dictionary = weapon_manager.upgrade_weapon(weapon_type)
    if not result.is_empty():
        weapon_manager.apply_evolution(weapon_type, evolution_id)

func _save_screenshot(path: String) -> Error:
    var image := get_viewport().get_texture().get_image()
    var error := image.save_png(path)
    if error != OK:
        push_error("SCREENSHOT_FAILED " + path + ": " + str(error))
    return error
