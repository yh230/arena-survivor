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

var _players: Array[AudioStreamPlayer] = []
var _next_index := 0
var _last_player: AudioStreamPlayer = null

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
    player.play()
    _last_player = player

func has_sound(sound_name: String) -> bool:
    return SOUNDS.has(sound_name)

func get_sound_names() -> Array:
    return SOUNDS.keys()

func is_last_playing() -> bool:
    return _last_player != null and _last_player.playing
