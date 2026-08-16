extends Control

# Self-contained character-select presentation. The preview viewport owns its
# World3D, so city geometry can never render through or occlude the roster model.

const ROSTER = preload("res://character_roster.gd")
const CHARACTER_PREVIEW_SCRIPT = preload("res://character_preview.gd")

const STAT_KEYS: Array[String] = [
	"speed", "acceleration", "swing", "air", "combat", "defense"
]
const STAT_NAMES: Array[String] = [
	"SPEED", "ACCELERATION", "SWING", "AIR CONTROL", "COMBAT", "DEFENSE"
]

var preview_character: Node3D = null
var name_label: Label = null
var class_label: Label = null
var roster_index_label: Label = null
var movement_label: Label = null
var special_label: Label = null
var strength_label: Label = null
var weakness_label: Label = null
var accent_strip: ColorRect = null
var scan_line: ColorRect = null
var stat_bars: Array[ProgressBar] = []
var stat_value_labels: Array[Label] = []
var stat_fill_styles: Array[StyleBoxFlat] = []
var roster_cards: Array[PanelContainer] = []
var roster_card_labels: Array[Label] = []
var selected_index: int = 0
var selection_pulse: float = 0.0
var elapsed: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_header()
	_build_preview_stage()
	_build_info_panel()
	_build_roster_row()
	_build_controls()
	show_character(selected_index)


func _process(delta: float) -> void:
	elapsed += delta
	selection_pulse = maxf(0.0, selection_pulse - delta)
	if accent_strip != null:
		accent_strip.modulate.a = 0.82 + sin(elapsed * 2.4) * 0.12
	if scan_line != null:
		scan_line.position.x = fmod(elapsed * 82.0, 620.0) - 40.0
		scan_line.modulate.a = 0.12 + minf(selection_pulse * 1.6, 0.34)


func show_character(index: int) -> void:
	selected_index = posmod(index, ROSTER.count())
	var data: Dictionary = ROSTER.get_character(selected_index)
	var accent := Color(String(data.get("primary", "#ff4f9a")))
	var accent_light := accent.lightened(0.28)

	name_label.text = String(data.get("name", "RUNNER"))
	class_label.text = String(data.get("class", "TRAVERSAL"))
	roster_index_label.text = "%02d / %02d" % [selected_index + 1, ROSTER.count()]
	movement_label.text = String(data.get("movement", ""))
	special_label.text = String(data.get("special", ""))
	strength_label.text = "+  " + String(data.get("strength", ""))
	weakness_label.text = "−  " + String(data.get("weakness", ""))
	name_label.add_theme_color_override("font_color", accent_light)
	class_label.add_theme_color_override("font_color", accent.lightened(0.42))
	accent_strip.color = accent

	var stats: Dictionary = data.get("stats", {})
	for stat_index in range(STAT_KEYS.size()):
		var rating: int = int(stats.get(STAT_KEYS[stat_index], 0))
		stat_bars[stat_index].value = rating * 20.0
		stat_value_labels[stat_index].text = "%d / 5" % rating
		stat_fill_styles[stat_index].bg_color = accent

	for card_index in range(roster_cards.size()):
		var selected: bool = card_index == selected_index
		var card_data: Dictionary = ROSTER.get_character(card_index)
		var card_color := Color(String(card_data.get("primary", "#ffffff")))
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = (
			card_color.darkened(0.48)
			if selected
			else Color(0.025, 0.04, 0.075, 0.92)
		)
		card_style.border_color = card_color if selected else Color("#31415f")
		card_style.set_border_width_all(3 if selected else 1)
		card_style.set_corner_radius_all(6)
		roster_cards[card_index].add_theme_stylebox_override("panel", card_style)
		roster_card_labels[card_index].add_theme_color_override(
			"font_color",
			card_color.lightened(0.35) if selected else Color("#8fa0bd")
		)

	if preview_character != null and preview_character.has_method("rebuild"):
		preview_character.call("rebuild", selected_index)
	selection_pulse = 0.34


func _build_background() -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.48, 1.0])
	gradient.colors = PackedColorArray([
		Color("#070b16"),
		Color("#11172b"),
		Color("#21122d")
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1280
	texture.height = 720
	texture.fill_from = Vector2(0.05, 0.05)
	texture.fill_to = Vector2(0.96, 0.92)
	background.texture = texture
	add_child(background)

	for index in range(9):
		var stripe := ColorRect.new()
		stripe.color = Color(0.16, 0.24, 0.42, 0.09)
		stripe.position = Vector2(-160.0 + index * 190.0, 80.0)
		stripe.size = Vector2(88.0, 780.0)
		stripe.rotation = -0.20
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripe)


func _build_header() -> void:
	var eyebrow := Label.new()
	eyebrow.position = Vector2(40, 20)
	eyebrow.size = Vector2(520, 24)
	eyebrow.text = "SPIDER CITY // RUNNER DATABASE"
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", Color("#65f3dc"))
	add_child(eyebrow)

	var title := Label.new()
	title.position = Vector2(38, 42)
	title.size = Vector2(700, 46)
	title.text = "CHOOSE YOUR RUNNER"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f5f7ff"))
	add_child(title)

	roster_index_label = Label.new()
	roster_index_label.position = Vector2(1030, 34)
	roster_index_label.size = Vector2(205, 46)
	roster_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	roster_index_label.add_theme_font_size_override("font_size", 24)
	roster_index_label.add_theme_color_override("font_color", Color("#9db1d2"))
	add_child(roster_index_label)


func _build_preview_stage() -> void:
	var stage_panel := Panel.new()
	stage_panel.position = Vector2(38, 96)
	stage_panel.size = Vector2(594, 470)
	stage_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.03, 0.060, 0.94)
	panel_style.border_color = Color("#314868")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	stage_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(stage_panel)

	var stage_tag := Label.new()
	stage_tag.position = Vector2(58, 110)
	stage_tag.size = Vector2(300, 28)
	stage_tag.text = "LIVE MODEL // IDLE LOOP"
	stage_tag.add_theme_font_size_override("font_size", 13)
	stage_tag.add_theme_color_override("font_color", Color("#7f95b8"))
	add_child(stage_tag)

	var viewport_container := SubViewportContainer.new()
	viewport_container.position = Vector2(50, 142)
	viewport_container.size = Vector2(570, 408)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(570, 408)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b9c9ec")
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.03, 5.2)
	camera.fov = 36.0
	camera.current = true
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, -0.05, 0.0), Vector3.UP)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-34, -28, 0)
	key_light.light_energy = 1.9
	key_light.shadow_enabled = true
	viewport.add_child(key_light)
	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(20, 150, 0)
	rim_light.light_energy = 1.15
	rim_light.light_color = Color("#7c9dff")
	viewport.add_child(rim_light)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 1.38
	platform_mesh.bottom_radius = 1.52
	platform_mesh.height = 0.12
	platform_mesh.radial_segments = 32
	platform.mesh = platform_mesh
	platform.position = Vector3(0.0, -1.40, 0.08)
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color("#182844")
	platform_material.metallic = 0.24
	platform_material.roughness = 0.52
	platform.material_override = platform_material
	viewport.add_child(platform)

	preview_character = Node3D.new()
	preview_character.name = "SelectedCharacterPreview"
	preview_character.set_script(CHARACTER_PREVIEW_SCRIPT)
	# A complete slow turn shows the silhouette and texture from every side while
	# the skeleton continues its independent hero-idle sequence.
	preview_character.call("configure_preview", 0, true, 0.0, 1.0)
	viewport.add_child(preview_character)

	accent_strip = ColorRect.new()
	accent_strip.position = Vector2(40, 558)
	accent_strip.size = Vector2(590, 7)
	accent_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent_strip)

	scan_line = ColorRect.new()
	scan_line.position = Vector2(40, 548)
	scan_line.size = Vector2(110, 2)
	scan_line.color = Color("#dffcff")
	scan_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan_line)


func _build_info_panel() -> void:
	var info_panel := Panel.new()
	info_panel.position = Vector2(662, 96)
	info_panel.size = Vector2(578, 488)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.018, 0.026, 0.052, 0.95)
	info_style.border_color = Color("#263957")
	info_style.set_border_width_all(2)
	info_style.set_corner_radius_all(10)
	info_panel.add_theme_stylebox_override("panel", info_style)
	add_child(info_panel)

	name_label = Label.new()
	name_label.position = Vector2(690, 112)
	name_label.size = Vector2(510, 52)
	name_label.add_theme_font_size_override("font_size", 38)
	add_child(name_label)
	class_label = Label.new()
	class_label.position = Vector2(692, 160)
	class_label.size = Vector2(510, 30)
	class_label.add_theme_font_size_override("font_size", 18)
	add_child(class_label)

	var divider := ColorRect.new()
	divider.position = Vector2(690, 198)
	divider.size = Vector2(522, 2)
	divider.color = Color("#31415e")
	add_child(divider)

	for stat_index in range(STAT_NAMES.size()):
		var y: float = 214.0 + stat_index * 30.0
		var label := Label.new()
		label.position = Vector2(690, y)
		label.size = Vector2(150, 25)
		label.text = STAT_NAMES[stat_index]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#c8d3e8"))
		add_child(label)

		var bar := ProgressBar.new()
		bar.position = Vector2(842, y + 5)
		bar.size = Vector2(286, 14)
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.show_percentage = false
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color("#111a2c")
		bar_bg.set_corner_radius_all(4)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color("#ff4f9a")
		bar_fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", bar_fill)
		add_child(bar)
		stat_bars.append(bar)
		stat_fill_styles.append(bar_fill)

		var value_label := Label.new()
		value_label.position = Vector2(1140, y - 1)
		value_label.size = Vector2(64, 25)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 13)
		value_label.add_theme_color_override("font_color", Color("#8fa4c5"))
		add_child(value_label)
		stat_value_labels.append(value_label)

	var movement_heading := _make_section_heading("MOVEMENT PROFILE", Vector2(690, 400))
	add_child(movement_heading)
	movement_label = _make_wrapped_label(Vector2(690, 422), Vector2(510, 42), 13)
	add_child(movement_label)
	var special_heading := _make_section_heading("SIGNATURE SPECIAL", Vector2(690, 470))
	add_child(special_heading)
	special_label = _make_wrapped_label(Vector2(690, 492), Vector2(510, 42), 13)
	add_child(special_label)

	strength_label = Label.new()
	strength_label.position = Vector2(690, 538)
	strength_label.size = Vector2(510, 20)
	strength_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strength_label.add_theme_font_size_override("font_size", 12)
	strength_label.add_theme_color_override("font_color", Color("#65f3a5"))
	add_child(strength_label)
	weakness_label = Label.new()
	weakness_label.position = Vector2(690, 560)
	weakness_label.size = Vector2(510, 20)
	weakness_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	weakness_label.add_theme_font_size_override("font_size", 12)
	weakness_label.add_theme_color_override("font_color", Color("#ff8095"))
	add_child(weakness_label)


func _build_roster_row() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(38, 590)
	row.size = Vector2(1202, 64)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for index in range(ROSTER.count()):
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(293, 64)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(card)
		roster_cards.append(card)

		var label := Label.new()
		label.text = "%02d  %s" % [
			index + 1,
			String(ROSTER.get_character(index).get("name", "RUNNER"))
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		card.add_child(label)
		roster_card_labels.append(label)


func _build_controls() -> void:
	var controls := Label.new()
	controls.position = Vector2(38, 670)
	controls.size = Vector2(1202, 34)
	controls.text = "A / D   CHANGE RUNNER        ENTER   LOCK IN"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 16)
	controls.add_theme_color_override("font_color", Color("#d7e2f5"))
	add_child(controls)


func _make_section_heading(text: String, position_value: Vector2) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = Vector2(510, 22)
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#65f3dc"))
	return label


func _make_wrapped_label(
	position_value: Vector2,
	size_value: Vector2,
	font_size: int
) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#d7e0f1"))
	return label
