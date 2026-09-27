extends SceneTree
func _initialize():
    call_deferred("run")
func frames(count):
    for i in count:
        await process_frame
func shot(path):
    await RenderingServer.frame_post_draw
    if RenderingServer.get_current_rendering_method() == "gl_compatibility":
        path = path.replace("graphics-", "graphics-compat-")
    root.get_texture().get_image().save_png(path)
func run():
    var main = load("res://Main.tscn").instantiate()
    root.add_child(main)
    for i in 1800:
        if main.game_state == "menu":
            break
        await process_frame
    main._start_game()
    main.game_state = "validation"
    main.player.set_physics_process(false)
    main.player.visual_root.hide()
    main.player.active = false
    for child in main.get_children():
        if child is CanvasLayer:
            child.hide()
    var cam = Camera3D.new()
    main.add_child(cam)
    cam.current = true
    cam.fov = 65
    cam.global_position = Vector3(-150,215,230)
    cam.look_at(Vector3(60,24,-80))
    main.player.global_position = cam.global_position + Vector3(0,-10,0)
    await frames(90)
    await shot("res://docs/validation/graphics-skyline.png")
    var life = main.get_node("CityLife")
    main.player.global_position = Vector3(0,2,25)
    cam.global_position = Vector3(0,3,25)
    cam.look_at(Vector3(15,10,-65))
    await frames(30)
    await shot("res://docs/validation/graphics-street.png")
    var samples: Array[float] = []
    var previous = Time.get_ticks_usec()
    for i in 180:
        await process_frame
        var now = Time.get_ticks_usec()
        samples.append((now-previous)/1000.0)
        previous=now
    samples.sort()
    print("CITY_RENDER: active pedestrians=",life.active_walkers," total=",life.walkers.size()," static pieces=",life.static_instance_count," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," median_ms=",samples[90]," p95_ms=",samples[171])
    main.queue_free()
    await frames(3)
    quit()
