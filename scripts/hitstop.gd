extends Node

## 打击停顿（hitstop）：用 Engine.time_scale 做极短的全局时间塌缩。
##
## 为什么选 autoload 而不是场景内单例：
## 触发者分散在 player / hero_grenade / weapon_manager / main（击杀结算）四个互不继承的节点上，
## 场景内单例要么得靠 node path 硬绑、要么得靠 signal 中转；而本局会来回切 stage / 商店 / 重开，
## 场景级节点会被 queue_free 掉，time_scale 一旦在切换瞬间被冻结就再也没人恢复（倍率泄漏）。
## autoload 与场景生命周期解耦，是唯一能保证"谁都能调用、谁都拆不掉"的持有者。
##
## 安全约束：
## 1. 单飞（单例状态机）：同一时刻只允许一个 hitstop，运行期间的新请求直接丢弃，禁止嵌套。
## 2. 用 ignore_time_scale=true 的 SceneTreeTimer 恢复，恢复时间用挂钟计量，不受自己塌缩影响。
## 3. 另有挂钟看门狗兜底：计时器若因任何原因没回调，也在 deadline + 50ms 内强制归位。
## 4. 测试/回放模式（--smoke-test / --playtest / --screenshot）完全禁用；
##    触发前若 Engine.time_scale 已不是 1.0，说明外部（playtest bot）接管了时间，立刻自锁禁用。

const FEEL_PATH := "res://data/feel.json"

## 缺文件/缺字段时的内置默认值，与 data/feel.json 保持一致。
const DEFAULT_FEEL := {
	"hitstop": {
		"enabled": true,
		"scale": 0.08,
		"grenade_blast_ms": 45.0,
		"hammer_hit_ms": 25.0,
		"player_hit_ms": 30.0,
		"kill_ms": 15.0,
		"min_interval_ms": 120.0,
		"budget_window_ms": 1000.0,
		"budget_max_ms": 90.0,
	},
	"audio": {
		"pitch_jitter": 0.08,
		"pitch_jitter_sounds": ["hit", "enemy_die"],
	},
	"blast": {
		"layer_min_hits": 3,
		"layer_ring_scale": 1.35,
		"layer_ring_life": 0.95,
		"layer_ring_width": 1.6,
		"zoom_pulse": 0.02,
		"zoom_pulse_ms": 120.0,
	},
}

## kind -> feel.json 里的毫秒字段
const DURATION_KEYS := {
	"grenade_blast": "grenade_blast_ms",
	"hammer_hit": "hammer_hit_ms",
	"player_hit": "player_hit_ms",
	"kill": "kill_ms",
}

var enabled := true
var disabled_reason := ""

var _feel: Dictionary = {}
var _active := false
var _restore_scale := 1.0
var _guard_at_ms := 0.0
var _guard_ms := 0.0
var _log: Array = []
var _last_stop_at_ms := -1.0e9
var _granted := 0
var _skipped_nested := 0
var _skipped_budget := 0
var _skipped_rate := 0

func _ready() -> void:
	_feel = _load_feel()
	var args := _cmdline_args()
	if args.has("--smoke-test") or args.has("--playtest") or args.has("--screenshot"):
		_disable("test_mode")
	elif not bool(feel("hitstop", "enabled", true)):
		_disable("config_disabled")
	elif not is_equal_approx(Engine.time_scale, 1.0):
		_disable("time_scale_preset")
	if disabled_reason != "":
		# 一行启动留痕：--playtest / --smoke-test 的证据就是这行。
		print("HITSTOP_STATE enabled=false reason=%s" % disabled_reason)

func _cmdline_args() -> Array:
	# Godot 只把 `--` 之后的参数放进 user_args，CI 习惯直接写 --smoke-test，两边都认。
	var args := OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_args():
		if arg == "--smoke-test" or arg == "--playtest" or arg == "--screenshot" or arg == "--perf":
			if not args.has(arg):
				args.append(arg)
	return args

func _disable(reason: String) -> void:
	if not enabled:
		return
	enabled = false
	disabled_reason = reason
	if _active:
		_restore()

func is_enabled() -> bool:
	return enabled

## 供其它模块读取同一份配置（音频抖音、爆炸分层都用这里，避免重复解析 json）。
func feel(section: String, key: String, fallback):
	var bucket = _feel.get(section, {})
	if bucket is Dictionary and bucket.has(key):
		return bucket[key]
	return fallback

## 返回实际授予的毫秒数；0 表示未生效（禁用/嵌套/超预算/超频）。
func request(kind: String) -> float:
	if not enabled:
		return 0.0
	if _active:
		_skipped_nested += 1
		return 0.0
	# 外部已经把时间轴拉离 1.0（playtest bot），此后永久不接管。
	if not is_equal_approx(Engine.time_scale, 1.0):
		_disable("time_scale_not_unity")
		return 0.0

	var duration_ms := _duration_for(kind)
	if duration_ms <= 0.0:
		return 0.0

	var now_ms := float(Time.get_ticks_msec())
	# 最小间隔对"任意来源"生效，而不只是击杀：45ms 的爆炸刚落，紧接着的重锤
	# 或补刀会首尾相接连成一段可见的卡顿带，读起来像掉帧而不是顿帧。
	var min_interval := maxf(0.0, float(feel("hitstop", "min_interval_ms", 120.0)))
	if now_ms - _last_stop_at_ms < min_interval:
		_skipped_rate += 1
		return 0.0
	_last_stop_at_ms = now_ms

	var window_ms := maxf(1.0, float(feel("hitstop", "budget_window_ms", 1000.0)))
	var budget_ms := maxf(0.0, float(feel("hitstop", "budget_max_ms", 90.0)))
	var used_ms := 0.0
	var kept: Array = []
	for entry in _log:
		if now_ms - float(entry["at"]) <= window_ms:
			kept.append(entry)
			used_ms += float(entry["ms"])
	_log = kept
	if used_ms + duration_ms > budget_ms:
		_skipped_budget += 1
		return 0.0

	_log.append({"at": now_ms, "ms": duration_ms})
	_granted += 1
	_active = true
	_restore_scale = Engine.time_scale
	_guard_at_ms = now_ms
	_guard_ms = duration_ms
	Engine.time_scale = clampf(float(feel("hitstop", "scale", 0.08)), 0.0, 1.0)

	# 关键：ignore_time_scale=true，否则计时器会被自己压慢，恢复时间被拉长几倍。
	var timer := get_tree().create_timer(duration_ms / 1000.0, true, false, true)
	timer.timeout.connect(_restore, CONNECT_ONE_SHOT)
	return duration_ms

func _duration_for(kind: String) -> float:
	if not DURATION_KEYS.has(kind):
		return 0.0
	return maxf(0.0, float(feel("hitstop", str(DURATION_KEYS[kind]), 0.0)))

func _restore() -> void:
	if not _active:
		return
	_active = false
	_guard_ms = 0.0
	Engine.time_scale = _restore_scale if _restore_scale > 0.0 else 1.0

func _process(_delta: float) -> void:
	# 看门狗：计时器万一没回调（节点被移出树、树被暂停等），按挂钟强制归位，绝不泄漏倍率。
	if not _active or _guard_ms <= 0.0:
		return
	var elapsed_ms := float(Time.get_ticks_msec()) - _guard_at_ms
	if elapsed_ms >= _guard_ms + 50.0:
		push_warning("Hitstop 恢复超时（%.1fms），强制归位 time_scale" % elapsed_ms)
		_restore()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _active:
		Engine.time_scale = _restore_scale if _restore_scale > 0.0 else 1.0

func get_stats() -> Dictionary:
	return {
		"enabled": enabled,
		"reason": disabled_reason,
		"granted": _granted,
		"skipped_nested": _skipped_nested,
		"skipped_budget": _skipped_budget,
		"skipped_rate": _skipped_rate,
		"time_scale": Engine.time_scale,
	}

func _load_feel() -> Dictionary:
	var merged := DEFAULT_FEEL.duplicate(true)
	if not FileAccess.file_exists(FEEL_PATH):
		return merged
	var text := FileAccess.get_file_as_string(FEEL_PATH)
	if text.strip_edges() == "":
		return merged
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("data/feel.json 解析失败，回退内置默认值")
		return merged
	var data: Dictionary = parsed
	for section in data.keys():
		var value = data[section]
		if value is Dictionary and merged.get(section) is Dictionary:
			var bucket: Dictionary = merged[section]
			for key in value.keys():
				bucket[key] = value[key]
		else:
			merged[section] = value
	return merged
