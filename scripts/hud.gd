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
signal dash_requested

@onready var health_label: Label = $Root/Stats/HealthLabel
@onready var stage_label: Label = $Root/Stats/StageLabel
@onready var wave_label: Label = $Root/Stats/WaveLabel
@onready var gold_label: Label = $Root/Stats/GoldLabel
@onready var timer_label: Label = $Root/Stats/TimerLabel
@onready var enemy_label: Label = $Root/Stats/EnemyLabel
@onready var best_label: Label = $Root/Stats/BestLabel
@onready var tip_label: Label = $Root/TipLabel
@onready var joystick: Control = $Root/Joystick
@onready var dash_button: Button = $Root/DashButton
@onready var boss_bar: Control = $Root/BossBar
@onready var boss_bar_value: ProgressBar = $Root/BossBar/Bar
@onready var end_panel: Control = $Root/EndPanel
@onready var end_title: Label = $Root/EndPanel/Center/VBox/Title
@onready var end_stats: Label = $Root/EndPanel/Center/VBox/Stats
@onready var restart_button: Button = $Root/EndPanel/Center/VBox/RestartButton
@onready var weapon_slot_labels = [
    $Root/WeaponSlots/Slot1,
    $Root/WeaponSlots/Slot2,
    $Root/WeaponSlots/Slot3,
    $Root/WeaponSlots/Slot4,
    $Root/WeaponSlots/Slot5,
    $Root/WeaponSlots/Slot6,
]
@onready var item_slot_labels = [
    $Root/ItemSlots/Slot1,
    $Root/ItemSlots/Slot2,
    $Root/ItemSlots/Slot3,
    $Root/ItemSlots/Slot4,
    $Root/ItemSlots/Slot5,
    $Root/ItemSlots/Slot6,
]

var stage_panel: Control
var shop_panel: Control
var stage_buttons: Dictionary = {}
var endless_button: Button
var shop_offer_buttons: Array = []
var shop_weapon_buttons: Array = []
var shop_item_buttons: Array = []
var shop_gold_label: Label
var shop_message_label: Label
var shop_reroll_button: Button
var shop_next_button: Button
var end_next_button: Button
var end_select_button: Button
var stage_subtitle: Label

func _ready() -> void:
    end_panel.visible = false
    boss_bar.visible = false
    restart_button.pressed.connect(_on_retry_pressed)
    dash_button.pressed.connect(_on_dash_pressed)
    _build_end_actions()
    _build_stage_select()
    _build_shop()

func set_health(current: int, maximum: int) -> void:
    health_label.text = "HP %d / %d" % [current, maximum]

func set_stage(label: String) -> void:
    stage_label.text = "STAGE " + label

func set_wave(current: int, total: int) -> void:
    if total <= 0:
        wave_label.text = "WAVE %d" % current
    else:
        wave_label.text = "WAVE %d / %d" % [current, total]

func set_gold(value: int) -> void:
    gold_label.text = "GOLD %d" % value

func set_wave_time(seconds: float, is_boss: bool) -> void:
    if is_boss:
        timer_label.text = "BOSS"
    else:
        timer_label.text = "TIME %ds" % int(ceil(float(seconds)))

func set_enemy_count(count: int) -> void:
    enemy_label.text = "ENEMIES %d" % count

func set_best_wave(value: int) -> void:
    best_label.text = "BEST ENDLESS %d" % value

func set_dash_state(ready: bool, remaining: float) -> void:
    dash_button.disabled = not ready
    if ready:
        dash_button.text = "DASH"
    else:
        dash_button.text = "DASH %.1fs" % maxf(remaining, 0.0)

func set_weapon_slots(slots: Array) -> void:
    for index in range(weapon_slot_labels.size()):
        if index < slots.size() and not slots[index].is_empty():
            var slot: Dictionary = slots[index]
            var quality := int(slot.get("quality", 0))
            var color := _quality_color(quality)
            weapon_slot_labels[index].text = "%s %s%s" % [
                str(slot.get("id", "")).to_upper(),
                _quality_letter(quality),
                "*" if bool(slot.get("legendary", false)) else "",
            ]
            weapon_slot_labels[index].add_theme_color_override("font_color", color)
        else:
            weapon_slot_labels[index].text = "EMPTY"
            weapon_slot_labels[index].add_theme_color_override("font_color", Color(0.65, 0.85, 0.90, 0.5))

func set_item_slots(slots: Array) -> void:
    for index in range(item_slot_labels.size()):
        if index < slots.size() and not slots[index].is_empty():
            var slot: Dictionary = slots[index]
            var quality := int(slot.get("quality", 0))
            item_slot_labels[index].text = "%s %s" % [
                str(slot.get("id", "")).to_upper(),
                _quality_letter(quality),
            ]
            item_slot_labels[index].add_theme_color_override("font_color", _quality_color(quality))
        else:
            item_slot_labels[index].text = "EMPTY"
            item_slot_labels[index].add_theme_color_override("font_color", Color(0.70, 0.80, 0.75, 0.5))

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

func show_stage_select(data: Dictionary) -> void:
    _set_gameplay_visible(false)
    _hide_gameplay_inputs()
    end_panel.visible = false
    shop_panel.visible = false
    stage_panel.visible = true
    var stages: Array = data.get("stages", [])
    for stage in stages:
        var id := str(stage["id"])
        if not stage_buttons.has(id):
            continue
        var button: Button = stage_buttons[id]
        var label := str(stage["label"])
        if bool(stage["cleared"]):
            label += " *"
        button.text = label
        button.disabled = bool(stage["locked"])
        button.modulate = Color(1, 1, 1, 1) if not bool(stage["locked"]) else Color(0.45, 0.45, 0.45, 0.6)
    endless_button.disabled = not bool(data.get("endless_unlocked", false))
    endless_button.text = "ENDLESS" if bool(data.get("endless_unlocked", false)) else "ENDLESS (CLEAR 3-1)"
    endless_button.modulate = Color(1, 1, 1, 1) if not endless_button.disabled else Color(0.45, 0.45, 0.45, 0.6)
    var best := int(data.get("best_endless", 0))
    if bool(data.get("endless_unlocked", false)):
        stage_subtitle.text = "Clear a stage to unlock the next. BEST ENDLESS WAVE %d." % best
    else:
        stage_subtitle.text = "Clear a stage to unlock the next. Clear 3-1 to unlock ENDLESS."

func hide_stage_select() -> void:
    stage_panel.visible = false
    _set_gameplay_visible(true)
    _show_gameplay_inputs()

func is_stage_select_visible() -> bool:
    return stage_panel.visible

func show_shop(data: Dictionary) -> void:
    _set_gameplay_visible(false)
    _hide_gameplay_inputs()
    end_panel.visible = false
    stage_panel.visible = false
    shop_panel.visible = true
    refresh_shop(data)

func refresh_shop(data: Dictionary) -> void:
    shop_gold_label.text = "GOLD %d" % int(data.get("gold", 0))
    shop_message_label.text = str(data.get("message", ""))
    var offers: Array = data.get("offers", [])
    for index in range(shop_offer_buttons.size()):
        var button: Button = shop_offer_buttons[index]
        if index >= offers.size():
            button.visible = false
            continue
        var offer: Dictionary = offers[index]
        button.visible = true
        var offer_title := str(offer.get("title", ""))
        if offer_title == "":
            offer_title = str(offer["id"]).to_upper()
        button.text = "%s %s\n%dg" % [
            str(offer["quality_name"]),
            offer_title,
            int(offer["price"]),
        ]
        button.disabled = bool(offer.get("disabled", false))
        button.modulate = Color(1, 1, 1, 1) if not bool(offer.get("disabled", false)) else Color(0.55, 0.55, 0.55, 0.7)
        button.add_theme_color_override("font_color", offer.get("quality_color", Color.WHITE))
        var reason := str(offer.get("reason", ""))
        var tooltip := str(offer.get("title", "")) + " — " + str(offer.get("desc", ""))
        if reason != "":
            tooltip += "\n" + reason
        button.tooltip_text = tooltip

    var weapons: Array = data.get("weapons", [])
    for index in range(shop_weapon_buttons.size()):
        var button: Button = shop_weapon_buttons[index]
        if index >= weapons.size() or weapons[index].is_empty():
            button.text = "EMPTY"
            button.disabled = true
            button.modulate = Color(0.65, 0.65, 0.65, 0.6)
            button.set_meta("id", "")
        else:
            var slot: Dictionary = weapons[index]
            var quality := int(slot.get("quality", 0))
            button.text = "%s %s\nSELL %dg" % [
                str(slot.get("id", "")).to_upper(),
                _quality_letter(quality),
                int(slot.get("sell_price", 0)),
            ]
            button.disabled = false
            button.modulate = Color(1, 1, 1, 1)
            button.add_theme_color_override("font_color", _quality_color(quality))
            button.set_meta("id", str(slot.get("id", "")))

    var items: Array = data.get("items", [])
    for index in range(shop_item_buttons.size()):
        var button: Button = shop_item_buttons[index]
        if index >= items.size() or items[index].is_empty():
            button.text = "EMPTY"
            button.disabled = true
            button.modulate = Color(0.65, 0.65, 0.65, 0.6)
            button.set_meta("id", "")
        else:
            var slot: Dictionary = items[index]
            var quality := int(slot.get("quality", 0))
            button.text = "%s %s\nSELL %dg" % [
                str(slot.get("id", "")).to_upper(),
                _quality_letter(quality),
                int(slot.get("sell_price", 0)),
            ]
            button.disabled = false
            button.modulate = Color(1, 1, 1, 1)
            button.add_theme_color_override("font_color", _quality_color(quality))
            button.set_meta("id", str(slot.get("id", "")))

    var free_rerolls := int(data.get("free_rerolls", 0))
    if free_rerolls > 0:
        shop_reroll_button.text = "FREE REROLL (%d)" % free_rerolls
    else:
        shop_reroll_button.text = "REROLL %dg" % int(data.get("reroll_cost", 2))

func hide_shop() -> void:
    shop_panel.visible = false
    _set_gameplay_visible(true)
    _show_gameplay_inputs()

func is_shop_visible() -> bool:
    return shop_panel.visible

func show_stage_clear(stage: String, has_next: bool, stats: String) -> void:
    stage_panel.visible = false
    shop_panel.visible = false
    _set_gameplay_visible(false)
    _hide_gameplay_inputs()
    end_title.text = "STAGE %s CLEAR" % stage
    end_title.add_theme_color_override("font_color", Color(0.55, 1.00, 0.85))
    end_stats.text = stats
    restart_button.visible = true
    restart_button.text = "RETRY"
    end_next_button.visible = has_next
    end_select_button.visible = true
    end_panel.visible = true

func show_game_over(stage: String, stats: String) -> void:
    stage_panel.visible = false
    shop_panel.visible = false
    _set_gameplay_visible(false)
    _hide_gameplay_inputs()
    end_title.text = "GAME OVER"
    end_title.add_theme_color_override("font_color", Color(1.00, 0.45, 0.45))
    end_stats.text = stage + "\n" + stats
    restart_button.visible = true
    restart_button.text = "RETRY"
    end_next_button.visible = false
    end_select_button.visible = true
    end_panel.visible = true

func hide_end_panel() -> void:
    end_panel.visible = false
    if not stage_panel.visible and not shop_panel.visible:
        _set_gameplay_visible(true)

func is_end_panel_visible() -> bool:
    return end_panel.visible

func get_stage_button(stage_id: String) -> Button:
    return stage_buttons.get(stage_id)

func get_shop_offer_button(index: int) -> Button:
    if index < 0 or index >= shop_offer_buttons.size():
        return null
    return shop_offer_buttons[index]

func get_shop_weapon_button(index: int) -> Button:
    if index < 0 or index >= shop_weapon_buttons.size():
        return null
    return shop_weapon_buttons[index]

func get_shop_item_button(index: int) -> Button:
    if index < 0 or index >= shop_item_buttons.size():
        return null
    return shop_item_buttons[index]

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

func _set_gameplay_visible(value: bool) -> void:
    $Root/Stats.visible = value
    tip_label.visible = value
    $Root/WeaponSlots.visible = value
    $Root/ItemSlots.visible = value
    if not value:
        boss_bar.visible = false

func _hide_gameplay_inputs() -> void:
    joystick.release()
    joystick.visible = false
    dash_button.visible = false

func _show_gameplay_inputs() -> void:
    joystick.visible = true
    dash_button.visible = true

func _build_end_actions() -> void:
    var vbox: VBoxContainer = $Root/EndPanel/Center/VBox
    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 14)
    end_next_button = Button.new()
    end_next_button.text = "NEXT STAGE"
    end_next_button.custom_minimum_size = Vector2(210, 54)
    end_next_button.add_theme_font_size_override("font_size", 20)
    end_next_button.pressed.connect(func(): next_stage.emit())
    end_select_button = Button.new()
    end_select_button.text = "STAGE SELECT"
    end_select_button.custom_minimum_size = Vector2(210, 54)
    end_select_button.add_theme_font_size_override("font_size", 20)
    end_select_button.pressed.connect(func(): stage_select.emit())
    actions.add_child(end_next_button)
    actions.add_child(end_select_button)
    vbox.add_child(actions)

func _build_stage_select() -> void:
    stage_panel = Control.new()
    stage_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    stage_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    stage_panel.visible = false
    $Root.add_child(stage_panel)

    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.02, 0.03, 0.05, 0.93)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_panel.add_child(backdrop)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_panel.add_child(center)

    var vbox := VBoxContainer.new()
    vbox.custom_minimum_size = Vector2(760, 600)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 18)
    center.add_child(vbox)

    var title := Label.new()
    title.text = "机关百炼 · STAGE SELECT"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 42)
    title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.92))
    vbox.add_child(title)

    stage_subtitle = Label.new()
    stage_subtitle.text = "Clear a stage to unlock the next. Clear 3-1 to unlock ENDLESS."
    stage_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stage_subtitle.add_theme_font_size_override("font_size", 17)
    stage_subtitle.add_theme_color_override("font_color", Color(0.70, 0.82, 0.86))
    vbox.add_child(stage_subtitle)

    var grid := GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 14)
    grid.add_theme_constant_override("v_separation", 14)
    grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vbox.add_child(grid)
    for chapter in range(1, 4):
        for stage in range(1, 5):
            var id := "%d-%d" % [chapter, stage]
            var button := Button.new()
            button.text = id
            button.custom_minimum_size = Vector2(160, 66)
            button.add_theme_font_size_override("font_size", 22)
            button.pressed.connect(_on_stage_button_pressed.bind(id))
            grid.add_child(button)
            stage_buttons[id] = button

    endless_button = Button.new()
    endless_button.text = "ENDLESS"
    endless_button.custom_minimum_size = Vector2(300, 58)
    endless_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    endless_button.add_theme_font_size_override("font_size", 22)
    endless_button.pressed.connect(_on_endless_pressed)
    vbox.add_child(endless_button)

    var tip := Label.new()
    tip.text = "16 waves per stage · Boss at wave 8 and 16 · Shop between battles"
    tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    tip.add_theme_font_size_override("font_size", 15)
    tip.add_theme_color_override("font_color", Color(0.55, 0.68, 0.72))
    vbox.add_child(tip)

func _build_shop() -> void:
    shop_panel = Control.new()
    shop_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    shop_panel.visible = false
    $Root.add_child(shop_panel)

    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.02, 0.03, 0.05, 0.97)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shop_panel.add_child(backdrop)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shop_panel.add_child(center)

    var vbox := VBoxContainer.new()
    vbox.custom_minimum_size = Vector2(1060, 650)
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    vbox.add_theme_constant_override("separation", 10)
    center.add_child(vbox)

    var title := Label.new()
    title.text = "PREPARATION"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 36)
    title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.92))
    vbox.add_child(title)

    shop_gold_label = Label.new()
    shop_gold_label.text = "GOLD 0"
    shop_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shop_gold_label.add_theme_font_size_override("font_size", 24)
    shop_gold_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.45))
    vbox.add_child(shop_gold_label)

    var offers := HBoxContainer.new()
    offers.alignment = BoxContainer.ALIGNMENT_CENTER
    offers.add_theme_constant_override("separation", 12)
    vbox.add_child(offers)
    for index in range(4):
        var button := Button.new()
        button.custom_minimum_size = Vector2(240, 88)
        button.add_theme_font_size_override("font_size", 16)
        button.pressed.connect(_on_offer_pressed.bind(index))
        offers.add_child(button)
        shop_offer_buttons.append(button)

    var weapon_label := Label.new()
    weapon_label.text = "WEAPONS — click to sell"
    weapon_label.add_theme_font_size_override("font_size", 16)
    weapon_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.9))
    vbox.add_child(weapon_label)
    var weapons := HBoxContainer.new()
    weapons.alignment = BoxContainer.ALIGNMENT_CENTER
    weapons.add_theme_constant_override("separation", 8)
    vbox.add_child(weapons)
    for index in range(6):
        var button := Button.new()
        button.custom_minimum_size = Vector2(158, 58)
        button.add_theme_font_size_override("font_size", 13)
        button.pressed.connect(_on_sell_weapon_pressed.bind(index))
        weapons.add_child(button)
        shop_weapon_buttons.append(button)

    var item_label := Label.new()
    item_label.text = "ITEMS — click to sell"
    item_label.add_theme_font_size_override("font_size", 16)
    item_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.9))
    vbox.add_child(item_label)
    var items := HBoxContainer.new()
    items.alignment = BoxContainer.ALIGNMENT_CENTER
    items.add_theme_constant_override("separation", 8)
    vbox.add_child(items)
    for index in range(6):
        var button := Button.new()
        button.custom_minimum_size = Vector2(158, 58)
        button.add_theme_font_size_override("font_size", 13)
        button.pressed.connect(_on_sell_item_pressed.bind(index))
        items.add_child(button)
        shop_item_buttons.append(button)

    var actions := HBoxContainer.new()
    actions.alignment = BoxContainer.ALIGNMENT_CENTER
    actions.add_theme_constant_override("separation", 18)
    vbox.add_child(actions)
    shop_reroll_button = Button.new()
    shop_reroll_button.text = "REROLL 2g"
    shop_reroll_button.custom_minimum_size = Vector2(230, 54)
    shop_reroll_button.add_theme_font_size_override("font_size", 20)
    shop_reroll_button.pressed.connect(func(): reroll_shop.emit())
    actions.add_child(shop_reroll_button)
    shop_next_button = Button.new()
    shop_next_button.text = "NEXT WAVE"
    shop_next_button.custom_minimum_size = Vector2(230, 54)
    shop_next_button.add_theme_font_size_override("font_size", 20)
    shop_next_button.pressed.connect(func(): next_wave.emit())
    actions.add_child(shop_next_button)

    shop_message_label = Label.new()
    shop_message_label.text = ""
    shop_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    shop_message_label.add_theme_font_size_override("font_size", 16)
    shop_message_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.88))
    vbox.add_child(shop_message_label)

func _on_stage_button_pressed(stage_id: String) -> void:
    stage_selected.emit(stage_id)

func _on_endless_pressed() -> void:
    if endless_button.disabled:
        return
    endless_selected.emit()

func _on_offer_pressed(index: int) -> void:
    buy_offer.emit(index)

func _on_sell_weapon_pressed(index: int) -> void:
    var button: Button = shop_weapon_buttons[index]
    var id := str(button.get_meta("id", ""))
    if id != "":
        sell_weapon.emit(id)

func _on_sell_item_pressed(index: int) -> void:
    var button: Button = shop_item_buttons[index]
    var id := str(button.get_meta("id", ""))
    if id != "":
        sell_item.emit(id)

func _on_retry_pressed() -> void:
    retry_stage.emit()

func _on_dash_pressed() -> void:
    dash_requested.emit()

func _quality_letter(quality: int) -> String:
    match quality:
        1:
            return "C"
        2:
            return "R"
        3:
            return "E"
        4:
            return "L"
        _:
            return "-"

func _quality_color(quality: int) -> Color:
    match quality:
        1:
            return Color("#9ca3af")
        2:
            return Color("#60a5fa")
        3:
            return Color("#c084fc")
        4:
            return Color("#fbbf24")
        _:
            return Color.WHITE
