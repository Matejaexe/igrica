extends SceneTree
var players = []
var floors = []
var floor_meshes = []
var label: Label
func _initialize(): call_deferred("run")
func make_view(index: int):
    var view = SubViewport.new()
    view.size = Vector2i(426,620)
    view.own_world_3d = true
    view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var display = TextureRect.new()
    display.texture = view.get_texture()
    display.position = Vector2(index*426,80)
    display.size = Vector2(426,620)
    root.add_child(display)
    var world = Node3D.new()
    view.add_child(world)
    var env = WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color("233443")
    env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color = Color("e3edf7")
    env.environment.ambient_light_energy = .7
    world.add_child(env)
    var light = DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-35,-35,0)
    light.light_energy = 1.5
    light.shadow_enabled = true
    world.add_child(light)
    var floor_mesh = MeshInstance3D.new()
    floor_mesh.mesh = PlaneMesh.new()
    floor_mesh.mesh.size = Vector2(12,12)
    var material = StandardMaterial3D.new()
    material.albedo_color = Color("586575")
    floor_mesh.material_override = material
    world.add_child(floor_mesh)
    floor_meshes.append(floor_mesh)
    var floor_body = StaticBody3D.new()
    var shape = CollisionShape3D.new()
    shape.shape = BoxShape3D.new()
    shape.shape.size = Vector3(12,.2,12)
    shape.position.y = -.1
    floor_body.add_child(shape)
    world.add_child(floor_body)
    floors.append(floor_body)
    var player = preload("res://player.gd").new()
    player.position.y = 1.44
    world.add_child(player)
    player.set_physics_process(false)
    player.animation_driver.set_process(false)
    player.visual_root.rotation = Vector3.ZERO
    player.animation_driver.swing_modifier.set_active(false)
    players.append(player)
    var cam = Camera3D.new()
    world.add_child(cam)
    cam.position = [Vector3(0,2.0,-6.6),Vector3(6.6,2.0,0),Vector3(4.8,2.0,-4.8)][index]
    cam.look_at(Vector3(0,1.4,0))
    cam.fov = 39
    cam.current = true
    var angle_label = Label.new()
    angle_label.text = ["FRONT","SIDE","THREE-QUARTER"][index]
    angle_label.position = Vector2(index*426+20,55)
    angle_label.add_theme_font_size_override("font_size",18)
    root.add_child(angle_label)
func run():
    Engine.max_fps = 30
    preload("res://input_bindings.gd").setup()
    for i in 3: make_view(i)
    label = Label.new()
    label.position = Vector2(20,15)
    label.add_theme_font_size_override("font_size",25)
    root.add_child(label)
    var output = OS.get_environment("SPIDER_CAPTURE_DIR")
    if output.is_empty():
        push_error("Set SPIDER_CAPTURE_DIR")
        quit(2)
        return
    DirAccess.make_dir_recursive_absolute(output)
    var index = 0
    for i in 8:
        await physics_frame
        for p in players:
            p.velocity = Vector3.DOWN*2
            p.move_and_slide()
    for state_label in ["Idle","Punch","PunchLeft","Finisher","Slope"]:
        var state = "Punch" if state_label == "Slope" else state_label
        if state_label == "Slope":
            for i in 3:
                floors[i].rotation.z = deg_to_rad(12)
                floor_meshes[i].rotation.z = deg_to_rad(12)
                players[i].position = Vector3(0,1.6,0)
                players[i].animation_driver.ground_modifier.reset_support()
            for tick in 20:
                await physics_frame
                for p in players:
                    p.velocity = Vector3.DOWN*2
                    p.move_and_slide()
        label.text = "GROUNDED COMBAT / "+state_label.to_upper()
        var duration = players[0].animation_driver.animation_player.get_animation(players[0].animation_driver.clips[state]).length
        var frames = 30 if state == "Idle" else roundi(duration*30)
        for repeat in 3:
            for p in players:
                var d = p.animation_driver
                d._play_state(state,1.0)
                d.playback.start(state,true)
                d.advance_animation(0)
            for frame in frames:
                for p in players: p.animation_driver.advance_animation(1.0/30)
                await process_frame
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_jpg(output+"/frame-%04d.jpg" % index,.92)
                if repeat == 1 and frame in [1,roundi(frames*.4)-1,frames-2]:
                    root.get_texture().get_image().save_png("res://docs/validation/support-%s-%02d.png" % [state_label,frame])
                index += 1
    print("SUPPORT_CAPTURE_RESULT: ",index," rendered frames, three camera angles")
    quit()
