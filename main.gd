extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")
const COLLECTIBLE_SCRIPT = preload("res://collectible.gd")
const RING_SCRIPT = preload("res://ring.gd")
const DRONE_SCRIPT = preload("res://drone.gd")
const ROSTER = preload("res://character_roster.gd")
const CHARACTER_SELECT_SCRIPT = preload("res://character_select_screen.gd")
const AUDIO_MANAGER_SCRIPT = preload("res://audio_manager.gd")
const WORLD_DECORATOR_SCRIPT = preload("res://world_decorator.gd")
const GRAFFITI_MANAGER_SCRIPT = preload("res://graffiti_manager.gd")
const PLAYER_SFX_SCRIPT = preload("res://player_sfx.gd")
const LOADING_SCREEN_SCRIPT = preload("res://loading_screen.gd")
const TITLE_LOGO = preload("res://art/ui/spider_city_logo.svg")

# Traversal city dimensions and road hierarchy. The original mission core is
# kept around the origin; deterministic outer districts extend the playable
# skyline without changing any movement code.
const CITY_HALF_EXTENT = 270.0
const CITY_ROADS_X = [-188.0, -116.0, -45.0, 0.0, 45.0, 112.0, 184.0]
const CITY_ROADS_Z = [-184.0, -108.0, -45.0, 0.0, 45.0, 116.0, 190.0]
# Total collidable building volumes, including the legacy StartTower.
const CITY_BUILDING_TARGET = 132
const CITY_LAYOUT_SEED = 0x5C17C1
const CITY_EDGE_MARGIN = 10.0
const CITY_BLOCK_SIDEWALK = 2.6

const CITY_COLORS = [
    Color("#29384f"), Color("#34445c"), Color("#3e5069"),
    Color("#485b75"), Color("#52647c"), Color("#303f58"),
    Color("#43536b"), Color("#27354a")
]

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
var audio_manager = null
var audio_overlay = null
var master_slider = null
var music_slider = null
var sfx_slider = null
var material_cache: Dictionary = {}
var city_root: Node3D = null
var city_infrastructure: Node3D = null
var city_districts: Dictionary = {}
var city_building_count: int = 0
var city_height_min: float = INF
var city_height_max: float = 0.0
var city_tier_counts: Dictionary = {}
var city_heights: Array[float] = []
var loading_screen = null

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
    game_state = "loading"
    _setup_input()
    _load_save()
    _build_loading_screen()
    await get_tree().process_frame
    _set_loading_progress(0.06, "CALIBRATING SKYLINE")
    _build_environment()
    await get_tree().process_frame
    await _build_ground_and_city()
    _set_loading_progress(0.72, "SKINNING CITY FACADES")
    await _build_world_decorator()
    _set_loading_progress(0.82, "SPAWNING RUNNER")
    _build_player()
    await get_tree().process_frame
    _set_loading_progress(0.87, "CONNECTING AUDIO")
    _build_audio()
    _set_loading_progress(0.92, "BUILDING INTERFACE")
    _build_ui()
    await get_tree().process_frame
    _set_loading_progress(0.97, "REGISTERING GRAFFITI ROUTES")
    _build_graffiti()
    _show_menu()
    # Keep keyboard input locked until the loading layer has fully faded. The
    # completed menu remains visible underneath for a seamless transition.
    game_state = "loading"
    if loading_screen != null:
        await loading_screen.finish_loading()
        loading_screen.queue_free()
        loading_screen = null
    game_state = "menu"

func _build_loading_screen():
    loading_screen = CanvasLayer.new()
    loading_screen.name = "StartupLoadingScreen"
    loading_screen.set_script(LOADING_SCREEN_SCRIPT)
    add_child(loading_screen)

func _set_loading_progress(value: float, stage: String):
    if loading_screen != null and is_instance_valid(loading_screen):
        loading_screen.call("set_progress", value, stage)

func _build_world_decorator():
    var decorator = WORLD_DECORATOR_SCRIPT.new()
    decorator.name = "WorldDecorator"
    add_child(decorator)
    await decorator.decorate_city(city_root if city_root != null else self)

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
    _build_city_hierarchy()
    city_building_count = 0
    city_height_min = INF
    city_height_max = 0.0
    city_tier_counts.clear()
    city_heights.clear()

    _add_static_box(
        "Ground",
        Vector3(0, -1.5, 0),
        Vector3(CITY_HALF_EXTENT * 2.0, 3, CITY_HALF_EXTENT * 2.0),
        Color("#273141"),
        city_infrastructure
    )

    # An asymmetric road hierarchy keeps the old central routes intact while
    # producing narrow inner streets and broad outer traversal avenues.
    var road_color = Color("#191f2a")
    for z_value in CITY_ROADS_Z:
        var z_road: float = float(z_value)
        var road_width_x: float = _road_width(z_road)
        _add_visual_box(
            "RoadX_%d" % int(z_road),
            Vector3(0, 0.03, z_road),
            Vector3(CITY_HALF_EXTENT * 2.0, 0.09, road_width_x),
            road_color,
            false,
            city_infrastructure
        )
    var road_z_segments: Array[Vector2] = _road_segments_between(
        CITY_ROADS_Z
    )
    for x_value in CITY_ROADS_X:
        var x_road: float = float(x_value)
        var road_width_z: float = _road_width(x_road)
        for segment_index in range(road_z_segments.size()):
            var segment: Vector2 = road_z_segments[segment_index]
            var segment_length: float = segment.y - segment.x
            _add_visual_box(
                "RoadZ_%d_%02d" % [int(x_road), segment_index],
                Vector3(x_road, 0.03, (segment.x + segment.y) * 0.5),
                Vector3(road_width_z, 0.09, segment_length),
                road_color,
                false,
                city_infrastructure
            )

    _add_avenue_lane_paint()
    _set_loading_progress(0.20, "LAYING OUT STREETS")
    await get_tree().process_frame

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

    var occupied: Array[Rect2] = []
    var index = 0
    for spec in specs:
        _add_building(
            "Building_%03d" % index,
            spec[0],
            spec[1],
            spec[2],
            _tier_for_height(float(spec[1].y)),
            index % 3,
            true
        )
        occupied.append(_building_rect(spec[0], spec[1]))
        index += 1

    # Start building.
    var start_position = Vector3(0, 8, 0)
    var start_size = Vector3(18, 16, 18)
    _add_building(
        "StartTower",
        start_position,
        start_size,
        Color("#586a82"),
        "low",
        2,
        true
    )
    occupied.append(_building_rect(start_position, start_size))
    # Keep all legacy mission, ring, drone, cable, and graffiti routes free of
    # newly generated geometry.
    occupied.append(Rect2(Vector2(-106, -100), Vector2(212, 200)))
    _set_loading_progress(0.34, "RESTORING CENTRAL DISTRICT")
    await get_tree().process_frame

    # Preserve the known-good prototype parks and reserve several larger
    # setbacks so the expanded districts have landmarks and breathing room.
    _add_visual_box("ParkA", Vector3(-84, 0.08, 66), Vector3(26,0.12,20), Color("#355b43"), false, city_infrastructure)
    _add_visual_box("ParkB", Vector3(76, 0.08, -2), Vector3(26,0.12,22), Color("#3b6248"), false, city_infrastructure)
    var outer_open_spaces: Array = [
        [Vector3(-150, 0.08, 78), Vector3(32, 0.12, 26)],
        [Vector3(148, 0.08, 76), Vector3(38, 0.12, 30)],
        [Vector3(-78, 0.08, -148), Vector3(30, 0.12, 24)]
    ]
    for space_index in range(outer_open_spaces.size()):
        var space: Array = outer_open_spaces[space_index]
        _add_visual_box(
            "OuterPlaza_%02d" % space_index,
            space[0],
            space[1],
            Color("#344f43").lightened(float(space_index) * 0.025),
            false,
            city_infrastructure
        )
        occupied.append(_building_rect(space[0], space[1]))

    index = _add_skyline_landmarks(index, occupied)
    _set_loading_progress(0.40, "RAISING SKYLINE LANDMARKS")
    await get_tree().process_frame
    await _add_outer_city_buildings(index, occupied)
    _add_street_lights()
    _add_billboards()
    _report_city_generation()
    _set_loading_progress(0.69, "CITY COLLISION READY")
    await get_tree().process_frame


func _build_city_hierarchy() -> void:
    city_root = Node3D.new()
    city_root.name = "City"
    add_child(city_root)

    city_infrastructure = Node3D.new()
    city_infrastructure.name = "Infrastructure"
    city_root.add_child(city_infrastructure)

    city_districts.clear()
    for district_name in [
        "CentralDistrict",
        "NorthDistrict",
        "SouthDistrict",
        "EastDistrict",
        "WestDistrict",
        "SkylineLandmarks"
    ]:
        var district := Node3D.new()
        district.name = district_name
        city_root.add_child(district)
        city_districts[district_name] = district


func _district_parent_for(position: Vector3, tier: String) -> Node3D:
    if tier == "landmark":
        return city_districts.get("SkylineLandmarks", city_root) as Node3D
    if absf(position.x) <= 110.0 and absf(position.z) <= 110.0:
        return city_districts.get("CentralDistrict", city_root) as Node3D
    if absf(position.x) > absf(position.z):
        var east_west := "EastDistrict" if position.x >= 0.0 else "WestDistrict"
        return city_districts.get(east_west, city_root) as Node3D
    var north_south := "NorthDistrict" if position.z >= 0.0 else "SouthDistrict"
    return city_districts.get(north_south, city_root) as Node3D


func _road_width(coordinate: float) -> float:
    if absf(coordinate) < 0.1:
        return 22.0
    if absf(coordinate) > 175.0:
        return 18.0
    if absf(coordinate) > 100.0:
        return 15.0
    return 13.0


func _road_segments_between(crossing_roads: Array) -> Array[Vector2]:
    var segments: Array[Vector2] = []
    var cursor: float = -CITY_HALF_EXTENT
    for road_value in crossing_roads:
        var coordinate: float = float(road_value)
        var half_width: float = _road_width(coordinate) * 0.5
        var segment_end: float = coordinate - half_width
        if segment_end - cursor > 0.1:
            segments.append(Vector2(cursor, segment_end))
        cursor = coordinate + half_width
    if CITY_HALF_EXTENT - cursor > 0.1:
        segments.append(Vector2(cursor, CITY_HALF_EXTENT))
    return segments


func _add_avenue_lane_paint() -> void:
    var paint := Color("#e8d678")
    var segment_count: int = 25
    var segment_step: float = CITY_HALF_EXTENT * 2.0 / float(segment_count)
    var lane_mesh := BoxMesh.new()
    lane_mesh.size = Vector3(segment_step * 0.42, 0.03, 0.24)

    var lane_multimesh := MultiMesh.new()
    lane_multimesh.transform_format = MultiMesh.TRANSFORM_3D
    lane_multimesh.mesh = lane_mesh
    lane_multimesh.instance_count = (
        segment_count * (CITY_ROADS_X.size() + CITY_ROADS_Z.size())
    )

    var lane_index: int = 0
    for segment in range(segment_count):
        var along: float = -CITY_HALF_EXTENT + (float(segment) + 0.5) * segment_step
        for z_value in CITY_ROADS_Z:
            var z: float = float(z_value)
            lane_multimesh.set_instance_transform(
                lane_index,
                Transform3D(Basis.IDENTITY, Vector3(along, 0.07, z))
            )
            lane_index += 1
        for x_value in CITY_ROADS_X:
            var x: float = float(x_value)
            lane_multimesh.set_instance_transform(
                lane_index,
                Transform3D(
                    Basis(Vector3.UP, PI * 0.5),
                    Vector3(x, 0.075, along)
                )
            )
            lane_index += 1

    var lane_instance := MultiMeshInstance3D.new()
    lane_instance.name = "AvenueLanePaint"
    lane_instance.multimesh = lane_multimesh
    lane_instance.material_override = _make_material(paint, true)
    lane_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    city_infrastructure.add_child(lane_instance)


func _add_skyline_landmarks(index: int, occupied: Array[Rect2]) -> int:
    # Hand-placed skyline anchors sit in different districts so orientation is
    # readable from anywhere in the expanded city. Nearby procedural towers
    # create climbable height gradients toward them.
    var landmarks: Array = [
        [Vector2(-223, -144), Vector3(30, 168, 32), Color("#202f47")],
        [Vector2(220, 148), Vector3(32, 190, 30), Color("#24334c")],
        [Vector2(-80, 153), Vector3(28, 146, 26), Color("#2b3952")],
        [Vector2(145, -146), Vector3(34, 158, 30), Color("#213049")],
        [Vector2(222, 226), Vector3(28, 136, 28), Color("#2d3c55")]
    ]
    for landmark_value in landmarks:
        var landmark: Array = landmark_value
        var ground_position: Vector2 = landmark[0]
        var size: Vector3 = landmark[1]
        var position := Vector3(ground_position.x, size.y * 0.5, ground_position.y)
        _add_building(
            "Building_%03d_Landmark" % index,
            position,
            size,
            landmark[2],
            "landmark",
            4,
            false
        )
        occupied.append(_building_rect(position, size))
        index += 1
    return index


func _add_outer_city_buildings(start_index: int, occupied: Array[Rect2]) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = CITY_LAYOUT_SEED
    var index: int = start_index
    var blocks: Array[Rect2] = _city_block_rects()
    _shuffle_with_rng(blocks, rng)

    # Lots are derived from road-bounded blocks, then consumed in layers. The
    # first pass spreads one building across many blocks before denser blocks
    # receive their alley-separated second, third, or fourth volume.
    var lot_groups: Array = []
    var max_lot_count: int = 0
    var buildings_since_yield: int = 0
    for block in blocks:
        var lots: Array[Rect2] = _lots_for_block(block, rng)
        lot_groups.append(lots)
        max_lot_count = maxi(max_lot_count, lots.size())

    for lot_layer in range(max_lot_count):
        for lots_value in lot_groups:
            if city_building_count >= CITY_BUILDING_TARGET:
                break
            var lots: Array[Rect2] = lots_value
            if lot_layer >= lots.size():
                continue
            if _try_add_city_lot(index, lots[lot_layer], rng, occupied):
                index += 1
                buildings_since_yield += 1
                if buildings_since_yield >= 8:
                    buildings_since_yield = 0
                    _set_loading_progress(
                        lerpf(
                            0.40,
                            0.68,
                            clampf(
                                float(city_building_count)
                                / float(CITY_BUILDING_TARGET),
                                0.0,
                                1.0
                            )
                        ),
                        "ASSEMBLING DISTRICT %03d / %03d" % [
                            city_building_count,
                            CITY_BUILDING_TARGET
                        ]
                    )
                    await get_tree().process_frame
        if city_building_count >= CITY_BUILDING_TARGET:
            break

    if city_building_count < CITY_BUILDING_TARGET:
        push_warning(
            "[CITY] Road-block packing stopped at %d of %d buildings." % [
                city_building_count,
                CITY_BUILDING_TARGET
            ]
        )


func _buildable_axis_intervals(road_coordinates: Array) -> Array[Vector2]:
    var intervals: Array[Vector2] = []
    var cursor: float = -CITY_HALF_EXTENT + CITY_EDGE_MARGIN
    for road_value in road_coordinates:
        var coordinate: float = float(road_value)
        var road_edge: float = _road_width(coordinate) * 0.5
        var interval_end: float = coordinate - road_edge - CITY_BLOCK_SIDEWALK
        if interval_end - cursor >= 15.0:
            intervals.append(Vector2(cursor, interval_end))
        cursor = coordinate + road_edge + CITY_BLOCK_SIDEWALK

    var city_end: float = CITY_HALF_EXTENT - CITY_EDGE_MARGIN
    if city_end - cursor >= 15.0:
        intervals.append(Vector2(cursor, city_end))
    return intervals


func _city_block_rects() -> Array[Rect2]:
    var x_intervals: Array[Vector2] = _buildable_axis_intervals(CITY_ROADS_X)
    var z_intervals: Array[Vector2] = _buildable_axis_intervals(CITY_ROADS_Z)
    var blocks: Array[Rect2] = []
    for x_interval in x_intervals:
        for z_interval in z_intervals:
            blocks.append(Rect2(
                Vector2(x_interval.x, z_interval.x),
                Vector2(
                    x_interval.y - x_interval.x,
                    z_interval.y - z_interval.x
                )
            ))
    return blocks


func _lots_for_block(
    block: Rect2,
    rng: RandomNumberGenerator
) -> Array[Rect2]:
    var edge_inset: float = rng.randf_range(2.0, 4.2)
    var inner: Rect2 = block.grow(-edge_inset)
    if inner.size.x < 12.0 or inner.size.y < 12.0:
        return []

    var columns: int = 1
    var rows: int = 1
    if inner.size.x >= 66.0:
        columns = 3
    elif inner.size.x >= 39.0:
        columns = 2
    if inner.size.y >= 66.0:
        rows = 3
    elif inner.size.y >= 39.0:
        rows = 2

    # Occasional broad slabs leave a longer clear roof/swing edge and stop the
    # road grid from producing the same subdivision in every block.
    if columns > 1 and rows > 1 and rng.randf() < 0.12:
        if rng.randf() < 0.5:
            columns = 1
        else:
            rows = 1

    var alley_x: float = rng.randf_range(4.0, 7.2) if columns > 1 else 0.0
    var alley_z: float = rng.randf_range(4.0, 7.2) if rows > 1 else 0.0
    var cell_width: float = (
        inner.size.x - alley_x * float(columns - 1)
    ) / float(columns)
    var cell_depth: float = (
        inner.size.y - alley_z * float(rows - 1)
    ) / float(rows)
    var lots: Array[Rect2] = []

    for row in range(rows):
        for column in range(columns):
            var cell_position := inner.position + Vector2(
                float(column) * (cell_width + alley_x),
                float(row) * (cell_depth + alley_z)
            )
            var inset_left: float = rng.randf_range(0.8, 2.8)
            var inset_right: float = rng.randf_range(0.8, 2.8)
            var inset_front: float = rng.randf_range(0.8, 2.8)
            var inset_back: float = rng.randf_range(0.8, 2.8)
            var lot := Rect2(
                cell_position + Vector2(inset_left, inset_front),
                Vector2(
                    cell_width - inset_left - inset_right,
                    cell_depth - inset_front - inset_back
                )
            )
            if lot.size.x >= 12.0 and lot.size.y >= 12.0:
                lots.append(lot)

    _shuffle_with_rng(lots, rng)
    return lots


func _shuffle_with_rng(values: Array, rng: RandomNumberGenerator) -> void:
    for index in range(values.size() - 1, 0, -1):
        var swap_index: int = rng.randi_range(0, index)
        var held_value: Variant = values[index]
        values[index] = values[swap_index]
        values[swap_index] = held_value


func _try_add_city_lot(
    index: int,
    lot: Rect2,
    rng: RandomNumberGenerator,
    occupied: Array[Rect2]
) -> bool:
    var center: Vector2 = lot.get_center()
    if not _lot_clears_roads(
        center.x,
        center.y,
        lot.size.x,
        lot.size.y
    ):
        return false

    var candidate: Rect2 = lot.grow(1.2)
    if not _rect_is_clear(candidate, occupied):
        return false

    var tier: String = _choose_city_tier(center, rng)
    var height: float = _height_for_tier(tier, rng)
    var position := Vector3(center.x, height * 0.5, center.y)
    var color: Color = CITY_COLORS[rng.randi_range(0, CITY_COLORS.size() - 1)]
    # Full landmark crowns are reserved for the five authored skyline anchors.
    var style: int = rng.randi_range(0, 3)
    var orientation_degrees: float = 90.0 if rng.randf() < 0.34 else 0.0
    # Swap local footprint axes before a quarter-turn so the resulting world
    # AABB stays inside the road-derived lot reservation.
    var size := Vector3(lot.size.x, height, lot.size.y)
    if orientation_degrees > 0.0:
        size = Vector3(lot.size.y, height, lot.size.x)

    _add_building(
        "Building_%03d" % index,
        position,
        size,
        color,
        tier,
        style,
        false,
        orientation_degrees
    )
    occupied.append(candidate)
    return true


func _lot_clears_roads(x: float, z: float, width: float, depth: float) -> bool:
    for road_x_value in CITY_ROADS_X:
        var road_x: float = float(road_x_value)
        if absf(x - road_x) < width * 0.5 + _road_width(road_x) * 0.5 + 2.4:
            return false
    for road_z_value in CITY_ROADS_Z:
        var road_z: float = float(road_z_value)
        if absf(z - road_z) < depth * 0.5 + _road_width(road_z) * 0.5 + 2.4:
            return false
    return true


func _rect_is_clear(candidate: Rect2, occupied: Array[Rect2]) -> bool:
    for existing in occupied:
        if candidate.intersects(existing, true):
            return false
    return true


func _building_rect(
    position: Vector3,
    size: Vector3,
    padding: float = 0.0
) -> Rect2:
    return Rect2(
        Vector2(
            position.x - size.x * 0.5 - padding,
            position.z - size.z * 0.5 - padding
        ),
        Vector2(size.x + padding * 2.0, size.z + padding * 2.0)
    )


func _choose_city_tier(position: Vector2, rng: RandomNumberGenerator) -> String:
    var landmark_distance: float = _nearest_landmark_distance(position)
    var roll: float = rng.randf()
    if landmark_distance < 58.0:
        return "tall" if roll < 0.72 else "medium"
    if landmark_distance < 102.0:
        return "tall" if roll < 0.42 else "medium"

    # Dense western MDK3 favors closely stepped low/medium roofs. Northern and
    # eastern Jerkovic favors taller anchors and wider street-scale swings.
    if position.x < -105.0:
        if roll < 0.40:
            return "low"
        return "medium" if roll < 0.88 else "tall"
    if position.x > 75.0 or position.y > 95.0:
        if roll < 0.16:
            return "low"
        return "medium" if roll < 0.58 else "tall"
    if roll < 0.27:
        return "low"
    return "medium" if roll < 0.76 else "tall"


func _nearest_landmark_distance(position: Vector2) -> float:
    var nearest: float = INF
    for landmark in [
        Vector2(-223, -144), Vector2(220, 148), Vector2(-80, 153),
        Vector2(145, -146), Vector2(222, 226)
    ]:
        nearest = minf(nearest, position.distance_to(landmark))
    return nearest


func _height_for_tier(tier: String, rng: RandomNumberGenerator) -> float:
    match tier:
        "low":
            return rng.randf_range(8.0, 18.0)
        "tall":
            return rng.randf_range(50.0, 90.0)
        _:
            return rng.randf_range(20.0, 45.0)


func _tier_for_height(height: float) -> String:
    if height < 20.0:
        return "low"
    if height < 50.0:
        return "medium"
    if height < 100.0:
        return "tall"
    return "landmark"

func _add_building(
    node_name: String,
    pos: Vector3,
    size: Vector3,
    color: Color,
    tier: String = "medium",
    style: int = 0,
    legacy_details: bool = false,
    orientation_degrees: float = 0.0
):
    var body = _add_static_box(
        node_name,
        pos,
        size,
        color,
        _district_parent_for(pos, tier)
    )
    body.rotation_degrees.y = orientation_degrees
    var accent = color.lightened(0.22)
    var silhouette_range: float = _building_silhouette_range(tier)
    var detail_range: float = _building_detail_range(tier)
    body.add_to_group("city_building")
    body.set_meta("city_tier", tier)
    body.set_meta("architecture_style", style)
    body.set_meta("floor_count", maxi(3, roundi(float(size.y) / 4.1)))
    body.set_meta("city_detail_range", detail_range)
    body.set_meta("city_silhouette_range", silhouette_range)
    body.set_meta("legacy_roof_kit", legacy_details)

    city_building_count += 1
    city_height_min = minf(city_height_min, size.y)
    city_height_max = maxf(city_height_max, size.y)
    city_heights.append(size.y)
    city_tier_counts[tier] = int(city_tier_counts.get(tier, 0)) + 1

    var base_mesh := body.get_child(0) as MeshInstance3D
    if base_mesh != null:
        base_mesh.visibility_range_end = silhouette_range
        base_mesh.visibility_range_end_margin = 35.0

    # Sparse ribs read at traversal speed without rebuilding the thousands of
    # tiny window meshes now covered by the facade-card decorator.
    var ox = size.x * 0.5 - 0.16
    var oz = size.z * 0.5 - 0.16
    for x in [-ox, ox]:
        for z in [-oz, oz]:
            _add_child_box(body, "Rib", Vector3(x,0,z), Vector3(0.22,size.y+0.04,0.22), accent, false)

    # Preserve the original core's familiar roof kit. New districts receive
    # cheaper, style-driven roof silhouettes from world_decorator.gd.
    if legacy_details:
        _add_rooftop_props(body, size, accent)


func _building_silhouette_range(tier: String) -> float:
    match tier:
        "low":
            return 340.0
        "medium":
            return 470.0
        "tall":
            return 680.0
        "landmark":
            return 1400.0
        _:
            return 420.0


func _building_detail_range(tier: String) -> float:
    match tier:
        "low":
            return 230.0
        "medium":
            return 300.0
        "tall":
            return 410.0
        "landmark":
            return 850.0
        _:
            return 280.0


func _report_city_generation() -> void:
    if city_building_count <= 0:
        return

    var sorted_heights: Array[float] = city_heights.duplicate()
    sorted_heights.sort()
    var middle: int = sorted_heights.size() >> 1
    var median_height: float = sorted_heights[middle]
    if sorted_heights.size() % 2 == 0:
        median_height = (
            sorted_heights[middle - 1] + sorted_heights[middle]
        ) * 0.5

    var summary: String = (
        "[CITY] %d buildings | heights %.1f / %.1f / %.1f m "
        + "(min / median / max) | tiers %s | seed %d"
    ) % [
        city_building_count,
        city_height_min,
        median_height,
        city_height_max,
        str(city_tier_counts),
        CITY_LAYOUT_SEED
    ]
    print(summary)

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
    if parent.has_meta("city_detail_range"):
        antenna.visibility_range_end = float(parent.get_meta("city_detail_range"))
        antenna.visibility_range_end_margin = 25.0
    parent.add_child(antenna)

func _add_street_lights():
    var along_positions = [-232.0, -158.0, -78.0, 78.0, 158.0, 232.0]
    for x_value in along_positions:
        var x: float = float(x_value)
        _add_street_light(Vector3(x, 0, -98.5))
        _add_street_light(Vector3(x, 0, 125.5))
    for z_value in along_positions:
        var z: float = float(z_value)
        _add_street_light(Vector3(-106.5, 0, z))
        _add_street_light(Vector3(121.5, 0, z))


func _add_street_light(world_position: Vector3) -> void:
    var holder = Node3D.new()
    holder.position = world_position
    city_infrastructure.add_child(holder)

    var pole = MeshInstance3D.new()
    var pole_mesh = CylinderMesh.new()
    pole_mesh.top_radius = 0.11
    pole_mesh.bottom_radius = 0.13
    pole_mesh.height = 7.0
    pole_mesh.radial_segments = 10
    pole.mesh = pole_mesh
    pole.position = Vector3(0,3.5,0)
    pole.material_override = _make_material(Color("#8f9caf"), false)
    pole.visibility_range_end = 190.0
    pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
    bulb.visibility_range_end = 220.0
    bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    holder.add_child(bulb)

func _add_billboards():
    var positions = [Vector3(-22, 34, -71.8), Vector3(62, 38, -15.8), Vector3(-60, 39, 36.2)]
    var colors = [Color("#ff4f88"), Color("#48f0d0"), Color("#ffd44f")]
    for i in range(positions.size()):
        _add_visual_box(
            "Billboard_%d" % i,
            positions[i],
            Vector3(7.0,3.0,0.30),
            colors[i],
            true,
            city_districts.get("CentralDistrict", city_root) as Node3D
        )

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

    character_overlay = Control.new()
    character_overlay.name = "CharacterSelectScreen"
    character_overlay.set_script(CHARACTER_SELECT_SCRIPT)
    character_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    character_overlay.visible = false
    ui.add_child(character_overlay)

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
    if character_overlay != null and character_overlay.has_method("show_character"):
        character_overlay.call("show_character", selected_character)

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

func _add_static_box(
    node_name,
    pos,
    size,
    color,
    parent: Node3D = null
):
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

    var target_parent: Node3D = parent if parent != null else self
    target_parent.add_child(body)
    return body

func _add_visual_box(
    node_name,
    pos,
    size,
    color,
    glow,
    parent: Node3D = null
):
    var instance = MeshInstance3D.new()
    instance.name = node_name
    instance.position = pos
    var mesh = BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.material_override = _make_material(color, glow)
    var target_parent: Node3D = parent if parent != null else self
    target_parent.add_child(instance)
    return instance

func _add_child_box(parent, node_name, pos, size, color, glow):
    var instance = MeshInstance3D.new()
    instance.name = node_name
    instance.position = pos
    var mesh = BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.material_override = _make_material(color, glow)
    if parent.has_meta("city_detail_range"):
        instance.visibility_range_end = float(parent.get_meta("city_detail_range"))
        instance.visibility_range_end_margin = 25.0
    if size.y < 2.0 or maxf(size.x, size.z) < 3.2:
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
    return instance

func _make_material(color, glow):
    var key: String = "%s|%s" % [color.to_html(true), str(glow)]
    if material_cache.has(key):
        return material_cache[key]
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.72
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.8
    material_cache[key] = mat
    return mat
