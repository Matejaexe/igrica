extends SceneTree

func _initialize():
    call_deferred("capture")

func capture():
    var block = load("res://scenes/traversal_block.tscn").instantiate()
    root.add_child(block)
    await create_timer(1.0).timeout
    block.player.set_physics_process(false)
    block.set_process(false)
    DirAccess.make_dir_recursive_absolute("res://docs/validation")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://docs/validation/flow-block.png")
    var p = block.player
    for child in block.get_children():
        if child is CanvasLayer:
            child.hide()
    p.active = false
    p.visual_root.rotation = Vector3.ZERO
    p.animation_driver.set_process(false)
    var camera = Camera3D.new()
    block.add_child(camera)
    camera.current = true
    camera.global_position = p.global_position + Vector3(4, 1.2, -6)
    camera.look_at(p.global_position + Vector3(0, .2, 0))
    camera.fov = 40
    for state in ["Idle", "Walk", "Run", "Jump", "Fall", "Land", "SwingLeft", "SwingRight", "SwingTuckRight", "Release", "Dive", "Punch", "WallRun", "WallClimb"]:
        p.grappling = state.begins_with("Swing")
        p.swing_hand = "Left" if state.ends_with("Left") else "Right"
        p.grapple_point = p.global_position + Vector3(5,9,-3)
        var animator = p.animation_driver.animation_player
        animator.play(p.animation_driver.clips[state], 0.0)
        animator.advance(0.0)
        animator.seek(0.2, true)
        animator.pause()
        p.animation_driver.skeleton.force_update_all_bone_transforms()
        for frame in 20:
            await process_frame
            p._update_web_visual()
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://docs/validation/pose-" + state + ".png")
    quit()
