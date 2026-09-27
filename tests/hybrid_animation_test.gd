extends SceneTree
var failures = 0
func check(ok,message):
    print("PASS: " if ok else "FAIL: ",message)
    if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
    var block = load("res://scenes/traversal_block.tscn").instantiate()
    root.add_child(block)
    block.set_process(false)
    var p = block.player
    p.set_physics_process(false)
    var d = p.animation_driver
    d.set_process(false)
    var s = d.skeleton
    var contract = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/spidey/rig_contract.json"))
    var compatible = s.get_bone_count() == contract.bones.size()
    for i in mini(s.get_bone_count(),contract.bones.size()):
        var b = contract.bones[i]
        var t = s.get_bone_rest(i)
        var values = [t.basis.x.x,t.basis.x.y,t.basis.x.z,t.basis.y.x,t.basis.y.y,t.basis.y.z,t.basis.z.x,t.basis.z.y,t.basis.z.z,t.origin.x,t.origin.y,t.origin.z]
        compatible = compatible and s.get_bone_name(i) == b.name and s.get_bone_parent(i) == int(b.parent)
        for j in 12: compatible = compatible and absf(values[j]-b.rest[j]) < .00001
    check(compatible,"GLB bone names, hierarchy and rest matrices match pre-edit rig")
    check(d.animation_tree.active and not d.animation_player.is_playing(),"AnimationTree is the sole clip evaluator; AnimationPlayer is a library")
    var initial_position = p.position
    var initial_velocity = Vector3(17,3,-4)
    p.velocity = initial_velocity
    var tracks_valid = true
    var poses_finite = true
    var hips = s.find_bone("Hips")
    var hips_origin = s.get_bone_global_pose(hips).origin
    var horizontal_drift = 0.0
    for state in d.clips:
        var animation = d.animation_player.get_animation(d.clips[state])
        for track in animation.get_track_count():
            var path = animation.track_get_path(track)
            if path.get_subname_count() > 0:
                tracks_valid = tracks_valid and s.find_bone(str(path.get_subname(0))) >= 0
        d._play_state(state,1.0)
        for i in 6:
            d.advance_animation(animation.length/6.0)
            var offset = s.get_bone_global_pose(hips).origin-hips_origin
            horizontal_drift = maxf(horizontal_drift,Vector2(offset.x,offset.z).length())
            for bone in s.get_bone_count(): poses_finite = poses_finite and s.get_bone_global_pose(bone).is_finite()
    check(tracks_valid and poses_finite,"Every one of 31 imported states targets real bones and produces finite poses")
    check(p.position == initial_position and p.velocity == initial_velocity,"All clip evaluation is in-place and cannot alter physics position or momentum")
    check(horizontal_drift < .001,"Authored hips contain no horizontal root-motion drift")
    d._play_state("Walk",1.0)
    d.advance_animation(0)
    d.advance_animation(d.animation_player.get_animation(d.clips.Walk).length*.37)
    print("BEFORE: ", d.playback.get_current_node()," pos=", d.playback.get_current_play_position()," scale=",d.animation_tree.get("parameters/Rate/scale"))
    for state in ["Run","Sprint","Walk"]:
        d._play_state(state,1.0)
        d.advance_animation(0)
        var phase = d.get_play_position()/d.animation_player.get_animation(d.clips[state]).length
        print("PHASE: ",state," ",phase," current=",d.playback.get_current_node()," fade=",d.playback.get_fading_from_node())
        check(absf(phase-.37) < .02,"Stride phase survives transition to "+state)
    var timings_ok = true
    for i in 3:
        var state = ["Punch","PunchLeft","Finisher"][i]
        timings_ok = timings_ok and absf(d.animation_player.get_animation(d.clips[state]).length-p.NORMAL_ATTACK_LENGTHS[i]) < .005
    check(timings_ok,"Imported combat durations match gameplay contact clock")
    d._play_state("Run",1.0)
    d.advance_animation(.4)
    var bone = s.find_bone("RightHand")
    var before = s.get_bone_global_pose(bone).origin
    d._play_state("Fall",1.0)
    d.advance_animation(.001)
    var after = s.get_bone_global_pose(bone).origin
    check(d.playback.get_fading_from_node() == &"Run" and before.distance_to(after)<.15,"Run-to-air crossfade starts continuously, without a pose snap")
    p.position = Vector3(0,19.425,10)
    for i in 3:
        await physics_frame
        p.velocity = Vector3.DOWN
        p.move_and_slide()
    d.ground_pose_time = 0
    d.previous_speed = 25
    Input.action_press("move_forward")
    p.velocity = Vector3(0,0,-25)
    d._process(.016)
    var sprint_entered = d.current_state == "Sprint"
    p.velocity.z = -21
    d._process(.016)
    var sprint_held = d.current_state == "Sprint"
    p.velocity.z = -19
    d._process(.016)
    Input.action_release("move_forward")
    check(sprint_entered and sprint_held and d.current_state == "Run","Grounded controller selects speed-driven sprint with hysteresis")
    block.queue_free()
    await process_frame
    print("HYBRID_ANIMATION_RESULT: ",failures," failures")
    quit(1 if failures else 0)
