extends SceneTree
var failures = 0
func check(value: bool, message: String):
    print("PASS: " if value else "FAIL: ",message)
    if not value:
        failures += 1
func _initialize():
    call_deferred("run")
func wall(parent: Node3D, pos: Vector3, size: Vector3):
    var body = StaticBody3D.new()
    body.position = pos
    var col = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    col.shape = shape
    body.add_child(col)
    parent.add_child(body)
    return body
func run():
    preload("res://input_bindings.gd").setup()
    var world = Node3D.new()
    root.add_child(world)
    wall(world,Vector3(10,20,-25),Vector3(12,40,6))
    var p = preload("res://player.gd").new()
    p.position = Vector3(0,10,0)
    world.add_child(p)
    p.set_physics_process(false)
    p.animation_driver.set_process(false)
    await physics_frame
    p.camera.look_at(Vector3(0,12,-30))
    var target = p.TARGETING.find_anchor(p,false)
    check(not target.is_empty(),"Aim assist finds offset building when center aim misses")
    if not target.is_empty():
        check(target.position.x >= 4 and target.position.y > p.position.y,"Assisted anchor lies on real elevated building surface")
    p.camera.look_at(p.camera.global_position+Vector3(0,100,-1))
    check(p.TARGETING.find_anchor(p,false).is_empty(),"Empty sky cannot create a web anchor")
    p.grappling = true
    p.swing_hand = "Right"
    p.grapple_point = p.position + Vector3(12,20,-20)
    var driver = p.animation_driver
    driver._play_state("SwingRight",1)
    driver.advance_animation(.2)
    var modifier = driver.swing_modifier
    modifier.set_active(false)
    var skeleton = driver.skeleton
    var upper = skeleton.find_bone("RightArm")
    var hand = skeleton.find_bone("RightHand")
    var shoulder = skeleton.get_bone_global_pose(upper).origin
    var before = (skeleton.get_bone_global_pose(hand).origin-shoulder).normalized()
    var direction = (skeleton.to_local(p.grapple_point)-shoulder).normalized()
    modifier._process_modification_with_delta(1)
    var after = (skeleton.get_bone_global_pose(hand).origin-shoulder).normalized()
    check(after.dot(direction) > .96 and after.dot(direction) >= before.dot(direction),"Swing arm aligns actual shoulder-to-hand chain with anchor")
    check(modifier.final_hand.is_equal_approx(skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)),"Web origin is cached from final modified hand")
    p.position = Vector3(0,80,0)
    p.velocity = Vector3(22,7,0)
    var earned = p.velocity
    p._begin_release_trick()
    check(p.release_trick_time > 0 and p.velocity == earned,"Safe release starts cosmetic trick without changing velocity")
    p.grappling = false
    p.release_trick_time = .35
    driver._process(.016)
    check(absf(driver.trick_pivot.rotation.z) > 1,"Release trick rotates only presentation pivot")
    check(p.rotation.is_zero_approx(),"Collision body remains upright during aerial trick")
    p.release_trick_time = 0
    for i in 40:
        driver._process(.016)
    check(absf(wrapf(driver.trick_pivot.rotation.z,-PI,PI)) < .02,"Interrupted trick smoothly returns to normal presentation")
    p.position = Vector3(0,10,0)
    p.wall_normal_memory = Vector3.BACK
    p.wall_contact_grace = .18
    p.pre_slide_velocity = Vector3(0,0,-17)
    p.camera_pivot.rotation = Vector3.ZERO
    Input.action_press("move_forward")
    p._update_wall_ride(1.0/60)
    check(p.wall_climbing,"Fast head-on approach enters upward wall-run")
    p._handle_movement(1.0/60,Vector3.FORWARD)
    check(p.velocity.y > 0,"Upward wall-run supplies lift")
    p.wall_climb_time = 1.5
    p._update_wall_ride(1.0/60)
    check(not p.wall_climbing,"Wall climbing expires instead of granting infinite ascent")
    Input.action_release("move_forward")
    p._respawn(false)
    check(not p.wall_climbing and p.release_trick_time == 0,"Respawn resets extended traversal states")
    world.queue_free()
    await process_frame
    print("TRAVERSAL_V2_RESULT: ",failures," failures")
    quit(0 if failures == 0 else 1)
