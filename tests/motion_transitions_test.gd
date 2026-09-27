extends SceneTree
var failures = 0
func check(ok, message):
    print("PASS: " if ok else "FAIL: ",message)
    if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
    var block = load("res://scenes/traversal_block.tscn").instantiate()
    root.add_child(block)
    var p = block.player
    p.set_physics_process(false)
    block.set_process(false)
    var d = p.animation_driver
    d.set_process(false)
    var valid = true
    for state in d.EXTRA_STATES:
        valid = valid and d.clips.has(state)
        if d.clips.has(state):
            valid = valid and d.animation_player.get_animation(d.clips[state]).loop_mode == Animation.LOOP_NONE
    check(valid,"All one-shot traversal action clips load and do not loop")
    p.landing_sequence += 1
    p.landing_travel_speed = 15
    p.landing_impact_speed = 30
    d._update_ground_transition(.016,15,true,true)
    check(d.ground_pose == "LandRun","Fast landing keeps running presentation")
    var timer = d.ground_pose_time
    d._update_ground_transition(.05,15,true,true)
    check(d.ground_pose_time < timer,"Landing contact is consumed once, not replayed")
    p.landing_sequence += 1
    p.landing_travel_speed = 0
    d._update_ground_transition(.016,0,true,false)
    check(d.ground_pose == "HardLand","Heavy stationary impact gets compression recovery")
    d._update_ground_transition(.016,3,false,true)
    check(d.ground_pose_time == 0,"Jump immediately interrupts landing")
    d.reset_transition_state()
    d._update_ground_transition(.016,2,true,true)
    check(d.ground_pose == "StartRun","Acceleration from rest gets takeoff stride")
    d.reset_transition_state()
    d.previous_speed = 17
    d._update_ground_transition(.016,15,true,false)
    check(d.ground_pose == "StopRun","Deceleration gets braking stride")
    d._update_ground_transition(.016,16,true,true)
    check(d.ground_pose_time == 0,"Reacceleration immediately interrupts braking")
    p.position = Vector3(0,80,0)
    p.velocity = Vector3(12,8,0)
    var momentum = p.velocity
    p.wall_jump_pose_time = .2
    p.wall_ride_normal = Vector3.RIGHT
    d._process(.016)
    check(d.current_state.begins_with("WallJump"),"Wall jump timer selects dedicated airborne pose")
    p.wall_jump_pose_time = 0
    p.double_jump_pose_time = .3
    p.double_jump_sequence = 1
    d._process(.016)
    check(d.current_state == "AirJumpRight","Air jump gets asymmetric pose")
    p.grappling = true
    p.grapple_point = p.position+Vector3(10,20,0)
    d._process(.016)
    check(d.current_state.begins_with("Swing") and p.velocity == momentum,"New web attach interrupts jump pose without changing velocity")
    p._respawn(false)
    check(d.ground_pose_time == 0 and p.landing_impact_speed == 0,"Respawn clears transition feedback")
    p.position = Vector3(0,42,10)
    p.active = true
    var before_contact = p.landing_sequence
    var played_heavy = false
    for step in 180:
        await physics_frame
        p._physics_process(1.0/60.0)
        d._process(1.0/60.0)
        if d.current_state == "HardLand": played_heavy = true
        if p.landing_sequence > before_contact and p.is_on_floor(): break
    check(p.landing_sequence == before_contact+1 and p.landing_impact_speed > 24,"Real rooftop collision emits one measured heavy landing event")
    check(played_heavy,"Actual falling character enters heavy landing animation")
    block.queue_free()
    await process_frame
    print("MOTION_TRANSITIONS_RESULT: ",failures," failures")
    quit(1 if failures else 0)
