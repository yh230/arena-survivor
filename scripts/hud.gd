extends CanvasLayer

signal restart_requested
signal upgrade_selected(id: String)
signal dash_requested

@onready var health_label: Label = $Root/Stats/HealthLabel
@onready var wave_label: Label = $Root/Stats/WaveLabel
@onready var enemy_label: Label = $Root/Stats/EnemyLabel
@onready var remaining_label: Label = $Root/Stats/RemainingLabel
@onready var time_label: Label = $Root/Stats/TimeLabel
@onready var best_label: Label = $Root/Stats/BestLabel
@onready var tip_label: Label = $Root/TipLabel
@onready var end_panel: Control = $Root/EndPanel
@onready var end_title: Label = $Root/EndPanel/Center/VBox/Title
@onready var end_stats: Label = $Root/EndPanel/Center/VBox/Stats
@onready var joystick: Control = $Root/Joystick
@onready var dash_button: Button = $Root/DashButton
@onready var boss_bar: Control = $Root/BossBar
@onready var boss_bar_value: ProgressBar = $Root/BossBar/Bar
@onready var restart_button: Button = $Root/EndPanel/Center/VBox/RestartButton
@onready var upgrade_panel: Control = $Root/UpgradePanel
@onready var choice_buttons = [
    $Root/UpgradePanel/Center/VBox/Choices/Choice1,
    $Root/UpgradePanel/Center/VBox/Choices/Choice2,
    $Root/UpgradePanel/Center/VBox/Choices/Choice3,
]

var _current_choices: Array = []

func _ready() -> void:
    end_panel.visible = false
    upgrade_panel.visible = false
    boss_bar.visible = false
    restart_button.pressed.connect(_on_restart_pressed)
    dash_button.pressed.connect(_on_dash_pressed)
    for index in range(choice_buttons.size()):
        choice_buttons[index].pressed.connect(_on_upgrade_choice_pressed.bind(index))

func set_health(current: int, maximum: int) -> void:
    health_label.text = "HP %d / %d" % [current, maximum]

func set_wave(current: int, total: int) -> void:
    wave_label.text = "WAVE %d / %d" % [current, total]

func set_enemy_count(count: int) -> void:
    enemy_label.text = "ENEMIES %d" % count

func set_remaining(count: int) -> void:
    remaining_label.text = "LEFT %d" % count

func set_time(seconds: float) -> void:
    time_label.text = "TIME %ds" % int(seconds)

func set_best_wave(value: int) -> void:
    best_label.text = "BEST WAVE %d" % value

func set_dash_state(ready: bool, remaining: float) -> void:
    dash_button.disabled = not ready
    if ready:
        dash_button.text = "DASH"
    else:
        dash_button.text = "DASH %.1fs" % maxf(remaining, 0.0)

func show_boss_bar(current: int, maximum: int) -> void:
    boss_bar_value.max_value = maximum
    boss_bar_value.value = current
    boss_bar.visible = true
    tip_label.visible = false

func set_boss_health(current: int, maximum: int) -> void:
    boss_bar_value.max_value = maximum
    boss_bar_value.value = current

func hide_boss_bar() -> void:
    boss_bar.visible = false
    tip_label.visible = true

func is_boss_bar_visible() -> bool:
    return boss_bar.visible

func is_upgrade_panel_visible() -> bool:
    return upgrade_panel.visible

func is_end_panel_visible() -> bool:
    return end_panel.visible

func show_upgrade_choices(choices: Array) -> void:
    _current_choices = choices
    for index in range(choice_buttons.size()):
        var available := index < choices.size()
        choice_buttons[index].visible = available
        if available:
            choice_buttons[index].text = str(choices[index]["title"])
    joystick.release()
    joystick.visible = false
    dash_button.visible = false
    end_panel.visible = false
    upgrade_panel.visible = true

func close_upgrade_choices() -> void:
    upgrade_panel.visible = false
    joystick.visible = true
    dash_button.visible = true

func show_game_over(seconds: float, wave: int, total: int, best: int) -> void:
    end_title.text = "GAME OVER"
    end_title.add_theme_color_override("font_color", Color(1.00, 0.45, 0.45))
    end_stats.text = "Reached wave %d / %d\nSurvived %ds\nBest wave %d" % [wave, total, int(seconds), best]
    _show_end_panel()

func show_victory(seconds: float, total: int, best: int) -> void:
    end_title.text = "M3 CLEAR"
    end_title.add_theme_color_override("font_color", Color(0.55, 1.00, 0.85))
    end_stats.text = "Cleared %d waves in %ds\nBest wave %d" % [total, int(seconds), best]
    _show_end_panel()

func _show_end_panel() -> void:
    upgrade_panel.visible = false
    joystick.release()
    joystick.visible = false
    dash_button.visible = false
    hide_boss_bar()
    end_panel.visible = true

func _on_restart_pressed() -> void:
    restart_requested.emit()

func _on_dash_pressed() -> void:
    dash_requested.emit()

func _on_upgrade_choice_pressed(index: int) -> void:
    if index < 0 or index >= _current_choices.size():
        return
    var choice_id := str(_current_choices[index]["id"])
    Audio.play("upgrade", -8.0)
    close_upgrade_choices()
    upgrade_selected.emit(choice_id)
