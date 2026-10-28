extends Node

signal shake_requested(strength: float, duration: float)

const UI := preload("res://scripts/ui_forge.gd")
const BURST_SCRIPT := preload("res://scripts/fx_burst.gd")
const COMBAT_FX := preload("res://scripts/combat_fx.gd")
const MAX_DAMAGE_LABELS := 36
const MAX_COMBAT_FX := 90

func shake(strength := 6.0, duration := 0.15) -> void:
    shake_requested.emit(strength, duration)

func ring(at: Vector2, color: Color, radius: float, life := 0.28, width := 3.0) -> void:
    var fx = _spawn_fx()
    if fx == null:
        return
    fx.setup_ring(at, color, radius, life, width)

func shock(at: Vector2, color: Color, radius: float, life := 0.4) -> void:
    var fx = _spawn_fx()
    if fx == null:
        return
    fx.setup_shock(at, color, radius, life)

func sparks(at: Vector2, color: Color, count := 8, spread := 220.0, life := 0.32) -> void:
    var fx = _spawn_fx()
    if fx == null:
        return
    fx.setup_sparks(at, color, count, spread, life)

func slash(at: Vector2, facing_angle: float, color: Color, radius := 42.0, life := 0.2, span := PI * 0.9) -> void:
    var fx = _spawn_fx()
    if fx == null:
        return
    fx.setup_slash(at, facing_angle, color, radius, life, span)

func bolt(points: PackedVector2Array, color: Color, life := 0.2, width := 3.0) -> void:
    if points.size() < 2:
        return
    var fx = _spawn_fx()
    if fx == null:
        return
    fx.setup_bolt(points, color, life, width)

func _spawn_fx() -> Node2D:
    var scene = get_tree().current_scene
    if scene == null:
        return null
    if get_tree().get_nodes_in_group("combat_fx").size() >= MAX_COMBAT_FX:
        return null
    var fx = COMBAT_FX.new()
    scene.add_child(fx)
    return fx

func damage_number(global_position: Vector2, amount: int, color := Color.WHITE, font_size := 20, crit := false) -> void:
    var scene = get_tree().current_scene
    if scene == null:
        return
    if get_tree().get_nodes_in_group("damage_number").size() >= MAX_DAMAGE_LABELS:
        return

    var label := Label.new()
    label.text = str(amount)
    label.add_theme_font_override("font", UI.bold_font())
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 0.96))
    label.add_theme_constant_override("outline_size", 5 if crit else 3)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.size = Vector2(120.0, 40.0)
    label.pivot_offset = label.size * 0.5
    label.position = global_position + Vector2(-60.0 + randf_range(-7.0, 7.0), -44.0)
    label.z_index = 100
    label.rotation = randf_range(-0.10, 0.10) if crit else randf_range(-0.04, 0.04)
    label.scale = Vector2(0.55, 0.55) if crit else Vector2(0.8, 0.8)
    label.add_to_group("damage_number")
    scene.add_child(label)

    var drift := randf_range(-14.0, 14.0) if crit else randf_range(-7.0, 7.0)
    var rise := 56.0 if crit else 46.0
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "scale", Vector2(1.18, 1.18) if crit else Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "position", label.position + Vector2(drift, -rise), 0.64).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.2)
    tween.finished.connect(label.queue_free)

func burst(global_position: Vector2, color: Color, count := 8) -> void:
    var scene = get_tree().current_scene
    if scene == null:
        return
    var burst_node = BURST_SCRIPT.new()
    scene.add_child(burst_node)
    burst_node.setup(global_position, color, count)

func clear_effects() -> void:
    for node in get_tree().get_nodes_in_group("damage_number"):
        if is_instance_valid(node):
            node.queue_free()
    for node in get_tree().get_nodes_in_group("fx_burst"):
        if is_instance_valid(node):
            node.queue_free()
    for node in get_tree().get_nodes_in_group("combat_fx"):
        if is_instance_valid(node):
            node.queue_free()
