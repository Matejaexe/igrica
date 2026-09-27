extends SceneTree

var failures: Array[String] = []
func check(ok: bool, description: String):
    if not ok:
        failures.append(description)
        push_error(description)
    else:
        print("PASS: ", description)

func _initialize():
    call_deferred("run")

func run():
    var block = load("res://scenes/traversal_block.tscn").instantiate()
    root.add_child(block)
    await physics_frame
    var p = block.player
    p.set_physics_process(false)
    p.set_process_unhandled_input(false)
    p.global_position = Vector3(0, 100, 0)
    p.velocity = Vector3(30, 0, 0)
    p.grappling = false
    p.wall_riding = false
    for i in 60:
        p._handle_movement(1.0 / 60, Vector3.ZERO)
    check(absf(p.velocity.x - 30) < 0.01, "Airborne coast preserves earned horizontal speed")
    p.velocity = Vector3(30, 0, 0)
    for i in 60:
        p._handle_movement(1.0 / 60, Vector3.RIGHT)
    check(absf(p.velocity.x - 30) < 0.01, "Forward air input does not clamp swing release to run speed")
    p.grappling = true
    p.grapple_point = p.global_position + Vector3(0, 20.72, 0)
    p.rope_length = 25
    p.velocity = Vector3(10, 0, 0)
    p._apply_swing_physics(1.0 / 60, Vector3.ZERO)
    check(p.velocity.is_equal_approx(Vector3(10, 0, 0)), "Slack rope does not add artificial inward force")
    p.rope_length = 20
    p.velocity = Vector3(10, -5, 0)
    p._apply_swing_physics(1.0 / 60, Vector3.ZERO)
    check(absf(p.velocity.x - 10) < 0.01 and absf(p.velocity.y) < 0.01, "Taut rope removes outward radial motion but preserves tangent")
    for hz in [30, 60, 120]:
        p.global_position = Vector3(0, 100, 0)
        p.grapple_point = Vector3(0, 120.72, 0)
        p.rope_length = 20
        p.velocity = Vector3(18, 0, 0)
        var max_stretch = 0.0
        for step in range(hz * 8):
            var dt = 1.0 / hz
            p.velocity.y -= p.GRAVITY_FORCE * dt
            p._apply_swing_physics(dt, Vector3.ZERO)
            p.global_position += p.velocity * dt
            max_stretch = maxf(max_stretch, (p.grapple_point - p.global_position - Vector3.UP * .72).length() - 20)
        check(p.velocity.is_finite() and max_stretch < 0.2, "8-second pendulum stable at %d Hz (stretch %.3fm)" % [hz, max_stretch])
    var driver = p.animation_driver
    check(driver.clips.size() == 30, "All thirty animation states resolve on imported rig")
    driver.set_process(false)
    var poses = []
    for state in ["Idle", "Jump", "Fall", "Land", "SwingLeft", "SwingRight", "WallRun"]:
        driver._play_state(state, 1.0)
        driver.animation_player.advance(.2)
        var bone = driver.skeleton.find_bone("LeftHand")
        poses.append(driver.skeleton.get_bone_global_pose(bone).origin)
    check(poses[0].distance_to(poses[4]) > .1, "Swing changes actual hand pose, not only invisible proxies")
    driver._play_state("Run", 1.0)
    for i in 1800:
        driver.animation_player.advance(1.0 / 60)
    check(driver.animation_player.is_playing(), "Run continues looping after 30 seconds")
    p._respawn(false)
    check(not p.grappling and p.velocity == Vector3.ZERO and p.wall_contact_grace == 0.0, "Respawn clears traversal state")
    print("TEST_RESULT: ", failures.size(), " failures")
    block.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
