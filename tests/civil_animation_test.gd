extends SceneTree
var failures = 0
func check(value, label):
    print("PASS: " if value else "FAIL: ",label)
    if not value: failures += 1
func _initialize(): call_deferred("run")
func run():
    if DisplayServer.get_name() == "headless":
        push_error("This test requires a rendering device for MultiMesh transform readback; omit --headless.")
        quit(2)
        return
    var main = load("res://Main.tscn").instantiate()
    root.add_child(main)
    for i in 1800:
        if main.game_state == "menu": break
        await process_frame
    var life = main.get_node("CityLife")
    life.set_process(false)
    var soles_valid = true
    var min_sole = 100.0
    var max_error = 0.0
    var joints_valid = true
    for frame in 60:
        for i in 6:
            var person = life.walkers[i].duplicate()
            person.position = Vector3.ZERO
            person.direction = Vector3.FORWARD
            person.motion = 1.0
            person.distance = float(frame)/60.0*1.2
            life._draw_person(i,person,0.0,true)
            for side in 2:
                var foot = life.crowd_meshes.shoes.get_instance_transform(i*2+side)
                min_sole = minf(min_sole,foot.origin.y-foot.basis.y.length()*.5)
                soles_valid = soles_valid and foot.origin.y-foot.basis.y.length()*.5 > -.001
                for part in ["legs","shins"]:
                    var limb = life.crowd_meshes[part].get_instance_transform(i*2+side)
                    max_error = maxf(max_error,absf(limb.basis.y.length()/person.height-.4))
                    joints_valid = joints_valid and limb.is_finite() and absf(limb.basis.y.length()/person.height-.4) < .005
    print("SOLE_MIN=",min_sole," LEG_ERROR=",max_error)
    check(soles_valid,"Pedestrian soles stay above pavement through full stride")
    check(joints_valid,"Both leg segments maintain length through full stride")
    main._start_game()
    var driver = main.player.animation_driver
    driver.set_process(false)
    driver._play_state("Walk",1.0)
    driver.advance_animation(0)
    driver.advance_animation(driver.animation_player.get_animation(driver.clips["Walk"]).length*.37)
    driver._play_state("Run",1.0)
    driver.advance_animation(0)
    var phase = driver.get_play_position()/driver.animation_player.get_animation(driver.clips["Run"]).length
    check(absf(phase-.37)<.02,"Walk to run preserves normalized stride phase")
    main.queue_free()
    await process_frame
    print("CIVIL_ANIMATION_RESULT: ",failures," failures")
    quit(1 if failures else 0)
