extends CanvasLayer

# Startup loading presentation. Progress is fed by Main's real construction
# stages; the screen never invents a fake timer or blocks scene initialization.

const ROSTER = preload("res://character_roster.gd")
const CHARACTER_PREVIEW_SCRIPT = preload("res://character_preview.gd")
const TITLE_LOGO = preload("res://art/ui/spider_city_logo.svg")

var root_control: Control = null
var progress_bar: ProgressBar = null
var stage_label: Label = null
var percent_label: Label = null
var tip_label: Label = null
var scan_line: ColorRect = null
var target_progress: float = 0.0
var displayed_progress: float = 0.0
var elapsed: float = 0.0
var tips: Array[String] = [
	"Release near the fastest part of the swing to carry momentum forward.",
	"A diagonal approach makes wall running easier to enter and control.",
	"Use Q to zip toward a valid surface without erasing your current route.",
	"A second press of Space in the air triggers the compact double jump.",
	"Tall skyline landmarks are built to be seen — and reached — from far away."
]


func _ready() -> void:
	layer = 100
	_build_interface()
	root_control.modulate.a = 0.0
	var intro := create_tween()
	intro.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(root_control, "modulate:a", 1.0, 0.24)


func _process(delta: float) -> void:
	elapsed += delta
	displayed_progress = move_toward(
		displayed_progress,
		target_progress,
		maxf(0.12, absf(target_progress - displayed_progress) * 5.5) * delta
	)
	if progress_bar != null:
		progress_bar.value = displayed_progress * 100.0
	if percent_label != null:
		percent_label.text = "%03d%%" % roundi(displayed_progress * 100.0)
	if scan_line != null:
		scan_line.position.y = fmod(elapsed * 54.0, 720.0) - 40.0
		scan_line.modulate.a = 0.10 + sin(elapsed * 2.1) * 0.025


func set_progress(value: float, stage: String) -> void:
	target_progress = clampf(value, target_progress, 1.0)
	if stage_label != null:
		stage_label.text = stage.to_upper()
	if tip_label != null:
		var tip_index: int = mini(
			int(floor(target_progress * float(tips.size()))),
			tips.size() - 1
		)
		tip_label.text = "TRAVERSAL TIP // " + tips[tip_index]


func finish_loading() -> void:
	set_progress(1.0, "CITY READY")
	displayed_progress = 1.0
	if progress_bar != null:
		progress_bar.value = 100.0
	if percent_label != null:
		percent_label.text = "100%"
	# Avoid a one-frame flash on faster machines: the animated lineup remains
	# readable, while the actual progress still comes only from real load stages.
	while elapsed < 1.35:
		await get_tree().process_frame
	var outro := create_tween()
	outro.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(root_control, "modulate:a", 0.0, 0.34)
	await outro.finished


func _build_interface() -> void:
	root_control = Control.new()
	root_control.name = "LoadingScreenRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = PackedColorArray([
		Color("#070b18"),
		Color("#111c38"),
		Color("#29133d")
	])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 1280
	gradient_texture.height = 720
	gradient_texture.fill_from = Vector2(0.08, 0.05)
	gradient_texture.fill_to = Vector2(0.92, 0.95)
	background.texture = gradient_texture
	root_control.add_child(background)

	_build_skyline(root_control)
	_build_accent_shapes(root_control)

	var header := HBoxContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 40.0
	header.offset_top = 22.0
	header.offset_right = -40.0
	header.offset_bottom = 72.0
	header.add_theme_constant_override("separation", 18)
	root_control.add_child(header)

	var system_label := Label.new()
	system_label.text = "SPIDER CITY // V0.1"
	system_label.add_theme_font_size_override("font_size", 16)
	system_label.add_theme_color_override("font_color", Color("#65f3dc"))
	system_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(system_label)

	var district_label := Label.new()
	district_label.text = "MDK3 + JERKOVIC / TRAVERSAL NETWORK"
	district_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	district_label.add_theme_font_size_override("font_size", 14)
	district_label.add_theme_color_override("font_color", Color("#9eb3d5"))
	district_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(district_label)

	var logo := TextureRect.new()
	logo.texture = TITLE_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	logo.position = Vector2(34, 62)
	logo.size = Vector2(500, 150)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(logo)

	var run_label := Label.new()
	run_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	run_label.position = Vector2(-408, 94)
	run_label.size = Vector2(360, 78)
	run_label.text = "NIGHT RUN INITIALIZING\nKEEP YOUR MOMENTUM"
	run_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	run_label.add_theme_font_size_override("font_size", 18)
	run_label.add_theme_color_override("font_color", Color("#ff5b9e"))
	root_control.add_child(run_label)

	_build_character_lineup(root_control)
	_build_bottom_panel(root_control)

	scan_line = ColorRect.new()
	scan_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	scan_line.offset_left = 0.0
	scan_line.offset_right = 0.0
	scan_line.offset_top = 0.0
	scan_line.offset_bottom = 3.0
	scan_line.color = Color("#72f7e1")
	scan_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(scan_line)


func _build_character_lineup(parent: Control) -> void:
	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "CharacterLineup"
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.offset_left = 56.0
	viewport_container.offset_top = 160.0
	viewport_container.offset_right = -56.0
	viewport_container.offset_bottom = -164.0
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1168, 396)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.18, 8.2)
	camera.fov = 36.0
	camera.current = true
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.08, 0.0), Vector3.UP)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-34.0, -28.0, 0.0)
	key_light.light_energy = 2.0
	key_light.shadow_enabled = true
	viewport.add_child(key_light)
	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(18.0, 142.0, 0.0)
	rim_light.light_energy = 1.05
	rim_light.light_color = Color("#7c9dff")
	viewport.add_child(rim_light)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9.0, 2.8)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, -1.34, 0.25)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#111a2a")
	floor_material.roughness = 0.72
	floor_mesh.material_override = floor_material
	viewport.add_child(floor_mesh)

	var positions: Array[float] = [-2.55, -0.85, 0.85, 2.55]
	var facing: Array[float] = [-0.13, -0.045, 0.045, 0.13]
	for index in range(ROSTER.count()):
		var preview := Node3D.new()
		preview.name = "LoadingCharacter_%s" % String(
			ROSTER.get_character(index).get("id", index)
		)
		preview.set_script(CHARACTER_PREVIEW_SCRIPT)
		preview.position = Vector3(positions[index], 0.0, 0.0)
		preview.rotation.y = facing[index]
		preview.call(
			"configure_preview",
			index,
			false,
			float(index) * 1.37,
			0.86
		)
		viewport.add_child(preview)

	var names := HBoxContainer.new()
	names.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	names.offset_left = 80.0
	names.offset_top = -190.0
	names.offset_right = -80.0
	names.offset_bottom = -148.0
	names.add_theme_constant_override("separation", 12)
	parent.add_child(names)
	for index in range(ROSTER.count()):
		var data: Dictionary = ROSTER.get_character(index)
		var label := Label.new()
		label.text = String(data.get("name", "RUNNER"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override(
			"font_color",
			Color(String(data.get("primary", "#ffffff"))).lightened(0.25)
		)
		names.add_child(label)


func _build_bottom_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 56.0
	panel.offset_top = -146.0
	panel.offset_right = -56.0
	panel.offset_bottom = -28.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.085, 0.94)
	style.border_color = Color("#40567d")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	panel.add_child(stack)

	var status_row := HBoxContainer.new()
	stack.add_child(status_row)
	stage_label = Label.new()
	stage_label.text = "BOOTING TRAVERSAL NETWORK"
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_label.add_theme_font_size_override("font_size", 16)
	stage_label.add_theme_color_override("font_color", Color("#e7efff"))
	status_row.add_child(stage_label)
	percent_label = Label.new()
	percent_label.text = "000%"
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent_label.add_theme_font_size_override("font_size", 16)
	percent_label.add_theme_color_override("font_color", Color("#65f3dc"))
	status_row.add_child(percent_label)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 12.0
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("#11172a")
	bar_background.corner_radius_top_left = 5
	bar_background.corner_radius_top_right = 5
	bar_background.corner_radius_bottom_left = 5
	bar_background.corner_radius_bottom_right = 5
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("#ff4f9a")
	bar_fill.corner_radius_top_left = 5
	bar_fill.corner_radius_top_right = 5
	bar_fill.corner_radius_bottom_left = 5
	bar_fill.corner_radius_bottom_right = 5
	progress_bar.add_theme_stylebox_override("background", bar_background)
	progress_bar.add_theme_stylebox_override("fill", bar_fill)
	stack.add_child(progress_bar)

	tip_label = Label.new()
	tip_label.text = "TRAVERSAL TIP // " + tips[0]
	tip_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tip_label.add_theme_font_size_override("font_size", 13)
	tip_label.add_theme_color_override("font_color", Color("#9eb3d5"))
	stack.add_child(tip_label)


func _build_skyline(parent: Control) -> void:
	var skyline := Control.new()
	skyline.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	skyline.offset_top = -310.0
	skyline.offset_bottom = 0.0
	skyline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(skyline)
	var heights: Array[float] = [
		82, 134, 68, 176, 110, 238, 96, 154, 74,
		192, 122, 262, 88, 146, 214, 102, 168, 118
	]
	for index in range(heights.size()):
		var building := ColorRect.new()
		building.color = Color(0.035, 0.055, 0.105, 0.82)
		building.position = Vector2(float(index) * 74.0 - 18.0, 310.0 - heights[index])
		building.size = Vector2(58.0 + float(index % 3) * 10.0, heights[index])
		skyline.add_child(building)


func _build_accent_shapes(parent: Control) -> void:
	var left_bar := ColorRect.new()
	left_bar.color = Color(1.0, 0.22, 0.52, 0.20)
	left_bar.position = Vector2(-160.0, 250.0)
	left_bar.size = Vector2(520.0, 42.0)
	left_bar.rotation = -0.23
	left_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(left_bar)
	var right_bar := ColorRect.new()
	right_bar.color = Color(0.25, 0.95, 0.82, 0.13)
	right_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_bar.position = Vector2(-330.0, 180.0)
	right_bar.size = Vector2(480.0, 34.0)
	right_bar.rotation = 0.28
	right_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(right_bar)
