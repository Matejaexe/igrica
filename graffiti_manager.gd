extends Node

const GRAFFITI_CANVAS_SCRIPT = preload("res://graffiti_canvas.gd")

const TAG_PANEL_TEXTURES = [
    preload("res://art/tag_panels/tag_panel_01.svg"),
    preload("res://art/tag_panels/tag_panel_02.svg"),
    preload("res://art/tag_panels/tag_panel_03.svg"),
    preload("res://art/tag_panels/tag_panel_04.svg")
]

const COMPLETED_TEXTURES = [
    preload("res://art/graffiti/rushline.svg"),
    preload("res://art/graffiti/static_bloom.svg"),
    preload("res://art/graffiti/no_signal.svg"),
    preload("res://art/graffiti/void_runner.svg")
]

var player: Node3D = null
var spots: Array[Area3D] = []
var completed_spots: Dictionary = {}

var ui_layer: CanvasLayer = null
var prompt_label: Label = null
var overlay: ColorRect = null
var graffiti_canvas: Control = null
var result_label: Label = null
var active_spot: Area3D = null
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var pulse_time: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func setup(world_root: Node3D) -> void:
    player = get_tree().get_first_node_in_group("player") as Node3D
    _build_ui()
    _spawn_spots(world_root)

func _process(delta: float) -> void:
    pulse_time += delta

    if overlay != null and overlay.visible:
        if Input.is_action_just_pressed("close_menu"):
            _close_minigame()
        return

    if player == null or not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player") as Node3D
        return

    var nearest: Area3D = _nearest_available_spot()
    _update_spot_pulse(nearest)

    if nearest == null:
        prompt_label.visible = false
        return

    prompt_label.visible = true
    prompt_label.text = "F  //  THROW UP A PIECE"
    if Input.is_action_just_pressed("interact"):
        _open_minigame(nearest)

func _nearest_available_spot() -> Area3D:
    var nearest: Area3D = null
    var best_distance: float = 6.8

    for spot_value in spots:
        var spot: Area3D = spot_value
        if completed_spots.has(spot.get_instance_id()):
            continue
        var distance: float = player.global_position.distance_to(spot.global_position)
        if distance < best_distance:
            best_distance = distance
            nearest = spot
    return nearest

func _spawn_spots(world_root: Node3D) -> void:
    # Big readable tag panels attached to current blockout surfaces.
    var definitions: Array = [
        [Vector3(-22, 4.2, -71.72), Vector3(0, 0, 0), Color("#45f0d0")],
        [Vector3(33.02, 4.1, -26), Vector3(0, 90, 0), Color("#ff4f9a")],
        [Vector3(-50.72, 4.3, 26), Vector3(0, 90, 0), Color("#ffd34e")],
        [Vector3(22, 4.2, 71.72), Vector3(0, 180, 0), Color("#68a7ff")]
    ]

    for index in range(definitions.size()):
        var definition: Array = definitions[index]
        var position_value: Vector3 = definition[0]
        var rotation_value: Vector3 = definition[1]
        var accent_value: Color = definition[2]

        var spot := Area3D.new()
        spot.name = "GraffitiSpot_%02d" % index
        spot.position = position_value
        spot.rotation_degrees = rotation_value
        spot.set_meta("pattern", index % 3)
        spot.set_meta("accent", accent_value)
        spot.set_meta("index", index)
        world_root.add_child(spot)

        var shape_node := CollisionShape3D.new()
        var sphere := SphereShape3D.new()
        sphere.radius = 6.8
        shape_node.shape = sphere
        spot.add_child(shape_node)

        var frame := MeshInstance3D.new()
        frame.name = "TagFrame"
        var frame_mesh := BoxMesh.new()
        frame_mesh.size = Vector3(8.5, 4.6, 0.18)
        frame.mesh = frame_mesh
        frame.material_override = _solid_material(Color("#0b0f19"), false)
        spot.add_child(frame)

        var panel := MeshInstance3D.new()
        panel.name = "TagSurface"
        var quad := QuadMesh.new()
        quad.size = Vector2(8.0, 4.0)
        panel.mesh = quad
        panel.position = Vector3(0, 0, -0.105)
        panel.material_override = _texture_material(TAG_PANEL_TEXTURES[index % TAG_PANEL_TEXTURES.size()], false)
        spot.add_child(panel)

        # Four chunky emissive corners are far more visible at traversal speed.
        for corner_value in [
            Vector3(-4.15, -2.15, -0.13),
            Vector3(4.15, -2.15, -0.13),
            Vector3(-4.15, 2.15, -0.13),
            Vector3(4.15, 2.15, -0.13)
        ]:
            var corner: Vector3 = corner_value
            var marker := MeshInstance3D.new()
            marker.name = "TagCorner"
            var marker_mesh := BoxMesh.new()
            marker_mesh.size = Vector3(0.32, 0.32, 0.10)
            marker.mesh = marker_mesh
            marker.position = corner
            marker.material_override = _solid_material(accent_value, true)
            spot.add_child(marker)

        spots.append(spot)

func _update_spot_pulse(nearest: Area3D) -> void:
    for spot_value in spots:
        var spot: Area3D = spot_value
        var scale_value: float = 1.0
        if spot == nearest and not completed_spots.has(spot.get_instance_id()):
            scale_value = 1.0 + sin(pulse_time * 5.0) * 0.055

        for child_value in spot.get_children():
            var child: Node = child_value
            if child is MeshInstance3D and child.name == "TagCorner":
                var marker := child as MeshInstance3D
                marker.scale = Vector3.ONE * scale_value

func _build_ui() -> void:
    ui_layer = CanvasLayer.new()
    ui_layer.layer = 20
    add_child(ui_layer)

    prompt_label = Label.new()
    prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    prompt_label.position = Vector2(-230, -96)
    prompt_label.size = Vector2(460, 48)
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_label.add_theme_font_size_override("font_size", 23)
    prompt_label.add_theme_color_override("font_color", Color("#ffe58a"))
    prompt_label.visible = false
    ui_layer.add_child(prompt_label)

    overlay = ColorRect.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.color = Color(0.006, 0.01, 0.026, 0.96)
    overlay.visible = false
    ui_layer.add_child(overlay)

    var title := Label.new()
    title.position = Vector2(0, 28)
    title.set_anchors_preset(Control.PRESET_TOP_WIDE)
    title.size = Vector2(0, 64)
    title.text = "GRAFFITI // FOLLOW THE NODES"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    overlay.add_child(title)

    var help := Label.new()
    help.position = Vector2(0, 78)
    help.set_anchors_preset(Control.PRESET_TOP_WIDE)
    help.size = Vector2(0, 50)
    help.text = "Hold LMB and drag through every point in order.   ESC = cancel"
    help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    help.add_theme_font_size_override("font_size", 17)
    overlay.add_child(help)

    graffiti_canvas = Control.new()
    graffiti_canvas.set_script(GRAFFITI_CANVAS_SCRIPT)
    graffiti_canvas.set_anchors_preset(Control.PRESET_CENTER)
    graffiti_canvas.position = Vector2(-390, -215)
    graffiti_canvas.size = Vector2(780, 430)
    overlay.add_child(graffiti_canvas)
    graffiti_canvas.completed.connect(_on_graffiti_completed)

    result_label = Label.new()
    result_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    result_label.position = Vector2(-260, -82)
    result_label.size = Vector2(520, 52)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.add_theme_font_size_override("font_size", 30)
    overlay.add_child(result_label)

func _open_minigame(spot: Area3D) -> void:
    active_spot = spot
    result_label.text = ""
    overlay.visible = true
    prompt_label.visible = false
    previous_mouse_mode = Input.mouse_mode
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().paused = true

    var pattern_index: int = int(spot.get_meta("pattern", 0))
    graffiti_canvas.configure(pattern_index)
    graffiti_canvas.grab_focus()

func _on_graffiti_completed(rating: String) -> void:
    if active_spot == null:
        return

    result_label.text = rating
    if rating == "PERFECT":
        result_label.add_theme_color_override("font_color", Color("#45f0d0"))
    elif rating == "CLEAN":
        result_label.add_theme_color_override("font_color", Color("#ffd34e"))
    else:
        result_label.add_theme_color_override("font_color", Color("#ff7a8a"))

    completed_spots[active_spot.get_instance_id()] = true
    _apply_finished_tag(active_spot)
    await get_tree().create_timer(0.75, true).timeout
    _close_minigame()

func _apply_finished_tag(spot: Area3D) -> void:
    var index: int = int(spot.get_meta("index", 0))
    var panel := spot.get_node_or_null("TagSurface") as MeshInstance3D
    if panel != null:
        panel.material_override = _texture_material(COMPLETED_TEXTURES[index % COMPLETED_TEXTURES.size()], true)

    for child_value in spot.get_children():
        var child: Node = child_value
        if child is MeshInstance3D and child.name == "TagCorner":
            var marker := child as MeshInstance3D
            marker.visible = false

func _close_minigame() -> void:
    if overlay == null or not overlay.visible:
        return
    overlay.visible = false
    active_spot = null
    get_tree().paused = false
    Input.mouse_mode = previous_mouse_mode

func _texture_material(texture: Texture2D, emission: bool) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_texture = texture
    material.roughness = 0.82
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    if emission:
        material.emission_enabled = true
        material.emission_texture = texture
        material.emission_energy_multiplier = 1.35
    return material

func _solid_material(color: Color, emission: bool) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85
    if emission:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 2.2
    return material
