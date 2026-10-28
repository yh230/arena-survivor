extends CanvasLayer

signal stage_selected(stage_id: String)
signal endless_selected
signal buy_offer(index: int)
signal reroll_shop
signal sell_weapon(weapon_id: String)
signal sell_item(item_id: String)
signal next_wave
signal next_stage
signal retry_stage
signal stage_select
signal skill_requested

const UI := preload("res://scripts/ui_forge.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/virtual_joystick.gd")
const SKILL_RING_SCRIPT := preload("res://scripts/dash_ring.gd")
const BG_ART_PATHS := [
    "res://assets/art/bg_ch1.jpg",
    "res://assets/art/bg_ch2.jpg",
    "res://assets/art/bg_ch3.jpg",
]
const STAGE_COUNT := 12

var root: Control
var _bg_art: Array = []
var combat_ui: Control
var stats_panel: Panel
var health_label: Label
var hp_bar: ProgressBar
var hp_flash: ColorRect
var wave_banner: Label
var notice_label: Label
var stage_tag_label: Label
var stage_label: Label
var wave_label: Label
var gold_label: Label
var timer_label: Label
var sub_label: Label
var tip_label: Label
var boss_bar: Panel
var boss_bar_value: ProgressBar
var wave_track: Control
var wave_track_label: Label
var wave_segments: Array = []
var weapon_slots: Array = []
var item_slots: Array = []
var joystick: Control
var skill_button: Button
var skill_ring: Control
var skill_title: Label
var skill_sub: Label

var stage_panel: Control
var stage_content: Control
var stage_art: TextureRect
var stage_buttons: Dictionary = {}
var stage_cards: Dictionary = {}
var stage_progress_cells: Array = []
var stage_progress_label: Label
var stage_chapter_titles: Array = []
var stage_chapter_tags: Array = []
var endless_button: Button
var endless_desc: Label
var endless_state: Label

var shop_panel: Control
var shop_content: Control
var shop_art: TextureRect
var shop_offer_buttons: Array = []
var shop_offer_uis: Array = []
var shop_weapon_buttons: Array = []
var shop_weapon_uis: Array = []
var shop_item_buttons: Array = []
var shop_item_uis: Array = []
var shop_gold_label: Label
var shop_gold_line: Label
var shop_health_label: Label
var shop_message_label: Label
var shop_reroll_button: Button
var shop_next_button: Button
var shop_weapon_count: Label
var shop_item_count: Label

var end_panel: Control
var end_art: TextureRect
var end_box: VBoxContainer
var end_title: Label
var end_sub: Label
var end_seal: Panel
var end_stats_box: HBoxContainer
var end_next_label: Label
var end_next_button: Button
var end_select_button: Button
var restart_button: Button

var _gold_tween: Tween
var _gold_count_tween: Tween
var _last_gold := -1
var _display_gold := 0
var _hp_flash_tween: Tween
var _low_hp_tween: Tween
var _last_health := 100
var _wave_banner_tween: Tween
var _notice_tween: Tween
var _panel_tweens: Dictionary = {}
var _stage_card_tween: Tween
var _stage_current_tween: Tween
var _current_stage_id := ""
var _last_track_wave := -1
var _skill_was_ready := true
var _animate_offers := false
var _offer_entrance_tween: Tween
var _last_offer_bought: Array = []
var _shop_last_gold := -1
var _shop_last_health := -1
var _last_weapon_qualities := {}
var _last_item_qualities := {}
var _enemy_count := 0
var _best_wave := 0
var _current_wave := 1
var _wave_total := 16

func _ready() -> void:
    root = Control.new()
    root.name = "Root"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.theme = UI.make_theme()
    add_child(root)

    for path in BG_ART_PATHS:
        _bg_art.append(load(path))

    _build_combat_ui()
    _build_inputs()
    _build_stage_select()
    _build_shop()
    _build_end_panel()

    _set_gameplay_visible(true)
    _hide_gameplay_inputs()

func _full_rect(node: Control) -> void:
    node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _margin(px: int) -> MarginContainer:
    var margin := MarginContainer.new()
    _full_rect(margin)
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", px)
    margin.add_theme_constant_override("margin_top", px)
    margin.add_theme_constant_override("margin_right", px)
    margin.add_theme_constant_override("margin_bottom", px)
    return margin

func _content_box(panel: Panel, px: int, separation: int = 5) -> VBoxContainer:
    var margin := _margin(px)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", separation)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_child(box)
    return box

func _make_portrait(path: String, size: float, glow := Color(0.0, 0.0, 0.0, 0.0)) -> Panel:
    var frame := Panel.new()
    frame.custom_minimum_size = Vector2(size, size)
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.add_theme_stylebox_override("panel", UI.panel_style(
        Color(0.025, 0.07, 0.08, 1.0),
        Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.7),
        5, 1
    ))
    if glow.a > 0.0:
        var halo := TextureRect.new()
        halo.texture = ArtFX.glow_texture()
        halo.material = ArtFX.additive_material()
        halo.modulate = glow
        halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        halo.offset_left = -size * 0.45
        halo.offset_top = -size * 0.45
        halo.offset_right = size * 0.45
        halo.offset_bottom = size * 0.45
        frame.add_child(halo)
    var art := TextureRect.new()
    art.texture = load(path)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    art.offset_left = 2.0
    art.offset_top = 2.0
    art.offset_right = -2.0
    art.offset_bottom = -2.0
    frame.add_child(art)
    return frame

func _animate_panel(panel: Control, content: Control, key: String) -> void:
    var old: Tween = _panel_tweens.get(key, null)
    if old != null and old.is_valid():
        old.kill()
    panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
    var home := content.position
    content.position = home + Vector2(0.0, 10.0)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(content, "position", home, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _panel_tweens[key] = tween

func _fade_panel(panel: Control, key: String) -> void:
    var old: Tween = _panel_tweens.get(key, null)
    if old != null and old.is_valid():
        old.kill()
    panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
    var tween := create_tween()
    tween.tween_property(panel, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _panel_tweens[key] = tween

func _pulse_control(node: Control, amount := 1.06, duration := 0.18) -> void:
    node.pivot_offset = node.size * 0.5
    node.scale = Vector2(amount, amount)
    var tween := create_tween()
    tween.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _float_combat_text(text: String, color: Color, anchor: Vector2, size := 14) -> void:
    var node := UI.outlined(UI.label(text, size, color, true), Color(0.01, 0.02, 0.03, 0.9), 3)
    node.position = anchor
    combat_ui.add_child(node)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(node, "position:y", node.position.y - 26.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(node, "modulate:a", 0.0, 0.6)
    tween.finished.connect(node.queue_free)

func show_notice(text: String) -> void:
    if notice_label == null:
        return
    notice_label.text = text
    notice_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
    if _notice_tween != null and _notice_tween.is_valid():
        _notice_tween.kill()
    _notice_tween = create_tween()
    _notice_tween.tween_property(notice_label, "modulate:a", 1.0, 0.12)
    _notice_tween.tween_interval(0.85)
    _notice_tween.tween_property(notice_label, "modulate:a", 0.0, 0.3)

func show_heal_feedback(amount: int) -> void:
    _flash_health(Color(0.35, 1.0, 0.65, 0.34))
    _float_combat_text("+%d" % amount, Color("#8affc1"), health_label.global_position + Vector2(96.0, -6.0), 14)

# ---------------------------------------------------------------------------
# Combat HUD
# ---------------------------------------------------------------------------
func _build_combat_ui() -> void:
    combat_ui = Control.new()
    combat_ui.name = "Combat"
    _full_rect(combat_ui)
    combat_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(combat_ui)

    _build_stats_panel()
    _build_wave_track()
    _build_boss_bar()
    _build_weapon_bar()
    _build_item_bar()

    var tip_backdrop := Panel.new()
    tip_backdrop.position = Vector2(850.0, 22.0)
    tip_backdrop.size = Vector2(406.0, 26.0)
    tip_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    UI.apply_panel(tip_backdrop, Color(0.03, 0.07, 0.08, 0.82), Color(0.15, 0.25, 0.25, 0.5), 4, 1)
    combat_ui.add_child(tip_backdrop)
    tip_label = UI.outlined(UI.label("拖动摇杆移动 · 点按震雷", 13, UI.MUTED), Color(0.01, 0.02, 0.03, 0.8), 3)
    tip_label.position = Vector2(850.0, 22.0)
    tip_label.size = Vector2(406.0, 26.0)
    tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    combat_ui.add_child(tip_label)

    wave_banner = UI.outlined(UI.label("", 30, UI.BRASS_LIGHT, true), Color(0.01, 0.02, 0.03, 0.9), 5)
    wave_banner.position = Vector2(0.0, 188.0)
    wave_banner.size = Vector2(1280.0, 44.0)
    wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    wave_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    wave_banner.modulate.a = 0.0
    combat_ui.add_child(wave_banner)

    notice_label = UI.outlined(UI.label("", 18, Color("#ffe4a3"), true), Color(0.01, 0.02, 0.03, 0.9), 4)
    notice_label.position = Vector2(0.0, 246.0)
    notice_label.size = Vector2(1280.0, 30.0)
    notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    notice_label.modulate.a = 0.0
    combat_ui.add_child(notice_label)

func _build_stats_panel() -> void:
    stats_panel = Panel.new()
    stats_panel.position = Vector2(24.0, 24.0)
    stats_panel.size = Vector2(330.0, 176.0)
    stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    UI.apply_panel(stats_panel, Color(0.045, 0.10, 0.11, 0.94), UI.LINE, 8, 1)
    combat_ui.add_child(stats_panel)

    var box := _content_box(stats_panel, 13, 5)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 10)
    top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(top_row)

    top_row.add_child(_make_portrait("res://assets/sprites/player.png", 52.0, Color(0.4, 1.0, 0.9, 0.22)))

    var hp_column := VBoxContainer.new()
    hp_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hp_column.add_theme_constant_override("separation", 3)
    hp_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top_row.add_child(hp_column)

    var hp_row := HBoxContainer.new()
    hp_row.add_theme_constant_override("separation", 8)
    hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_row.add_child(UI.label("生命", 13, UI.MUTED))
    health_label = UI.label("120 / 120", 27, UI.TEXT, true)
    hp_row.add_child(health_label)
    hp_column.add_child(hp_row)

    hp_bar = ProgressBar.new()
    hp_bar.custom_minimum_size = Vector2(0.0, 14.0)
    hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hp_bar.max_value = 120.0
    hp_bar.value = 120.0
    hp_bar.show_percentage = false
    hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_bar.add_theme_stylebox_override("background", UI.panel_style(Color(0.02, 0.05, 0.06, 1.0), Color(0.13, 0.25, 0.26, 1.0), 7, 1))
    hp_bar.add_theme_stylebox_override("fill", UI.panel_style(UI.TEAL, UI.TEAL, 7, 0))
    hp_flash = ColorRect.new()
    hp_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hp_flash.color = Color(1.0, 1.0, 1.0, 0.0)
    hp_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_bar.add_child(hp_flash)
    var hp_ticks := Control.new()
    hp_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hp_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_ticks.set_script(load("res://scripts/bar_ticks.gd"))
    hp_ticks.set("segments", 10)
    hp_bar.add_child(hp_ticks)
    hp_column.add_child(hp_bar)

    var stage_row := HBoxContainer.new()
    stage_row.add_theme_constant_override("separation", 8)
    stage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var tag_panel := Panel.new()
    tag_panel.custom_minimum_size = Vector2(54.0, 22.0)
    tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tag_panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.10, 0.17, 0.12, 0.55), Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.5), 3, 1))
    stage_tag_label = UI.label("第一章", 10, UI.BRASS_LIGHT, true)
    _full_rect(stage_tag_label)
    stage_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stage_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    tag_panel.add_child(stage_tag_label)
    stage_row.add_child(tag_panel)
    stage_label = UI.label("1-1", 24, UI.TEXT, true)
    stage_row.add_child(stage_label)
    wave_label = UI.label("第 1 / 16 波", 12, UI.MUTED)
    wave_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    stage_row.add_child(wave_label)
    box.add_child(stage_row)

    var gold_row := HBoxContainer.new()
    gold_row.add_theme_constant_override("separation", 7)
    gold_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var coin := UI.make_coin(16.0)
    gold_row.add_child(coin)
    gold_label = UI.label("金币 15", 18, UI.BRASS_LIGHT, true)
    gold_row.add_child(gold_label)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    gold_row.add_child(spacer)
    timer_label = UI.label("剩余 0 / 0", 12, UI.MUTED)
    gold_row.add_child(timer_label)
    box.add_child(gold_row)

    sub_label = UI.label("敌人 0 · 无尽最佳 0", 11, UI.MUTED)
    box.add_child(sub_label)
    UI.add_corners(stats_panel)

func _build_wave_track() -> void:
    var wave_backdrop := Panel.new()
    wave_backdrop.position = Vector2(470.0, 24.0)
    wave_backdrop.size = Vector2(340.0, 58.0)
    wave_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    UI.apply_panel(wave_backdrop, Color(0.04, 0.09, 0.10, 0.97), UI.LINE, 6, 1)
    combat_ui.add_child(wave_backdrop)
    UI.add_corners(wave_backdrop)

    wave_track = Control.new()
    wave_track.position = Vector2(470.0, 24.0)
    wave_track.size = Vector2(340.0, 58.0)
    wave_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    combat_ui.add_child(wave_track)

    var left := UI.label("波次进度", 11, UI.MUTED)
    left.position = Vector2(0.0, 0.0)
    left.size = Vector2(170.0, 18.0)
    wave_track.add_child(left)
    wave_track_label = UI.label("第 1 / 16 波", 12, UI.BRASS_LIGHT, true)
    wave_track_label.position = Vector2(160.0, 0.0)
    wave_track_label.size = Vector2(180.0, 18.0)
    wave_track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    wave_track.add_child(wave_track_label)

    for index in range(16):
        var segment := ColorRect.new()
        segment.position = Vector2(float(index) * 21.0, 32.0)
        segment.size = Vector2(18.0, 5.0)
        segment.color = Color("#1a3133")
        segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
        wave_track.add_child(segment)
        wave_segments.append(segment)

    for index in [7, 15]:
        var mark := UI.label("◆", 8, UI.BRASS)
        mark.position = Vector2(float(index) * 21.0 + 5.0, 40.0)
        mark.size = Vector2(12.0, 14.0)
        mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        wave_track.add_child(mark)

func _build_boss_bar() -> void:
    boss_bar = Panel.new()
    boss_bar.position = Vector2(380.0, 94.0)
    boss_bar.size = Vector2(520.0, 50.0)
    boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    UI.apply_panel(boss_bar, Color(0.12, 0.055, 0.055, 0.97), Color(0.55, 0.22, 0.19, 0.8), 6, 1)
    boss_bar.visible = false
    combat_ui.add_child(boss_bar)

    var box := _content_box(boss_bar, 7, 3)
    var main_row := HBoxContainer.new()
    main_row.add_theme_constant_override("separation", 8)
    main_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(main_row)
    main_row.add_child(_make_portrait("res://assets/sprites/boss.png", 38.0, Color(1.0, 0.35, 0.2, 0.2)))

    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 2)
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    main_row.add_child(column)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(UI.label("首领", 11, UI.RED, true))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(spacer)
    row.add_child(UI.label("机关核心", 10, UI.MUTED))
    column.add_child(row)

    boss_bar_value = ProgressBar.new()
    boss_bar_value.custom_minimum_size = Vector2(0.0, 16.0)
    boss_bar_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    boss_bar_value.max_value = 100.0
    boss_bar_value.value = 100.0
    boss_bar_value.show_percentage = false
    boss_bar_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_bar_value.add_theme_stylebox_override("background", UI.panel_style(Color(0.08, 0.025, 0.025, 1.0), Color(0.38, 0.12, 0.10, 1.0), 7, 1))
    boss_bar_value.add_theme_stylebox_override("fill", UI.panel_style(UI.RED, Color("#ff9a8f"), 7, 0))
    column.add_child(boss_bar_value)
    UI.add_corners(boss_bar, Color("#c76b5f"))

func _build_weapon_bar() -> void:
    var bar := Control.new()
    bar.position = Vector2(308.0, 544.0)
    bar.size = Vector2(664.0, 64.0)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    combat_ui.add_child(bar)

    for index in range(6):
        var slot := Panel.new()
        slot.position = Vector2(float(index) * 112.0, 0.0)
        slot.size = Vector2(104.0, 64.0)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        UI.apply_panel(slot, Color(0.045, 0.10, 0.11, 0.94), UI.DARK_LINE, 6, 1)
        bar.add_child(slot)

        var accent := ColorRect.new()
        accent.position = Vector2.ZERO
        accent.size = Vector2(104.0, 3.0)
        accent.color = UI.TEAL
        accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(accent)

        var seal := UI.make_seal("刃", 30.0)
        seal.position = Vector2(8.0, 14.0)
        slot.add_child(seal)
        var seal_label := seal.get_child(0)

        var name_label := UI.label("枫叶环刃", 12, UI.TEXT, true)
        name_label.position = Vector2(44.0, 9.0)
        name_label.size = Vector2(54.0, 18.0)
        name_label.clip_text = true
        slot.add_child(name_label)
        var quality_label := UI.label("稀有", 10, UI.TEAL)
        quality_label.position = Vector2(44.0, 29.0)
        quality_label.size = Vector2(54.0, 16.0)
        quality_label.clip_text = true
        slot.add_child(quality_label)
        var empty_label := UI.label("空", 11, UI.MUTED)
        _full_rect(empty_label)
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_label.visible = false
        slot.add_child(empty_label)

        weapon_slots.append({
            "panel": slot,
            "accent": accent,
            "seal": seal,
            "seal_label": seal_label,
            "name": name_label,
            "quality": quality_label,
            "empty": empty_label,
        })

func _build_item_bar() -> void:
    var bar := Control.new()
    bar.position = Vector2(367.0, 620.0)
    bar.size = Vector2(546.0, 38.0)
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    combat_ui.add_child(bar)

    for index in range(6):
        var slot := Panel.new()
        slot.position = Vector2(float(index) * 92.0, 0.0)
        slot.size = Vector2(86.0, 38.0)
        slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
        UI.apply_panel(slot, Color(0.04, 0.09, 0.10, 0.9), UI.DARK_LINE, 5, 1)
        bar.add_child(slot)

        var accent := ColorRect.new()
        accent.position = Vector2.ZERO
        accent.size = Vector2(2.0, 38.0)
        accent.color = UI.TEAL
        accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(accent)

        var seal := UI.make_seal("磁", 22.0)
        seal.position = Vector2(6.0, 8.0)
        slot.add_child(seal)
        var seal_label := seal.get_child(0)

        var name_label := UI.label("磁铁", 10, UI.TEXT, true)
        name_label.position = Vector2(32.0, 3.0)
        name_label.size = Vector2(50.0, 14.0)
        name_label.clip_text = true
        slot.add_child(name_label)
        var quality_label := UI.label("普通", 8, UI.MUTED)
        quality_label.position = Vector2(32.0, 19.0)
        quality_label.size = Vector2(50.0, 12.0)
        quality_label.clip_text = true
        slot.add_child(quality_label)
        var empty_label := UI.label("空", 9, UI.MUTED)
        _full_rect(empty_label)
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_label.visible = false
        slot.add_child(empty_label)

        item_slots.append({
            "panel": slot,
            "accent": accent,
            "seal": seal,
            "seal_label": seal_label,
            "name": name_label,
            "quality": quality_label,
            "empty": empty_label,
        })

func _build_inputs() -> void:
    joystick = Control.new()
    joystick.name = "Joystick"
    joystick.position = Vector2.ZERO
    joystick.size = Vector2(640.0, 720.0)
    joystick.add_to_group("virtual_joystick")
    joystick.set_script(JOYSTICK_SCRIPT)
    joystick.set("base_radius", 90.0)
    joystick.set("knob_radius", 38.0)
    joystick.set("dead_zone", 0.06)
    joystick.set("anchor_center", Vector2(142.0, 578.0))
    root.add_child(joystick)
    joystick.visible = false

    skill_ring = Control.new()
    skill_ring.name = "SkillRing"
    skill_ring.position = Vector2(1108.0, 548.0)
    skill_ring.size = Vector2(124.0, 124.0)
    skill_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    skill_ring.set_script(SKILL_RING_SCRIPT)
    root.add_child(skill_ring)
    skill_ring.visible = false

    skill_button = Button.new()
    skill_button.name = "SkillButton"
    skill_button.position = Vector2(1108.0, 548.0)
    skill_button.size = Vector2(124.0, 124.0)
    skill_button.text = ""
    UI.apply_button(skill_button, "flat")
    skill_button.pressed.connect(_on_skill_pressed)
    root.add_child(skill_button)
    skill_button.visible = false

    skill_title = UI.label("震雷", 18, UI.TEXT, true)
    skill_title.position = Vector2(0.0, 40.0)
    skill_title.size = Vector2(124.0, 26.0)
    skill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    skill_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    skill_button.add_child(skill_title)
    skill_sub = UI.label("就绪", 10, UI.MUTED)
    skill_sub.position = Vector2(0.0, 66.0)
    skill_sub.size = Vector2(124.0, 16.0)
    skill_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    skill_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    skill_button.add_child(skill_sub)

func _on_skill_pressed() -> void:
    skill_requested.emit()

func set_health(current: int, maximum: int) -> void:
    var previous := _last_health
    _last_health = current
    health_label.text = "%d / %d" % [current, maximum]
    hp_bar.max_value = maximum
    hp_bar.value = current
    var low := maximum > 0 and float(current) / float(maximum) <= 0.3
    hp_bar.add_theme_stylebox_override("fill", UI.panel_style(UI.RED if low else UI.TEAL, Color("#ff9a8f") if low else UI.TEAL, 7, 0))
    if current < previous:
        _flash_health(Color(1.0, 0.22, 0.18, 0.36))
    elif current > previous:
        _flash_health(Color(0.30, 1.0, 0.62, 0.30))
    _update_low_health_pulse(low)

func _flash_health(color: Color) -> void:
    if hp_flash == null:
        return
    if _hp_flash_tween != null and _hp_flash_tween.is_valid():
        _hp_flash_tween.kill()
    hp_flash.color = color
    _hp_flash_tween = create_tween()
    _hp_flash_tween.tween_property(hp_flash, "color:a", 0.0, 0.28)

func _update_low_health_pulse(low: bool) -> void:
    if low and _low_hp_tween == null:
        _low_hp_tween = create_tween().set_loops()
        _low_hp_tween.tween_property(hp_bar, "modulate:a", 0.62, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        _low_hp_tween.tween_property(hp_bar, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    elif not low and _low_hp_tween != null:
        _low_hp_tween.kill()
        _low_hp_tween = null
        hp_bar.modulate.a = 1.0

func get_health_text() -> String:
    return health_label.text

func set_stage(label: String) -> void:
    stage_label.text = label
    if label == "无尽" or label == "ENDLESS":
        stage_tag_label.text = "无尽"
    elif label.length() > 0:
        stage_tag_label.text = "第%s章" % label.substr(0, 1)
    else:
        stage_tag_label.text = "机关"

func set_wave(current: int, total: int) -> void:
    _current_wave = current
    _wave_total = total
    if total <= 0:
        wave_label.text = "第 %d 波" % current
        wave_track_label.text = "无尽 · 第 %d 波" % current
    else:
        wave_label.text = "第 %d / %d 波" % [current, total]
        wave_track_label.text = "第 %d / %d 波" % [current, total]
    _update_wave_segments()
    _show_wave_banner("第 %d 波" % current)

func _show_wave_banner(text: String) -> void:
    if wave_banner == null:
        return
    wave_banner.text = text
    wave_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
    wave_banner.pivot_offset = wave_banner.size * 0.5
    wave_banner.scale = Vector2(1.04, 1.04)
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    _wave_banner_tween = create_tween().set_parallel(true)
    _wave_banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.15)
    _wave_banner_tween.tween_property(wave_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _wave_banner_tween.chain().tween_interval(0.55)
    _wave_banner_tween.chain().tween_property(wave_banner, "modulate:a", 0.0, 0.25)

func _update_wave_segments() -> void:
    var current_in_track := ((_current_wave - 1) % 16) + 1
    for index in range(wave_segments.size()):
        var segment: ColorRect = wave_segments[index]
        var mark := index + 1
        var is_boss := mark == 8 or mark == 16
        var is_now := mark == current_in_track
        var is_done := mark < current_in_track
        var color := Color("#1a3133")
        if is_now:
            color = UI.TEAL
        elif is_done:
            color = UI.BRASS
        elif is_boss:
            color = Color("#7d3e2f")
        segment.color = color
        var height := 8.0 if (is_now or is_boss) else 5.0
        segment.size = Vector2(18.0, height)
        segment.position.y = 37.0 - height
    if current_in_track != _last_track_wave:
        _last_track_wave = current_in_track
        var now_segment: ColorRect = wave_segments[current_in_track - 1]
        now_segment.modulate = Color(1.6, 1.5, 1.3, 1.0)
        var glow := create_tween()
        glow.tween_property(now_segment, "modulate", Color.WHITE, 0.3)

func set_wave_progress(remaining: int, total: int, is_boss: bool) -> void:
    var text := "首领战" if is_boss else "剩余 %d / %d" % [remaining, total]
    if timer_label.text == text:
        return
    timer_label.text = text
    if is_boss:
        timer_label.add_theme_color_override("font_color", UI.RED)
    elif remaining <= 3 and remaining > 0:
        timer_label.add_theme_color_override("font_color", UI.BRASS_LIGHT)
    else:
        timer_label.add_theme_color_override("font_color", UI.MUTED)

func get_wave_remaining_text() -> String:
    return timer_label.text

func set_gold(value: int) -> void:
    if value == _last_gold:
        return
    var had_previous := _last_gold >= 0
    var previous := _display_gold
    var delta := value - _last_gold
    _last_gold = value
    _display_gold = value
    if _gold_count_tween != null and _gold_count_tween.is_valid():
        _gold_count_tween.kill()
    _gold_count_tween = create_tween()
    _gold_count_tween.tween_method(_set_gold_text, float(previous), float(value), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    if _gold_tween != null and _gold_tween.is_valid():
        _gold_tween.kill()
    gold_label.modulate = Color.WHITE
    _gold_tween = create_tween()
    _gold_tween.tween_property(gold_label, "modulate", Color(1.18, 1.10, 0.82, 1.0), 0.08)
    _gold_tween.tween_property(gold_label, "modulate", Color.WHITE, 0.18)
    if had_previous and delta > 0:
        _float_combat_text("+%d" % delta, UI.BRASS_LIGHT, gold_label.global_position + Vector2(48.0, -16.0), 13)

func _set_gold_text(value: float) -> void:
    gold_label.text = "金币 %d" % int(round(value))

func set_enemy_count(count: int) -> void:
    _enemy_count = count
    _update_sub_label()

func set_best_wave(value: int) -> void:
    _best_wave = value
    _update_sub_label()

func _update_sub_label() -> void:
    sub_label.text = "机关师 · 机关伤害 +15%% · 敌 %d · 无尽 %d" % [_enemy_count, _best_wave]

func set_skill_state(ready: bool, remaining: float, total: float) -> void:
    var ready_changed := ready != _skill_was_ready
    _skill_was_ready = ready
    skill_button.disabled = not ready
    var ratio := 1.0
    if not ready:
        ratio = 1.0 - clampf(remaining / maxf(total, 0.01), 0.0, 1.0)
    skill_ring.set("ratio", ratio)
    skill_ring.queue_redraw()
    skill_title.add_theme_color_override("font_color", UI.TEXT if ready else UI.MUTED)
    skill_sub.text = "就绪" if ready else "%.1f 秒" % maxf(remaining, 0.0)
    if ready and ready_changed:
        _pulse_control(skill_ring, 1.06, 0.22)

func set_weapon_slots(slots: Array) -> void:
    for index in range(weapon_slots.size()):
        var ui: Dictionary = weapon_slots[index]
        var panel: Panel = ui["panel"]
        var accent: ColorRect = ui["accent"]
        var seal: Panel = ui["seal"]
        var seal_label = ui["seal_label"]
        var name_label: Label = ui["name"]
        var quality_label: Label = ui["quality"]
        var empty_label: Label = ui["empty"]
        var filled: bool = index < slots.size() and not slots[index].is_empty()
        if not filled:
            accent.color = Color(0.0, 0.0, 0.0, 0.0)
            seal.visible = false
            name_label.visible = false
            quality_label.visible = false
            empty_label.visible = true
            UI.apply_panel(panel, Color(0.035, 0.075, 0.085, 0.86), Color(0.16, 0.24, 0.25, 0.95), 6, 1)
            continue

        var slot: Dictionary = slots[index]
        var quality := int(slot.get("quality", 0))
        var color := UI.quality_color(quality)
        var weapon_id := str(slot.get("id", ""))
        var old_quality := int(_last_weapon_qualities.get(weapon_id, 0))
        accent.color = color
        seal.visible = true
        seal_label.text = UI.seal_glyph(weapon_id)
        seal.add_theme_stylebox_override("panel", UI.panel_style(Color(0.06, 0.11, 0.12, 0.95), color, 15, 1))
        name_label.text = str(slot.get("title", weapon_id))
        name_label.visible = true
        name_label.add_theme_color_override("font_color", UI.TEXT)
        var quality_text := UI.quality_name(quality)
        if bool(slot.get("legendary", false)):
            quality_text += " ★"
        quality_label.text = quality_text
        quality_label.visible = true
        quality_label.add_theme_color_override("font_color", color)
        empty_label.visible = false
        UI.apply_panel(panel, Color(0.045, 0.10, 0.11, 0.94), UI.DARK_LINE, 6, 1)
        if quality > old_quality and old_quality > 0:
            _flash_panel(panel)
        _last_weapon_qualities[weapon_id] = quality

func set_item_slots(slots: Array) -> void:
    for index in range(item_slots.size()):
        var ui: Dictionary = item_slots[index]
        var panel: Panel = ui["panel"]
        var accent: ColorRect = ui["accent"]
        var seal: Panel = ui["seal"]
        var seal_label = ui["seal_label"]
        var name_label: Label = ui["name"]
        var quality_label: Label = ui["quality"]
        var empty_label: Label = ui["empty"]
        var filled: bool = index < slots.size() and not slots[index].is_empty()
        if not filled:
            accent.color = Color(0.0, 0.0, 0.0, 0.0)
            seal.visible = false
            name_label.visible = false
            quality_label.visible = false
            empty_label.visible = true
            UI.apply_panel(panel, Color(0.035, 0.075, 0.085, 0.82), Color(0.15, 0.22, 0.23, 0.9), 5, 1)
            continue

        var slot: Dictionary = slots[index]
        var quality := int(slot.get("quality", 0))
        var color := UI.quality_color(quality)
        var item_id := str(slot.get("id", ""))
        var old_quality := int(_last_item_qualities.get(item_id, 0))
        accent.color = color
        seal.visible = true
        seal_label.text = UI.seal_glyph(item_id)
        seal.add_theme_stylebox_override("panel", UI.panel_style(Color(0.06, 0.11, 0.12, 0.95), color, 11, 1))
        name_label.text = str(slot.get("title", item_id))
        name_label.visible = true
        quality_label.text = UI.quality_name(quality)
        quality_label.visible = true
        quality_label.add_theme_color_override("font_color", color)
        empty_label.visible = false
        UI.apply_panel(panel, Color(0.04, 0.09, 0.10, 0.9), UI.DARK_LINE, 5, 1)
        if quality > old_quality and old_quality > 0:
            _flash_panel(panel)
        _last_item_qualities[item_id] = quality

func _flash_panel(panel: Panel) -> void:
    panel.modulate = Color(1.35, 1.28, 1.02, 1.0)
    var tween := create_tween()
    tween.tween_property(panel, "modulate", Color.WHITE, 0.28)

func show_boss_bar(current: int, maximum: int) -> void:
    boss_bar_value.max_value = maximum
    boss_bar_value.value = current
    boss_bar.visible = true
    boss_bar.modulate.a = 0.0
    boss_bar.pivot_offset = boss_bar.size * 0.5
    boss_bar.scale = Vector2(0.96, 0.96)
    var tween := create_tween().set_parallel(true)
    tween.tween_property(boss_bar, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(boss_bar, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func set_boss_health(current: int, maximum: int) -> void:
    boss_bar_value.max_value = maximum
    boss_bar_value.value = current

func hide_boss_bar() -> void:
    boss_bar.visible = false

func is_boss_bar_visible() -> bool:
    return boss_bar.visible

# ---------------------------------------------------------------------------
# Stage select
# ---------------------------------------------------------------------------
func _build_stage_select() -> void:
    stage_panel = Control.new()
    stage_panel.name = "StageSelect"
    _full_rect(stage_panel)
    stage_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    stage_panel.visible = false
    root.add_child(stage_panel)

    stage_art = TextureRect.new()
    _full_rect(stage_art)
    stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    stage_art.texture = _bg_art[0]
    stage_art.modulate = Color(0.66, 0.70, 0.72, 1.0)
    stage_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_panel.add_child(stage_art)

    var backdrop := ColorRect.new()
    _full_rect(backdrop)
    backdrop.color = Color(0.02, 0.03, 0.04, 0.70)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_panel.add_child(backdrop)

    var content := Control.new()
    content.position = Vector2(80.0, 36.0)
    content.size = Vector2(1120.0, 660.0)
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_panel.add_child(content)
    stage_content = content

    var eyebrow := UI.label("机 关 百 炼", 12, UI.BRASS)
    eyebrow.position = Vector2(0.0, 0.0)
    eyebrow.size = Vector2(500.0, 18.0)
    content.add_child(eyebrow)

    var title_row := HBoxContainer.new()
    title_row.position = Vector2(0.0, 18.0)
    title_row.size = Vector2(620.0, 52.0)
    title_row.add_theme_constant_override("separation", 0)
    title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_row.add_child(UI.label("选择", 42, UI.TEXT, true))
    title_row.add_child(UI.label("关卡", 42, UI.BRASS_LIGHT, true))
    content.add_child(title_row)

    var subtitle := UI.label("通关解锁下一关 · 每关独立构筑", 13, UI.MUTED)
    subtitle.position = Vector2(2.0, 74.0)
    subtitle.size = Vector2(620.0, 20.0)
    content.add_child(subtitle)

    var progress_title := UI.label("通关进度", 11, UI.MUTED)
    progress_title.position = Vector2(900.0, 0.0)
    progress_title.size = Vector2(220.0, 16.0)
    progress_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(progress_title)
    stage_progress_label = UI.label("0 / 12", 26, UI.BRASS_LIGHT, true)
    stage_progress_label.position = Vector2(900.0, 16.0)
    stage_progress_label.size = Vector2(220.0, 32.0)
    stage_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(stage_progress_label)
    var cells := HBoxContainer.new()
    cells.position = Vector2(900.0, 54.0)
    cells.size = Vector2(220.0, 8.0)
    cells.alignment = BoxContainer.ALIGNMENT_END
    cells.add_theme_constant_override("separation", 3)
    cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for _index in range(STAGE_COUNT):
        var cell := ColorRect.new()
        cell.custom_minimum_size = Vector2(12.0, 6.0)
        cell.color = Color("#1b3234")
        cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
        cells.add_child(cell)
        stage_progress_cells.append(cell)
    content.add_child(cells)

    var rule := ColorRect.new()
    rule.position = Vector2(0.0, 105.0)
    rule.size = Vector2(1120.0, 1.0)
    rule.color = Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.35)
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(rule)

    for chapter_index in range(3):
        var chapter_y := 124.0 + float(chapter_index) * 140.0
        var chapter_title := UI.label("第%d章" % (chapter_index + 1), 17, UI.BRASS_LIGHT, true)
        chapter_title.position = Vector2(0.0, chapter_y)
        chapter_title.size = Vector2(420.0, 24.0)
        content.add_child(chapter_title)
        stage_chapter_titles.append(chapter_title)

        var chapter_tag := UI.label("0 / 4", 11, UI.MUTED)
        chapter_tag.position = Vector2(260.0, chapter_y + 2.0)
        chapter_tag.size = Vector2(80.0, 20.0)
        content.add_child(chapter_tag)
        stage_chapter_tags.append(chapter_tag)

        var chapter_line := ColorRect.new()
        chapter_line.position = Vector2(340.0, chapter_y + 12.0)
        chapter_line.size = Vector2(780.0, 1.0)
        chapter_line.color = Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.18)
        chapter_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
        content.add_child(chapter_line)

        for stage_index in range(4):
            var stage_id := "%d-%d" % [chapter_index + 1, stage_index + 1]
            var card := Button.new()
            card.position = Vector2(float(stage_index) * 284.0, chapter_y + 24.0)
            card.size = Vector2(268.0, 100.0)
            card.text = ""
            UI.apply_button(card, "card")
            card.pressed.connect(_on_stage_button_pressed.bind(stage_id))
            content.add_child(card)

            var number := UI.label(stage_id, 24, UI.TEXT, true)
            number.position = Vector2(14.0, 8.0)
            number.size = Vector2(120.0, 32.0)
            card.add_child(number)
            var name_label := UI.label("", 11, UI.MUTED)
            name_label.position = Vector2(14.0, 44.0)
            name_label.size = Vector2(210.0, 18.0)
            name_label.clip_text = true
            card.add_child(name_label)
            var state_label := UI.label("未解锁", 10, UI.MUTED)
            state_label.position = Vector2(14.0, 74.0)
            state_label.size = Vector2(150.0, 16.0)
            card.add_child(state_label)

            var pips := HBoxContainer.new()
            pips.position = Vector2(186.0, 76.0)
            pips.size = Vector2(64.0, 16.0)
            pips.alignment = BoxContainer.ALIGNMENT_END
            pips.add_theme_constant_override("separation", 2)
            pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
            var pip_labels: Array = []
            for _pip in range(3):
                var pip := UI.label("◆", 9, Color(0.2, 0.3, 0.31))
                pips.add_child(pip)
                pip_labels.append(pip)
            card.add_child(pips)

            var seal := Panel.new()
            seal.custom_minimum_size = Vector2(28.0, 28.0)
            seal.size = Vector2(28.0, 28.0)
            seal.position = Vector2(228.0, 8.0)
            seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
            seal.add_theme_stylebox_override("panel", UI.panel_style(Color(0.10, 0.03, 0.03, 0.55), Color(0.88, 0.35, 0.31), 3, 1))
            var seal_text := UI.label("通", 11, Color("#f29a91"), true)
            _full_rect(seal_text)
            seal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
            seal_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
            seal.add_child(seal_text)
            seal.rotation = deg_to_rad(-6.0)
            seal.pivot_offset = Vector2(14.0, 14.0)
            seal.visible = false
            card.add_child(seal)

            stage_buttons[stage_id] = card
            stage_cards[stage_id] = {
                "button": card,
                "number": number,
                "name": name_label,
                "state": state_label,
                "pips": pip_labels,
                "seal": seal,
            }

    endless_button = Button.new()
    endless_button.position = Vector2(0.0, 552.0)
    endless_button.size = Vector2(1120.0, 54.0)
    endless_button.text = ""
    UI.apply_button(endless_button, "card")
    endless_button.pressed.connect(_on_endless_pressed)
    content.add_child(endless_button)

    var endless_mark := UI.make_seal("∞", 36.0)
    endless_mark.position = Vector2(14.0, 9.0)
    endless_button.add_child(endless_mark)
    var endless_title := UI.label("无尽试炼", 17, UI.BRASS_LIGHT, true)
    endless_title.position = Vector2(62.0, 6.0)
    endless_title.size = Vector2(300.0, 22.0)
    endless_button.add_child(endless_title)
    endless_desc = UI.label("连续波次 · 首领每 8 波 · 最佳 0 波", 11, UI.MUTED)
    endless_desc.position = Vector2(62.0, 28.0)
    endless_desc.size = Vector2(700.0, 18.0)
    endless_button.add_child(endless_desc)
    endless_state = UI.label("通关 3-1 解锁", 11, UI.MUTED)
    endless_state.position = Vector2(860.0, 18.0)
    endless_state.size = Vector2(240.0, 20.0)
    endless_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    endless_button.add_child(endless_state)

    var footer_left := UI.label("每关 16 波 · 第 8 / 16 波首领", 11, UI.MUTED)
    footer_left.position = Vector2(0.0, 622.0)
    footer_left.size = Vector2(600.0, 18.0)
    content.add_child(footer_left)
    var footer_right := UI.label("波间整备 · 一命通关", 11, UI.MUTED)
    footer_right.position = Vector2(720.0, 622.0)
    footer_right.size = Vector2(400.0, 18.0)
    footer_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(footer_right)

func show_stage_select(data: Dictionary) -> void:
    _set_gameplay_visible(false)
    _hide_gameplay_inputs()
    end_panel.visible = false
    shop_panel.visible = false

    var stages: Array = data.get("stages", [])
    var chapter_names: Array = data.get("chapter_names", [])
    var current_index := int(data.get("current_index", -1))
    var cleared_count := int(data.get("cleared_count", 0))
    _current_stage_id = ""
    var art_chapter := 3 if current_index < 0 else int(current_index / 4) + 1
    set_chapter_art(art_chapter)

    stage_progress_label.text = "%d / %d" % [cleared_count, STAGE_COUNT]
    for index in range(stage_progress_cells.size()):
        var cell: ColorRect = stage_progress_cells[index]
        if index < cleared_count:
            cell.color = UI.BRASS
        elif index == current_index:
            cell.color = UI.TEAL
        else:
            cell.color = Color("#1b3234")

    for index in range(stages.size()):
        var info: Dictionary = stages[index]
        var stage_id := str(info["id"])
        if not stage_cards.has(stage_id):
            continue
        var ui: Dictionary = stage_cards[stage_id]
        var button: Button = ui["button"]
        var number_label: Label = ui["number"]
        var name_label: Label = ui["name"]
        var state_label: Label = ui["state"]
        var seal: Panel = ui["seal"]
        var pips: Array = ui["pips"]
        var locked := bool(info.get("locked", true))
        var cleared := bool(info.get("cleared", false))
        var current := index == current_index
        if current:
            _current_stage_id = stage_id

        button.disabled = locked
        number_label.text = stage_id
        name_label.text = str(info.get("name", ""))
        var state_text := "可挑战"
        var state_color := UI.MUTED
        if locked:
            state_text = "未解锁"
        elif current:
            state_text = "当前关卡"
            state_color = UI.TEAL
        elif cleared:
            state_text = "已通关"
            state_color = UI.BRASS_LIGHT
        state_label.text = state_text
        state_label.add_theme_color_override("font_color", state_color)
        seal.visible = cleared

        var chapter_no := int(info.get("chapter", 1))
        var stage_no := int(info.get("stage", 1))
        var pip_count := clampi(chapter_no + (1 if stage_no >= 2 else 0), 1, 3)
        for pip_index in range(pips.size()):
            var pip: Label = pips[pip_index]
            pip.add_theme_color_override("font_color", UI.BRASS if pip_index < pip_count else Color(0.2, 0.3, 0.31))

        _apply_stage_card_style(button, current, cleared, locked)
        button.modulate = Color(1.0, 1.0, 1.0, 1.0) if not locked else Color(1.0, 1.0, 1.0, 0.52)

    for chapter_index in range(3):
        var chapter_title: Label = stage_chapter_titles[chapter_index]
        var chapter_tag: Label = stage_chapter_tags[chapter_index]
        var chapter_cleared := 0
        var chapter_unlocked := false
        for info in stages:
            if int(info.get("chapter", 0)) == chapter_index + 1:
                if bool(info.get("cleared", false)):
                    chapter_cleared += 1
                if not bool(info.get("locked", true)):
                    chapter_unlocked = true
        if chapter_index < chapter_names.size():
            chapter_title.text = str(chapter_names[chapter_index])
        else:
            chapter_title.text = "第%d章" % (chapter_index + 1)
        chapter_tag.text = "%d / 4" % chapter_cleared
        chapter_title.modulate = Color(1.0, 1.0, 1.0, 1.0) if chapter_unlocked else Color(1.0, 1.0, 1.0, 0.52)
        chapter_tag.modulate = chapter_title.modulate

    var endless_unlocked := bool(data.get("endless_unlocked", false))
    var best := int(data.get("best_endless", 0))
    endless_button.disabled = not endless_unlocked
    endless_button.modulate = Color(1.0, 1.0, 1.0, 1.0) if endless_unlocked else Color(1.0, 1.0, 1.0, 0.55)
    endless_desc.text = "连续波次 · 首领每 8 波 · 最佳 %d 波" % best
    endless_state.text = "进入" if endless_unlocked else "通关 3-1 解锁"
    endless_state.add_theme_color_override("font_color", UI.TEAL if endless_unlocked else UI.MUTED)

    stage_panel.visible = true
    _animate_panel(stage_panel, stage_content, "stage")
    _animate_stage_cards()

func _animate_stage_cards() -> void:
    if _stage_card_tween != null and _stage_card_tween.is_valid():
        _stage_card_tween.kill()
    if _stage_current_tween != null and _stage_current_tween.is_valid():
        _stage_current_tween.kill()
    _stage_card_tween = create_tween().set_parallel(true)
    var card_index := 0
    for chapter_index in range(3):
        for stage_index in range(4):
            var stage_id := "%d-%d" % [chapter_index + 1, stage_index + 1]
            if not stage_cards.has(stage_id):
                continue
            var ui: Dictionary = stage_cards[stage_id]
            var card: Button = ui["button"]
            var target_alpha := card.modulate.a
            card.modulate.a = 0.0
            card.scale = Vector2(0.97, 0.97)
            card.pivot_offset = Vector2(134.0, 50.0)
            var delay := float(card_index) * 0.02
            _stage_card_tween.tween_property(card, "modulate:a", target_alpha, 0.16).set_delay(delay)
            _stage_card_tween.tween_property(card, "scale", Vector2.ONE, 0.18).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
            var seal: Panel = ui["seal"]
            if seal.visible:
                seal.scale = Vector2(0.6, 0.6)
                seal.pivot_offset = Vector2(14.0, 14.0)
                _stage_card_tween.tween_property(seal, "scale", Vector2.ONE, 0.2).set_delay(delay + 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
            card_index += 1

    if _current_stage_id != "" and stage_cards.has(_current_stage_id):
        var current_card: Button = stage_cards[_current_stage_id]["button"]
        current_card.pivot_offset = Vector2(134.0, 50.0)
        _stage_current_tween = create_tween().set_loops()
        _stage_current_tween.tween_interval(0.5)
        _stage_current_tween.tween_property(current_card, "scale", Vector2(1.008, 1.008), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
        _stage_current_tween.tween_property(current_card, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_stage_card_style(button: Button, current: bool, cleared: bool, locked: bool) -> void:
    var border := UI.DARK_LINE
    var bg := Color(0.05, 0.11, 0.12, 0.94)
    if current:
        border = UI.TEAL
    elif cleared:
        border = UI.BRASS
    elif locked:
        border = Color(0.10, 0.15, 0.16, 0.9)
        bg = Color(0.03, 0.06, 0.07, 0.72)
    button.add_theme_stylebox_override("normal", UI.panel_style(bg, border, 7, 1))
    button.add_theme_stylebox_override("hover", UI.panel_style(Color(0.08, 0.18, 0.19, 0.96), border.lightened(0.12), 7, 1))
    button.add_theme_stylebox_override("pressed", UI.panel_style(Color(0.04, 0.09, 0.10, 0.98), border, 7, 1))
    button.add_theme_stylebox_override("disabled", UI.panel_style(Color(0.03, 0.06, 0.07, 0.72), Color(0.10, 0.15, 0.16, 0.9), 7, 1))

func set_chapter_art(chapter: int) -> void:
    var index := clampi(chapter, 1, _bg_art.size()) - 1
    stage_art.texture = _bg_art[index]
    shop_art.texture = _bg_art[index]
    end_art.texture = _bg_art[index]

func hide_stage_select() -> void:
    if _stage_card_tween != null and _stage_card_tween.is_valid():
        _stage_card_tween.kill()
    if _stage_current_tween != null and _stage_current_tween.is_valid():
        _stage_current_tween.kill()
    stage_panel.visible = false
    _set_gameplay_visible(true)
    _show_gameplay_inputs()

func is_stage_select_visible() -> bool:
    return stage_panel.visible

func _on_stage_button_pressed(stage_id: String) -> void:
    stage_selected.emit(stage_id)

func _on_endless_pressed() -> void:
    if endless_button.disabled:
        return
    endless_selected.emit()

# ---------------------------------------------------------------------------
# Shop
# ---------------------------------------------------------------------------
func _build_shop() -> void:
    shop_panel = Control.new()
    shop_panel.name = "Shop"
    _full_rect(shop_panel)
    shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    shop_panel.visible = false
    root.add_child(shop_panel)

    shop_art = TextureRect.new()
    _full_rect(shop_art)
    shop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    shop_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    shop_art.texture = _bg_art[0]
    shop_art.modulate = Color(0.60, 0.64, 0.66, 1.0)
    shop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shop_panel.add_child(shop_art)

    var backdrop := ColorRect.new()
    _full_rect(backdrop)
    backdrop.color = Color(0.02, 0.03, 0.04, 0.74)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shop_panel.add_child(backdrop)

    var content := Control.new()
    content.position = Vector2(48.0, 24.0)
    content.size = Vector2(1184.0, 660.0)
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shop_panel.add_child(content)
    shop_content = content

    var eyebrow := UI.label("波 间 整 备", 12, UI.BRASS)
    eyebrow.position = Vector2(0.0, 0.0)
    eyebrow.size = Vector2(500.0, 18.0)
    content.add_child(eyebrow)
    var title_row := HBoxContainer.new()
    title_row.position = Vector2(0.0, 18.0)
    title_row.size = Vector2(620.0, 52.0)
    title_row.add_theme_constant_override("separation", 0)
    title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_row.add_child(UI.label("机关", 40, UI.TEXT, true))
    title_row.add_child(UI.label("商店", 40, UI.BRASS_LIGHT, true))
    content.add_child(title_row)
    var subtitle := UI.label("购买同名同品质可升品 · 点击构筑栏出售", 13, UI.MUTED)
    subtitle.position = Vector2(2.0, 72.0)
    subtitle.size = Vector2(700.0, 20.0)
    content.add_child(subtitle)

    var gold_title := UI.label("持有金币", 11, UI.MUTED)
    gold_title.position = Vector2(964.0, 0.0)
    gold_title.size = Vector2(220.0, 16.0)
    gold_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(gold_title)
    shop_gold_label = UI.label("0", 28, UI.BRASS_LIGHT, true)
    shop_gold_label.position = Vector2(964.0, 18.0)
    shop_gold_label.size = Vector2(220.0, 38.0)
    shop_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(shop_gold_label)

    shop_health_label = UI.label("生命 120 / 120", 11, UI.MUTED)
    shop_health_label.position = Vector2(964.0, 60.0)
    shop_health_label.size = Vector2(220.0, 16.0)
    shop_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    content.add_child(shop_health_label)

    var rule := ColorRect.new()
    rule.position = Vector2(0.0, 108.0)
    rule.size = Vector2(1184.0, 1.0)
    rule.color = Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.35)
    rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(rule)

    var offers_grid := GridContainer.new()
    offers_grid.columns = 2
    offers_grid.position = Vector2(0.0, 128.0)
    offers_grid.add_theme_constant_override("h_separation", 16)
    offers_grid.add_theme_constant_override("v_separation", 14)
    offers_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(offers_grid)
    for index in range(4):
        var card := Button.new()
        card.custom_minimum_size = Vector2(300.0, 185.0)
        card.text = ""
        UI.apply_button(card, "card")
        card.pressed.connect(_on_offer_pressed.bind(index))
        offers_grid.add_child(card)

        var art := TextureRect.new()
        art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        art.modulate = Color(1.0, 1.0, 1.0, 0.38)
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(art)

        var accent := ColorRect.new()
        accent.position = Vector2.ZERO
        accent.size = Vector2(300.0, 3.0)
        accent.color = UI.TEAL
        accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(accent)
        var quality := UI.label("普通 · 武器", 11, UI.MUTED)
        quality.position = Vector2(14.0, 12.0)
        quality.size = Vector2(170.0, 16.0)
        card.add_child(quality)
        var price := UI.label("0 金币", 17, UI.BRASS_LIGHT, true)
        price.position = Vector2(160.0, 10.0)
        price.size = Vector2(126.0, 22.0)
        price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        card.add_child(price)
        var seal := UI.make_seal("刃", 52.0)
        seal.position = Vector2(14.0, 42.0)
        card.add_child(seal)
        var seal_label := seal.get_child(0)
        var name_label := UI.label("", 17, UI.TEXT, true)
        name_label.position = Vector2(78.0, 40.0)
        name_label.size = Vector2(208.0, 24.0)
        name_label.clip_text = true
        card.add_child(name_label)
        var desc := UI.label("", 11, UI.MUTED)
        desc.position = Vector2(78.0, 66.0)
        desc.size = Vector2(208.0, 38.0)
        desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
        desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
        card.add_child(desc)
        var badge = UI.badge("购买", UI.BRASS)
        badge.position = Vector2(14.0, 148.0)
        card.add_child(badge)
        var owned := UI.label("", 10, UI.MUTED)
        owned.position = Vector2(150.0, 150.0)
        owned.size = Vector2(136.0, 16.0)
        owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        card.add_child(owned)

        shop_offer_buttons.append(card)
        shop_offer_uis.append({
            "button": card,
            "art": art,
            "accent": accent,
            "quality": quality,
            "price": price,
            "seal": seal,
            "seal_label": seal_label,
            "name": name_label,
            "desc": desc,
            "badge": badge,
            "owned": owned,
        })

    var build_panel := Panel.new()
    build_panel.position = Vector2(648.0, 128.0)
    build_panel.size = Vector2(536.0, 390.0)
    build_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    UI.apply_panel(build_panel, Color(0.04, 0.09, 0.10, 0.9), UI.LINE, 7, 1)
    content.add_child(build_panel)

    var build_box := _content_box(build_panel, 12, 6)
    UI.add_corners(build_panel)
    var build_head := HBoxContainer.new()
    build_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var build_title := UI.label("我的机关", 16, UI.BRASS_LIGHT, true)
    build_head.add_child(build_title)
    var build_spacer := Control.new()
    build_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    build_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    build_head.add_child(build_spacer)
    shop_weapon_count = UI.label("武器 0 / 6", 10, UI.MUTED)
    build_head.add_child(shop_weapon_count)
    var count_gap := Control.new()
    count_gap.custom_minimum_size = Vector2(10.0, 0.0)
    count_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
    build_head.add_child(count_gap)
    shop_item_count = UI.label("道具 0 / 6", 10, UI.MUTED)
    build_head.add_child(shop_item_count)
    build_box.add_child(build_head)

    build_box.add_child(UI.label("武器 · 点击出售", 10, UI.MUTED))
    var weapons_grid := GridContainer.new()
    weapons_grid.columns = 3
    weapons_grid.add_theme_constant_override("h_separation", 8)
    weapons_grid.add_theme_constant_override("v_separation", 8)
    weapons_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    build_box.add_child(weapons_grid)
    for index in range(6):
        var sell_card := _build_sell_slot("weapon", index)
        weapons_grid.add_child(sell_card["button"])
        shop_weapon_buttons.append(sell_card["button"])
        shop_weapon_uis.append(sell_card)

    build_box.add_child(UI.label("道具 · 点击出售", 10, UI.MUTED))
    var items_grid := GridContainer.new()
    items_grid.columns = 3
    items_grid.add_theme_constant_override("h_separation", 8)
    items_grid.add_theme_constant_override("v_separation", 8)
    items_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
    build_box.add_child(items_grid)
    for index in range(6):
        var sell_card := _build_sell_slot("item", index)
        items_grid.add_child(sell_card["button"])
        shop_item_buttons.append(sell_card["button"])
        shop_item_uis.append(sell_card)

    var foot := HBoxContainer.new()
    foot.position = Vector2(0.0, 548.0)
    foot.size = Vector2(1184.0, 56.0)
    foot.add_theme_constant_override("separation", 12)
    foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    content.add_child(foot)
    var coin := UI.make_coin(18.0)
    foot.add_child(coin)
    shop_gold_line = UI.label("金币 0", 17, UI.BRASS_LIGHT, true)
    foot.add_child(shop_gold_line)
    var hint := UI.label("同名同品质购买会立即升品 · 出售返还约 50% 金币", 11, UI.MUTED)
    hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    foot.add_child(hint)

    shop_reroll_button = Button.new()
    shop_reroll_button.text = "刷新 2 金币"
    shop_reroll_button.custom_minimum_size = Vector2(180.0, 52.0)
    UI.apply_button(shop_reroll_button, "ghost")
    shop_reroll_button.pressed.connect(_on_reroll_pressed)
    foot.add_child(shop_reroll_button)

    shop_next_button = Button.new()
    shop_next_button.text = "下一波"
    shop_next_button.custom_minimum_size = Vector2(210.0, 52.0)
    UI.apply_button(shop_next_button, "primary")
    shop_next_button.pressed.connect(func() -> void: next_wave.emit())
    foot.add_child(shop_next_button)

    shop_message_label = UI.label("", 12, UI.MUTED)
    shop_message_label.position = Vector2(0.0, 612.0)
    shop_message_label.size = Vector2(1184.0, 20.0)
    shop_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    content.add_child(shop_message_label)

func _build_sell_slot(kind: String, index: int) -> Dictionary:
    var is_weapon := kind == "weapon"
    var button := Button.new()
    button.custom_minimum_size = Vector2(160.0, 72.0 if is_weapon else 54.0)
    button.text = ""
    UI.apply_button(button, "card")
    button.pressed.connect(_on_sell_slot_pressed.bind(kind, index))

    var accent := ColorRect.new()
    accent.position = Vector2.ZERO
    accent.size = Vector2(2.0, 72.0 if is_weapon else 54.0)
    accent.color = UI.TEAL
    accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(accent)

    var seal := UI.make_seal("刃", 26.0 if is_weapon else 22.0)
    seal.position = Vector2(8.0, 8.0)
    button.add_child(seal)
    var seal_label := seal.get_child(0)
    var name_label := UI.label("空", 11 if is_weapon else 10, UI.TEXT, true)
    name_label.position = Vector2(40.0 if is_weapon else 36.0, 5.0)
    name_label.size = Vector2(118.0 if is_weapon else 122.0, 16.0)
    name_label.clip_text = true
    button.add_child(name_label)
    var quality_label := UI.label("", 9, UI.MUTED)
    quality_label.position = Vector2(40.0 if is_weapon else 36.0, 23.0)
    quality_label.size = Vector2(118.0, 14.0)
    button.add_child(quality_label)
    var sell_label := UI.label("", 9, UI.BRASS_LIGHT)
    sell_label.position = Vector2(40.0 if is_weapon else 36.0, 39.0 if is_weapon else 35.0)
    sell_label.size = Vector2(118.0, 14.0)
    button.add_child(sell_label)

    return {
        "button": button,
        "accent": accent,
        "seal": seal,
        "seal_label": seal_label,
        "name": name_label,
        "quality": quality_label,
        "sell": sell_label,
    }

func show_shop(data: Dictionary) -> void:
    _set_gameplay_visible(false)
    _hide_gameplay_inputs()
    stage_panel.visible = false
    end_panel.visible = false
    shop_panel.visible = true
    set_chapter_art(int(data.get("chapter", 1)))
    _animate_offers = true
    _shop_last_gold = -1
    _shop_last_health = -1
    _animate_panel(shop_panel, shop_content, "shop")
    refresh_shop(data)

func refresh_shop(data: Dictionary) -> void:
    var gold := int(data.get("gold", 0))
    var previous_shop_gold := _shop_last_gold
    _shop_last_gold = gold
    shop_gold_label.text = str(gold)
    shop_gold_line.text = "金币 %d" % gold
    shop_message_label.text = str(data.get("message", ""))
    if previous_shop_gold >= 0 and gold != previous_shop_gold:
        _pulse_control(shop_gold_label, 1.08, 0.18)
        _pulse_control(shop_gold_line, 1.05, 0.18)
    var health := int(data.get("health", 100))
    var max_health := maxi(1, int(data.get("max_health", 100)))
    var low_health := float(health) / float(max_health) <= 0.3
    shop_health_label.text = "生命 %d / %d" % [health, max_health]
    shop_health_label.add_theme_color_override("font_color", UI.RED if low_health else UI.MUTED)
    var heal_amount := int(data.get("heal_amount", 0))
    if heal_amount > 0:
        shop_health_label.modulate = Color(0.65, 1.35, 0.85, 1.0)
        var heal_tween := create_tween()
        heal_tween.tween_property(shop_health_label, "modulate", Color.WHITE, 0.45)
    if _shop_last_health >= 0 and health != _shop_last_health:
        _pulse_control(shop_health_label, 1.06, 0.18)
    _shop_last_health = health
    if _last_offer_bought.size() < shop_offer_buttons.size():
        var old_size := _last_offer_bought.size()
        _last_offer_bought.resize(shop_offer_buttons.size())
        for index in range(old_size, _last_offer_bought.size()):
            _last_offer_bought[index] = false

    var offers: Array = data.get("offers", [])
    for index in range(shop_offer_buttons.size()):
        var button: Button = shop_offer_buttons[index]
        var ui: Dictionary = shop_offer_uis[index]
        if index >= offers.size():
            button.visible = false
            continue
        button.visible = true
        var offer: Dictionary = offers[index]
        var quality := int(offer.get("quality", 1))
        var qcolor: Color = offer.get("quality_color", UI.quality_color(quality))
        var is_weapon := str(offer.get("kind", "weapon")) == "weapon"
        var accent: ColorRect = ui["accent"]
        var art: TextureRect = ui["art"]
        var quality_label: Label = ui["quality"]
        var price_label: Label = ui["price"]
        var seal: Panel = ui["seal"]
        var seal_label = ui["seal_label"]
        var name_label: Label = ui["name"]
        var desc_label: Label = ui["desc"]
        var badge: PanelContainer = ui["badge"]
        var owned_label: Label = ui["owned"]
        var disabled := bool(offer.get("disabled", false))
        var reason := str(offer.get("reason", ""))
        var owned := int(offer.get("owned", 0))

        accent.color = qcolor
        var art_path := "res://assets/art/cards/%s.jpg" % str(offer.get("id", ""))
        art.texture = load(art_path) if ResourceLoader.exists(art_path) else null
        art.visible = art.texture != null
        quality_label.text = "%s · %s" % [str(offer.get("quality_name", "")), "武器" if is_weapon else "道具"]
        quality_label.add_theme_color_override("font_color", qcolor)
        price_label.text = "%d 金币" % int(offer.get("price", 0))
        seal_label.text = UI.seal_glyph(str(offer.get("id", "")))
        seal.add_theme_stylebox_override("panel", UI.panel_style(Color(0.06, 0.11, 0.12, 0.95), qcolor, 26, 1))
        name_label.text = str(offer.get("title", offer.get("id", "")))
        var desc_text := str(offer.get("desc", ""))
        var legendary_text := str(offer.get("legendary_desc", ""))
        if quality >= 4 and legendary_text != "":
            desc_label.text = legendary_text
        else:
            desc_label.text = desc_text
        owned_label.text = "已有 %s" % UI.quality_name(owned) if owned > 0 else ""

        var bought_now := bool(offer.get("bought", false))
        var was_bought := false
        if index < _last_offer_bought.size() and _last_offer_bought[index] != null:
            was_bought = _last_offer_bought[index] == true
        var badge_text := "购买"
        var badge_color := UI.BRASS
        if bought_now:
            badge_text = "已售"
            badge_color = UI.MUTED
        elif reason != "":
            badge_text = reason
            badge_color = UI.RED
        elif owned > 0 and quality == owned:
            badge_text = "可升品"
            badge_color = UI.TEAL
        elif owned > 0 and quality > owned:
            badge_text = "可升级"
            badge_color = UI.TEAL
        UI.set_badge(badge, badge_text, badge_color)
        _pulse_badge(ui, badge_text)

        button.disabled = disabled
        button.modulate = Color(0.62, 0.62, 0.62, 0.8) if disabled else Color.WHITE
        _apply_offer_card_style(button, qcolor, disabled)
        button.tooltip_text = name_label.text + " — " + desc_text
        if quality >= 4 and legendary_text != "":
            button.tooltip_text += "\n" + legendary_text
        if reason != "":
            button.tooltip_text += "\n" + reason
        _last_offer_bought[index] = bought_now
        if bought_now and not was_bought:
            _flash_offer(button)

    _refresh_sell_slots(shop_weapon_uis, data.get("weapons", []), "weapon")
    _refresh_sell_slots(shop_item_uis, data.get("items", []), "item")

    var weapon_count := 0
    for slot in data.get("weapons", []):
        if not slot.is_empty():
            weapon_count += 1
    var item_count := 0
    for slot in data.get("items", []):
        if not slot.is_empty():
            item_count += 1
    shop_weapon_count.text = "武器 %d / 6" % weapon_count
    shop_item_count.text = "道具 %d / 6" % item_count

    var free_rerolls := int(data.get("free_rerolls", 0))
    if free_rerolls > 0:
        shop_reroll_button.text = "免费刷新 %d" % free_rerolls
    else:
        shop_reroll_button.text = "刷新 %d 金币" % int(data.get("reroll_cost", 2))
    if _animate_offers:
        _animate_offer_cards()
        _animate_offers = false

func _animate_offer_cards() -> void:
    if _offer_entrance_tween != null and _offer_entrance_tween.is_valid():
        _offer_entrance_tween.kill()
    _offer_entrance_tween = create_tween().set_parallel(true)
    for index in range(shop_offer_buttons.size()):
        var button: Button = shop_offer_buttons[index]
        if not button.visible:
            continue
        var target_alpha := 0.8 if button.disabled else 1.0
        button.modulate.a = 0.0
        button.scale = Vector2(0.97, 0.97)
        button.pivot_offset = button.custom_minimum_size * 0.5
        var delay := float(index) * 0.035
        _offer_entrance_tween.tween_property(button, "modulate:a", target_alpha, 0.16).set_delay(delay)
        _offer_entrance_tween.tween_property(button, "scale", Vector2.ONE, 0.18).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _flash_offer(button: Button) -> void:
    var target_alpha := 0.8 if button.disabled else 1.0
    var target := Color(button.modulate.r, button.modulate.g, button.modulate.b, target_alpha)
    button.modulate = Color(1.35, 1.25, 0.82, target_alpha)
    button.scale = Vector2(1.03, 1.03)
    button.pivot_offset = button.custom_minimum_size * 0.5
    var tween := create_tween().set_parallel(true)
    tween.tween_property(button, "modulate", target, 0.2)
    tween.tween_property(button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _pulse_badge(ui: Dictionary, badge_text: String) -> void:
    var badge: PanelContainer = ui["badge"]
    var old: Tween = ui.get("badge_tween", null)
    if old != null and old.is_valid():
        old.kill()
    badge.modulate = Color.WHITE
    ui["badge_tween"] = null
    if badge_text != "可升品" and badge_text != "可升级":
        return
    var tween := create_tween().set_loops()
    tween.tween_property(badge, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(badge, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    ui["badge_tween"] = tween

func _on_reroll_pressed() -> void:
    _animate_offers = true
    reroll_shop.emit()

func _apply_offer_card_style(button: Button, color: Color, disabled: bool) -> void:
    var bg := Color(0.05, 0.11, 0.12, 0.95)
    var border := Color(color.r, color.g, color.b, 0.38)
    button.add_theme_stylebox_override("normal", UI.panel_style(bg, border, 7, 1))
    button.add_theme_stylebox_override("hover", UI.panel_style(Color(0.08, 0.18, 0.19, 0.97), color, 7, 1))
    button.add_theme_stylebox_override("pressed", UI.panel_style(Color(0.04, 0.09, 0.10, 0.98), color, 7, 1))
    button.add_theme_stylebox_override("disabled", UI.panel_style(Color(0.035, 0.07, 0.08, 0.82), Color(0.12, 0.18, 0.19, 0.8), 7, 1))

func _refresh_sell_slots(uis: Array, slots: Array, kind: String) -> void:
    for index in range(uis.size()):
        var ui: Dictionary = uis[index]
        var button: Button = ui["button"]
        var accent: ColorRect = ui["accent"]
        var seal: Panel = ui["seal"]
        var seal_label = ui["seal_label"]
        var name_label: Label = ui["name"]
        var quality_label: Label = ui["quality"]
        var sell_label: Label = ui["sell"]
        var filled: bool = index < slots.size() and not slots[index].is_empty()
        if not filled:
            button.disabled = true
            button.set_meta("id", "")
            accent.color = Color(0.0, 0.0, 0.0, 0.0)
            seal.visible = false
            name_label.text = "空"
            name_label.add_theme_color_override("font_color", UI.MUTED)
            quality_label.text = ""
            sell_label.text = ""
            button.modulate = Color(1.0, 1.0, 1.0, 0.42)
            _apply_sell_style(button, UI.MUTED, false)
            continue

        var slot: Dictionary = slots[index]
        var quality := int(slot.get("quality", 0))
        var color := UI.quality_color(quality)
        var slot_id := str(slot.get("id", ""))
        button.disabled = false
        button.set_meta("id", slot_id)
        accent.color = color
        seal.visible = true
        seal_label.text = UI.seal_glyph(slot_id)
        seal.add_theme_stylebox_override("panel", UI.panel_style(Color(0.06, 0.11, 0.12, 0.95), color, 13, 1))
        name_label.text = str(slot.get("title", slot_id))
        name_label.add_theme_color_override("font_color", UI.TEXT)
        var slot_name := str(slot.get("slot_name", ""))
        var quality_text := UI.quality_name(quality)
        if slot_name != "":
            quality_text += " · " + slot_name
        quality_label.text = quality_text
        quality_label.add_theme_color_override("font_color", color)
        sell_label.text = "售 %d" % int(slot.get("sell_price", 0))
        button.modulate = Color.WHITE
        _apply_sell_style(button, color, true)

func _apply_sell_style(button: Button, color: Color, filled: bool) -> void:
    var bg := Color(0.05, 0.11, 0.12, 0.94)
    var border := Color(color.r, color.g, color.b, 0.45) if filled else Color(0.12, 0.18, 0.19, 0.8)
    button.add_theme_stylebox_override("normal", UI.panel_style(bg, border, 5, 1))
    button.add_theme_stylebox_override("hover", UI.panel_style(Color(0.08, 0.17, 0.18, 0.96), color if filled else border, 5, 1))
    button.add_theme_stylebox_override("pressed", UI.panel_style(Color(0.04, 0.09, 0.10, 0.98), border, 5, 1))
    button.add_theme_stylebox_override("disabled", UI.panel_style(Color(0.03, 0.06, 0.07, 0.7), Color(0.10, 0.15, 0.16, 0.8), 5, 1))

func hide_shop() -> void:
    shop_panel.visible = false
    _set_gameplay_visible(true)
    _show_gameplay_inputs()

func is_shop_visible() -> bool:
    return shop_panel.visible

func _on_offer_pressed(index: int) -> void:
    buy_offer.emit(index)

func _on_sell_slot_pressed(kind: String, index: int) -> void:
    var buttons := shop_weapon_buttons if kind == "weapon" else shop_item_buttons
    if index < 0 or index >= buttons.size():
        return
    var button: Button = buttons[index]
    var slot_id := str(button.get_meta("id", ""))
    if slot_id == "":
        return
    if kind == "weapon":
        sell_weapon.emit(slot_id)
    else:
        sell_item.emit(slot_id)

func get_shop_weapon_button(index: int) -> Button:
    if index < 0 or index >= shop_weapon_buttons.size():
        return null
    return shop_weapon_buttons[index]

func get_shop_item_button(index: int) -> Button:
    if index < 0 or index >= shop_item_buttons.size():
        return null
    return shop_item_buttons[index]

# ---------------------------------------------------------------------------
# End panel
# ---------------------------------------------------------------------------
func _build_end_panel() -> void:
    end_panel = Control.new()
    end_panel.name = "EndPanel"
    _full_rect(end_panel)
    end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    end_panel.visible = false
    root.add_child(end_panel)

    var backdrop := ColorRect.new()
    _full_rect(backdrop)
    backdrop.color = Color(0.02, 0.03, 0.04, 0.985)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    end_panel.add_child(backdrop)

    end_art = TextureRect.new()
    _full_rect(end_art)
    end_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    end_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    end_art.texture = _bg_art[0]
    end_art.modulate = Color(0.74, 0.76, 0.78, 1.0)
    end_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    end_panel.add_child(end_art)
    var end_shade := ColorRect.new()
    _full_rect(end_shade)
    end_shade.color = Color(0.02, 0.03, 0.04, 0.66)
    end_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    end_panel.add_child(end_shade)

    var center := CenterContainer.new()
    _full_rect(center)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    end_panel.add_child(center)

    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(780.0, 0.0)
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 12)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(box)
    end_box = box

    var kicker := UI.label("机 关 百 炼", 12, UI.BRASS)
    kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(kicker)

    var title_row := HBoxContainer.new()
    title_row.alignment = BoxContainer.ALIGNMENT_CENTER
    title_row.add_theme_constant_override("separation", 18)
    title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(title_row)
    end_title = UI.label("关卡完成", 50, Color("#f2e6c8"), true)
    end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_row.add_child(end_title)
    end_seal = Panel.new()
    end_seal.custom_minimum_size = Vector2(76.0, 76.0)
    end_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    end_seal.add_theme_stylebox_override("panel", UI.panel_style(Color(0.10, 0.03, 0.03, 0.8), Color(0.88, 0.35, 0.31), 5, 2))
    var seal_label := UI.label("通\n关", 22, Color("#f29a91"), true)
    _full_rect(seal_label)
    seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    seal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    seal_label.add_theme_constant_override("line_spacing", -4)
    end_seal.add_child(seal_label)
    end_seal.pivot_offset = Vector2(38.0, 38.0)
    end_seal.rotation = deg_to_rad(-8.0)
    title_row.add_child(end_seal)

    end_sub = UI.label("", 14, UI.MUTED)
    end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(end_sub)

    end_stats_box = HBoxContainer.new()
    end_stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
    end_stats_box.add_theme_constant_override("separation", 12)
    end_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(end_stats_box)

    end_next_label = UI.label("", 13, UI.MUTED)
    end_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(end_next_label)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 12)
    actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(actions)

    end_next_button = Button.new()
    end_next_button.text = "下一关"
    end_next_button.custom_minimum_size = Vector2(160.0, 54.0)
    UI.apply_button(end_next_button, "primary")
    end_next_button.pressed.connect(func() -> void: next_stage.emit())
    actions.add_child(end_next_button)

    end_select_button = Button.new()
    end_select_button.text = "重选关卡"
    end_select_button.custom_minimum_size = Vector2(150.0, 54.0)
    UI.apply_button(end_select_button, "ghost")
    end_select_button.pressed.connect(func() -> void: stage_select.emit())
    actions.add_child(end_select_button)

    restart_button = Button.new()
    restart_button.text = "重试本关"
    restart_button.custom_minimum_size = Vector2(150.0, 54.0)
    UI.apply_button(restart_button, "ghost")
    restart_button.pressed.connect(_on_retry_pressed)
    actions.add_child(restart_button)

func show_stage_clear(stage: String, has_next: bool, stats: String, next_label := "") -> void:
    stage_panel.visible = false
    shop_panel.visible = false
    _set_gameplay_visible(false)
    _hide_gameplay_inputs()
    end_panel.visible = true
    end_title.text = "关卡完成"
    end_title.add_theme_color_override("font_color", Color("#f2e6c8"))
    end_sub.text = stage
    end_seal.visible = true
    _build_end_stats(stats)
    end_next_label.text = next_label if next_label != "" else ("已解锁下一关" if has_next else "全关通关 · 无尽试炼已解锁")
    end_next_button.visible = has_next
    end_select_button.visible = true
    restart_button.visible = true
    restart_button.text = "重试本关"
    UI.apply_button(restart_button, "ghost")
    UI.apply_button(end_next_button, "primary")
    UI.apply_button(end_select_button, "ghost")
    _animate_end_panel()

func show_game_over(stage: String, stats: String) -> void:
    stage_panel.visible = false
    shop_panel.visible = false
    _set_gameplay_visible(false)
    _hide_gameplay_inputs()
    end_panel.visible = true
    end_title.text = "挑战失败"
    end_title.add_theme_color_override("font_color", UI.RED)
    end_sub.text = stage
    end_seal.visible = false
    _build_end_stats(stats)
    end_next_label.text = ""
    end_next_button.visible = false
    end_select_button.visible = true
    restart_button.visible = true
    restart_button.text = "重试本关"
    UI.apply_button(restart_button, "primary")
    UI.apply_button(end_select_button, "ghost")
    _animate_end_panel()

func _animate_end_panel() -> void:
    _fade_panel(end_panel, "end")
    if end_seal.visible:
        end_seal.modulate.a = 0.0
        end_seal.scale = Vector2(0.6, 0.6)
        end_seal.rotation = deg_to_rad(-18.0)
        var seal_tween := create_tween().set_parallel(true)
        seal_tween.tween_property(end_seal, "modulate:a", 1.0, 0.2)
        seal_tween.tween_property(end_seal, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        seal_tween.tween_property(end_seal, "rotation", deg_to_rad(-8.0), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    var buttons: Array = [end_next_button, end_select_button, restart_button]
    for index in range(buttons.size()):
        var button: Button = buttons[index]
        if not button.visible:
            continue
        button.modulate.a = 0.0
        var tween := create_tween()
        tween.tween_property(button, "modulate:a", 1.0, 0.16).set_delay(0.12 + float(index) * 0.05)

func _build_end_stats(stats: String) -> void:
    for child in end_stats_box.get_children():
        child.queue_free()
    var lines := stats.split("\n", false)
    for index in range(lines.size()):
        var value_text := str(lines[index])
        if value_text == "":
            continue
        var card := Panel.new()
        card.custom_minimum_size = Vector2(232.0, 78.0)
        card.mouse_filter = Control.MOUSE_FILTER_IGNORE
        UI.apply_panel(card, Color(0.05, 0.11, 0.12, 0.92), Color(UI.BRASS.r, UI.BRASS.g, UI.BRASS.b, 0.3), 6, 1)
        var margin := _margin(10)
        card.add_child(margin)
        var color := UI.TEAL if index == 0 else (UI.BRASS_LIGHT if index == 1 else UI.TEXT)
        var value := UI.label(value_text, 16, color, true)
        value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        margin.add_child(value)
        card.modulate.a = 0.0
        card.scale = Vector2(0.96, 0.96)
        card.pivot_offset = Vector2(116.0, 39.0)
        end_stats_box.add_child(card)
        var tween := create_tween().set_parallel(true)
        tween.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(float(index) * 0.04)
        tween.tween_property(card, "scale", Vector2.ONE, 0.2).set_delay(float(index) * 0.04).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func hide_end_panel() -> void:
    end_panel.visible = false
    if not stage_panel.visible and not shop_panel.visible:
        _set_gameplay_visible(true)

func is_end_panel_visible() -> bool:
    return end_panel.visible

func _on_retry_pressed() -> void:
    retry_stage.emit()

# ---------------------------------------------------------------------------
# Shared visibility and getters
# ---------------------------------------------------------------------------
func _set_gameplay_visible(value: bool) -> void:
    combat_ui.visible = value
    if not value:
        boss_bar.visible = false

func _hide_gameplay_inputs() -> void:
    if joystick.has_method("release"):
        joystick.release()
    joystick.visible = false
    skill_button.visible = false
    skill_ring.visible = false

func _show_gameplay_inputs() -> void:
    joystick.visible = true
    skill_button.visible = true
    skill_ring.visible = true

func get_stage_button(stage_id: String) -> Button:
    return stage_buttons.get(stage_id)

func get_shop_offer_button(index: int) -> Button:
    if index < 0 or index >= shop_offer_buttons.size():
        return null
    return shop_offer_buttons[index]

func get_shop_offer_badge(index: int) -> String:
    if index < 0 or index >= shop_offer_uis.size():
        return ""
    var ui: Dictionary = shop_offer_uis[index]
    var badge: PanelContainer = ui["badge"]
    var text_node := badge.get_child(0) as Label
    return text_node.text if text_node != null else ""

func get_reroll_button() -> Button:
    return shop_reroll_button

func get_next_wave_button() -> Button:
    return shop_next_button

func get_next_stage_button() -> Button:
    return end_next_button

func get_select_stage_button() -> Button:
    return end_select_button

func get_retry_button() -> Button:
    return restart_button
