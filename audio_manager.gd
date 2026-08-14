extends Node

signal volume_changed(bus_name, linear_value)

var music_player: AudioStreamPlayer = null
var playlist = [
    preload("res://audio/music/01_concrete_canopy.wav"),
    preload("res://audio/music/02_neon_underpass.wav"),
    preload("res://audio/music/03_bridge_velocity.wav")
]
var current_track := 0

func _ready():
    _ensure_bus("Music")
    _ensure_bus("SFX")
    _load_audio_settings()

    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.bus = "Music"
    add_child(music_player)
    music_player.finished.connect(_play_next)
    play_music(0)

func _ensure_bus(bus_name: String):
    if AudioServer.get_bus_index(bus_name) == -1:
        AudioServer.add_bus(AudioServer.bus_count)
        AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func play_music(index: int):
    if playlist.is_empty():
        return
    current_track = posmod(index, playlist.size())
    music_player.stream = playlist[current_track]
    music_player.play()

func _play_next():
    play_music(current_track + 1)

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
