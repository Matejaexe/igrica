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
    if output.is_empty(): output = "user://skyline-route-frames"
    DirAccess.make_dir_recursive_absolute(output)
    var captured = 0
    var minimum_y = p.position.y
    for i in 3000:
        await physics_frame
        if not route.running: break
        var target: Vector3 = route.points[route.index]-p.position
        var horizontal = Vector2(target.x,target.z).length()
        p.yaw = atan2(-target.x,-target.z)
        if target.y < -horizontal*.16-4:
            Input.action_press("dive")
        else:
            Input.action_release("dive")
        minimum_y = minf(minimum_y,p.position.y)
        if i % 4 == 0:
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_jpg(output+"/frame-%04d.jpg" % captured,.86)
            captured += 1
        if i == 80:
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://docs/validation/skyline-glide.png")
    Input.action_release("move_forward")
    Input.action_release("dive")
    print("SKYLINE_ROUTE_PLAYBACK: complete=",route.completed," gates=",route.index," time=",route.elapsed," altitude=",p.position.y," min_y=",minimum_y)
    for i in 4: await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://docs/validation/skyline-result.png")
    var passed = route.completed
    main.queue_free()
    await process_frame
    quit(0 if passed else 1)
