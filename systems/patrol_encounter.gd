extends Node3D
const DRONE = preload("res://drone.gd")
var city: Node3D
var player: CharacterBody3D
var running = false
var status = ""
var wave = 0
var remaining = 0
var elapsed = 0.0
var intermission = 0.0
var xp = 0
var victories = 0
var best = 0.0
var arena = Vector3.ZERO
var previous_spawn = Vector3.ZERO
var actors: Array[Node] = []

func setup(owner_city: Node3D):
    city = owner_city
    player = city.player
    name = "PatrolEncounter"
    player.player_died.connect(_on_player_died)
    var save = ConfigFile.new()
    if save.load("user://patrol_progress.cfg") == OK:
        xp = int(save.get_value("progress","xp",0))
        victories = int(save.get_value("progress","victories",0))
        best = float(save.get_value("progress","best",0.0))

func toggle():
    if running:
        cancel("Patrol cancelled / C: retry")
        return
    if is_instance_valid(city.skyline_challenge) and city.skyline_challenge.running:
        city.skyline_challenge.toggle()
    previous_spawn = player.spawn_position
    arena = city.skyline_challenge.launch
    player._respawn(false)
    player.position = arena
    player.set_spawn_position(arena)
    player.yaw = 0
    wave = 0
    elapsed = 0
    running = true
    _spawn_wave()

func _spawn_wave():
    wave += 1
    remaining = wave+1
    for i in remaining:
        var drone = DRONE.new()
        var angle = TAU*float(i)/remaining+wave*.35
        drone.position = arena+Vector3(cos(angle)*7,1,sin(angle)*7)
        drone.health = 4 if wave == 3 else 2
        drone.attack_cooldown = .3+float(i)*.35
        add_child(drone)
        actors.append(drone)
        drone.set_target(player)
        drone.defeated.connect(_on_defeated)
    status = "WAVE %d/3 · %d DRONES / J,K attack · Alt evade" % [wave,remaining]

func _on_defeated(drone):
    if not running or not actors.has(drone): return
    actors.erase(drone)
    remaining -= 1
    if remaining > 0: return
    if wave < 3:
        intermission = 1.4
        status = "Wave cleared / next wave incoming"
        return
    running = false
    player.set_spawn_position(previous_spawn)
    player.heal_full()
    xp += 150
    victories += 1
    if best == 0 or elapsed < best: best = elapsed
    var save = ConfigFile.new()
    save.set_value("progress","xp",xp)
    save.set_value("progress","victories",victories)
    save.set_value("progress","best",best)
    save.save("user://patrol_progress.cfg")
    status = "PATROL CLEAR · +150 XP · %.1fs / C: replay" % elapsed

func _process(delta):
    if not is_instance_valid(city): return
    if city.game_state != "playing" or city.mission != 0:
        if running: cancel("")
        return
    if Input.is_action_just_pressed("patrol"): toggle()
    if not running: return
    elapsed += delta
    if player.position.distance_to(arena) > 90:
        cancel("Left patrol area / C: retry")
        return
    if intermission > 0:
        intermission = maxf(0,intermission-delta)
        if intermission == 0: _spawn_wave()
    elif remaining > 0:
        status = "WAVE %d/3 · %d DRONES · %.1fs / Alt evade" % [wave,remaining,elapsed]

func cancel(message: String):
    running = false
    intermission = 0
    player.set_spawn_position(previous_spawn)
    for actor in actors:
        if is_instance_valid(actor): actor.queue_free()
    actors.clear()
    remaining = 0
    status = message

func _on_player_died():
    if running: cancel("Patrol failed / C: retry")
