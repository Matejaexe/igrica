extends Node

const WEB_SHOT = preload("res://audio/sfx/web_shot.wav")
const WEB_RELEASE = preload("res://audio/sfx/web_release.wav")
const ZIP_BURST = preload("res://audio/sfx/zip_burst.wav")
const WALL_RIDE = preload("res://audio/sfx/wall_ride.wav")
const ATTACK_SWING = preload("res://audio/sfx/attack_swing.wav")
const SPECIAL_BURST = preload("res://audio/sfx/special_burst.wav")
const LAND_THUMP = preload("res://audio/sfx/land_thump.wav")
const SPEED_WIND = preload("res://audio/sfx/speed_wind_loop.wav")

var player: CharacterBody3D
var one_shots: Array[AudioStreamPlayer3D] = []
var wind_player: AudioStreamPlayer3D

var was_grappling := false
var previous_state := ""
var was_on_floor := false
var previous_vertical_speed := 0.0

func _ready() -> void:
    player = get_parent() as CharacterBody3D
    if player == null:
        set_process(false)
        return

    for i in range(4):
        var voice := AudioStreamPlayer3D.new()
        voice.name = "SFXVoice%d" % (i + 1)
        voice.bus = "SFX"
        voice.max_distance = 55.0
        voice.unit_size = 8.0
        add_child(voice)
        one_shots.append(voice)

    wind_player = AudioStreamPlayer3D.new()
    wind_player.name = "SpeedWind"
    wind_player.bus = "SFX"
    wind_player.max_distance = 30.0
    wind_player.unit_size = 6.0
    var wind_stream = SPEED_WIND.duplicate()
    if wind_stream is AudioStreamWAV:
        wind_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    wind_player.stream = wind_stream
    wind_player.volume_db = -45.0
    add_child(wind_player)
    wind_player.play()

    was_grappling = bool(player.get("grappling"))
    previous_state = _state_name()
    was_on_floor = player.is_on_floor()

func _process(delta: float) -> void:
    if player == null:
        return

    var grappling := bool(player.get("grappling"))
    if grappling and not was_grappling:
        _play(WEB_SHOT, -2.5, 1.0 + randf_range(-0.04, 0.04))
    elif was_grappling and not grappling:
        _play(WEB_RELEASE, -5.0, 1.0 + randf_range(-0.05, 0.05))
    was_grappling = grappling

    var state := _state_name()
    if state != previous_state:
        if state == "ZIP":
            _play(ZIP_BURST, -1.5, 1.0)
        elif state == "WALL RIDE":
            _play(WALL_RIDE, -4.0, 1.0 + randf_range(-0.05, 0.05))
    previous_state = state

    if Input.is_action_just_pressed("attack"):
        _play(ATTACK_SWING, -6.0, randf_range(0.94, 1.08))
    if Input.is_action_just_pressed("special_attack"):
        _play(SPECIAL_BURST, -3.0, randf_range(0.94, 1.04))

    var on_floor := player.is_on_floor()
    if on_floor and not was_on_floor and previous_vertical_speed < -8.0:
        var strength: float = clampf(abs(previous_vertical_speed) / 24.0, 0.35, 1.0)
        _play(LAND_THUMP, lerp(-10.0, -2.0, strength), lerp(1.08, 0.88, strength))
    was_on_floor = on_floor
    previous_vertical_speed = player.velocity.y

    var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
    var wind_amount: float = clampf((horizontal_speed - 13.0) / 25.0, 0.0, 1.0)
    var target_db: float = lerpf(-45.0, -11.0, wind_amount)
    wind_player.volume_db = lerp(wind_player.volume_db, target_db, min(1.0, delta * 5.0))
    wind_player.pitch_scale = lerp(0.88, 1.16, wind_amount)

func _state_name() -> String:
    if player != null and player.has_method("get_movement_state_name"):
        return String(player.get_movement_state_name())
    return ""

func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
    var voice: AudioStreamPlayer3D = one_shots[0]
    for candidate in one_shots:
        if not candidate.playing:
            voice = candidate
            break
    voice.stop()
    voice.stream = stream
    voice.volume_db = volume_db
    voice.pitch_scale = pitch
    voice.play()
