extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")
const COLLECTIBLE_SCRIPT = preload("res://collectible.gd")
const RING_SCRIPT = preload("res://ring.gd")
const DRONE_SCRIPT = preload("res://drone.gd")
const ROSTER = preload("res://character_roster.gd")
const CHARACTER_PREVIEW_SCRIPT = preload("res://character_preview.gd")
const AUDIO_MANAGER_SCRIPT = preload("res://audio_manager.gd")
const WORLD_DECORATOR_SCRIPT = preload("res://world_decorator.gd")
const GRAFFITI_MANAGER_SCRIPT = preload("res://graffiti_manager.gd")
const PLAYER_SFX_SCRIPT = preload("res://player_sfx.gd")
const TITLE_LOGO = preload("res://art/ui/spider_city_logo.svg")

var player = null
var game_state = "menu"
var mission = 0
var mission_count = 0
var mission_total = 0
var mission_timer = 0.0
var run_time = 0.0
var deaths = 0
var enemies_left = 0
var best_time = -1.0
var selected_character = 0
var character_overlay = null
var character_name_label = null
var character_class_label = null
var character_stats_label = null
var character_info_label = null
var preview_character = null
var audio_manager = null
var audio_overlay = null
var master_slider = null
var music_slider = null
var sfx_slider = null

var title_overlay = null
var mission_label = null
var counter_label = null
var timer_label = null
var health_label = null
var movement_label = null
var message_label = null
var result_overlay = null

var final_beacon_position = Vector3(62.0, 51.5, 66.0)

func _ready():
    _setup_input()
    _load_save()
    _build_environment()
    _build_ground_and_city()
    _build_world_decorator()
    _build_player()
    _build_audio()
    _build_ui()
    _build_graffiti()
    _show_menu()

func _build_world_decorator():
    var decorator = WORLD_DECORATOR_SCRIPT.new()
    decorator.name = "WorldDecorator"
    add_child(decorator)
    decorator.decorate_city(self)

func _build_graffiti():
    var graffiti_manager = GRAFFITI_MANAGER_SCRIPT.new()
    graffiti_manager.name = "GraffitiManager"
    add_child(graffiti_manager)
    graffiti_manager.setup(self)

func _process(delta):
    if game_state == "menu":
        if Input.is_action_just_pressed("audio_settings"):
            _toggle_audio_settings()
        if audio_overlay != null and audio_overlay.visible:
            if Input.is_action_just_pressed("close_menu"):
                _toggle_audio_settings()
            return
        if Input.is_action_just_pressed("start_game"):
            _show_character_select()
        return

    if game_state == "character_select":
        if Input.is_action_just_pressed("move_left"):
            _change_character(-1)
        elif Input.is_action_just_pressed("move_right"):
            _change_character(1)
        elif Input.is_action_just_pressed("start_game"):
            _lock_character_and_start()
        return

    if game_state == "won":
        if Input.is_action_just_pressed("start_game") or Input.is_action_just_pressed("restart"):
            get_tree().reload_current_scene()
        return

    if game_state != "playing":
        return

    run_time += delta

    if mission == 2 or mission == 4:
        mission_timer -= delta
        if mission_timer <= 0.0:
            if mission == 2:
                _restart_ring_mission()
            elif mission == 4:
                _restart_final_run()

    _update_hud()

func _setup_input():
    _bind_key("move_forward", KEY_W)
    _bind_key("move_back", KEY_S)
    _bind_key("move_left", KEY_A)
    _bind_key("move_right", KEY_D)
    _bind_key("jump", KEY_SPACE)
    _bind_key("grapple", KEY_SHIFT)
    _bind_key("zip", KEY_Q)
    _bind_key("interact", KEY_F)
    _bind_key("restart", KEY_R)
    _bind_key("start_game", KEY_ENTER)
    _bind_key("audio_settings", KEY_O)
    _bind_key("close_menu", KEY_ESCAPE)
    _bind_mouse("attack", MOUSE_BUTTON_LEFT)
    _bind_mouse("special_attack", MOUSE_BUTTON_RIGHT)

func _bind_key(action_name, key_code):
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    var ev = InputEventKey.new()
    ev.physical_keycode = key_code
    if not InputMap.action_has_event(action_name, ev):
        InputMap.action_add_event(action_name, ev)

func _bind_mouse(action_name, button_index):
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)
    var ev = InputEventMouseButton.new()
    ev.button_index = button_index
    if not InputMap.action_has_event(action_name, ev):
        InputMap.action_add_event(action_name, ev)

func _build_environment():
    var world_env = WorldEnvironment.new()
    var env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 1.15
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.glow_enabled = true
    env.glow_intensity = 0.10
    env.fog_enabled = true
    env.fog_density = 0.0020
    env.fog_aerial_perspective = 0.28
    env.fog_light_color = Color("#b8d9ff")

    var sky = Sky.new()
    var sky_mat = ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("#4c8ee8")
    sky_mat.sky_horizon_color = Color("#a5d8ff")
    sky_mat.ground_bottom_color = Color("#172233")
    sky_mat.ground_horizon_color = Color("#415d79")
    sky.sky_material = sky_mat
    env.sky = sky

    world_env.environment = env
    add_child(world_env)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
    sun.light_energy = 1.55
    sun.shadow_enabled = true
    add_child(sun)

    var fill = DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-18.0, 142.0, 0.0)
    fill.light_energy = 0.22
    fill.light_color = Color("#83a9ff")
    add_child(fill)

func _build_ground_and_city():
    _add_static_box("Ground", Vector3(0, -1.5, 0), Vector3(240, 3, 240), Color("#273141"))

    # Four broad crossing roads establish recognizable city blocks.
    var road_color = Color("#191f2a")
    for z in [-45.0, 0.0, 45.0]:
        _add_visual_box("RoadX_%s" % str(z), Vector3(0, 0.03, z), Vector3(240, 0.09, 13), road_color, false)
    for x in [-45.0, 0.0, 45.0]:
        _add_visual_box("RoadZ_%s" % str(x), Vector3(x, 0.03, 0), Vector3(13, 0.09, 240), road_color, false)

    # Lane paint.
    for k in range(-5, 6):
        for z in [-45.0, 0.0, 45.0]:
            _add_visual_box("LaneX_%d_%d" % [int(z), k], Vector3(k * 19.0, 0.07, z), Vector3(7.5, 0.03, 0.28), Color("#e8d678"), true)
        for x in [-45.0, 0.0, 45.0]:
            _add_visual_box("LaneZ_%d_%d" % [int(x), k], Vector3(x, 0.07, k * 19.0), Vector3(0.28, 0.03, 7.5), Color("#e8d678"), true)

    # Main playable towers. Sizes intentionally vary so good swing anchors differ from bad ones.
    var specs = [
        [Vector3(-84, 12, -82), Vector3(20,24,20), Color("#495870")],
        [Vector3(-58, 20, -82), Vector3(18,40,18), Color("#34445c")],
        [Vector3(-22, 14, -82), Vector3(22,28,20), Color("#52627b")],
        [Vector3(22, 22, -82), Vector3(22,44,20), Color("#36455f")],
        [Vector3(62, 15, -82), Vector3(22,30,20), Color("#4c5c75")],
        [Vector3(88, 25, -82), Vector3(18,50,18), Color("#2f3d53")],

        [Vector3(-84, 18, -26), Vector3(20,36,20), Color("#3b4b64")],
        [Vector3(-60, 11, -26), Vector3(18,22,20), Color("#59677e")],
        [Vector3(-22, 24, -26), Vector3(22,48,20), Color("#303e55")],
        [Vector3(22, 16, -26), Vector3(22,32,20), Color("#455570")],
        [Vector3(62, 23, -26), Vector3(22,46,20), Color("#334159")],
        [Vector3(88, 14, -26), Vector3(18,28,20), Color("#52627b")],

        [Vector3(-84, 13, 26), Vector3(20,26,20), Color("#4f5f78")],
        [Vector3(-60, 26, 26), Vector3(18,52,20), Color("#2d3a50")],
        [Vector3(-22, 17, 26), Vector3(22,34,20), Color("#42516a")],
        [Vector3(22, 27, 26), Vector3(22,54,20), Color("#2e3b50")],
        [Vector3(62, 18, 26), Vector3(22,36,20), Color("#41526c")],
        [Vector3(88, 22, 26), Vector3(18,44,20), Color("#35445d")],

        [Vector3(-84, 22, 82), Vector3(20,44,20), Color("#34435b")],
        [Vector3(-60, 15, 82), Vector3(18,30,20), Color("#50617a")],
        [Vector3(-22, 25, 82), Vector3(22,50,20), Color("#314057")],
        [Vector3(22, 18, 82), Vector3(22,36,20), Color("#485972")],
        [Vector3(62, 25, 66), Vector3(24,50,24), Color("#2d3b50")],
        [Vector3(88, 16, 82), Vector3(18,32,20), Color("#465670")]
    ]

    var index = 0
    for spec in specs:
        _add_building("Building_%02d" % index, spec[0], spec[1], spec[2])
        index += 1

    # Start building.
    _add_building("StartTower", Vector3(0, 8, 0), Vector3(18,16,18), Color("#586a82"))

    # Small park regions and rooftop props make the city less box-like.
    _add_visual_box("ParkA", Vector3(-84, 0.08, 66), Vector3(26,0.12,20), Color("#355b43"), false)
    _add_visual_box("ParkB", Vector3(76, 0.08, -2), Vector3(26,0.12,22), Color("#3b6248"), false)
    _add_street_lights()
    _add_billboards()

func _add_building(node_name, pos, size, color):
    var body = _add_static_box(node_name, pos, size, color)
    var accent = color.lightened(0.22)

    _add_child_box(body, "RoofTrim", Vector3(0,size.y*0.5+0.13,0), Vector3(size.x*0.88,0.24,size.z*0.88), Color("#65c8ff"), true)

    # Vertical architectural ribs.
    var ox = size.x * 0.5 - 0.16
    var oz = size.z * 0.5 - 0.16
    for x in [-ox, ox]:
        for z in [-oz, oz]:
            _add_child_box(body, "Rib", Vector3(x,0,z), Vector3(0.22,size.y+0.04,0.22), accent, false)

    _add_windows(body, size)
    _add_rooftop_props(body, size, accent)

func _add_windows(parent, size):
    var glow = Color("#d8f2ff")
    var floors = int(clamp(floor((size.y - 4.0) / 4.2), 3.0, 9.0))
    var cols_x = int(clamp(floor((size.x - 3.0) / 3.0), 3.0, 6.0))
    var cols_z = int(clamp(floor((size.z - 3.0) / 3.0), 3.0, 6.0))

    for floor_idx in range(floors):
        var t = float(floor_idx) / float(max(floors - 1, 1))
        var y = lerp(-size.y*0.5 + 2.7, size.y*0.5 - 2.3, t)
        for i in range(cols_x):
            var tx = float(i) / float(max(cols_x - 1,1))
            var x = lerp(-size.x*0.36, size.x*0.36, tx)
            _add_child_box(parent, "WF", Vector3(x,y,size.z*0.5+0.045), Vector3(1.05,1.35,0.08), glow, true)
            _add_child_box(parent, "WB", Vector3(x,y,-size.z*0.5-0.045), Vector3(1.05,1.35,0.08), glow.darkened(0.12), true)
        for j in range(cols_z):
            var tz = float(j) / float(max(cols_z - 1,1))
            var z = lerp(-size.z*0.36, size.z*0.36, tz)
            _add_child_box(parent, "WL", Vector3(-size.x*0.5-0.045,y,z), Vector3(0.08,1.35,1.05), glow.darkened(0.05), true)
            _add_child_box(parent, "WR", Vector3(size.x*0.5+0.045,y,z), Vector3(0.08,1.35,1.05), glow, true)

func _add_rooftop_props(parent, size, accent):
    var y = size.y*0.5 + 0.60
    _add_child_box(parent, "HVAC1", Vector3(-size.x*0.20,y,-size.z*0.15), Vector3(2.8,1.0,2.1), accent, false)
    _add_child_box(parent, "HVAC2", Vector3(size.x*0.16,y,size.z*0.18), Vector3(2.2,0.8,2.6), accent.darkened(0.12), false)

    var antenna = MeshInstance3D.new()
    var ant_mesh = CylinderMesh.new()
    ant_mesh.top_radius = 0.10
    ant_mesh.bottom_radius = 0.10
    ant_mesh.height = 4.5
    ant_mesh.radial_segments = 10
    antenna.mesh = ant_mesh
    antenna.position = Vector3(size.x*0.24, y+2.1, -size.z*0.20)
    antenna.material_override = _make_material(Color("#aab6c7"), false)
    parent.add_child(antenna)

func _add_street_lights():
    for x in [-54.0, -18.0, 18.0, 54.0]:
        for z in [-42.0, -6.0, 30.0, 66.0]:
            var holder = Node3D.new()
            holder.position = Vector3(x,0,z)
            add_child(holder)

            var pole = MeshInstance3D.new()
            var pole_mesh = CylinderMesh.new()
            pole_mesh.top_radius = 0.11
            pole_mesh.bottom_radius = 0.13
            pole_mesh.height = 7.0
            pole_mesh.radial_segments = 10
            pole.mesh = pole_mesh
            pole.position = Vector3(0,3.5,0)
            pole.material_override = _make_material(Color("#8f9caf"), false)
            holder.add_child(pole)

            var bulb = MeshInstance3D.new()
            var bulb_mesh = SphereMesh.new()
            bulb_mesh.radius = 0.20
            bulb_mesh.height = 0.40
            bulb_mesh.radial_segments = 10
            bulb_mesh.rings = 5
            bulb.mesh = bulb_mesh
            bulb.position = Vector3(0,7.0,0)
            bulb.material_override = _make_material(Color("#ffd89b"), true)
            holder.add_child(bulb)

func _add_billboards():
    var positions = [Vector3(-22, 34, -71.8), Vector3(62, 38, -15.8), Vector3(-60, 39, 36.2)]
    var colors = [Color("#ff4f88"), Color("#48f0d0"), Color("#ffd44f")]
    for i in range(positions.size()):
        _add_visual_box("Billboard_%d" % i, positions[i], Vector3(7.0,3.0,0.30), colors[i], true)

func _build_player():
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 17.4, 0)
    add_child(player)
    player.add_to_group("player")
    var player_sfx = Node.new()
    player_sfx.name = "PlayerSFX"
    player_sfx.set_script(PLAYER_SFX_SCRIPT)
    player.add_child(player_sfx)
    player.health_changed.connect(_on_health_changed)
    player.player_died.connect(_on_player_died)

func _build_audio():
    audio_manager = Node.new()
    audio_manager.name = "AudioManager"
    audio_manager.set_script(AUDIO_MANAGER_SCRIPT)
    add_child(audio_manager)

func _build_ui():
    var ui = CanvasLayer.new()
    add_child(ui)

    var hud_panel = ColorRect.new()
    hud_panel.position = Vector2(18,18)
    hud_panel.size = Vector2(520,164)
    hud_panel.color = Color(0.025,0.035,0.065,0.82)
    ui.add_child(hud_panel)

    mission_label = Label.new()
    mission_label.position = Vector2(34,30)
    mission_label.add_theme_font_size_override("font_size",23)
    ui.add_child(mission_label)

    counter_label = Label.new()
    counter_label.position = Vector2(34,65)
    counter_label.add_theme_font_size_override("font_size",17)
    ui.add_child(counter_label)

    timer_label = Label.new()
    timer_label.position = Vector2(34,92)
    timer_label.add_theme_font_size_override("font_size",16)
    ui.add_child(timer_label)

    health_label = Label.new()
    health_label.position = Vector2(34,119)
    health_label.add_theme_font_size_override("font_size",16)
    ui.add_child(health_label)

    movement_label = Label.new()
    movement_label.position = Vector2(34,146)
    movement_label.add_theme_font_size_override("font_size",16)
    movement_label.add_theme_color_override("font_color", Color("#7ee8ff"))
    ui.add_child(movement_label)

    message_label = Label.new()
    message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    message_label.position = Vector2(-365,24)
    message_label.size = Vector2(730,70)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size",18)
    ui.add_child(message_label)

    var crosshair = Label.new()
    crosshair.set_anchors_preset(Control.PRESET_CENTER)
    crosshair.position = Vector2(-8,-16)
    crosshair.text = "+"
    crosshair.add_theme_font_size_override("font_size",28)
    ui.add_child(crosshair)

    title_overlay = ColorRect.new()
    title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    title_overlay.color = Color(0.015,0.02,0.045,0.90)
    ui.add_child(title_overlay)

    var logo = TextureRect.new()
    logo.texture = TITLE_LOGO
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.set_anchors_preset(Control.PRESET_CENTER)
    logo.position = Vector2(-440,-245)
    logo.size = Vector2(880,300)
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_overlay.add_child(logo)

    var subtitle = Label.new()
    subtitle.set_anchors_preset(Control.PRESET_CENTER)
    subtitle.position = Vector2(-420,45)
    subtitle.size = Vector2(840,230)
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.text = "PS2 / urban traversal prototype v0.1\n\nWeb swing • graffiti • multiplayer foundation • character roster\n\nPRESS ENTER FOR CHARACTER SELECT\n\nO = AUDIO SETTINGS"
    subtitle.add_theme_font_size_override("font_size",20)
    title_overlay.add_child(subtitle)

    character_overlay = ColorRect.new()
    character_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    character_overlay.color = Color(0.012,0.018,0.040,0.96)
    character_overlay.visible = false
    ui.add_child(character_overlay)

    var select_title = Label.new()
    select_title.position = Vector2(42,28)
    select_title.text = "SELECT YOUR CHARACTER"
    select_title.add_theme_font_size_override("font_size",32)
    character_overlay.add_child(select_title)

    var preview_container = SubViewportContainer.new()
    preview_container.position = Vector2(40,92)
    preview_container.size = Vector2(560,560)
    preview_container.stretch = true
    character_overlay.add_child(preview_container)

    var preview_viewport = SubViewport.new()
    preview_viewport.size = Vector2i(560,560)
    preview_viewport.transparent_bg = true
    preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview_container.add_child(preview_viewport)

    var preview_camera = Camera3D.new()
    preview_camera.position = Vector3(0.0,0.15,5.6)
    preview_camera.fov = 45.0
    preview_camera.current = true
    preview_viewport.add_child(preview_camera)

    var key_light = DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-30,-25,0)
    key_light.light_energy = 1.8
    preview_viewport.add_child(key_light)
    var rim_light = DirectionalLight3D.new()
    rim_light.rotation_degrees = Vector3(15,145,0)
    rim_light.light_energy = 0.8
    rim_light.light_color = Color("#79b8ff")
    preview_viewport.add_child(rim_light)

    preview_character = Node3D.new()
    preview_character.set_script(CHARACTER_PREVIEW_SCRIPT)
    preview_character.position = Vector3(0,-0.05,0)
    preview_viewport.add_child(preview_character)

    character_name_label = Label.new()
    character_name_label.position = Vector2(650,115)
    character_name_label.size = Vector2(560,55)
    character_name_label.add_theme_font_size_override("font_size",36)
    character_overlay.add_child(character_name_label)

    character_class_label = Label.new()
    character_class_label.position = Vector2(652,166)
    character_class_label.size = Vector2(520,40)
    character_class_label.add_theme_font_size_override("font_size",20)
    character_overlay.add_child(character_class_label)

    character_stats_label = Label.new()
    character_stats_label.position = Vector2(652,224)
    character_stats_label.size = Vector2(520,220)
    character_stats_label.add_theme_font_size_override("font_size",18)
    character_overlay.add_child(character_stats_label)

    character_info_label = Label.new()
    character_info_label.position = Vector2(652,448)
    character_info_label.size = Vector2(550,210)
    character_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    character_info_label.add_theme_font_size_override("font_size",16)
    character_overlay.add_child(character_info_label)

    var select_help = Label.new()
    select_help.position = Vector2(40,670)
    select_help.size = Vector2(1200,42)
    select_help.text = "A / D: change character     ENTER: LOCK IN     •     Model rotates automatically"
    select_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    select_help.add_theme_font_size_override("font_size",18)
    character_overlay.add_child(select_help)

    audio_overlay = ColorRect.new()
    audio_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    audio_overlay.color = Color(0.01,0.015,0.035,0.965)
    audio_overlay.visible = false
    ui.add_child(audio_overlay)

    var audio_title = Label.new()
    audio_title.position = Vector2(420,110)
    audio_title.size = Vector2(440,70)
    audio_title.text = "AUDIO SETTINGS"
    audio_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    audio_title.add_theme_font_size_override("font_size",34)
    audio_overlay.add_child(audio_title)

    master_slider = _make_audio_slider(audio_overlay, "MASTER VOLUME", Vector2(390,220), "Master")
    music_slider = _make_audio_slider(audio_overlay, "MUSIC", Vector2(390,330), "Music")
    sfx_slider = _make_audio_slider(audio_overlay, "SFX", Vector2(390,440), "SFX")

    var audio_help = Label.new()
    audio_help.position = Vector2(390,555)
    audio_help.size = Vector2(500,90)
    audio_help.text = "Changes save automatically.\\nESC = back"
    audio_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    audio_help.add_theme_font_size_override("font_size",17)
    audio_overlay.add_child(audio_help)

    result_overlay = ColorRect.new()
    result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    result_overlay.color = Color(0.01,0.02,0.04,0.91)
    result_overlay.visible = false
    ui.add_child(result_overlay)

func _make_audio_slider(parent: Control, label_text: String, pos: Vector2, bus_name: String):
    var label = Label.new()
    label.position = pos
    label.size = Vector2(500,30)
    label.text = label_text
    label.add_theme_font_size_override("font_size",18)
    parent.add_child(label)

    var slider = HSlider.new()
    slider.position = pos + Vector2(0,36)
    slider.size = Vector2(500,34)
    slider.min_value = 0.0
    slider.max_value = 1.0
    slider.step = 0.01
    slider.value = audio_manager.get_volume(bus_name)
    slider.value_changed.connect(func(value): audio_manager.set_volume(bus_name, value))
    parent.add_child(slider)
    return slider

func _toggle_audio_settings():
    if audio_overlay == null:
        return
    audio_overlay.visible = not audio_overlay.visible
    if audio_overlay.visible:
        master_slider.value = audio_manager.get_volume("Master")
        music_slider.value = audio_manager.get_volume("Music")
        sfx_slider.value = audio_manager.get_volume("SFX")

func _show_menu():
    game_state = "menu"
    player.set_active(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    title_overlay.visible = true
    character_overlay.visible = false
    mission_label.text = ""
    counter_label.text = ""
    timer_label.text = ""
    health_label.text = ""
    movement_label.text = ""
    message_label.text = ""

func _show_character_select():
    game_state = "character_select"
    title_overlay.visible = false
    audio_overlay.visible = false
    character_overlay.visible = true
    player.set_active(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _refresh_character_select()

func _change_character(direction):
    selected_character = posmod(selected_character + direction, ROSTER.count())
    _refresh_character_select()

func _refresh_character_select():
    var data = ROSTER.get_character(selected_character)
    character_name_label.text = data["name"]
    character_class_label.text = data["class"]
    var stats = data["stats"]
    character_stats_label.text = "SPEED          %s\nACCELERATION   %s\nSWING          %s\nAIR CONTROL    %s\nCOMBAT         %s\nDEFENSE        %s" % [
        ROSTER.stars(stats["speed"]), ROSTER.stars(stats["acceleration"]), ROSTER.stars(stats["swing"]),
        ROSTER.stars(stats["air"]), ROSTER.stars(stats["combat"]), ROSTER.stars(stats["defense"])]
    character_info_label.text = "MOVEMENT\n%s\n\nSPECIAL\n%s\n\n+ %s\n- %s" % [data["movement"], data["special"], data["strength"], data["weakness"]]
    if preview_character != null and preview_character.has_method("rebuild"):
        preview_character.rebuild(selected_character)

func _lock_character_and_start():
    character_overlay.visible = false
    player.set_character(selected_character)
    _start_game()

func _start_game():
    title_overlay.visible = false
    game_state = "playing"
    mission = 1
    run_time = 0.0
    deaths = 0
    player.set_active(true)
    player.heal_full()
    _start_collect_mission()

func _clear_mission_nodes():
    for node in get_tree().get_nodes_in_group("mission_nodes"):
        if node != null and is_instance_valid(node):
            node.queue_free()

func _start_collect_mission():
    _clear_mission_nodes()
    mission = 1
    mission_count = 0
    var points = [
        Vector3(-22, 49.5, -26), Vector3(22, 33.5, -26), Vector3(62, 47.5, -26),
        Vector3(22, 55.5, 26), Vector3(-60, 53.5, 26), Vector3(-22, 51.5, 82),
        Vector3(62, 51.5, 66), Vector3(-58, 41.5, -82)
    ]
    mission_total = points.size()
    for p in points:
        var orb = Area3D.new()
        orb.position = p
        orb.set_script(COLLECTIBLE_SCRIPT)
        orb.add_to_group("mission_nodes")
        add_child(orb)
        orb.collected.connect(_on_orb_collected)
    message_label.text = "MISSION 1 — collect the cyan data shards across the rooftops."
    _update_hud()

func _on_orb_collected():
    if mission != 1:
        return
    mission_count += 1
    if mission_count >= mission_total:
        message_label.text = "Nice. Traversal test unlocked."
        _start_ring_mission()

func _start_ring_mission():
    _clear_mission_nodes()
    mission = 2
    mission_count = 0
    mission_timer = 52.0
    var points = [
        Vector3(6,26,-12), Vector3(22,37,-36), Vector3(34,45,-64), Vector3(62,39,-56),
        Vector3(78,34,-30), Vector3(54,39,0), Vector3(34,48,24), Vector3(14,42,44),
        Vector3(-18,40,48), Vector3(-42,43,30)
    ]
    mission_total = points.size()
    for p in points:
        var ring = Area3D.new()
        ring.position = p
        ring.set_script(RING_SCRIPT)
        ring.add_to_group("mission_nodes")
        add_child(ring)
        ring.passed.connect(_on_ring_passed)
    player.set_spawn_position(Vector3(0,17.4,0))
    message_label.text = "MISSION 2 — hit every gold ring before time runs out. Keep your swing momentum."
    _update_hud()

func _on_ring_passed(_ring):
    if mission != 2:
        return
    mission_count += 1
    if mission_count >= mission_total:
        _start_combat_mission()

func _restart_ring_mission():
    message_label.text = "Time up — traversal course restarted."
    player.global_position = Vector3(0,17.4,0)
    player.velocity = Vector3.ZERO
    _start_ring_mission()

func _start_combat_mission():
    _clear_mission_nodes()
    mission = 3
    mission_count = 0
    var positions = [
        Vector3(-22,52,-26), Vector3(22,58,26), Vector3(62,49,-26),
        Vector3(-60,55,26), Vector3(-22,53,82), Vector3(62,54,66)
    ]
    enemies_left = positions.size()
    mission_total = enemies_left
    for p in positions:
        var drone = CharacterBody3D.new()
        drone.position = p
        drone.set_script(DRONE_SCRIPT)
        drone.add_to_group("mission_nodes")
        add_child(drone)
        drone.set_target(player)
        drone.defeated.connect(_on_drone_defeated)
    message_label.text = "MISSION 3 — hostile drones! Use LMB combos and your RMB special."
    _update_hud()

func _on_drone_defeated(_drone):
    if mission != 3:
        return
    mission_count += 1
    enemies_left = max(0, mission_total - mission_count)
    if mission_count >= mission_total:
        _start_final_mission()

func _start_final_mission():
    _clear_mission_nodes()
    mission = 4
    mission_count = 0
    mission_total = 1
    mission_timer = 38.0
    player.set_spawn_position(Vector3(-84,45,-82))
    player.global_position = Vector3(-84,45,-82)
    player.velocity = Vector3.ZERO
    player.heal_full()
    _add_final_beacon()
    message_label.text = "FINAL MISSION — reach the magenta beacon before the clock hits zero."
    _update_hud()

func _restart_final_run():
    message_label.text = "Final run reset — try a better web line."
    _start_final_mission()

func _add_final_beacon():
    var area = Area3D.new()
    area.position = final_beacon_position
    area.collision_layer = 0
    area.collision_mask = 1
    area.add_to_group("mission_nodes")

    var mesh_instance = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 6.0
    mesh.radial_segments = 18
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _make_material(Color("#ff4d9a"), true)
    area.add_child(mesh_instance)

    var collision = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 2.5
    collision.shape = shape
    area.add_child(collision)

    area.body_entered.connect(_on_final_beacon_entered)
    add_child(area)

func _on_final_beacon_entered(body):
    if mission == 4 and body == player:
        _win_game()

func _win_game():
    game_state = "won"
    player.set_active(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    var is_record = best_time < 0.0 or run_time < best_time
    if is_record:
        best_time = run_time
        _save_best_time()

    result_overlay.visible = true
    var label = Label.new()
    label.set_anchors_preset(Control.PRESET_CENTER)
    label.position = Vector2(-400,-170)
    label.size = Vector2(800,360)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var record_line = "NEW BEST TIME!" if is_record else "Best: %.2fs" % best_time
    label.text = "CITY SAVED\n\nTotal time: %.2fs\nDeaths: %d\n%s\n\nPRESS ENTER OR R TO PLAY AGAIN" % [run_time, deaths, record_line]
    label.add_theme_font_size_override("font_size",30)
    result_overlay.add_child(label)

func _on_health_changed(_value):
    _update_hud()

func _on_player_died():
    deaths += 1
    message_label.text = "Down, but not out — checkpoint respawn."

func _update_hud():
    if game_state != "playing":
        return
    mission_label.text = "MISSION %d / 4" % mission
    health_label.text = "Health: %d   |   Deaths: %d   |   Run: %.1fs" % [player.health, deaths, run_time]
    movement_label.text = "MOVEMENT: %s" % player.get_movement_state_name()

    if mission == 1:
        counter_label.text = "Data shards: %d / %d" % [mission_count, mission_total]
        timer_label.text = "No time limit"
    elif mission == 2:
        counter_label.text = "Traversal rings: %d / %d" % [mission_count, mission_total]
        timer_label.text = "Time left: %.1fs" % max(0.0, mission_timer)
    elif mission == 3:
        counter_label.text = "Drones defeated: %d / %d" % [mission_count, mission_total]
        timer_label.text = "LMB = combo   |   RMB = special"
    elif mission == 4:
        counter_label.text = "Reach the final beacon"
        timer_label.text = "Time left: %.1fs" % max(0.0, mission_timer)

func _load_save():
    var config = ConfigFile.new()
    var err = config.load("user://web_runner_save.cfg")
    if err == OK:
        best_time = float(config.get_value("scores", "best_time", -1.0))

func _save_best_time():
    var config = ConfigFile.new()
    config.set_value("scores", "best_time", best_time)
    config.save("user://web_runner_save.cfg")

func _add_static_box(node_name, pos, size, color):
    var body = StaticBody3D.new()
    body.name = node_name
    body.position = pos
    body.collision_layer = 1
    body.collision_mask = 1

    var mesh_instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _make_material(color, false)
    body.add_child(mesh_instance)

    var collision = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)

    add_child(body)
    return body

func _add_visual_box(node_name, pos, size, color, glow):
    var instance = MeshInstance3D.new()
    instance.name = node_name
    instance.position = pos
    var mesh = BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.material_override = _make_material(color, glow)
    add_child(instance)
    return instance

func _add_child_box(parent, node_name, pos, size, color, glow):
    var instance = MeshInstance3D.new()
    instance.name = node_name
    instance.position = pos
    var mesh = BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.material_override = _make_material(color, glow)
    parent.add_child(instance)
    return instance

func _make_material(color, glow):
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.72
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.8
    return mat
