extends SceneTree
var failures = 0
var player: CharacterBody3D
var floor_body: StaticBody3D
func check(ok, message):
    print("PASS: " if ok else "FAIL: ",message)
    if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
    preload("res://input_bindings.gd").setup()
    var world = Node3D.new()
    root.add_child(world)
    floor_body = StaticBody3D.new()
    var collider = CollisionShape3D.new()
    collider.shape = BoxShape3D.new()
    collider.shape.size = Vector3(20,.2,20)
    floor_body.add_child(collider)
    floor_body.position.y = -.1
    world.add_child(floor_body)
    player = preload("res://player.gd").new()
    player.position.y = 1.44
    world.add_child(player)
    player.set_physics_process(false)
    var d = player.animation_driver
    d.set_process(false)
    var g = d.ground_modifier
    g.set_active(false)
    g.set_physics_process(false)
    d.swing_modifier.set_active(false)
    player.visual_root.rotation = Vector3.ZERO
    for i in 5:
        await physics_frame
        player.velocity = Vector3.DOWN
        player.move_and_slide()
    check(player.is_on_floor(),"Test capsule actually rests on a physics floor")
    var position_before = player.position
    var velocity_before = player.velocity
    var max_error = 0.0
    for state in ["Idle","Punch","PunchLeft","Finisher"]:
        d._play_state(state,1.0)
        for i in 30:
            await physics_frame
            d.playback.start(state,true)
            d.advance_animation(.133 if state != "Finisher" else .2)
            g._physics_process(1.0/60)
            g._process_modification_with_delta(1.0/60)
        var error = 100.0 if g.last_soles.size() != 2 else maxf(absf(g.last_soles[0].y),absf(g.last_soles[1].y))
        max_error = maxf(max_error,error)
        print("SOLE_ERROR ",state," ",error)
        check(error < .012,"Both soles contact the floor in "+state)
    check(player.position == position_before and player.velocity == velocity_before,"Support correction cannot move the capsule or change momentum")
    var skeleton = d.skeleton
    var planted = true
    for state in ["Punch","PunchLeft","Finisher"]:
        d._play_state(state,1.0)
        d.playback.start(state,true)
        d.advance_animation(0)
        var left = skeleton.get_bone_global_pose(skeleton.find_bone("LeftFoot")).origin
        var right = skeleton.get_bone_global_pose(skeleton.find_bone("RightFoot")).origin
        for i in 30:
            d.advance_animation(d.animation_player.get_animation(d.clips[state]).length/30)
            planted = planted and left.distance_to(skeleton.get_bone_global_pose(skeleton.find_bone("LeftFoot")).origin) < .002
            planted = planted and right.distance_to(skeleton.get_bone_global_pose(skeleton.find_bone("RightFoot")).origin) < .002
    check(planted,"Blender combat ankles stay planted throughout all three imported clips")
    floor_body.rotation.z = deg_to_rad(12)
    player.position = Vector3(0,1.6,0)
    for i in 20:
        await physics_frame
        player.velocity = Vector3.DOWN*2
        player.move_and_slide()
    d._play_state("Punch",1)
    g.reset_support()
    for i in 30:
        await physics_frame
        d.playback.start("Punch",true)
        d.advance_animation(.133)
        g._physics_process(1.0/60)
        g._process_modification_with_delta(1.0/60)
    var slope_error = 100.0
    if g.last_soles.size() == 2 and not g.contacts[0].is_empty() and not g.contacts[1].is_empty():
        slope_error = 0
        for i in 2: slope_error = maxf(slope_error,absf((g.last_soles[i]-g.contacts[i].position).dot(g.contacts[i].normal)))
    print("SLOPE_ERROR ",slope_error)
    check(slope_error < .015,"Two feet adapt independently to an actual 12-degree slope")
    var grounded_weight = g.support_weight
    d._play_state("Run",1)
    d.advance_animation(.016)
    g._physics_process(.016)
    g._process_modification_with_delta(.016)
    check(g.support_weight > 0 and g.support_weight < grounded_weight and g.contacts[0].is_empty(),"Starting to run fades pelvis offset while releasing leg IK")
    for i in 10:
        d.advance_animation(.016)
        g._process_modification_with_delta(.016)
    check(g.support_weight == 0 and g.pelvis_drop == 0,"Ground transition completely releases support within 0.1 seconds")
    g.support_weight = 1.0
    g.pelvis_drop = -.08
    player.velocity = Vector3.UP*9
    g._process_modification_with_delta(.016)
    check(g.support_weight == 0 and g.last_ankles.is_empty(),"Jump releases ground support immediately")
    player.velocity = Vector3.ZERO
    for state in ["Run","Sprint","SwingLeft","WallRun","DodgeLeft","Vault"]:
        d._play_state(state,1)
        g._physics_process(.016)
        check(g.contacts[0].is_empty() and g.contacts[1].is_empty(),"No foot locking in "+state)
    d._play_state("Idle",1)
    floor_body.position.y = -4
    await physics_frame
    g._physics_process(.016)
    check(g.contacts[0].is_empty() and g.contacts[1].is_empty(),"Missing ground does not stretch legs across a ledge")
    d.reset_transition_state()
    check(g.support_weight == 0 and not g.previous_body_position.is_finite(),"Respawn reset clears old support data")
    world.queue_free()
    await process_frame
    print("GROUND_SUPPORT_RESULT: ",failures," failures; flat max error=",max_error)
    quit(1 if failures else 0)
