extends "res://scripts/main_game.gd"

## 测试/截图/回放入口都集中在子类，游戏主体（main_game.gd）不认识它们。
## 场景 main.tscn 仍挂在本文件上，所以冒烟与截图逻辑的调用方完全不用改。
func _post_ready() -> void:
    if _cli_args.has("--smoke-test"):
        call_deferred("_run_smoke_test")
    elif _cli_args.has("--screenshot"):
        call_deferred("_capture_screenshot")
    elif _cli_args.has("--playtest"):
        call_deferred("_start_playtest")

func _start_playtest() -> void:
    var bot: Node = load("res://scripts/playtest_bot.gd").new()
    add_child(bot)

func _capture_screenshot() -> void:
    await get_tree().create_timer(0.6).timeout
    max_unlocked = 1
    hud.show_stage_select(_stage_select_data())
    await get_tree().create_timer(0.5).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_stage_select.png")

    _begin_run("1-1", false)
    await get_tree().create_timer(1.6).timeout
    _gain_hero_xp(27)
    weapon_manager.buy_weapon("peony", 2)
    weapon_manager.buy_weapon("maple", 2)
    weapon_manager.buy_weapon("justice", 1)
    weapon_manager.buy_weapon("vigil", 3)
    weapon_manager.buy_weapon("hammer", 2)
    weapon_manager.buy_weapon("elixir", 2)
    weapon_manager.buy_item("magnet", 1)
    weapon_manager.buy_item("boots", 2)
    hud.set_weapon_slots(weapon_manager.get_weapon_slots())
    hud.set_item_slots(weapon_manager.get_item_slots())
    await get_tree().process_frame
    _spawn_screenshot_dummies()
    await get_tree().create_timer(3.2).timeout
    _prime_weapon_showcase()
    await get_tree().create_timer(0.08).timeout
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_battle.png")

    player.try_cast_skill()
    await get_tree().create_timer(0.62).timeout
    await get_tree().process_frame
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_skill.png")

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
    await get_tree().process_frame
    var treasure = get_tree().get_first_node_in_group("treasure")
    if treasure != null:
        treasure.max_health = 9999
        treasure.health = 9999
        treasure.active = false
        treasure.global_position = Vector2(820.0, 320.0)
        treasure.set_physics_process(false)
    await get_tree().create_timer(0.8).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_treasure.png")

    _start_wave(6)
    await get_tree().create_timer(0.5).timeout
    var elite = get_tree().get_first_node_in_group("elite")
    if elite != null:
        elite.global_position = Vector2(780.0, 352.0)
    await get_tree().create_timer(0.25).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_elite.png")
    _clear_arena()

    _start_wave(8)
    await get_tree().create_timer(1.0).timeout
    var boss = get_tree().get_first_node_in_group("boss")
    if boss != null:
        boss.max_health = 99999
        boss.health = int(float(boss.max_health) * 0.5) + 1
        boss.take_damage(1)
    await get_tree().create_timer(3.0).timeout
    if boss != null and is_instance_valid(boss):
        boss.global_position = Vector2(680.0, 300.0)
        boss.velocity = Vector2.ZERO
        boss.set_physics_process(false)
    player.global_position = Vector2(640.0, 420.0)
    await get_tree().create_timer(0.25).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_boss.png")

    for enemy in enemies.get_children():
        enemy.queue_free()
    weapon_manager.visible = false
    Fx.clear_effects()
    stage_clear = true
    get_tree().paused = true
    hud.show_stage_clear("1-1 · 青炉入口", true, "波次 16 / 16\n金币 100\n构筑 6 武器 · 2 道具", "下一关 · 1-2 风蚀回廊")
    await get_tree().create_timer(0.5).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_clear.png")

    get_tree().paused = false
    _begin_run("2-1", false)
    await get_tree().create_timer(1.2).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_ch2_battle.png")

    _begin_run("3-1", false)
    await get_tree().create_timer(1.2).timeout
    await RenderingServer.frame_post_draw
    _save_screenshot("res://screenshots/m5_ch3_battle.png")

    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    print("SCREENSHOT_SAVED m5_stage_select.png m5_battle.png m5_skill.png m5_shop.png m5_treasure.png m5_elite.png m5_boss.png m5_clear.png m5_ch2_battle.png m5_ch3_battle.png")
    get_tree().quit(0)

func _prime_weapon_showcase() -> void:
    weapon_manager.turret_timer = 0.0
    weapon_manager.chain_timer = 0.0
    weapon_manager.pierce_timer = 0.0
    weapon_manager.hammer_timer = 0.0
    weapon_manager.elixir_timer = 0.0
    for turret in weapon_manager.turrets:
        turret["fire"] = 0.0

func _spawn_screenshot_dummies() -> void:
    spawn_timer = 1.0e9
    wave_spawned = wave_total
    _clear_enemies()
    var spots := [
        Vector2(900.0, 420.0), Vector2(700.0, 258.0), Vector2(560.0, 470.0),
        Vector2(400.0, 380.0), Vector2(450.0, 330.0), Vector2(700.0, 220.0),
    ]
    for spot in spots:
        var dummy = ENEMY_SCENE.instantiate()
        enemies.add_child(dummy)
        dummy.global_position = spot
        dummy.max_health = 999
        dummy.health = 720
        dummy.move_speed = 0.0
        dummy.contact_range = 0.0
        dummy.died.connect(_on_enemy_died)

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
    var weapon_error := _check_weapon_rules()
    if weapon_error != "":
        _fail_test(weapon_error)
        return
    var hero_error := _check_hero_rules()
    if hero_error != "":
        _fail_test(hero_error)
        return
    var wave_plan_error := _check_wave_plan_rules()
    if wave_plan_error != "":
        _fail_test(wave_plan_error)
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
    if absf(player.move_speed - 360.0) > 0.01:
        _fail_test("base move speed not tuned")
        return
    if player.has_method("try_dash") or player.has_method("_try_auto_attack"):
        _fail_test("legacy dash or auto attack still present")
        return
    if not player.has_method("try_cast_skill"):
        _fail_test("hero skill missing")
        return
    if weapon_manager.get_emplacement_count() != 6:
        _fail_test("emplacement count wrong")
        return
    if weapon_manager.get_weapon_slot(STARTER_WEAPON) < 0:
        _fail_test("starter weapon has no emplacement")
        return
    var starter_count := 0
    for slot in weapon_manager.get_weapon_slots():
        if not slot.is_empty():
            starter_count += 1
    if starter_count < 2:
        _fail_test("second starter weapon missing")
        return
    if hero_level != 1 or not is_equal_approx(weapon_manager.get_weapon_damage_scale(), 1.15):
        _fail_test("hero level start wrong")
        return
    _gain_hero_xp(hero_xp_to_next)
    if hero_level != 2:
        _fail_test("hero level up missing")
        return
    if weapon_manager.get_weapon_damage_scale() <= 1.15:
        _fail_test("hero level damage scaling missing")
        return
    if player.get_skill_damage_mult() <= 1.0:
        _fail_test("hero skill level scaling missing")
        return
    if hud.get_hero_level_text() != "Lv.2":
        _fail_test("hero level HUD wrong")
        return
    hero_level = 1
    hero_xp = 0
    hero_xp_to_next = _hero_xp_needed(1)
    _apply_hero_level()
    if not is_equal_approx(weapon_manager.get_weapon_damage_scale(), 1.15):
        _fail_test("hero level reset wrong")
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

    var skill_button: Button = hud.get_node("Root/SkillButton")
    spawn_timer = 1.0e9
    _clear_enemies()
    await get_tree().process_frame
    var skill_target = ENEMY_SCENE.instantiate()
    skill_target.max_health = 400
    skill_target.coin_drop = 0
    skill_target.move_speed = 0.0
    skill_target.contact_damage = 0
    enemies.add_child(skill_target)
    skill_target.global_position = player.global_position + Vector2(180.0, 0.0)
    await get_tree().process_frame
    await _click_button(skill_button)
    await get_tree().create_timer(0.9).timeout
    if player.get_skill_cooldown_remaining() <= 0.0:
        _fail_test("skill cooldown did not start")
        return
    if not skill_button.disabled:
        _fail_test("skill button did not enter cooldown")
        return
    if weapon_manager.overclock_time <= 0.0:
        _fail_test("skill overclock missing")
        return
    if skill_target.health > 340:
        _fail_test("skill grenade did not damage enemy")
        return
    skill_target.queue_free()
    await get_tree().process_frame

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

    var status_enemy = ENEMY_SCENE.instantiate()
    if not status_enemy.has_method("apply_slow"):
        _fail_test("enemy status helpers missing")
        return
    status_enemy.max_health = 500
    status_enemy.coin_drop = 0
    enemies.add_child(status_enemy)
    status_enemy.global_position = Vector2(420.0, 520.0)
    if player.art == null or player.art.texture == null:
        _fail_test("player sprite art missing")
        return
    if status_enemy.art == null or status_enemy.art.texture == null:
        _fail_test("enemy sprite art missing")
        return
    status_enemy.apply_slow(1.0, 0.7)
    if not is_equal_approx(status_enemy.speed_multiplier(), 0.7):
        _fail_test("enemy slow not applied")
        return
    status_enemy.apply_stun(0.4)
    if not status_enemy.is_stunned():
        _fail_test("enemy stun not applied")
        return
    status_enemy.apply_mark(1.0, 0.15)
    if not is_equal_approx(status_enemy.damage_taken_multiplier(), 1.15):
        _fail_test("enemy mark not applied")
        return
    var marked_health: int = status_enemy.health
    status_enemy.take_damage(100)
    if status_enemy.health != marked_health - 115:
        _fail_test("enemy mark damage bonus wrong")
        return
    status_enemy.queue_free()
    await get_tree().process_frame

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
    player.global_position = Vector2(640.0, 360.0)
    player.health = player.max_health
    player.invuln_time = 0.0
    player.health_changed.emit(player.health, player.max_health)
    var toucher = ENEMY_SCENE.instantiate()
    toucher.max_health = 500
    toucher.move_speed = 0.0
    toucher.contact_damage = 9
    toucher.contact_interval = 0.2
    enemies.add_child(toucher)
    toucher.global_position = player.global_position
    await get_tree().create_timer(0.15).timeout
    if player.health > player.max_health - 9:
        _fail_test("contact damage did not apply")
        return
    var after_contact: int = player.health
    await get_tree().create_timer(0.2).timeout
    if player.health != after_contact:
        _fail_test("hit invulnerability did not block contact")
        return
    await get_tree().create_timer(0.6).timeout
    if player.health >= after_contact:
        _fail_test("contact damage did not resume after invulnerability")
        return
    toucher.queue_free()
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
    if item_type == "boots" and player.move_speed <= 360.0:
        _fail_test("boots effect did not apply")
        return
    if item_type == "holy_fire":
        if player.max_health <= 120:
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
    var boss_speed: float = boss.move_speed
    boss.health = int(float(boss.max_health) * 0.5) + 1
    boss.take_damage(1)
    if not boss.enraged or boss.move_speed <= boss_speed:
        _fail_test("boss enrage phase missing")
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

    if _debug_keys_enabled():
        _fail_test("debug keys must be disabled under --smoke-test")
        return
    print("DEBUG_CHECK debug_keys_enabled=false under --smoke-test")
    _start_wave(1)
    _debug_next_wave()
    _debug_next_wave()
    _debug_next_wave()
    if wave != 4:
        _fail_test("debug next wave x3 did not reach wave 4")
        return
    print("DEBUG_CHECK debug_next_wave x3 -> wave=%d" % wave)
    var gold_before_debug := gold
    _debug_add_gold(100)
    if gold != gold_before_debug + 100:
        _fail_test("debug add gold 100 wrong")
        return
    print("DEBUG_CHECK debug_add_gold(100) -> gold=%d" % gold)
    var dummy = ENEMY_SCENE.instantiate()
    dummy.max_health = 99999
    dummy.coin_drop = 0
    dummy.move_speed = 0.0
    dummy.contact_range = 0.0
    enemies.add_child(dummy)
    dummy.global_position = player.global_position + Vector2(60.0, 0.0)
    weapon_manager._damage_enemy(dummy, 50, "maple")
    weapon_manager._damage_enemy(dummy, 30, "peony")
    dummy.queue_free()
    _export_run_report()
    if not FileAccess.file_exists(_report_path()):
        _fail_test("run report file missing")
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(_report_path()))
    if not (parsed is Dictionary):
        _fail_test("run report not a JSON object")
        return
    var required_keys := ["stage", "wave_reached", "survival_sec", "hero_level", "gold", "weapons", "skill", "damage_taken", "waves", "idle_sec"]
    for key in required_keys:
        if not parsed.has(key):
            _fail_test("run report missing key %s" % key)
            return
    var weapons_sum := 0.0
    for weapon_id in parsed["weapons"].keys():
        weapons_sum += float(parsed["weapons"][weapon_id].get("damage", 0.0))
    var damage_total: float = weapon_manager.get_weapon_damage_total()
    if absf(weapons_sum - damage_total) > 0.5:
        _fail_test("run report weapon damage sum mismatch")
        return
    print("DEBUG_CHECK run_report keys=%d weapons_damage_sum=%.1f total=%.1f" % [required_keys.size(), weapons_sum, damage_total])
    _debug_force_boss()
    if not boss_wave or wave != 8:
        _fail_test("debug force boss did not start boss wave")
        return
    print("DEBUG_CHECK debug_force_boss -> wave=%d boss_wave=%s" % [wave, str(boss_wave)])

    var wave_spawn_error := _run_wave_spawn_checks()
    if wave_spawn_error != "":
        _fail_test(wave_spawn_error)
        return

    player.take_damage(999999)
    await get_tree().create_timer(0.3).timeout
    if not hud.is_end_panel_visible():
        _fail_test("game over panel missing")
        return
    if hud.get_retry_button() == null:
        _fail_test("game over retry button missing")
        return

    var required_sounds := ["hit", "enemy_die", "hurt", "wave_start", "upgrade", "boss_spawn", "boss_die", "turret", "chain", "pierce", "enemy_shot", "explode", "orbiter"]
    for sound_name in required_sounds:
        if not Audio.get_sound_names().has(sound_name):
            _fail_test("audio sounds missing: " + sound_name)
            return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
    print("SMOKE_TEST_PASS input=%s stage_select=true shop=true merge=true coins=true enemies=true boss8=true stage_clear=true endless=true build=%s" % [input_mode, weapon_manager.get_build_signature()])
    get_tree().paused = false
    _clear_arena()
    Fx.clear_effects()
    await get_tree().create_timer(0.35).timeout
    Fx.clear_effects()
    await get_tree().process_frame
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
    if not is_equal_approx(_wave_heal_ratio(false), 0.15):
        return "normal wave heal wrong"
    if not is_equal_approx(_wave_heal_ratio(true), 0.35):
        return "boss wave heal wrong"
    if not is_equal_approx(_stage_hp_mult_for(1, 1), 1.0):
        return "stage 1-1 mult wrong"
    if not is_equal_approx(_stage_hp_mult_for(3, 4), 1.63):
        return "stage 3-4 mult wrong"
    if absf(_wave_hp_mult_for(16, false) - 2.129) > 0.01:
        return "wave 16 hp mult wrong"
    if _enemy_hp_for("chaser", 16, 1, 1, false) != 204:
        return "chapter 1 wave 16 hp wrong"
    if _enemy_hp_for("chaser", 16, 3, 4, false) != 333:
        return "chapter 3 wave 16 hp wrong"
    if _contact_damage_for(16, 3) != 12 or _shooter_damage_for(16, 3) != 11:
        return "normal enemy damage wrong"
    if _exploder_damage_for(16, 3) != 40 or _boss_contact_for(3) != 24:
        return "special enemy damage wrong"
    if not is_equal_approx(_chapter_gold_mult_for(1), 1.0) or not is_equal_approx(_chapter_gold_mult_for(3), 1.3):
        return "chapter gold mult wrong"
    return ""

func _check_hero_rules() -> String:
    if not has_method("_hero_xp_needed") or not has_method("_gain_hero_xp"):
        return "hero xp helpers missing"
    if _hero_xp_needed(1) != 6:
        return "hero xp base wrong"
    if _hero_xp_needed(5) != 14:
        return "hero xp growth wrong"
    if HERO_MAX_LEVEL < 10:
        return "hero level cap too low"
    if not is_equal_approx(player.get_skill_damage_mult(), 1.0):
        return "hero skill baseline wrong"
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

func _check_weapon_rules() -> String:
    if not weapon_manager.has_method("_power_for"):
        return "weapon power helper missing"
    if not is_equal_approx(weapon_manager._power_for(1, 1), 1.0):
        return "weapon power start wrong"
    if not is_equal_approx(weapon_manager._power_for(16, 1), 1.75):
        return "weapon power wave scaling wrong"
    if not is_equal_approx(weapon_manager._power_for(1, 3), 1.24):
        return "weapon power chapter scaling wrong"
    if not weapon_manager.has_method("_damage_with_roll"):
        return "weapon crit helper missing"
    if weapon_manager._damage_with_roll(100, 0.05) != 180:
        return "weapon crit damage wrong"
    if weapon_manager._damage_with_roll(100, 0.9) != 100:
        return "weapon base damage wrong"
    if not weapon_manager.has_method("_orbiter_blade_count"):
        return "orbiter blade helper missing"
    if weapon_manager._orbiter_blade_count(1) != 1 or weapon_manager._orbiter_blade_count(2) != 2 or weapon_manager._orbiter_blade_count(4) != 3:
        return "orbiter blade scaling wrong"
    if not weapon_manager.has_method("_turret_cap"):
        return "turret cap helper missing"
    if weapon_manager._turret_cap(1) != 1 or weapon_manager._turret_cap(3) != 2:
        return "turret cap scaling wrong"
    if weapon_manager.get_emplacement_count() != 6:
        return "emplacement count wrong"
    if weapon_manager.get_emplacement_position(0) != Vector2(783.0, 258.0):
        return "emplacement layout wrong"
    if not is_equal_approx(weapon_manager._orbiter_radius(1), 150.0) or not is_equal_approx(weapon_manager._orbiter_radius(4), 195.0):
        return "orbiter emplacement radius wrong"
    if not is_equal_approx(weapon_manager._hammer_target_range(1), 260.0):
        return "hammer target range wrong"
    if not is_equal_approx(weapon_manager._elixir_target_range(1), 480.0):
        return "elixir target range wrong"
    if weapon_manager._turret_damage(4) != 36 or weapon_manager._pierce_damage(4) != 72:
        return "legendary weapon damage wrong"
    if not is_equal_approx(weapon_manager.get_weapon_damage_scale(), 1.15):
        return "hero attribute damage scale wrong"
    return ""

## 波次计划规则：wave=3/5/7/9/11/13/15 有预期 pattern/weights/burst，
## 第 8/16（Boss）与第 6/14（精英）以及其余波次必须保持现有随机逻辑（计划为空）。
func _check_wave_plan_rules() -> String:
    var expected := [
        [3, "two_sides", {"chaser": 80, "shooter": 20, "exploder": 0}, 1],
        [5, "one_side", {"chaser": 60, "shooter": 30, "exploder": 10}, 1],
        [7, "one_side", {"chaser": 15, "shooter": 15, "exploder": 70}, 2],
        [9, "ring", {"chaser": 85, "shooter": 10, "exploder": 5}, 1],
        [11, "two_sides", {"chaser": 50, "shooter": 50, "exploder": 0}, 1],
        [13, "two_sides", {"chaser": 20, "shooter": 0, "exploder": 80}, 1],
        [15, "cone", {"chaser": 34, "shooter": 33, "exploder": 33}, 1],
    ]
    for entry in expected:
        var wave_no := int(entry[0])
        var plan := _wave_plan_for(wave_no)
        if plan.is_empty():
            return "wave %d plan missing" % wave_no
        if str(plan.get("pattern", "")) != str(entry[1]):
            return "wave %d pattern wrong" % wave_no
        var weights: Dictionary = plan.get("weights", {})
        var wanted: Dictionary = entry[2]
        for kind in WAVE_PLAN_KINDS:
            if int(weights.get(kind, -1)) != int(wanted.get(kind, -1)):
                return "wave %d weight %s wrong" % [wave_no, kind]
        if int(plan.get("burst", 1)) != int(entry[3]):
            return "wave %d burst wrong" % wave_no
    if not bool(_wave_plan_for(11).get("diagonal", false)):
        return "wave 11 diagonal missing"
    var sides: Array = _wave_plan_for(11).get("sides", [])
    if sides.size() != 2 or int(sides[0].get("shooter", 0)) != 100 or int(sides[1].get("chaser", 0)) != 100:
        return "wave 11 sides wrong"
    if _wave_plan_for(3).get("edges", []) != ["left", "right"]:
        return "wave 3 edges wrong"
    if _wave_plan_for(13).get("edges", []) != ["left", "right"]:
        return "wave 13 edges wrong"
    for empty_wave in [1, 2, 4, 6, 8, 10, 12, 14, 16]:
        if not _wave_plan_for(empty_wave).is_empty():
            return "wave %d must keep existing random logic" % empty_wave
    return ""

func _spawn_side_name(pos: Vector2, view_size: Vector2) -> String:
    if absf(pos.y + 32.0) < 0.5:
        return "top"
    if absf(pos.y - (view_size.y + 32.0)) < 0.5:
        return "bottom"
    if absf(pos.x + 32.0) < 0.5:
        return "left"
    if absf(pos.x - (view_size.x + 32.0)) < 0.5:
        return "right"
    return "unknown"

## 固定种子下验证出怪点约束与 burst：第 5 波 one_side 全部落在同一边、
## 第 7 波一次生成 2 只且同边；第 8 波仍走 Boss、第 6 波仍走精英。
func _run_wave_spawn_checks() -> String:
    for wave_no in [3, 5, 7, 9, 11, 13, 15]:
        var plan := _wave_plan_for(wave_no)
        print("DEBUG_CHECK wave_plan wave=%d pattern=%s weights=%s burst=%d" % [
            wave_no, str(plan.get("pattern", "")), str(plan.get("weights", {})), int(plan.get("burst", 1))])

    var view_size := get_viewport_rect().size
    seed(24681357)
    _start_wave(5)
    spawn_timer = 1.0e9
    _clear_enemies()
    var shooter_count := 0
    var first_side := ""
    var all_same_side := true
    var sample_pos := Vector2.ZERO
    for spawn_index in range(16):
        var before := enemies.get_child_count()
        _spawn_enemy()
        if enemies.get_child_count() != before + 1:
            return "wave 5 spawn did not add exactly 1 enemy"
        var spawned = enemies.get_child(enemies.get_child_count() - 1)
        var side := _spawn_side_name(spawned.global_position, view_size)
        if side == "unknown":
            return "wave 5 spawn off edge at %s" % str(spawned.global_position)
        if first_side == "":
            first_side = side
            sample_pos = spawned.global_position
        elif side != first_side:
            all_same_side = false
        if spawned.get("projectile_damage") != null:
            shooter_count += 1
    if not all_same_side:
        return "wave 5 one_side spawns spread across multiple edges"
    if shooter_count < 1:
        return "wave 5 spawns contained no shooter under fixed seed"
    for spawned in enemies.get_children():
        if spawned.get("projectile_damage") != null and _spawn_side_name(spawned.global_position, view_size) != first_side:
            return "wave 5 shooter off the planned side"
    print("DEBUG_CHECK w5 one_side side=%s spawns=16 shooters=%d all_on_side=%s first=%s" % [
        first_side, shooter_count, str(all_same_side), str(sample_pos)])

    seed(97531864)
    _start_wave(7)
    spawn_timer = 1.0e9
    _clear_enemies()
    var before7 := enemies.get_child_count()
    _spawn_enemy()
    var added7 := enemies.get_child_count() - before7
    if added7 != 2:
        return "wave 7 burst did not spawn 2 in one call (got %d)" % added7
    var side7 := _spawn_side_name(enemies.get_child(before7).global_position, view_size)
    if side7 == "unknown":
        return "wave 7 burst spawn off edge"
    for index in range(1, added7):
        if _spawn_side_name(enemies.get_child(before7 + index).global_position, view_size) != side7:
            return "wave 7 burst spawns on different sides"
    print("DEBUG_CHECK w7 burst=%d side=%s both_on_side=true" % [added7, side7])

    _start_wave(8)
    if not boss_wave or not _wave_plan_for(8).is_empty():
        return "wave 8 must keep boss logic"
    _start_wave(6)
    if boss_wave or not _is_elite_wave(6) or not _wave_plan_for(6).is_empty():
        return "wave 6 must keep elite logic"
    print("DEBUG_CHECK boss_elite w8 boss_wave=true plan_empty=true w6 boss_wave=false elite=true plan_empty=true")
    spawn_timer = 1.0e9
    _clear_enemies()
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
