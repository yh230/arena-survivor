extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SPAWN_INTERVAL := 1.4
const MAX_ENEMIES := 16

@onready var player = $Player
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var hud = $HUD

var spawn_timer := 0.8
var elapsed := 0.0
var game_over := false

func _ready() -> void:
    get_viewport().size_changed.connect(queue_redraw)
    player.health_changed.connect(hud.set_health)
    player.died.connect(_on_player_died)
    hud.restart_requested.connect(_restart)
    hud.set_health(player.health, player.max_health)
    hud.set_enemy_count(0)
    hud.set_time(0.0)

    if OS.get_cmdline_user_args().has("--smoke-test"):
        call_deferred("_run_smoke_test")
    elif OS.get_cmdline_user_args().has("--screenshot"):
        call_deferred("_capture_screenshot")

func _process(delta: float) -> void:
    if game_over:
        return

    elapsed += delta
    spawn_timer -= delta
    if spawn_timer <= 0.0 and enemies.get_child_count() < MAX_ENEMIES:
        _spawn_enemy()
        spawn_timer = SPAWN_INTERVAL

    hud.set_enemy_count(enemies.get_child_count())
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
    enemies.add_child(enemy)
    enemy.global_position = spawn_position
    enemy.move_speed = randf_range(85.0, 135.0)

func _on_player_died() -> void:
    game_over = true
    for enemy in enemies.get_children():
        if enemy.has_method("stop"):
            enemy.stop()
    hud.show_game_over(elapsed)

func _restart() -> void:
    get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
    if game_over and event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_R or event.keycode == KEY_ENTER:
            _restart()

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

    var test_enemy := ENEMY_SCENE.instantiate()
    enemies.add_child(test_enemy)
    test_enemy.global_position = player.global_position + Vector2(110.0, 0.0)
    await get_tree().create_timer(2.2).timeout

    if is_instance_valid(test_enemy) and not test_enemy.is_queued_for_deletion():
        _fail_smoke_test("auto attack did not kill test enemy")
        return

    if player.health <= 0:
        _fail_smoke_test("player died before forced death test")
        return

    player.take_damage(999)
    await get_tree().process_frame

    if not game_over:
        _fail_smoke_test("game over state missing")
        return

    if input_mode == "headless_vector":
        print("SMOKE_TEST_PASS input=headless_vector auto_attack=true game_over=true")
    else:
        print("SMOKE_TEST_PASS input=mouse+touch+keyboard auto_attack=true game_over=true")
    get_tree().quit(0)

func _fail_smoke_test(reason: String) -> void:
    push_error("SMOKE_TEST_FAIL: " + reason)
    get_tree().quit(1)

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
    await get_tree().create_timer(4.0).timeout
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var path := "res://m1_screenshot.png"
    var error := image.save_png(path)
    if error == OK:
        print("SCREENSHOT_SAVED ", path)
        get_tree().quit(0)
    else:
        push_error("SCREENSHOT_FAILED: " + str(error))
        get_tree().quit(1)
