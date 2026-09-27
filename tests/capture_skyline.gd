extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var main = load("res://Main.tscn").instantiate()
    root.add_child(main)
    for i in 1800:
        if main.game_state == "menu": break
        await process_frame
    main._start_free_roam()
    var p = main.player
    var route = main.skyline_challenge
    route.toggle()
    for i in 12: await physics_frame
    Input.action_press("move_forward")
    for i in 12: await physics_frame
    Input.action_press("jump")
    await physics_frame
    Input.action_release("jump")
    for i in 12: await physics_frame
    p._toggle_glide()
    var output = OS.get_environment("SPIDER_CAPTURE_DIR")
    if output.is_empty(): output = "user://skyline-frames"
    DirAccess.make_dir_recursive_absolute(output)
    var glided = false
    for i in 150:
        await physics_frame
        if p.gliding: glided = true
        await RenderingServer.frame_post_draw
        if i % 2 == 0:
            root.get_texture().get_image().save_png(output+"/frame-%04d.png" % (i/2))
        if i == 70:
            root.get_texture().get_image().save_png("res://docs/validation/skyline-glide.png")
    Input.action_release("move_forward")
    print("SKYLINE_CAPTURE: glide_entered=",glided," gates_passed=",route.index," speed=",p.velocity.length()," launch=",route.launch)
    main.queue_free()
    await process_frame
    quit()
