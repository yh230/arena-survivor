extends CanvasLayer

signal restart_requested

@onready var health_label: Label = $Root/Stats/HealthLabel
@onready var enemy_label: Label = $Root/Stats/EnemyLabel
@onready var time_label: Label = $Root/Stats/TimeLabel
@onready var game_over_panel: Control = $Root/GameOver
@onready var game_over_stats: Label = $Root/GameOver/Center/VBox/Stats
@onready var joystick: Control = $Root/Joystick
@onready var restart_button: Button = $Root/GameOver/Center/VBox/RestartButton

func _ready() -> void:
    game_over_panel.visible = false
    restart_button.pressed.connect(_on_restart_pressed)

func set_health(current: int, maximum: int) -> void:
    health_label.text = "HP %d / %d" % [current, maximum]

func set_enemy_count(count: int) -> void:
    enemy_label.text = "ENEMIES %d" % count

func set_time(seconds: float) -> void:
    time_label.text = "TIME %ds" % int(seconds)

func show_game_over(seconds: float) -> void:
    game_over_stats.text = "Survived %ds" % int(seconds)
    joystick.visible = false
    game_over_panel.visible = true

func _on_restart_pressed() -> void:
    restart_requested.emit()
