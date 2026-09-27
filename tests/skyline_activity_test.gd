extends SceneTree
var failures = 0
func check(ok,message):
    print("PASS: " if ok else "FAIL: ",message)
    if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
    var main = load("res://Main.tscn").instantiate()
    root.add_child(main)
    for i in 1800:
        if main.game_state == "menu": break
        await process_frame
    main._start_free_roam()
    main.player.set_physics_process(false)
    var route = main.skyline_challenge
    route.set_process(false)
    var spawn = main.player.spawn_position
    route.toggle()
    check(route.points.size() == 7 and route.running,"Activity starts with seven ordered gates")
    main.player.position = route.points[1]
    route._process(.016)
    check(route.index == 0,"Out-of-order gate does not advance the route")
    route.toggle()
    check(not route.running and main.player.spawn_position == spawn,"Cancel restores the previous respawn location")
    route.toggle()
    route.best = 0
    for point in route.points:
        main.player.position = point
        route._process(1.0)
    check(route.completed and not route.running and route.index == 7,"Ordered gate completion produces a result")
    var save = ConfigFile.new()
    var loaded = save.load("user://skyline_challenge.cfg")
    check(loaded == OK and is_equal_approx(float(save.get_value("route","best",0)),route.elapsed),"Best result persists and loads from disk")
    check(main.player.spawn_position == spawn,"Completing the activity restores the previous respawn")
    main.queue_free()
    await process_frame
    print("SKYLINE_ACTIVITY_RESULT: ",failures," failures")
    quit(1 if failures else 0)
