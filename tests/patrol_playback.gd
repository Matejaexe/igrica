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
    var patrol = main.patrol
    var victories = patrol.victories
    patrol.toggle()
    var output = OS.get_environment("SPIDER_CAPTURE_DIR")
    var capture = not output.is_empty()
    if capture: DirAccess.make_dir_recursive_absolute(output)
    var captured = 0
    for i in 3000:
        await physics_frame
        if not patrol.running: break
        if i % 20 == 0: Input.action_press("attack")
        if i % 20 == 1: Input.action_release("attack")
        var to_center = patrol.arena-p.position
        to_center.y = 0
        if to_center.length() > 3:
            p.yaw = atan2(-to_center.x,-to_center.z)
            Input.action_press("move_forward")
        else:
            Input.action_release("move_forward")
        if capture and i % 4 == 0:
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_jpg(output+"/frame-%04d.jpg" % captured,.86)
            captured += 1
        if capture and i == 110:
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("res://docs/validation/patrol-combat.png")
    Input.action_release("attack")
    Input.action_release("move_forward")
    var passed = patrol.victories == victories+1
    print("PATROL_PLAYBACK: victory=",passed," wave=",patrol.wave," time=",patrol.elapsed," player_health=",p.health," status=",patrol.status)
    if capture:
        for i in 5: await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://docs/validation/patrol-result.png")
    main.queue_free()
    await process_frame
    quit(0 if passed else 1)
