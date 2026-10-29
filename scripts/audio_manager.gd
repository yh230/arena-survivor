extends Node

const SOUNDS := {
    "shoot": preload("res://assets/audio/shoot.wav"),
    "hit": preload("res://assets/audio/hit.wav"),
    "enemy_die": preload("res://assets/audio/enemy_die.wav"),
    "hurt": preload("res://assets/audio/hurt.wav"),
    "dash": preload("res://assets/audio/dash.wav"),
    "wave_start": preload("res://assets/audio/wave_start.wav"),
    "upgrade": preload("res://assets/audio/upgrade.wav"),
    "victory": preload("res://assets/audio/victory.wav"),
    "game_over": preload("res://assets/audio/game_over.wav"),
    "boss_spawn": preload("res://assets/audio/boss_spawn.wav"),
    "boss_die": preload("res://assets/audio/boss_die.wav"),
    "turret": preload("res://assets/audio/turret.wav"),
    "chain": preload("res://assets/audio/chain.wav"),
    "pierce": preload("res://assets/audio/pierce.wav"),
    "enemy_shot": preload("res://assets/audio/enemy_shot.wav"),
    "explode": preload("res://assets/audio/explode.wav"),
    "orbiter": preload("res://assets/audio/orbiter.wav"),
}
const POOL_SIZE := 12
## 命中/击杀是全场最高频的两条音轨，固定 pitch 会听出"循环播放"的机械感。
## ±8% 随机 pitch 只在每次播放时抖动，不新增音频文件、不改音量。
const PITCH_JITTER := 0.08
const PITCH_JITTER_SOUNDS := ["hit", "enemy_die"]

var _players: Array[AudioStreamPlayer] = []
var _next_index := 0
var _last_player: AudioStreamPlayer = null
var _last_played_at := {}
var _feel_hub: Node = null

func _ready() -> void:
    for _index in range(POOL_SIZE):
        var player := AudioStreamPlayer.new()
        add_child(player)
        _players.append(player)

func play(sound_name: String, volume_db := -8.0) -> void:
    if not SOUNDS.has(sound_name):
        return
    var player := _players[_next_index]
    _next_index = (_next_index + 1) % _players.size()
    player.stream = SOUNDS[sound_name]
    player.volume_db = volume_db
    player.pitch_scale = _pitch_for(sound_name)
    player.play()
    _last_player = player

func _pitch_for(sound_name: String) -> float:
    if not PITCH_JITTER_SOUNDS.has(sound_name):
        return 1.0
    if _feel_hub == null:
        _feel_hub = get_node_or_null("/root/Hitstop")
    var jitter := PITCH_JITTER
    if _feel_hub != null and _feel_hub.has_method("feel"):
        jitter = float(_feel_hub.feel("audio", "pitch_jitter", PITCH_JITTER))
    return 1.0 + randf_range(-jitter, jitter)

func play_limited(sound_name: String, volume_db := -8.0, min_interval := 0.07) -> void:
    var now := float(Time.get_ticks_msec()) / 1000.0
    if now - float(_last_played_at.get(sound_name, -100.0)) < min_interval:
        return
    _last_played_at[sound_name] = now
    play(sound_name, volume_db)

func has_sound(sound_name: String) -> bool:
    return SOUNDS.has(sound_name)

func get_sound_names() -> Array:
    return SOUNDS.keys()

func is_last_playing() -> bool:
    return _last_player != null and _last_player.playing
