extends Node3D

const PLAYER = preload("res://player.gd")
const ROUTE = [Vector3(0, 20, 4), Vector3(0, 18, -24), Vector3(22, 24, -46), Vector3(44, 31, -20), Vector3(23, 21, 10)]
var player: CharacterBody3D
var marker: MeshInstance3D
var hud: Label
var checkpoint = 0
var elapsed = 0.0
var finished = false
var best = 0.0

func _ready():
    preload("res://input_bindings.gd").setup()
    var environment = WorldEnvironment.new()
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("9bc5d5")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b5cce3")
    env.ambient_light_energy = 0.45
    environment.environment = env
    add_child(environment)
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -35, 0)
    sun.light_energy = 1.0
    sun.shadow_enabled = true
    add_child(sun)
    _box(Vector3(15, -1, -20), Vector3(130, 2, 135), Color("263448"), true)
    # A compact loop: launch roof, swing canyon, wall-run slab, recovery roofs.
    var buildings = [Vector4(-15, 10, 8, 20), Vector4(17, -12, 12, 32), Vector4(-18, -35, 18, 40), Vector4(23, -50, 16, 22), Vector4(49, -42, 15, 45), Vector4(49, -14, 18, 28), Vector4(25, 12, 18, 18), Vector4(-16, -65, 18, 28)]
    for i in buildings.size():
        var b: Vector4 = buildings[i]
        var tint = Color("495e79") if i % 2 == 0 else Color("8b645e")
        _box(Vector3(b.x, b.w / 2, b.y), Vector3(b.z, b.w, b.z), tint, true)
        _box(Vector3(b.x, b.w + 0.2, b.y), Vector3(b.z + 0.4, 0.4, b.z + 0.4), Color("dfac62"), true)
        for floor_index in range(2, int(b.w), 4):
            _box(Vector3(b.x, floor_index, b.y + b.z / 2 + 0.03), Vector3(b.z - 2, 1.2, 0.05), Color("9ad2d6"), false)
        _box(Vector3(b.x - 2, b.w + 1, b.y), Vector3(2, 2, 3), Color("344254"), true)
    _box(Vector3(0, 9, 10), Vector3(12, 18, 12), Color("526f83"), true)
    player = PLAYER.new()
    player.position = Vector3(0, 20, 10)
    add_child(player)
    player.set_active(true)
    var audio = preload("res://audio_manager.gd").new()
    add_child(audio)
    player.add_child(preload("res://player_sfx.gd").new())
    marker = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 1.4
    sphere.height = 2.8
    marker.mesh = sphere
    var glow = StandardMaterial3D.new()
    glow.albedo_color = Color("ffe598")
    glow.emission_enabled = true
    glow.emission = Color("ffb13b")
    marker.material_override = glow
    add_child(marker)
    marker.position = ROUTE[0]
    var ui = CanvasLayer.new()
    add_child(ui)
    hud = Label.new()
    hud.position = Vector2(24, 20)
    hud.add_theme_font_size_override("font_size", 21)
    hud.add_theme_color_override("font_outline_color", Color("142034"))
    hud.add_theme_constant_override("outline_size", 6)
    ui.add_child(hud)
    var crosshair = Label.new()
    crosshair.text = "+"
    crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    ui.add_child(crosshair)
    var save = ConfigFile.new()
    if save.load("user://traversal_block.cfg") == OK:
        best = float(save.get_value("route", "best", 0.0))

func _process(delta):
    if Input.is_action_just_pressed("restart"):
        get_tree().reload_current_scene()
        return
    if not finished:
        elapsed += delta
        if player.position.distance_to(ROUTE[checkpoint]) < 4.0:
            checkpoint += 1
            if checkpoint == ROUTE.size():
                finished = true
                marker.hide()
                if best == 0.0 or elapsed < best:
                    best = elapsed
                    var save = ConfigFile.new()
                    save.set_value("route", "best", best)
                    save.save("user://traversal_block.cfg")
            else:
                marker.position = ROUTE[checkpoint]
    hud.text = "SPIDER CITY / FLOW BLOCK\n%s   %.1fs   BEST %.1fs\n%s / %.1f m/s\nWASD move | W/S reel | Space jump/release | F2 controls\nR restart | Tab city menu\n%s" % ["COMPLETE" if finished else "CHECKPOINT %d / %d" % [checkpoint + 1, ROUTE.size()], elapsed, best, player.get_movement_state_name(), player.velocity.length(), preload("res://input_bindings.gd").hint()]

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
        get_tree().change_scene_to_file("res://Main.tscn")

func _box(pos: Vector3, size: Vector3, color: Color, collision: bool):
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position = pos
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85
    mesh.material_override = material
    add_child(mesh)
    if collision:
        var body = StaticBody3D.new()
        var shape = CollisionShape3D.new()
        var box_shape = BoxShape3D.new()
        box_shape.size = size
        shape.shape = box_shape
        body.add_child(shape)
        mesh.add_child(body)
