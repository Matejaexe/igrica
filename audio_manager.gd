extends Node

signal volume_changed(bus_name, linear_value)
signal music_track_changed(track_id, display_name, pool_name)

const CROSSFADE_SECONDS = 1.5
const SILENT_DB = -60.0

# Named pools keep selection separate from playback. Future zone code can add
# MDK3, JERKOVIC, MLD, PANCEVO, and BOSS without changing the shuffle logic.
const MUSIC_POOLS = {
    "default": [
        {
            "id": "04_rooftop_static",
            "display_name": "Rooftop Static",
            "stream": preload("res://audio/music/04_rooftop_static.wav")
        },
        {
            "id": "05_highrise_rush",
            "display_name": "Highrise Rush",
            "stream": preload("res://audio/music/05_highrise_rush.wav")
        },
        {
            "id": "06_factory_pressure",
            "display_name": "Factory Pressure",
            "stream": preload("res://audio/music/06_factory_pressure.wav")
        },
        {
            "id": "07_concrete_tricks",
            "display_name": "Concrete Tricks",
            "stream": preload("res://audio/music/07_concrete_tricks.wav")
        },
        {
            "id": "08_redline_pursuit",
            "display_name": "Redline Pursuit",
            "stream": preload("res://audio/music/08_redline_pursuit.wav")
        }
    ],
    "legacy": [
        {
            "id": "01_concrete_canopy",
            "display_name": "Concrete Canopy",
            "stream": preload("res://audio/music/01_concrete_canopy.wav")
        },
        {
            "id": "02_neon_underpass",
            "display_name": "Neon Underpass",
            "stream": preload("res://audio/music/02_neon_underpass.wav")
        },
        {
            "id": "03_bridge_velocity",
            "display_name": "Bridge Velocity",
            "stream": preload("res://audio/music/03_bridge_velocity.wav")
        }
    ]
}

var music_players: Array[AudioStreamPlayer] = []
var active_player_index := 0
var incoming_player_index := 1
var active_pool_name := ""
var shuffle_bag: Array[int] = []
var current_track: Dictionary = {}
var last_track_id := ""
var crossfade_active := false
var crossfade_elapsed := 0.0

func _ready():
    _ensure_bus("Music")
    _ensure_bus("SFX")
    _load_audio_settings()
    _build_music_players()
    set_music_pool("default")

func _process(delta):
    if music_players.is_empty():
        return

    if crossfade_active:
        _update_crossfade(delta)
        return

    var active_player = music_players[active_player_index]
    if not active_player.playing or active_player.stream == null:
        return

    var remaining = active_player.stream.get_length() - active_player.get_playback_position()
    if remaining > 0.0 and remaining <= CROSSFADE_SECONDS:
        _play_next_track(true)

func _build_music_players():
    for index in range(2):
        var player = AudioStreamPlayer.new()
        player.name = "MusicPlayer%d" % (index + 1)
        player.bus = "Music"
        player.volume_db = 0.0
        player.finished.connect(_on_music_player_finished.bind(index))
        add_child(player)
        music_players.append(player)

func set_music_pool(pool_name: String) -> bool:
    if not MUSIC_POOLS.has(pool_name):
        push_warning("Unknown music pool: %s" % pool_name)
        return false
    if active_pool_name == pool_name and not current_track.is_empty():
        return true

    active_pool_name = pool_name
    shuffle_bag.clear()
    if current_track.is_empty():
        _play_next_track(false)
    else:
        _play_next_track(true)
    return true

func get_current_track_metadata() -> Dictionary:
    return current_track.duplicate()

func get_active_music_pool() -> String:
    return active_pool_name

func _play_next_track(use_crossfade: bool):
    var track = _take_track_from_shuffle_bag()
    if track.is_empty():
        return

    var target_index = 1 - active_player_index
    var target_player = music_players[target_index]
    target_player.stop()
    target_player.stream = track["stream"]
    target_player.volume_db = SILENT_DB if use_crossfade else 0.0
    target_player.play()

    current_track = track
    last_track_id = String(track["id"])
    music_track_changed.emit(track["id"], track["display_name"], active_pool_name)

    if use_crossfade and music_players[active_player_index].playing:
        incoming_player_index = target_index
        crossfade_elapsed = 0.0
        crossfade_active = true
    else:
        music_players[active_player_index].stop()
        music_players[active_player_index].volume_db = 0.0
        target_player.volume_db = 0.0
        active_player_index = target_index

func _take_track_from_shuffle_bag() -> Dictionary:
    var pool: Array = MUSIC_POOLS.get(active_pool_name, [])
    if pool.is_empty():
        return {}
    if shuffle_bag.is_empty():
        _rebuild_shuffle_bag(pool)
    if shuffle_bag.is_empty():
        return {}
    return pool[shuffle_bag.pop_back()]

func _rebuild_shuffle_bag(pool: Array):
    shuffle_bag.clear()
    for index in range(pool.size()):
        shuffle_bag.append(index)
    shuffle_bag.shuffle()

    # pop_back() is next. Swap it when a new cycle would immediately repeat
    # the track that ended the previous cycle.
    if pool.size() > 1 and String(pool[shuffle_bag.back()]["id"]) == last_track_id:
        var swap_index = 0
        var last_index = shuffle_bag.size() - 1
        var temporary = shuffle_bag[last_index]
        shuffle_bag[last_index] = shuffle_bag[swap_index]
        shuffle_bag[swap_index] = temporary

func _update_crossfade(delta):
    crossfade_elapsed += delta
    var blend = clamp(crossfade_elapsed / CROSSFADE_SECONDS, 0.0, 1.0)
    var outgoing_player = music_players[active_player_index]
    var incoming_player = music_players[incoming_player_index]
    outgoing_player.volume_db = linear_to_db(max(1.0 - blend, 0.001))
    incoming_player.volume_db = linear_to_db(max(blend, 0.001))

    if blend >= 1.0:
        outgoing_player.stop()
        outgoing_player.volume_db = 0.0
        incoming_player.volume_db = 0.0
        active_player_index = incoming_player_index
        crossfade_active = false
        crossfade_elapsed = 0.0

func _on_music_player_finished(player_index: int):
    if crossfade_active or player_index != active_player_index:
        return
    _play_next_track(true)

func _ensure_bus(bus_name: String):
    if AudioServer.get_bus_index(bus_name) == -1:
        AudioServer.add_bus(AudioServer.bus_count)
        AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func set_volume(bus_name: String, linear_value: float):
    var idx = AudioServer.get_bus_index(bus_name)
    if idx == -1:
        return
    var value = clamp(linear_value, 0.0, 1.0)
    AudioServer.set_bus_mute(idx, value <= 0.001)
    if value > 0.001:
        AudioServer.set_bus_volume_db(idx, linear_to_db(value))
    volume_changed.emit(bus_name, value)
    _save_audio_settings()

func get_volume(bus_name: String) -> float:
    var idx = AudioServer.get_bus_index(bus_name)
    if idx == -1:
        return 1.0
    if AudioServer.is_bus_mute(idx):
        return 0.0
    return db_to_linear(AudioServer.get_bus_volume_db(idx))

func _load_audio_settings():
    var cfg = ConfigFile.new()
    if cfg.load("user://audio_settings.cfg") != OK:
        set_volume("Master", 0.85)
        set_volume("Music", 0.72)
        set_volume("SFX", 0.85)
        return
    _apply_saved("Master", float(cfg.get_value("audio", "master", 0.85)))
    _apply_saved("Music", float(cfg.get_value("audio", "music", 0.72)))
    _apply_saved("SFX", float(cfg.get_value("audio", "sfx", 0.85)))

func _apply_saved(bus_name: String, value: float):
    var idx = AudioServer.get_bus_index(bus_name)
    if idx == -1:
        return
    AudioServer.set_bus_mute(idx, value <= 0.001)
    if value > 0.001:
        AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(value, 0.001, 1.0)))

func _save_audio_settings():
    var cfg = ConfigFile.new()
    cfg.set_value("audio", "master", get_volume("Master"))
    cfg.set_value("audio", "music", get_volume("Music"))
    cfg.set_value("audio", "sfx", get_volume("SFX"))
    cfg.save("user://audio_settings.cfg")
