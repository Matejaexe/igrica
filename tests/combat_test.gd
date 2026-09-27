extends SceneTree
var failures = 0
func check(ok,message):
    print("PASS: " if ok else "FAIL: ",message)
    if not ok: failures += 1
func _initialize(): call_deferred("run")
func wall(world,pos,size):
    var b = StaticBody3D.new()
    b.position = pos
    var c = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    c.shape = shape
    b.add_child(c)
    world.add_child(b)
    return b
func run():
    preload("res://input_bindings.gd").setup()
    var world = Node3D.new()
    root.add_child(world)
    wall(world,Vector3(0,-.5,0),Vector3(60,1,60))
    var p = preload("res://player.gd").new()
    p.position = Vector3(0,1.44,0)
    world.add_child(p)
    p.active = true
    p.set_physics_process(false)
    p.animation_driver.set_process(false)
    await physics_frame
    p.velocity = Vector3.DOWN
    p.move_and_slide()
    await physics_frame
    p.velocity = Vector3.DOWN
    p.move_and_slide()
    var drone = preload("res://drone.gd").new()
    drone.position = Vector3(0,2.1,-2.5)
    drone.health = 20
    world.add_child(drone)
    drone.set_target(p)
    drone.set_physics_process(false)
    await physics_frame
    drone._physics_process(.01)
    var hp = p.health
    check(drone.windup > .5 and p.health == hp,"Drone announces attack before applying damage")
    drone._physics_process(.7)
    check(p.health < hp,"Telegraphed attack reaches the player at valid combat distance")
    p.invuln_time = 0
    p.velocity = Vector3.ZERO
    p._begin_dodge(Vector3.RIGHT)
    hp = p.health
    p.take_damage(15,drone.position)
    check(p.dodge_time > 0 and p.health == hp,"Ground dodge grants a brief invulnerable window")
    var cooldown = p.dodge_cooldown
    p._begin_dodge(Vector3.LEFT)
    check(p.dodge_direction.x > 0 and p.dodge_cooldown == cooldown,"Dodge cooldown prevents continuous retriggering")
    p.invuln_time = 0
    var obstruction = wall(world,Vector3(0,2,-1.2),Vector3(3,4,.2))
    await physics_frame
    var enemy_health = drone.health
    p._strike_nearest(4,2,0)
    check(drone.health == enemy_health,"Player melee cannot damage an enemy through a wall")
    drone.windup = .01
    hp = p.health
    drone._physics_process(.02)
    check(p.health == hp,"Enemy strike cannot damage the player through a wall")
    obstruction.queue_free()
    await physics_frame
    await physics_frame
    drone.windup = .4
    drone.hit(1,Vector3.BACK)
    check(drone.windup == 0 and drone.stagger > 0,"Player hit interrupts an enemy windup")
    p.dodge_time = 0
    p.combo_step = 0
    var combo: Array[int] = []
    for i in 4:
        await physics_frame
        p.attack_cooldown = 0
        Input.action_press("attack")
        await physics_frame
        p._handle_attack_input()
        combo.append(p.combo_step)
        Input.action_release("attack")
        await process_frame
    print("COMBO_SEQUENCE: ",combo)
    check(combo == [1,2,3,1],"Combo cycles left/right/finisher and restarts")
    drone.position = p.position + Vector3(0,.65,-2)
    enemy_health = drone.health
    p.combo_window = 0
    p._begin_normal_attack()
    p._advance_normal_attack(.10)
    check(drone.health == enemy_health,"Normal attack windup does not deal damage early")
    p._advance_normal_attack(.04)
    check(drone.health == enemy_health-1,"Normal attack deals damage at the authored contact time")
    enemy_health = drone.health
    p._advance_normal_attack(1)
    check(drone.health == enemy_health,"Contact can only deal damage once")
    p._begin_normal_attack()
    drone.position = p.position + Vector3(0,0,-20)
    p._advance_normal_attack(.3)
    check(drone.health == enemy_health,"Target leaving range during windup is not hit")
    drone.position = p.position + Vector3(0,.65,-2)
    p._begin_normal_attack()
    p.dodge_cooldown = 0
    p._begin_dodge(Vector3.RIGHT)
    p._advance_normal_attack(.3)
    check(drone.health == enemy_health and p.pending_attack_time < 0,"Dodge cancels pending attack contact")
    p.dodge_time = 0
    var d = p.animation_driver
    p.combo_step = 2
    p.attack_pose_time = .2
    d._process(.016)
    check(d.current_state == "PunchLeft","Second combo strike selects its own animation")
    d.advance_animation(.12)
    p.attack_sequence += 1
    d._process(.016)
    d.advance_animation(0)
    check(d.get_play_position() < .02,"Repeated attacks restart their animation")
    drone.hit(100,Vector3.BACK)
    var final_health = drone.health
    drone.hit(100,Vector3.BACK)
    check(drone.health == final_health and not drone.is_in_group("enemies"),"Defeated enemies cannot be hit or rewarded twice")
    p._respawn(false)
    check(p.dodge_time == 0 and p.combo_step == 0,"Respawn resets combat and evasion state")
    world.queue_free()
    await process_frame
    print("COMBAT_RESULT: ",failures," failures")
    quit(1 if failures else 0)
