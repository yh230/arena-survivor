extends Node

signal shake_requested(strength: float, duration: float)

const BURST_SCRIPT := preload("res://scripts/fx_burst.gd")
const MAX_DAMAGE_LABELS := 36

func shake(strength := 6.0, duration := 0.15) -> void:
    shake_requested.emit(strength, duration)

func damage_number(global_position: Vector2, amount: int, color := Color.WHITE) -> void:
    var scene = get_tree().current_scene
    if scene == null:
        return
    if get_tree().get_nodes_in_group("damage_number").size() >= MAX_DAMAGE_LABELS:
        return

    var label := Label.new()
    label.text = str(amount)
    label.add_theme_font_size_override("font_size", 20)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.position = global_position + Vector2(randf_range(-8.0, 8.0), -28.0)
    label.z_index = 100
    label.add_to_group("damage_number")
    scene.add_child(label)

    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "position", label.position + Vector2(0.0, -44.0), 0.55)
    tween.tween_property(label, "modulate:a", 0.0, 0.55)
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
