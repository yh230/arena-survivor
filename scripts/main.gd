extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const TOTAL_WAVES := 3
const WAVE_COUNTS := [8, 12, 16]
const WAVE_INTERVALS := [1.15, 0.95, 0.75]
const WAVE_HEALTH := [30, 45, 60]
const WAVE_CONTACT_DAMAGE := [8, 10, 12]
const WAVE_SPEED_MIN := [85.0, 95.0, 105.0]
const WAVE_SPEED_MAX := [120.0, 135.0, 150.0]
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
    _load_best_wave()
    hud.set_health(player.health, player.max_health)
    hud.set_best_wave(best_wave)
    _start_wave(1)

    if OS.get_cmdline_user_args().has("--smoke-test"):
        call_deferred("_run_smoke_test")
    elif OS.get_cmdline_user_args().has("--screenshot"):
        call_deferred("_capture_screenshot")

func _process(delta: float) -> void:
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

    if enemies_remaining_to_spawn == 0 and alive == 0:
        _complete_wave()

func _start_wave(number: int) -> void:
    if number > TOTAL_WAVES:
        return
    wave = number
    wave_active = true
    choosing_upgrade = false
    enemies_remaining_to_spawn = WAVE_COUNTS[wave - 1]
    spawn_timer = 0.35
    _record_wave(wave)
    hud.set_wave(wave, TOTAL_WAVES)
    hud.set_enemy_count(0)
    hud.set_remaining(enemies_remaining_to_spawn)
    hud.set_time(elapsed)

func _spawn_enemy() -> void:
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

    var enemy := ENEMY_SCENE.instantiate()
    enemy.max_health = WAVE_HEALTH[wave - 1]
    enemy.contact_damage = WAVE_CONTACT_DAMAGE[wave - 1]
    enemy.move_speed = randf_range(WAVE_SPEED_MIN[wave - 1], WAVE_SPEED_MAX[wave - 1])
    enemies.add_child(enemy)
    enemy.global_position = spawn_position

func _complete_wave() -> void:
    wave_active = false
    if wave >= TOTAL_WAVES:
        victory = true
        hud.show_victory(elapsed, TOTAL_WAVES, best_wave)
        get_tree().paused = true
        return

    choosing_upgrade = true
    hud.show_upgrade_choices(_pick_upgrades(3))
    get_tree().paused = true

func _on_upgrade_selected(id: String) -> void:
    player.apply_upgrade(id)
    hud.close_upgrade_choices()
    choosing_upgrade = false
    get_tree().paused = false
    _start_wave(wave + 1)

func _on_player_died() -> void:
    game_over = true
    wave_active = false
    choosing_upgrade = false
    for enemy in enemies.get_children():
        if enemy.has_method("stop"):
            enemy.stop()
    hud.show_game_over(elapsed, wave, TOTAL_WAVES, best_wave)
    get_tree().paused = true

func _restart() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
    if (game_over or victory) and event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R or event.keycode == KEY_ENTER:
            _restart()

func _pick_upgrades(count: int) -> Array:
    var ids := UPGRADE_POOL.keys()
    ids.shuffle()
    var choices: Array = []
    for index in range(mini(count, ids.size())):
        var id := str(ids[index])
        choices.append({"id": id, "title": UPGRADE_POOL[id]["title"]})
    return choices

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

    # Keep the wave open while input tests run; the test enemy closes it later.
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

    enemies_remaining_to_spawn = 0
    var test_enemy := ENEMY_SCENE.instantiate()
    enemies.add_child(test_enemy)
    test_enemy.global_position = player.global_position + Vector2(110.0, 0.0)
    await get_tree().create_timer(2.2).timeout

    if is_instance_valid(test_enemy) and not test_enemy.is_queued_for_deletion():
        _fail_smoke_test("auto attack did not kill test enemy")
        return

    await get_tree().process_frame
    if not choosing_upgrade:
        _fail_smoke_test("wave 1 upgrade choice missing")
        return
    if not get_tree().paused:
        _fail_smoke_test("tree not paused during upgrade")
        return
    if not hud.is_upgrade_panel_visible():
        _fail_smoke_test("upgrade panel missing")
        return

    var before_upgrade := _upgrade_snapshot()
    await _click_upgrade_choice(0)
    if get_tree().paused:
        _fail_smoke_test("tree still paused after upgrade")
        return
    if wave != 2:
        _fail_smoke_test("wave 2 did not start")
        return
    if _upgrade_snapshot() == before_upgrade:
        _fail_smoke_test("upgrade had no effect")
        return

    _force_clear_wave()
    await get_tree().process_frame
    await get_tree().process_frame
    if not choosing_upgrade:
        _fail_smoke_test("wave 2 upgrade choice missing")
        return
    await _click_upgrade_choice(0, true)
    await get_tree().process_frame
    if wave != 3:
        _fail_smoke_test("wave 3 did not start")
        return

    _force_clear_wave()
    await get_tree().process_frame
    await get_tree().process_frame
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
    if input_mode == "headless_vector":
        print("SMOKE_TEST_PASS input=headless_vector waves=3 upgrades=2 victory=true death=true save_load=true")
    else:
        print("SMOKE_TEST_PASS input=mouse+touch+keyboard waves=3 upgrades=2 victory=true death=true save_load=true")
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

func _click_upgrade_choice(index: int, use_touch := false) -> void:
    var button: Button = hud.get_node("Root/UpgradePanel/Center/VBox/Choices/Choice%d" % (index + 1))
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
        var touch_release := InputEventScreenTouch.new()
        touch_release.index = 0
        touch_release.pressed = false
        touch_release.position = center
        Input.parse_input_event(touch_release)
        await get_tree().process_frame
        return

    var motion := InputEventMouseMotion.new()
    motion.position = center
    Input.parse_input_event(motion)
    await get_tree().process_frame
    var press := InputEventMouseButton.new()
    press.button_index = MOUSE_BUTTON_LEFT
    press.pressed = true
    press.position = center
    Input.parse_input_event(press)
    await get_tree().process_frame
    var release := InputEventMouseButton.new()
    release.button_index = MOUSE_BUTTON_LEFT
    release.pressed = false
    release.position = center
    Input.parse_input_event(release)
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
    var first_error := _save_screenshot("res://screenshots/m2_screenshot.png")

    _force_clear_wave()
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.3).timeout
    await RenderingServer.frame_post_draw
    var second_error := _save_screenshot("res://screenshots/m2_upgrade_screenshot.png")

    choosing_upgrade = false
    victory = true
    hud.set_wave(TOTAL_WAVES, TOTAL_WAVES)
    hud.set_enemy_count(0)
    hud.set_remaining(0)
    hud.set_time(42.0)
    hud.set_best_wave(TOTAL_WAVES)
    hud.show_victory(42.0, TOTAL_WAVES, TOTAL_WAVES)
    await get_tree().create_timer(0.2).timeout
    await RenderingServer.frame_post_draw
    var third_error := _save_screenshot("res://screenshots/m2_end_screenshot.png")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

    if first_error == OK and second_error == OK and third_error == OK:
        print("SCREENSHOT_SAVED m2_screenshot.png m2_upgrade_screenshot.png m2_end_screenshot.png")
        get_tree().quit(0)
    else:
        get_tree().quit(1)

func _save_screenshot(path: String) -> Error:
    var image := get_viewport().get_texture().get_image()
    var error := image.save_png(path)
    if error != OK:
        push_error("SCREENSHOT_FAILED " + path + ": " + str(error))
    return error
