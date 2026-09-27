extends SceneTree
func _initialize(): call_deferred("run")
func run():
    var block = load("res://scenes/traversal_block.tscn").instantiate()
    root.add_child(block)
    await create_timer(.4).timeout
    var player = block.player
    player.set_physics_process(false)
    block.set_process(false)
    player.active = false
    player.visual_root.rotation = Vector3.ZERO
    player.animation_driver.set_process(false)
    for child in block.get_children():
        if child is CanvasLayer: child.hide()
    var camera = Camera3D.new()
    block.add_child(camera)
    camera.current = true
    camera.position = player.position + Vector3(3,1.0,-6)
    camera.look_at(player.position + Vector3(0,.2,0))
    camera.fov = 37
    var ui = CanvasLayer.new()
    block.add_child(ui)
    var label = Label.new()
    label.position = Vector2(40,40)
    label.add_theme_font_size_override("font_size",30)
    ui.add_child(label)
    var output = OS.get_environment("SPIDER_CAPTURE_DIR")
    if output.is_empty(): output = "user://motion-frames"
    DirAccess.make_dir_recursive_absolute(output)
    var driver = player.animation_driver
    driver.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var index = 0
    for entry in [["Idle",20],["StartRun",8],["Run",45],["StopRun",9],["Idle",15],["WallJumpLeft",10],["WallJumpRight",10],["AirJumpLeft",12],["AirJumpRight",12],["Fall",20],["LandRun",8],["Run",40],["HardLand",15],["Idle",30]]:
        label.text = "SPIDER CITY / " + entry[0].to_upper()
        driver._play_state(entry[0],1.0)
        driver.animation_player.speed_scale = 1.0
        for frame in entry[1]:
            driver.advance_animation(1.0/30.0)
            await process_frame
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(output+"/frame-%04d.png" % index)
            index += 1
    block.queue_free()
    await process_frame
    quit()
