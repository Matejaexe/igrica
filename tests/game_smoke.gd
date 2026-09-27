extends SceneTree

var failures = 0
func check(ok, message):
    print("PASS: " if ok else "FAIL: ", message)
    if not ok:
        failures += 1

func _initialize():
    call_deferred("run")

func frames(count: int):
    for i in count:
        await physics_frame

func run():
    var main = load("res://Main.tscn").instantiate()
    root.add_child(main)
    for i in 1200:
        if main.game_state == "menu":
            break
        await process_frame
    check(main.game_state == "menu", "Full city reaches main menu")
    check(main.city_building_count == 320, "Expanded 320-building city loads")
    var life = main.get_node("CityLife")
    check(life.walkers.size() == 280, "City populates 280 pedestrians")
    check(life.routes.size() > 60, "Crowd has distributed sidewalk routes")
    var clear_routes = true
    for route in life.routes:
        if not life._route_clear(route):
            clear_routes = false
    check(clear_routes, "All pedestrian loops avoid building footprints")
    check(life.static_instance_count > 20000 and life.batches.size() < 500, "Street details are batched, not individual render nodes")
    check(life.solid_props > 50, "Large street props have player collision")
    var before_crowd = life.walkers[0].distance
    life.elapsed = 10
    life._process(1.0)
    check(life.walkers[0].distance != before_crowd, "Pedestrians advance along routes")
    main._show_character_select()
    for index in 4:
        main.selected_character = index
        main._refresh_character_select()
        main.player.set_character(index)
        await process_frame
        check(main.player.animation_driver.clips.size() == 30, "Character %d loads all traversal states" % index)
    main._start_free_roam()
    check(main.mission == 0 and main.game_state == "playing", "Free roam opens without timed objectives")
    main._lock_character_and_start()
    await frames(60)
    check(main.game_state == "playing" and main.mission == 1, "Character select enters first mission")
    var p = main.player
    var start = p.global_position
    Input.action_press("move_forward")
    await frames(25)
    Input.action_release("move_forward")
    check(p.global_position.distance_to(start) > 1.0, "Actual physics input moves player in city")
    Input.action_press("jump")
    await frames(2)
    Input.action_release("jump")
    check(p.velocity.y > 0.0, "Jump input produces upward motion")
    main._start_ring_mission()
    check(main.mission == 2 and main.mission_total > 0, "Traversal mission still initializes")
    main._start_combat_mission()
    check(main.mission == 3 and main.enemies_left > 0, "Combat mission still spawns enemies")
    await frames(30)
    main.queue_free()
    await process_frame
    var block = load("res://scenes/traversal_block.tscn").instantiate()
    root.add_child(block)
    await frames(10)
    block.player.set_physics_process(false)
    # A separate forced checkpoint sweep validates progression and save/load;
    # this is not presented as a completed human traversal playthrough.
    for point in block.ROUTE:
        block.player.global_position = point
        block._process(.1)
    check(block.finished and block.best > 0, "Practice route completes and saves best time")
    block.queue_free()
    await process_frame
    var reload_block = load("res://scenes/traversal_block.tscn").instantiate()
    root.add_child(reload_block)
    check(reload_block.best > 0, "Practice record reloads from disk")
    reload_block.queue_free()
    await process_frame
    print("GAME_SMOKE_RESULT: ", failures, " failures")
    quit(0 if failures == 0 else 1)
