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
    var activity = main.patrol
    activity.set_process(false)
    var spawn = main.player.spawn_position
    main.skyline_challenge.toggle()
    activity.toggle()
    check(activity.running and not main.skyline_challenge.running,"Patrol and flight activities cannot run together")
    check(activity.wave == 1 and activity.remaining == 2,"Patrol starts with two enemies")
    var initial_xp = activity.xp
    for wave in 3:
        for actor in activity.actors.duplicate(): actor.hit(100,Vector3.BACK)
        if activity.running: activity._process(1.5)
        await process_frame
    check(not activity.running and activity.wave == 3 and activity.actors.is_empty(),"Three waves finish and clean up all hostile actors")
    check(activity.xp == initial_xp+150,"Victory grants exactly one XP reward")
    var save = ConfigFile.new()
    var loaded = save.load("user://patrol_progress.cfg")
    check(loaded == OK and int(save.get_value("progress","xp",0)) == activity.xp,"Patrol reward persists to disk")
    check(main.player.spawn_position == spawn,"Victory restores the previous respawn point")
    activity.toggle()
    var xp = activity.xp
    activity._on_player_died()
    await process_frame
    check(not activity.running and activity.actors.is_empty() and activity.xp == xp,"Defeat cleans up and grants no reward")
    activity.toggle()
    main.skyline_challenge.toggle()
    await process_frame
    check(not activity.running and main.skyline_challenge.running,"Starting the flight route cancels combat safely")
    main.queue_free()
    await process_frame
    print("PATROL_ACTIVITY_RESULT: ",failures," failures")
    quit(1 if failures else 0)
