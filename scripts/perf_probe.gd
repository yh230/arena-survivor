extends CanvasLayer

## 性能探针 —— 只由 `--perf` 启动参数创建，正常游玩不会加载。
##
## 用途一：屏幕左上角实时显示帧预算，截图即可留证。
## 用途二：每 0.5s 追加一行 CSV 到 user://perf.log，跑完可直接算 P50/P95，
##         不必靠肉眼看瞬时数字（瞬时值抖动大，容易误判）。
##
## 注意：RENDER_TOTAL_DRAW_CALLS_IN_FRAME 只在 Vulkan/D3D12/Metal 后端有效，
##       本项目是 GL Compatibility，该值很可能恒为 0。启动时会打印一次，
##       用一行输出直接判定该监视器在本项目是否可用，避免继续拿它当依据。

const SAMPLE_INTERVAL := 0.5
const LOG_PATH := "user://perf.log"

var _label: Label
var _log: FileAccess
var _samples := 0
var _frames := 0
var _last_us := 0

func _ready() -> void:
    layer = 200

    # 关掉垂直同步：开启时 swap_buffers 的等待会被算进 TIME_PROCESS，
    # 60fps 下会稳定读出 16~20ms 的假 CPU 耗时，必须关掉才看得到真实成本。
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

    _label = Label.new()
    # 贴底居中：左上角是玩家血条卡片，探针压上去会挡血量与金币。
    _label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    _label.offset_top = -24.0
    _label.offset_bottom = -4.0
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.add_theme_font_size_override("font_size", 12)
    _label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.92))
    _label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
    _label.add_theme_constant_override("outline_size", 4)
    _label.text = "perf: 采样中…"
    add_child(_label)

    _log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
    if _log != null:
        _log.store_line("t_ms,fps,frame_ms,process_ms,physics_ms,nodes,objects,orphans,static_mb")
        _log.flush()

    # 启动首帧钉死三件事：实际光栅尺寸 / stretch 模式 / draw_calls 监视器是否可用。
    print("[perf] window=", DisplayServer.window_get_size(),
        " viewport=", get_viewport().get_visible_rect().size,
        " content_scale_factor=", get_window().content_scale_factor,
        " stretch_mode=", ProjectSettings.get_setting("display/window/stretch/mode"),
        " stretch_aspect=", ProjectSettings.get_setting("display/window/stretch/aspect"))
    print("[perf] draw_calls_monitor=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
        "  (若恒为 0 说明本后端不支持，只能用遮挡二分法)")
    print("[perf] vsync=", DisplayServer.window_get_vsync_mode(),
        " (0=disabled，已强制关闭以保证 TIME_PROCESS 只反映 CPU)",
        " time_scale=", Engine.time_scale,
        " (非 1.0 时 TIME_PHYSICS_PROCESS 需按倍数折算)")
    print("[perf] log -> ", ProjectSettings.globalize_path(LOG_PATH))

func _process(_delta: float) -> void:
    # 用墙上时钟而不是 delta 计时：--playtest 会把 Engine.time_scale 设成 3.0，
    # 此时 delta 与 Engine.get_frames_per_second() 都被放大 3 倍，只有
    # Time.get_ticks_usec() 的差值不受影响。采样间隔也按真实 0.5s 走。
    var now_us := Time.get_ticks_usec()
    _frames += 1
    if _last_us == 0:
        _last_us = now_us
        return
    var elapsed := float(now_us - _last_us) / 1000000.0
    if elapsed < SAMPLE_INTERVAL:
        return

    var count := _frames
    var fps := float(count) / maxf(0.0001, elapsed)
    _frames = 0
    _last_us = now_us

    var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
    var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
    var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
    var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
    var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
    var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0

    # 帧预算按真实帧时判断（1/60 = 16.67ms），比 TIME_PROCESS 可靠
    var frame_ms := elapsed * 1000.0 / maxf(1.0, float(count))
    var budget_color := Color(0.62, 0.9, 0.72)
    if frame_ms > 16.67:
        budget_color = Color(0.95, 0.84, 0.45)
    if frame_ms > 25.0:
        budget_color = Color(0.95, 0.52, 0.45)
    _label.add_theme_color_override("font_color", budget_color)

    # 孤儿节点必须恒为 0，>0 即泄漏（池化改造后重点看这一项）
    var orphan_flag := " ORPHAN!" if orphans > 0 else ""
    _label.text = "FPS %d | proc %.1fms | phys %.1fms | nodes %d | obj %d | %.1fMB%s" % [
        int(round(fps)), process_ms, physics_ms, nodes, objects, static_mb, orphan_flag,
    ]

    _samples += 1
    if _log != null:
        _log.store_line("%d,%d,%.3f,%.3f,%.3f,%d,%d,%d,%.2f" % [
            Time.get_ticks_msec(), int(round(fps)), frame_ms, process_ms, physics_ms,
            nodes, objects, orphans, static_mb,
        ])
        _log.flush()
        if _samples % 20 == 0:
            print("[perf] %d samples  fps=%d process=%.2fms nodes=%d" % [_samples, int(round(fps)), process_ms, nodes])

func _exit_tree() -> void:
    if _log != null:
        _log.flush()
        _log = null
