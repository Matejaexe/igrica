extends SceneTree
var failures = 0
func check(ok,message):
    print("PASS: " if ok else "FAIL: ",message)
    if not ok: failures += 1
func _initialize(): call_deferred("run")
func box(world,pos,size):
    var body = StaticBody3D.new()
    body.position = pos
    var collision = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    world.add_child(body)
    return body
func run():
    preload("res://input_bindings.gd").setup()
    var flight = preload("res://systems/flight_physics.gd")
    var results: Array[Vector3] = []
    for rate in [30,60,120]:
        var v = Vector3(25,-3,0)
        for frame in rate*2: v = flight.step(v,Vector3.FORWARD,false,1.0/rate)
        results.append(v)
    check(results[0].distance_to(results[2]) < .15,"Glide steering remains consistent at 30/60/120 Hz")
    check(results[0].y < 0 and results[0].length() < 25,"Level glide loses altitude and speed")
    var dive = flight.step(Vector3(30,-3,0),Vector3.RIGHT,true,1.0)
    check(dive.x > 30 and dive.y < -3,"Dive exchanges altitude for horizontal speed")
    var world = Node3D.new()
    root.add_child(world)
    box(world,Vector3(0,-.5,0),Vector3(100,1,100))
    box(world,Vector3(0,.5,-5),Vector3(4,1,1))
    box(world,Vector3(10,10,-5),Vector3(4,20,1))
    box(world,Vector3(0,70,-25),Vector3(20,50,2))
    var p = preload("res://player.gd").new()
    p.position = Vector3(0,60,0)
    world.add_child(p)
    p.set_physics_process(false)
    p.animation_driver.set_process(false)
    await physics_frame
    p.velocity = Vector3(0,-3,-25)
    var momentum = p.velocity
    p.grappling = true
    p._toggle_glide()
    check(p.gliding and not p.grappling and p.velocity == momentum,"Deploying wings preserves incoming velocity and detaches web")
    p.animation_driver._process(.016)
    check(p.animation_driver.current_state == "Glide","Glide owns the animation while airborne")
    p._toggle_glide()
    check(not p.gliding and p.velocity == momentum,"Folding wings preserves momentum")
    p.velocity = Vector3(0,-1,-3)
    p._toggle_glide()
    check(not p.gliding,"Wings cannot launch from insufficient forward speed")
    p.velocity = momentum
    p._toggle_glide()
    p._start_grapple(false)
    check(p.grappling and not p.gliding,"A real building anchor interrupts glide and engages the rope")
    p.grappling = false
    p.position = Vector3(0,1.44,0)
    p.velocity = Vector3(0,-1,0)
    p.move_and_slide()
    await physics_frame
    p.velocity = Vector3(0,-1,0)
    p.move_and_slide()
    p.velocity = Vector3(0,0,-17)
    check(p._can_vault(Vector3.FORWARD),"Low obstacle ahead is recognized for vault")
    p.position.x = 10
    check(not p._can_vault(Vector3.FORWARD),"Tall building cannot trigger low-obstacle vault")
    p.position.x = 0
    p.jump_buffer = .12
    p._handle_movement(1.0/60,Vector3.FORWARD)
    check(p.vault_pose_time > 0 and p.velocity.y > 0,"Buffered ground jump selects a vault pose")
    var cleared = false
    p.active = true
    Input.action_press("move_forward")
    for frame in 45:
        await physics_frame
        p._physics_process(1.0/60)
        if p.position.z < -6: cleared = true
    Input.action_release("move_forward")
    check(cleared,"Real capsule motion clears the low obstacle without teleporting")
    p.gliding = true
    p._respawn(false)
    check(not p.gliding and p.vault_pose_time == 0,"Respawn clears glide and vault state")
    world.queue_free()
    await process_frame
    print("SKYLINE_MOVEMENT_RESULT: ",failures," failures")
    quit(1 if failures else 0)
