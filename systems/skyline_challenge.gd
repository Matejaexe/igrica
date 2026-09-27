extends Node3D
var city: Node3D
var player: CharacterBody3D
var running = false
var completed = false
var elapsed = 0.0
var index = 0
var best = 0.0
var points: Array[Vector3] = []
var rings: Array[MeshInstance3D] = []
var launch = Vector3.ZERO
var previous_spawn = Vector3.ZERO
var status = "H: SKYLINE FLIGHT / E: glide / Ctrl: dive"

func setup(owner_city: Node3D):
    city = owner_city
    player = city.player
    name = "SkylineChallenge"
    var saved = ConfigFile.new()
    if saved.load("user://skyline_challenge.cfg") == OK:
        best = float(saved.get_value("route","best",0.0))
    var space = get_world_3d().direct_space_state
    # Attach the launch deck to a real nearby rooftop instead of suspending
    # a collision platform in empty air.
    var launch_score = -INF
    for building in get_tree().get_nodes_in_group("city_building"):
        if Vector2(building.position.x,building.position.z).length() > 180: continue
        for child in building.get_children():
            if child is CollisionShape3D and child.shape is BoxShape3D:
                var roof_y = building.position.y+child.shape.size.y*.5
                var score = roof_y-Vector2(building.position.x,building.position.z).length()*.2
                if score > launch_score:
                    launch_score = score
                    launch = Vector3(building.position.x,roof_y+2,building.position.z-child.shape.size.z*.5+2)
    if launch_score == -INF: launch = Vector3(0,20,20)
    var platform = StaticBody3D.new()
    platform.position = launch-Vector3.UP*1.8
    var mesh = BoxMesh.new()
    mesh.size = Vector3(12,.6,16)
    var visual = MeshInstance3D.new()
    visual.mesh = mesh
    var material = StandardMaterial3D.new()
    material.albedo_color = Color("263a51")
    visual.material_override = material
    platform.add_child(visual)
    var collider = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = mesh.size
    collider.shape = box
    platform.add_child(collider)
    add_child(platform)
    for p in [Vector3(0,-6,-25),Vector3(0,-13,-80),Vector3(0,-23,-140),Vector3(45,-33,-185),Vector3(90,-43,-185),Vector3(115,-56,-135),Vector3(115,-72,-70)]:
        var point = launch+Vector3(p.x,p.y,p.z-20)
        var surface = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,350,point.z),Vector3(point.x,0,point.z),1,[player.get_rid()]))
        if not surface.is_empty(): point.y = maxf(point.y,surface.position.y+8)
        points.append(point)
        var ring = MeshInstance3D.new()
        var torus = TorusMesh.new()
        torus.inner_radius = 4.5
        torus.outer_radius = 4.8
        torus.rings = 24
        torus.ring_segments = 8
        ring.mesh = torus
        ring.position = point
        ring.rotation.x = PI/2
        var glow = StandardMaterial3D.new()
        glow.albedo_color = Color("55d8e7")
        glow.emission_enabled = true
        glow.emission = glow.albedo_color
        glow.emission_energy_multiplier = 1.6
        ring.material_override = glow
        add_child(ring)
        rings.append(ring)
    _hide_gates()

func toggle():
    if running:
        player.set_spawn_position(previous_spawn)
        running = false
        status = "Route cancelled / H: restart"
        _hide_gates()
        return
    if is_instance_valid(city.get("patrol")):
        if city.patrol.running: city.patrol.cancel("")
        city.patrol.status = ""
    running = true
    completed = false
    elapsed = 0
    index = 0
    previous_spawn = player.spawn_position
    player._respawn(false)
    player.position = launch
    player.set_spawn_position(launch)
    player.yaw = 0
    player.pitch = -.10
    show()
    _refresh_rings()

func _process(delta):
    if not is_instance_valid(city) or city.game_state != "playing" or city.mission != 0:
        return
    if Input.is_action_just_pressed("skyline_challenge"): toggle()
    if not running: return
    elapsed += delta
    var distance = player.position.distance_to(points[index])
    status = "GATE %d/7 · %dm · %.1fs / H: cancel" % [index+1,int(distance),elapsed]
    if distance < 5.2:
        index += 1
        if index == points.size():
            running = false
            completed = true
            player.set_spawn_position(previous_spawn)
            var medal = "GOLD" if elapsed < 35 else ("SILVER" if elapsed < 55 else "BRONZE")
            if best == 0 or elapsed < best:
                best = elapsed
                var save = ConfigFile.new()
                save.set_value("route","best",best)
                save.save("user://skyline_challenge.cfg")
            status = "%s / %.1fs · BEST %.1fs / H: replay" % [medal,elapsed,best]
            _hide_gates()
        else:
            _refresh_rings()

func _refresh_rings():
    for i in rings.size():
        rings[i].visible = i >= index and i <= index+1
        rings[i].scale = Vector3.ONE*(1.0 if i == index else .65)

func _hide_gates():
    for ring in rings: ring.hide()
