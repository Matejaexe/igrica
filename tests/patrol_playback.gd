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
    var capture_prefix = OS.get_environment("SPIDER_CAPTURE_PREFIX")
    if capture_prefix.is_empty(): capture_prefix = "patrol"
    if capture: DirAccess.make_dir_recursive_absolute(output)
    var captured = 0
    var attack_pressed = false
    var dodge_pressed = false
    for i in 3000:
        await physics_frame
        if not patrol.running: break
        if attack_pressed:
            Input.action_release("attack")
            attack_pressed = false
        elif p.attack_cooldown <= 0 and p.dodge_time <= 0:
            Input.action_press("attack")
            attack_pressed = true
        if dodge_pressed:
            Input.action_release("dodge")
            dodge_pressed = false
        elif p.is_on_floor() and p.dodge_cooldown <= 0:
            for enemy in patrol.actors:
                if is_instance_valid(enemy) and enemy.windup > 0 and enemy.windup < .2 and enemy.position.distance_to(p.position) < 3.4:
                    Input.action_press("dodge")
                    dodge_pressed = true
                    break
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
            root.get_texture().get_image().save_png("res://docs/validation/"+capture_prefix+"-combat.png")
    Input.action_release("attack")
    Input.action_release("dodge")
    Input.action_release("move_forward")
    var passed = patrol.victories == victories+1
    print("PATROL_PLAYBACK: victory=",passed," wave=",patrol.wave," time=",patrol.elapsed," player_health=",p.health," status=",patrol.status)
    if capture:
        for i in 5: await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://docs/validation/"+capture_prefix+"-result.png")
    main.queue_free()
    await process_frame
    quit(0 if passed else 1)
