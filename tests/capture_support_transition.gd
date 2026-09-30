extends "res://tests/capture_ground_support.gd"

func run():
    Engine.max_fps = 60
    preload("res://input_bindings.gd").setup()
    for i in 3: make_view(i)
    label = Label.new()
    label.position = Vector2(20,15)
    label.add_theme_font_size_override("font_size",25)
    label.text = "GROUND SUPPORT → RUN / PELVIS FADE"
    root.add_child(label)
    var output = OS.get_environment("SPIDER_CAPTURE_DIR")
    if output.is_empty():
        quit(2)
        return
    DirAccess.make_dir_recursive_absolute(output)
    for i in 8:
        await physics_frame
        for p in players:
            p.velocity = Vector3.DOWN*2
            p.move_and_slide()
    for frame in 90:
        for p in players:
            var d = p.animation_driver
            d._play_state("Idle" if frame < 30 else "Run",1.0)
            d.advance_animation(1.0/60)
        await process_frame
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_jpg(output+"/frame-%04d.jpg" % frame,.92)
        if frame in [29,31,35,40]:
            root.get_texture().get_image().save_png("res://docs/validation/support-transition-%02d.png" % frame)
    print("SUPPORT_TRANSITION_CAPTURE: 90 frames, real tree crossfade and automatic modifiers")
    quit()
