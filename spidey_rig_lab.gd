extends Node3D

# Spider City BRC Rig Lab
#
# This scene is intentionally isolated from player.gd and all gameplay.
# It exists to calibrate the ACTUAL imported BRC skeleton before we author
# another locomotion animation.
#
# Godot 4 bone pose rotations INCLUDE the bone rest. Therefore each test
# starts from the imported rest rotation, then applies one controlled delta.

const COMIC_TEX: Texture2D = preload("res://art/spidey/spidey_comic.png")

const TESTS: Array[Dictionary] = [
	{"label": "LEFT KNEE",      "bone": "leg2l", "child": "footl"},
	{"label": "RIGHT KNEE",     "bone": "leg2r", "child": "footr"},
	{"label": "LEFT ELBOW",     "bone": "arm2l", "child": "handl"},
	{"label": "RIGHT ELBOW",    "bone": "arm2r", "child": "handr"},
	{"label": "LEFT SHOULDER",  "bone": "arm1l", "child": "arm2l"},
	{"label": "RIGHT SHOULDER", "bone": "arm1r", "child": "arm2r"},
	{"label": "LEFT CLAVICLE",  "bone": "shldl", "child": "arm1l"},
	{"label": "RIGHT CLAVICLE", "bone": "shldr", "child": "arm1r"},
	{"label": "LEFT ANKLE",     "bone": "footl", "child": "toesl"},
	{"label": "RIGHT ANKLE",    "bone": "footr", "child": "toesr"},
	{"label": "LEFT TOES",      "bone": "toesl", "child": ""},
	{"label": "RIGHT TOES",     "bone": "toesr", "child": ""},
	{"label": "HIPS",           "bone": "hips", "child": "s1"},
	{"label": "SPINE 1",        "bone": "s1", "child": "s2"},
	{"label": "SPINE 2",        "bone": "s2", "child": "neck"},
	{"label": "NECK",           "bone": "neck", "child": "head"},
	{"label": "HEAD",           "bone": "head", "child": ""}
]

var skeleton: Skeleton3D = null
var debug_mesh_instance: MeshInstance3D = null
var info_label: Label = null
var help_label: Label = null

var selected_test: int = 0
var selected_axis: int = 0 # 0 X, 1 Y, 2 Z
var angle_degrees: float = 60.0
var composition_mode: int = 0 # 0 = REST * DELTA, 1 = DELTA * REST
var show_skeleton: bool = true

var auto_test: bool = false
var auto_timer: float = 0.0
var auto_axis: int = 0
var auto_sign: float = 1.0

func _ready() -> void:
	skeleton = _find_skeleton(self)
	if skeleton == null:
		push_error("Rig Lab: Skeleton3D not found.")
		return

	_apply_texture(self)
	_build_ui()
	_build_debug_skeleton()
	_reset_pose()
	_apply_selected_test()

func _process(delta: float) -> void:
	if skeleton == null:
		return

	if auto_test:
		auto_timer += delta
		if auto_timer >= 1.1:
			auto_timer = 0.0
			auto_sign *= -1.0
			if auto_sign > 0.0:
				auto_axis = (auto_axis + 1) % 3
			selected_axis = auto_axis
			angle_degrees = 55.0 * auto_sign
			_apply_selected_test()

	_update_debug_skeleton()
	_update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_A:
			selected_test = posmod(selected_test - 1, TESTS.size())
			_reset_pose()
			_apply_selected_test()
		KEY_D:
			selected_test = (selected_test + 1) % TESTS.size()
			_reset_pose()
			_apply_selected_test()
		KEY_X:
			selected_axis = 0
			_apply_selected_test()
		KEY_Y:
			selected_axis = 1
			_apply_selected_test()
		KEY_Z:
			selected_axis = 2
			_apply_selected_test()
		KEY_Q:
			angle_degrees = clampf(angle_degrees - 15.0, -120.0, 120.0)
			_apply_selected_test()
		KEY_E:
			angle_degrees = clampf(angle_degrees + 15.0, -120.0, 120.0)
			_apply_selected_test()
		KEY_M:
			composition_mode = 1 - composition_mode
			_apply_selected_test()
		KEY_R:
			angle_degrees = 0.0
			auto_test = false
			_reset_pose()
		KEY_T:
			auto_test = not auto_test
			auto_timer = 0.0
			if not auto_test:
				_apply_selected_test()
		KEY_V:
			show_skeleton = not show_skeleton
			if debug_mesh_instance != null:
				debug_mesh_instance.visible = show_skeleton
		KEY_1:
			_jump_to_bone("leg2l")
		KEY_2:
			_jump_to_bone("arm2l")
		KEY_3:
			_jump_to_bone("arm1l")
		KEY_4:
			_jump_to_bone("footl")
		KEY_5:
			_jump_to_bone("toesl")
		KEY_6:
			_jump_to_bone("s1")
		KEY_7:
			_jump_to_bone("s2")
		KEY_8:
			_jump_to_bone("neck")

func _jump_to_bone(bone_name: String) -> void:
	for index in range(TESTS.size()):
		if String(TESTS[index]["bone"]) == bone_name:
			selected_test = index
			_reset_pose()
			_apply_selected_test()
			return

func _reset_pose() -> void:
	if skeleton != null:
		skeleton.reset_bone_poses()

func _apply_selected_test() -> void:
	if skeleton == null:
		return

	skeleton.reset_bone_poses()

	var test: Dictionary = TESTS[selected_test]
	var bone_name: String = String(test["bone"])
	var bone_index: int = skeleton.find_bone(bone_name)
	if bone_index < 0:
		return

	var rest_rotation: Quaternion = skeleton.get_bone_rest(bone_index).basis.orthonormalized().get_rotation_quaternion()
	var axis: Vector3 = Vector3.RIGHT
	if selected_axis == 1:
		axis = Vector3.UP
	elif selected_axis == 2:
		axis = Vector3.BACK

	var delta_rotation := Quaternion(axis, deg_to_rad(angle_degrees))
	var result := rest_rotation

	if composition_mode == 0:
		result = (rest_rotation * delta_rotation).normalized()
	else:
		result = (delta_rotation * rest_rotation).normalized()

	skeleton.set_bone_pose_rotation(bone_index, result)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RigLabUI"
	add_child(layer)

	var panel := ColorRect.new()
	panel.position = Vector2(18.0, 18.0)
	panel.size = Vector2(610.0, 220.0)
	panel.color = Color(0.02, 0.025, 0.04, 0.90)
	layer.add_child(panel)

	info_label = Label.new()
	info_label.position = Vector2(18.0, 14.0)
	info_label.size = Vector2(575.0, 105.0)
	info_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(info_label)

	help_label = Label.new()
	help_label.position = Vector2(18.0, 116.0)
	help_label.size = Vector2(575.0, 94.0)
	help_label.add_theme_font_size_override("font_size", 14)
	help_label.text = (
        "A/D joint   X/Y/Z axis   Q/E -/+15°   M order   R rest   T auto-test   V bones\n"
		+ "1 knee   2 elbow   3 shoulder   4 ankle   5 toes   6 spine1   7 spine2   8 neck\n"
		+ "Goal: find the axis/order where KNEE and ELBOW visibly FLEX instead of twist."
	)
	panel.add_child(help_label)

func _update_ui() -> void:
	if info_label == null or skeleton == null:
		return

	var test: Dictionary = TESTS[selected_test]
	var bone_name: String = String(test["bone"])
	var bone_index: int = skeleton.find_bone(bone_name)
	var parent_name := "none"
	if bone_index >= 0:
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		if parent_index >= 0:
			parent_name = String(skeleton.get_bone_name(parent_index))

	var axis_name := "X"
	if selected_axis == 1:
		axis_name = "Y"
	elif selected_axis == 2:
		axis_name = "Z"

	var order_name := "REST * DELTA"
	if composition_mode == 1:
		order_name = "DELTA * REST"

	info_label.text = (
		(
            "BRC RIG LAB  |  %s\n"
			+ "bone: %s   parent: %s   child: %s\n"
			+ "axis: %s   angle: %.0f°   order: %s   auto: %s"
		)
		% [
			String(test["label"]),
			bone_name,
			parent_name,
			String(test["child"]),
			axis_name,
			angle_degrees,
			order_name,
			"ON" if auto_test else "OFF"
		]
	)

func _build_debug_skeleton() -> void:
	if skeleton == null:
		return

	debug_mesh_instance = MeshInstance3D.new()
	debug_mesh_instance.name = "DebugSkeleton"
	skeleton.add_child(debug_mesh_instance)

func _update_debug_skeleton() -> void:
	if debug_mesh_instance == null or not show_skeleton:
		return

	var mesh := ImmediateMesh.new()
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.vertex_color_use_as_albedo = true
	line_material.no_depth_test = true

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, line_material)

	var selected_bone_name: String = String(TESTS[selected_test]["bone"])
	var selected_index: int = skeleton.find_bone(selected_bone_name)

	for bone_index in range(skeleton.get_bone_count()):
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		if parent_index < 0:
			continue

		var child_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
		var parent_pose: Transform3D = skeleton.get_bone_global_pose(parent_index)

		var color := Color(0.20, 0.95, 1.0, 1.0)
		if bone_index == selected_index:
			color = Color(1.0, 0.15, 0.10, 1.0)
		elif parent_index == selected_index:
			color = Color(0.35, 1.0, 0.20, 1.0)

		mesh.surface_set_color(color)
		mesh.surface_add_vertex(parent_pose.origin)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(child_pose.origin)

	# Selected joint cross.
	if selected_index >= 0:
		var selected_pose: Transform3D = skeleton.get_bone_global_pose(selected_index)
		var p: Vector3 = selected_pose.origin
		var radius: float = 0.045

		mesh.surface_set_color(Color(1.0, 0.1, 0.1, 1.0))
		mesh.surface_add_vertex(p - Vector3.RIGHT * radius)
		mesh.surface_add_vertex(p + Vector3.RIGHT * radius)
		mesh.surface_add_vertex(p - Vector3.UP * radius)
		mesh.surface_add_vertex(p + Vector3.UP * radius)
		mesh.surface_add_vertex(p - Vector3.BACK * radius)
		mesh.surface_add_vertex(p + Vector3.BACK * radius)

	mesh.surface_end()
	debug_mesh_instance.mesh = mesh

func _apply_texture(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := StandardMaterial3D.new()
				material.albedo_texture = COMIC_TEX
				material.roughness = 0.84
				material.metallic = 0.0
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				mesh_instance.set_surface_override_material(surface_index, material)

	for child_value in node.get_children():
		_apply_texture(child_value as Node)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D

	for child_value in node.get_children():
		var result: Skeleton3D = _find_skeleton(child_value as Node)
		if result != null:
			return result

	return null
