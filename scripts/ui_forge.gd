class_name ForgeUI
extends RefCounted

## 青绿机关 · 色板
## 取自矿物重彩（石青、石绿、泥金、朱砂）压深黛底，替代原「霓虹青 + 黄铜」的赛博仪表盘调性。
const INK := Color("#0a1418")          ## 墨底
const PANEL := Color("#152528")        ## 面板
const PANEL_2 := Color("#1c3038")      ## 面板（亮）
const PANEL_3 := Color("#244049")      ## 面板（更亮）
const BRASS := Color("#c9a227")        ## 泥金
const BRASS_LIGHT := Color("#ecd689")  ## 淡金
const TEAL := Color("#5aac86")         ## 石绿（主高亮）
const TEAL_DIM := Color("#3b7a5c")     ## 深石绿
const AZURE := Color("#4687a8")        ## 石青（次高亮）
const AZURE_DIM := Color("#2c566b")
const RED := Color("#c84a3c")          ## 朱砂
const TEXT := Color("#e8e3d5")         ## 蛤白
const MUTED := Color("#8fa3a8")        ## 灰青
const LINE := Color(0.788, 0.635, 0.153, 0.40)   ## 金线（泥金亮度低于原黄铜，alpha 相应上调）
const DARK_LINE := Color(0.14, 0.24, 0.27, 1.0)
const ICON_GLYPHS := ["炮", "刃", "链", "穿", "锤", "毒", "磁", "靴", "火", "猫", "砧", "翠"]
const QUALITY_COLORS := [
    Color("#cfc9bb"),   ## 白 · 宣纸
    Color("#8fa3a8"),   ## 普通 · 灰青
    Color("#4f8fa8"),   ## 稀有 · 石青
    Color("#8a6fa8"),   ## 史诗 · 青莲
    Color("#e0b445"),   ## 传说 · 泥金
]
const QUALITY_NAMES := ["", "普通", "稀有", "史诗", "传说"]
const SEALS := {
    "peony": "炮",
    "maple": "刃",
    "justice": "链",
    "vigil": "穿",
    "hammer": "锤",
    "elixir": "毒",
    "magnet": "磁",
    "boots": "靴",
    "holy_fire": "火",
    "lucky_cat": "猫",
    "anvil": "砧",
    "jade": "翠",
}

static var _regular_font: SystemFont
static var _bold_font: SystemFont
static var _theme: Theme

static func regular_font() -> SystemFont:
    if _regular_font == null:
        _regular_font = SystemFont.new()
        _regular_font.font_names = PackedStringArray([
            "Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC",
            "WenQuanYi Micro Hei", "sans-serif",
        ])
        _regular_font.allow_system_fallback = true
    return _regular_font

static func bold_font() -> SystemFont:
    if _bold_font == null:
        _bold_font = SystemFont.new()
        ## 标题与数字改用宋体系（衬线），是「东方匠造」调性的主要来源之一。
        ## 正文仍走 regular_font 的无衬线，保证 9–12px 小字清晰。
        _bold_font.font_names = PackedStringArray([
            "Source Han Serif SC", "Noto Serif CJK SC", "Songti SC",
            "STSong", "SimSun", "Microsoft YaHei", "serif",
        ])
        _bold_font.font_weight = 700
        _bold_font.allow_system_fallback = true
    return _bold_font

static func make_theme() -> Theme:
    if _theme == null:
        _theme = Theme.new()
        _theme.default_font = regular_font()
        _theme.default_font_size = 16
    return _theme

static func label(text: String, font_size: int, color: Color = TEXT, bold := false) -> Label:
    var node := Label.new()
    node.text = text
    node.add_theme_font_override("font", bold_font() if bold else regular_font())
    node.add_theme_font_size_override("font_size", font_size)
    node.add_theme_color_override("font_color", color)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return node

static func outlined(node: Label, color: Color = Color(0.01, 0.02, 0.03, 0.92), size := 4) -> Label:
    node.add_theme_color_override("font_outline_color", color)
    node.add_theme_constant_override("outline_size", size)
    return node

static func panel_style(bg: Color = PANEL, border: Color = LINE, radius := 8, border_width := 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 0.0
    style.content_margin_top = 0.0
    style.content_margin_right = 0.0
    style.content_margin_bottom = 0.0
    return style

static func apply_panel(panel: Panel, bg: Color = PANEL, border: Color = LINE, radius := 8, border_width := 1) -> void:
    panel.add_theme_stylebox_override("panel", panel_style(bg, border, radius, border_width))
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func apply_button(button: Button, kind: String = "ghost") -> void:
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_override("font", regular_font())
    button.add_theme_font_size_override("font_size", 16)
    match kind:
        "primary":
            _set_button_styles(button, BRASS, BRASS_LIGHT, INK, BRASS_LIGHT.darkened(0.08), BRASS.darkened(0.12), Color("#6d715f"))
        "danger":
            _set_button_styles(button, Color(0.30, 0.08, 0.07, 0.9), RED, Color("#ffd6d1"), Color(0.38, 0.10, 0.09, 1.0), Color(0.24, 0.06, 0.05, 1.0), Color("#87514c"))
        "card":
            _set_button_styles(button, PANEL_2, DARK_LINE, TEXT, Color(0.10, 0.22, 0.23, 1.0), Color(0.07, 0.15, 0.16, 1.0), Color(0.05, 0.10, 0.11, 0.9))
        "flat":
            for state in ["normal", "hover", "pressed", "disabled"]:
                button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
        _:
            _set_button_styles(button, Color(0.07, 0.15, 0.16, 0.92), LINE, BRASS_LIGHT, Color(0.11, 0.23, 0.24, 1.0), Color(0.05, 0.12, 0.13, 1.0), Color("#6d8582"))

static func _set_button_styles(button: Button, bg: Color, border: Color, text_color: Color, hover_bg: Color, pressed_bg: Color, disabled_color: Color) -> void:
    button.add_theme_stylebox_override("normal", panel_style(bg, border, 7, 1))
    button.add_theme_stylebox_override("hover", panel_style(hover_bg, border.lightened(0.12), 7, 1))
    button.add_theme_stylebox_override("pressed", panel_style(pressed_bg, border, 7, 1))
    button.add_theme_stylebox_override("disabled", panel_style(Color(0.04, 0.08, 0.09, 0.75), disabled_color, 7, 1))
    button.add_theme_color_override("font_color", text_color)
    button.add_theme_color_override("font_hover_color", text_color)
    button.add_theme_color_override("font_pressed_color", text_color)
    button.add_theme_color_override("font_disabled_color", disabled_color)

static func add_corners(panel: Control, color: Color = BRASS) -> void:
    var corners := Control.new()
    corners.name = "Corners"
    corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    corners.mouse_filter = Control.MOUSE_FILTER_IGNORE
    corners.set_script(load("res://scripts/ui_corners.gd"))
    corners.set("color", color)
    panel.add_child(corners)

static func make_coin(diameter := 16.0) -> Panel:
    var coin := Panel.new()
    coin.custom_minimum_size = Vector2(diameter, diameter)
    coin.size = Vector2(diameter, diameter)
    coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := panel_style(Color("#e0b445"), Color("#f5e2a8"), int(diameter * 0.5), 1)
    coin.add_theme_stylebox_override("panel", style)
    return coin

static func make_seal(glyph: String, diameter: float, border: Color = BRASS) -> Panel:
    var seal := Panel.new()
    seal.custom_minimum_size = Vector2(diameter, diameter)
    seal.size = Vector2(diameter, diameter)
    seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := panel_style(Color(0.06, 0.11, 0.12, 0.95), border, int(diameter * 0.5), 1)
    seal.add_theme_stylebox_override("panel", style)
    if glyph in ICON_GLYPHS:
        var icon := Control.new()
        icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        icon.set_script(load("res://scripts/forge_glyph.gd"))
        icon.set("text", glyph)
        icon.set("tint", BRASS_LIGHT)
        seal.add_child(icon)
        return seal
    var text := label(glyph, int(diameter * 0.42), BRASS_LIGHT, true)
    text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    seal.add_child(text)
    return seal

static func badge(text: String, color: Color) -> PanelContainer:
    var box := PanelContainer.new()
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := panel_style(Color(color.r, color.g, color.b, 0.07), Color(color.r, color.g, color.b, 0.5), 4, 1)
    style.content_margin_left = 5.0
    style.content_margin_top = 1.0
    style.content_margin_right = 5.0
    style.content_margin_bottom = 1.0
    box.add_theme_stylebox_override("panel", style)
    var text_node := label(text, 10, color)
    box.add_child(text_node)
    return box

static func set_badge(box: PanelContainer, text: String, color: Color) -> void:
    var style := panel_style(Color(color.r, color.g, color.b, 0.07), Color(color.r, color.g, color.b, 0.5), 4, 1)
    style.content_margin_left = 5.0
    style.content_margin_top = 1.0
    style.content_margin_right = 5.0
    style.content_margin_bottom = 1.0
    box.add_theme_stylebox_override("panel", style)
    var text_node := box.get_child(0) as Label
    if text_node != null:
        text_node.text = text
        text_node.add_theme_color_override("font_color", color)

static func quality_color(quality: int) -> Color:
    return QUALITY_COLORS[clampi(quality, 0, QUALITY_COLORS.size() - 1)]

static func quality_name(quality: int) -> String:
    if quality < 1 or quality >= QUALITY_NAMES.size():
        return ""
    return QUALITY_NAMES[quality]

static func seal_glyph(id: String) -> String:
    return str(SEALS.get(id, "?"))
