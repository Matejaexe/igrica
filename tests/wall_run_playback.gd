extends SceneTree
func _initialize():
    call_deferred("run")
func run():
    preload("res://input_bindings.gd").setup()
    var world = Node3D.new()
    root.add_child(world)
    var wall = StaticBody3D.new()
    wall.position = Vector3(0,15,-9)
    var shape = BoxShape3D.new()
    shape.size = Vector3(25,30,2)
    var collision = CollisionShape3D.new()
    collision.shape = shape
    wall.add_child(collision)
    world.add_child(wall)
    var p = preload("res://player.gd").new()
    p.position = Vector3(0,6,0)
    world.add_child(p)
    p.velocity = Vector3(0,0,-17)
    p.set_active(true)
    Input.action_press("move_forward")
    var climbed = false
    var max_height = 0.0
    var wall_climb_start_height = 0.0
    var breached = false
    for frame in 150:
        await physics_frame
        if p.wall_climbing and not climbed:
            wall_climb_start_height = p.position.y
            climbed = true
        max_height = maxf(max_height,p.position.y)
        breached = breached or p.position.z < -7.7
    Input.action_release("move_forward")
    var gained = max_height-wall_climb_start_height
    print("WALL_PLAYBACK: entered=",climbed," gained_height=",gained," breached_wall=",breached," exhausted=",not p.wall_climbing)
    var passed = climbed and gained > 3 and not breached and not p.wall_climbing
    world.queue_free()
    await process_frame
    print("WALL_PLAYBACK_RESULT: ", "PASS" if passed else "FAIL")
    quit(0 if passed else 1)
