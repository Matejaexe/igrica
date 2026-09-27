extends SceneTree
func _initialize():
    call_deferred("run")
func run():
    var main = load("res://Main.tscn").instantiate()
    root.add_child(main)
    for i in 1800:
        if main.game_state == "menu": break
        await process_frame
    main._start_game()
    main.game_state = "validation"
    main.player.set_physics_process(false)
    main.player.active = false
    main.player.visual_root.hide()
    for child in main.get_children():
        if child is CanvasLayer: child.hide()
    var life = main.get_node("CityLife")
    life.set_process(false)
    var floor_mesh = MeshInstance3D.new()
    var plane = BoxMesh.new()
    plane.size = Vector3(18,.1,12)
    floor_mesh.mesh = plane
    floor_mesh.position = Vector3(0,299.95,0)
    var material = StandardMaterial3D.new()
    material.albedo_color = Color("707a83")
    floor_mesh.material_override = material
    main.add_child(floor_mesh)
    var camera = Camera3D.new()
    main.add_child(camera)
    camera.current = true
    camera.fov = 43
    camera.position = Vector3(2.5,302.2,10)
    camera.look_at(Vector3(0,301,0))
    for pose in 4:
        for i in 6:
            var person = life.walkers[i].duplicate()
            person.position = Vector3((i-2.5)*1.25,300,0)
            person.direction = Vector3.BACK
            person.distance = pose*.30
            person.phase = i*.3
            person.motion = 1.0
            life._draw_person(i,person,sin(person.distance*TAU/1.2+person.phase)*.48,true)
        for frame in 12: await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://docs/validation/civilians-walk-%d.png" % pose)
    main.queue_free()
    await process_frame
    quit()
