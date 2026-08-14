extends CharacterBody3D

# Native Godot retarget test.
#
# The difficult source-rig -> BRC-rig conversion is performed by Godot's
# RetargetModifier3D.  The only custom copying done here is between a real
# skeleton and an exact proxy of THAT SAME skeleton:
#
# donor animated skeleton -> donor canonical proxy
#     -> RetargetModifier3D ->
# BRC canonical proxy -> real BRC skeleton
#
# The proxies preserve the exact original rests/hierarchy.  Only selected bone
# NAMES are changed to SkeletonProfileHumanoid canonical names so that
# RetargetModifier3D can match the two rigs.

const SOURCE_GLTF_PATH: String = "res://third_party/godot_platformer/player.glb"
const TARGET_GLTF_PATH: String = "res://models/spidey/spidey_funk_alt_v2.glb"

const MOVE_SPEED: float = 7.5
const ACCELERATION: float = 22.0
const AIR_ACCELERATION: float = 8.0
const JUMP_VELOCITY: float = 8.2
const TURN_SPEED: float = 12.0
const TARGET_MODEL_SCALE: float = 1.62

# BRC arm IK target tuning in the BRC skeleton's own model space.
# The BRC rig faces approximately +Z. Positive X is character-left.
#
# Instead of rotating shoulder/elbow axes by guessed angles, the run now asks:
# "where should the HAND and ELBOW be?" Godot 4.7 TwoBoneIK3D solves
# arm1 -> arm2 -> hand for that target and pole.
# Ground-arm targets.
#
# V6 only enabled IK while RUNNING, so the ugly donor arm pose was still visible
# whenever the character was idle/slow.  V7 owns the arm chain on the ground
# all the time.
#
# The hand is intentionally kept slightly FARTHER from the torso than the elbow.
# That makes elbow -> hand angle outward a little, never inward through the body.
const IDLE_HAND_SIDE: float = 0.305
const IDLE_HAND_Y: float = 0.905
const IDLE_HAND_Z: float = 0.015
const IDLE_ELBOW_SIDE: float = 0.255
const IDLE_ELBOW_Y: float = 1.075
const IDLE_ELBOW_Z: float = -0.010

const RUN_HAND_SIDE: float = 0.275
const RUN_HAND_MID_Y: float = 0.985
const RUN_HAND_FORWARD_Y: float = 0.055
const RUN_HAND_SWING_Z: float = 0.255
const RUN_ELBOW_SIDE: float = 0.230
const RUN_ELBOW_Y: float = 1.085
const RUN_ELBOW_Z_SCALE: float = 0.10

const ARM_TARGET_SMOOTH: float = 14.0
const ARM_IK_BLEND_SPEED: float = 10.0

const IDLE_STANCE_BLEND_SPEED: float = 8.0
const IDLE_STANCE_ACTIVE_MAX_SPEED: float = 1.15
const IDLE_LEG_BEND: float = 0.085
const IDLE_FOOT_BEND: float = -0.035
const IDLE_TOE_BEND: float = 0.020
const IDLE_THIGH_SPREAD_Z: float = 0.090
const IDLE_FOOT_OUT_Z: float = 0.060

# Godot official platformer donor bone -> SkeletonProfileHumanoid name.
const SOURCE_CANONICAL: Dictionary = {
	"hip": "Hips",
	"waist": "Spine",
	"chest": "Chest",
	"neck": "Neck",
	"head": "Head",

	"l-arm": "LeftUpperArm",
	"l-forearm": "LeftLowerArm",
	"r-arm": "RightUpperArm",
	"r-forearm": "RightLowerArm",

	"l-thigh": "LeftUpperLeg",
	"l-leg": "LeftLowerLeg",
	"l-foot": "LeftFoot",
	"r-thigh": "RightUpperLeg",
	"r-leg": "RightLowerLeg",
	"r-foot": "RightFoot",
}

# BRC Spider bone -> SkeletonProfileHumanoid name.
#
# Unlike the donor, the BRC rig DOES contain explicit shoulder, hand and toe
# bones.  Keeping those canonical entries in the target proxy lets the native
# modifier account for the different parent chain/rest structure.
const TARGET_CANONICAL: Dictionary = {
	"hips": "Hips",
	"s1": "Spine",
	"s2": "Chest",
	"neck": "Neck",
	"head": "Head",

	"shldl": "LeftShoulder",
	"arm1l": "LeftUpperArm",
	"arm2l": "LeftLowerArm",
	"handl": "LeftHand",

	"shldr": "RightShoulder",
	"arm1r": "RightUpperArm",
	"arm2r": "RightLowerArm",
	"handr": "RightHand",

	"leg1l": "LeftUpperLeg",
	"leg2l": "LeftLowerLeg",
	"footl": "LeftFoot",
	"toesl": "LeftToes",

	"leg1r": "RightUpperLeg",
	"leg2r": "RightLowerLeg",
	"footr": "RightFoot",
	"toesr": "RightToes",
}

@onready var visual_root: Node3D = $VisualRoot
@onready var target_mount: Node3D = $VisualRoot/TargetMount
@onready var source_mount: Node3D = $SourceMount
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var status_label: Label = $HUD/Status

var target_instance: Node3D = null
var source_instance: Node3D = null

var target_skeleton: Skeleton3D = null
var source_skeleton: Skeleton3D = null
var source_animation_player: AnimationPlayer = null

var source_proxy: Skeleton3D = null
var target_proxy: Skeleton3D = null
var retarget_modifier: RetargetModifier3D = null
var humanoid_profile: SkeletonProfileHumanoid = null

var target_proxy_to_real: Dictionary = {}

var current_animation: StringName = &""
var jump_was_down: bool = false
var mouse_captured: bool = true
var show_source_model: bool = false
var native_retarget_ready: bool = false
var retarget_frame_count: int = 0

var left_arm_ik: TwoBoneIK3D = null
var right_arm_ik: TwoBoneIK3D = null
var left_hand_target: Marker3D = null
var right_hand_target: Marker3D = null
var left_elbow_pole: Marker3D = null
var right_elbow_pole: Marker3D = null

var arm_ik_blend: float = 0.0
var arm_stride: float = 0.0
var hand_rest_rotation: Dictionary = {}
var shoulder_rest_rotation: Dictionary = {}
var idle_stance_blend: float = 0.0


func _ready() -> void:
	# Run after the donor AnimationPlayer's default process.
	process_priority = 100
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_load_target_model()
	_load_source_animation_rig()

	if target_skeleton == null or source_skeleton == null or source_animation_player == null:
		_fail(
			"Could not find source/target Skeleton3D or donor AnimationPlayer.\n"
			+ "Check the Output panel."
		)
		return

	_build_native_retarget_pipeline()
	_build_brc_arm_ik()
	_play_if_available(&"idle", 0.0)
	_update_status()


func _physics_process(delta: float) -> void:
	var gravity_value: float = float(
		ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	)

	if not is_on_floor():
		velocity.y -= gravity_value * delta

	var input_vec := Vector2(
		_float_key(KEY_D) - _float_key(KEY_A),
		_float_key(KEY_S) - _float_key(KEY_W)
	)

	var desired_direction := Vector3.ZERO
	if input_vec.length_squared() > 0.001:
		input_vec = input_vec.normalized()

		var cam_forward: Vector3 = -camera.global_transform.basis.z
		var cam_right: Vector3 = camera.global_transform.basis.x
		cam_forward.y = 0.0
		cam_right.y = 0.0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()

		desired_direction = (
			cam_right * input_vec.x + cam_forward * -input_vec.y
		).normalized()

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var target_horizontal: Vector3 = desired_direction * MOVE_SPEED
	var accel: float = ACCELERATION if is_on_floor() else AIR_ACCELERATION

	horizontal_velocity = horizontal_velocity.move_toward(
		target_horizontal,
		accel * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	var jump_down: bool = Input.is_physical_key_pressed(KEY_SPACE)
	if is_on_floor() and jump_down and not jump_was_down:
		velocity.y = JUMP_VELOCITY
	jump_was_down = jump_down

	if desired_direction.length_squared() > 0.01:
		var target_yaw: float = atan2(desired_direction.x, desired_direction.z)
		visual_root.rotation.y = lerp_angle(
			visual_root.rotation.y,
			target_yaw,
			clampf(TURN_SPEED * delta, 0.0, 1.0)
		)

	move_and_slide()
	_update_animation_state(horizontal_velocity.length())


func _process(delta: float) -> void:
	if native_retarget_ready:
		# This copy is SAME-RIG -> SAME-RIG. No retarget math is done here.
		_copy_complete_pose(source_skeleton, source_proxy)

		# RetargetModifier3D is a child modifier of source_proxy. The proxy is
		# manual so this is the only place that advances the native modifier.
		source_proxy.advance(delta)

	# RetargetModifier3D has now copied the donor pose onto the BRC rig.
	# Drive only the RUN arm endpoints with proper two-bone IK so the arms
	# travel forward/back beside the torso instead of being spread sideways.
	_update_brc_arm_ik_targets(delta)
	_stabilize_brc_shoulders()
	_stabilize_brc_hand_rotations()
	_apply_idle_stance_correction(delta)

	# The real BRC skeleton is manual so its TwoBoneIK3D modifiers execute
	# exactly after native retargeting.
	if target_skeleton != null:
		target_skeleton.advance(delta)

	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		var motion: InputEventMouseMotion = event
		camera_pivot.rotation.y -= motion.relative.x * 0.003
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x - motion.relative.y * 0.003,
			deg_to_rad(-55.0),
			deg_to_rad(25.0)
		)
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and not key_event.echo:
			if key_event.physical_keycode == KEY_ESCAPE:
				mouse_captured = not mouse_captured
				Input.mouse_mode = (
					Input.MOUSE_MODE_CAPTURED
					if mouse_captured
					else Input.MOUSE_MODE_VISIBLE
				)
			elif key_event.physical_keycode == KEY_F2:
				show_source_model = not show_source_model
				_set_source_visibility(show_source_model)


func _float_key(keycode: int) -> float:
	return 1.0 if Input.is_physical_key_pressed(keycode) else 0.0


func _load_target_model() -> void:
	if not ResourceLoader.exists(TARGET_GLTF_PATH):
		_fail("Missing BRC model: " + TARGET_GLTF_PATH)
		return

	var target_scene: PackedScene = load(TARGET_GLTF_PATH) as PackedScene
	if target_scene == null:
		_fail("Could not load BRC PackedScene.")
		return

	target_instance = target_scene.instantiate() as Node3D
	if target_instance == null:
		_fail("Could not instantiate BRC model.")
		return

	target_instance.scale = Vector3.ONE * TARGET_MODEL_SCALE
	target_mount.add_child(target_instance)
	target_skeleton = _find_skeleton(target_instance)

	if target_skeleton == null:
		_fail("No Skeleton3D in BRC model.")


func _load_source_animation_rig() -> void:
	if not ResourceLoader.exists(SOURCE_GLTF_PATH):
		_fail(
			"Missing official Godot donor:\n"
			+ SOURCE_GLTF_PATH
			+ "\nRun the installer again."
		)
		return

	var source_scene: PackedScene = load(SOURCE_GLTF_PATH) as PackedScene
	if source_scene == null:
		_fail("Could not load official Godot platformer player.glb.")
		return

	source_instance = source_scene.instantiate() as Node3D
	if source_instance == null:
		_fail("Could not instantiate donor model.")
		return

	source_mount.add_child(source_instance)
	source_skeleton = _find_skeleton(source_instance)
	source_animation_player = _find_animation_player(source_instance)
	_set_source_visibility(false)


func _build_native_retarget_pipeline() -> void:
	source_proxy = _duplicate_skeleton_as_proxy(
		source_skeleton,
		SOURCE_CANONICAL,
		"SourceHumanoidProxy"
	)
	target_proxy = _duplicate_skeleton_as_proxy(
		target_skeleton,
		TARGET_CANONICAL,
		"TargetHumanoidProxy"
	)

	if source_proxy == null or target_proxy == null:
		_fail("Could not build canonical proxy Skeleton3Ds.")
		return

	# Proxy skeleton is only a modifier driver; never drawn.
	add_child(source_proxy)

	source_proxy.modifier_callback_mode_process = (
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	)
	source_proxy.motion_scale = source_skeleton.motion_scale
	target_proxy.motion_scale = target_skeleton.motion_scale

	humanoid_profile = SkeletonProfileHumanoid.new()

	retarget_modifier = RetargetModifier3D.new()
	retarget_modifier.name = "NativeRetargetModifier3D"
	retarget_modifier.profile = humanoid_profile

	# First test only retargets rotations. This keeps BRC proportions and avoids
	# donor bone lengths/translation tracks changing the target body.
	retarget_modifier.set_position_enabled(false)
	retarget_modifier.set_rotation_enabled(true)
	retarget_modifier.set_scale_enabled(false)
	retarget_modifier.use_global_pose = false

	source_proxy.add_child(retarget_modifier)

	# RetargetModifier3D discovers direct child Skeleton3D nodes.
	retarget_modifier.add_child(target_proxy)

	target_proxy_to_real.clear()
	for target_brc_name_value: Variant in TARGET_CANONICAL.keys():
		var target_brc_name: String = String(target_brc_name_value)
		var canonical_name: String = String(TARGET_CANONICAL[target_brc_name_value])

		var proxy_index: int = target_proxy.find_bone(canonical_name)
		var real_index: int = target_skeleton.find_bone(target_brc_name)

		if proxy_index >= 0 and real_index >= 0:
			target_proxy_to_real[proxy_index] = real_index

	retarget_modifier.modification_processed.connect(
		_on_native_retarget_processed
	)

	var source_count: int = _count_profile_bones(source_proxy)
	var target_count: int = _count_profile_bones(target_proxy)

	print("[NATIVE RETARGET] source profile bones: ", source_count)
	print("[NATIVE RETARGET] target profile bones: ", target_count)
	print("[NATIVE RETARGET] target copy mappings: ", target_proxy_to_real.size())

	native_retarget_ready = (
		source_count >= 13
		and target_count >= 17
		and target_proxy_to_real.size() >= 17
	)

	if not native_retarget_ready:
		_fail(
			"Native retarget proxy mapping is incomplete.\n"
			+ "source="
			+ str(source_count)
			+ " target="
			+ str(target_count)
			+ " copy="
			+ str(target_proxy_to_real.size())
		)


func _duplicate_skeleton_as_proxy(
	original: Skeleton3D,
	canonical_map: Dictionary,
	proxy_name: String
) -> Skeleton3D:
	if original == null:
		return null

	var proxy := Skeleton3D.new()
	proxy.name = proxy_name

	var bone_count: int = original.get_bone_count()

	# Create bones in the exact same order so parent indices/rest hierarchy are
	# identical. Only mapped names become Humanoid profile names.
	for bone_index in range(bone_count):
		var original_name: String = original.get_bone_name(bone_index)
		var proxy_bone_name: String = original_name

		if canonical_map.has(original_name):
			proxy_bone_name = String(canonical_map[original_name])

		var added_index: int = proxy.add_bone(proxy_bone_name)
		if added_index != bone_index:
			push_error(
				"[NATIVE RETARGET] Proxy bone index mismatch for "
				+ original_name
			)
			return null

	for bone_index in range(bone_count):
		proxy.set_bone_parent(
			bone_index,
			original.get_bone_parent(bone_index)
		)
		proxy.set_bone_rest(
			bone_index,
			original.get_bone_rest(bone_index)
		)
		proxy.set_bone_enabled(
			bone_index,
			original.is_bone_enabled(bone_index)
		)

	proxy.reset_bone_poses()
	return proxy


func _copy_complete_pose(from_skeleton: Skeleton3D, to_skeleton: Skeleton3D) -> void:
	if from_skeleton == null or to_skeleton == null:
		return

	var count: int = mini(
		from_skeleton.get_bone_count(),
		to_skeleton.get_bone_count()
	)

	for bone_index in range(count):
		to_skeleton.set_bone_pose_position(
			bone_index,
			from_skeleton.get_bone_pose_position(bone_index)
		)
		to_skeleton.set_bone_pose_rotation(
			bone_index,
			from_skeleton.get_bone_pose_rotation(bone_index)
		)
		to_skeleton.set_bone_pose_scale(
			bone_index,
			from_skeleton.get_bone_pose_scale(bone_index)
		)


func _on_native_retarget_processed() -> void:
	if target_proxy == null or target_skeleton == null:
		return

	# Native RetargetModifier3D has now done the difficult cross-rig conversion.
	# Copy only its canonical target bones onto the identical real BRC rig.
	for proxy_index_value: Variant in target_proxy_to_real.keys():
		var proxy_index: int = int(proxy_index_value)
		var real_index: int = int(target_proxy_to_real[proxy_index_value])

		target_skeleton.set_bone_pose_rotation(
			real_index,
			target_proxy.get_bone_pose_rotation(proxy_index)
		)

	# Unmapped BRC bones (fingers etc.) remain at their imported rest pose and
	# follow the animated mapped parent chain normally.
	retarget_frame_count += 1



func _build_brc_arm_ik() -> void:
	if target_skeleton == null:
		return

	var arm1_l: int = target_skeleton.find_bone("arm1l")
	var arm2_l: int = target_skeleton.find_bone("arm2l")
	var hand_l: int = target_skeleton.find_bone("handl")
	var arm1_r: int = target_skeleton.find_bone("arm1r")
	var arm2_r: int = target_skeleton.find_bone("arm2r")
	var hand_r: int = target_skeleton.find_bone("handr")

	if (
		arm1_l < 0 or arm2_l < 0 or hand_l < 0
		or arm1_r < 0 or arm2_r < 0 or hand_r < 0
	):
		_fail("BRC arm chain is incomplete; cannot create TwoBoneIK3D.")
		return

	# The BRC skeleton is driven manually because native retargeting is copied
	# into it first, then arm IK must run afterward in the same frame.
	target_skeleton.modifier_callback_mode_process = (
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	)

	left_hand_target = Marker3D.new()
	left_hand_target.name = "LeftRunHandTarget"
	target_skeleton.add_child(left_hand_target)

	right_hand_target = Marker3D.new()
	right_hand_target.name = "RightRunHandTarget"
	target_skeleton.add_child(right_hand_target)

	left_elbow_pole = Marker3D.new()
	left_elbow_pole.name = "LeftRunElbowPole"
	target_skeleton.add_child(left_elbow_pole)

	right_elbow_pole = Marker3D.new()
	right_elbow_pole.name = "RightRunElbowPole"
	target_skeleton.add_child(right_elbow_pole)

	left_arm_ik = TwoBoneIK3D.new()
	left_arm_ik.name = "LeftRunTwoBoneIK"
	left_arm_ik.setting_count = 1
	left_arm_ik.set_root_bone_name(0, "arm1l")
	left_arm_ik.set_middle_bone_name(0, "arm2l")
	left_arm_ik.set_end_bone_name(0, "handl")
	target_skeleton.add_child(left_arm_ik)
	left_arm_ik.set_target_node(
		0,
		left_arm_ik.get_path_to(left_hand_target)
	)
	left_arm_ik.set_pole_node(
		0,
		left_arm_ik.get_path_to(left_elbow_pole)
	)
	left_arm_ik.influence = 0.0

	right_arm_ik = TwoBoneIK3D.new()
	right_arm_ik.name = "RightRunTwoBoneIK"
	right_arm_ik.setting_count = 1
	right_arm_ik.set_root_bone_name(0, "arm1r")
	right_arm_ik.set_middle_bone_name(0, "arm2r")
	right_arm_ik.set_end_bone_name(0, "handr")
	target_skeleton.add_child(right_arm_ik)
	right_arm_ik.set_target_node(
		0,
		right_arm_ik.get_path_to(right_hand_target)
	)
	right_arm_ik.set_pole_node(
		0,
		right_arm_ik.get_path_to(right_elbow_pole)
	)
	right_arm_ik.influence = 0.0

	hand_rest_rotation.clear()
	hand_rest_rotation["left"] = (
		target_skeleton
		.get_bone_rest(hand_l)
		.basis
		.orthonormalized()
		.get_rotation_quaternion()
	)
	hand_rest_rotation["right"] = (
		target_skeleton
		.get_bone_rest(hand_r)
		.basis
		.orthonormalized()
		.get_rotation_quaternion()
	)

	var shld_l: int = target_skeleton.find_bone("shldl")
	var shld_r: int = target_skeleton.find_bone("shldr")
	if shld_l >= 0:
		shoulder_rest_rotation["left"] = (
			target_skeleton
			.get_bone_rest(shld_l)
			.basis
			.orthonormalized()
			.get_rotation_quaternion()
		)
	if shld_r >= 0:
		shoulder_rest_rotation["right"] = (
			target_skeleton
			.get_bone_rest(shld_r)
			.basis
			.orthonormalized()
			.get_rotation_quaternion()
		)

	# Start in a compact neutral run-arm position rather than the donor's
	# abducted/T-pose-like arm placement.
	left_hand_target.position = Vector3(
		IDLE_HAND_SIDE,
		IDLE_HAND_Y,
		IDLE_HAND_Z
	)
	right_hand_target.position = Vector3(
		-IDLE_HAND_SIDE,
		IDLE_HAND_Y,
		IDLE_HAND_Z
	)
	left_elbow_pole.position = Vector3(
		IDLE_ELBOW_SIDE,
		IDLE_ELBOW_Y,
		IDLE_ELBOW_Z
	)
	right_elbow_pole.position = Vector3(
		-IDLE_ELBOW_SIDE,
		IDLE_ELBOW_Y,
		IDLE_ELBOW_Z
	)

	print("[ARM IK] Godot TwoBoneIK3D created for both BRC arms.")


func _update_brc_arm_ik_targets(delta: float) -> void:
	if (
		left_arm_ik == null
		or right_arm_ik == null
		or left_hand_target == null
		or right_hand_target == null
	):
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var grounded: bool = is_on_floor()
	var run_weight: float = clampf(
		(horizontal_speed - 0.25) / 2.75,
		0.0,
		1.0
	)

	# On the ground the BRC IK owns the arms even while standing still.
	# This prevents the donor's wide/T-pose-like idle arms from leaking through.
	var target_blend: float = 1.0 if grounded else 0.0
	arm_ik_blend = move_toward(
		arm_ik_blend,
		target_blend,
		ARM_IK_BLEND_SPEED * delta
	)

	left_arm_ik.influence = arm_ik_blend
	right_arm_ik.influence = arm_ik_blend

	if arm_ik_blend <= 0.001:
		return

	var raw_stride: float = 0.0

	if run_weight > 0.001:
		var foot_l: int = target_skeleton.find_bone("footl")
		var foot_r: int = target_skeleton.find_bone("footr")

		if foot_l >= 0 and foot_r >= 0:
			var left_foot: Vector3 = (
				target_skeleton.get_bone_global_pose(foot_l).origin
			)
			var right_foot: Vector3 = (
				target_skeleton.get_bone_global_pose(foot_r).origin
			)

			raw_stride = clampf(
				(left_foot.z - right_foot.z) / 0.34,
				-1.0,
				1.0
			)

	arm_stride = lerpf(
		arm_stride,
		raw_stride,
		clampf(ARM_TARGET_SMOOTH * delta, 0.0, 1.0)
	)

	var left_forwardness: float = -arm_stride
	var right_forwardness: float = arm_stride

	var idle_left_hand := Vector3(
		IDLE_HAND_SIDE,
		IDLE_HAND_Y,
		IDLE_HAND_Z
	)
	var idle_right_hand := Vector3(
		-IDLE_HAND_SIDE,
		IDLE_HAND_Y,
		IDLE_HAND_Z
	)

	var run_left_hand := Vector3(
		RUN_HAND_SIDE,
		RUN_HAND_MID_Y + left_forwardness * RUN_HAND_FORWARD_Y,
		left_forwardness * RUN_HAND_SWING_Z
	)
	var run_right_hand := Vector3(
		-RUN_HAND_SIDE,
		RUN_HAND_MID_Y + right_forwardness * RUN_HAND_FORWARD_Y,
		right_forwardness * RUN_HAND_SWING_Z
	)

	var idle_left_pole := Vector3(
		IDLE_ELBOW_SIDE,
		IDLE_ELBOW_Y,
		IDLE_ELBOW_Z
	)
	var idle_right_pole := Vector3(
		-IDLE_ELBOW_SIDE,
		IDLE_ELBOW_Y,
		IDLE_ELBOW_Z
	)

	var run_left_pole := Vector3(
		RUN_ELBOW_SIDE,
		RUN_ELBOW_Y,
		run_left_hand.z * RUN_ELBOW_Z_SCALE
	)
	var run_right_pole := Vector3(
		-RUN_ELBOW_SIDE,
		RUN_ELBOW_Y,
		run_right_hand.z * RUN_ELBOW_Z_SCALE
	)

	var left_target: Vector3 = idle_left_hand.lerp(
		run_left_hand,
		run_weight
	)
	var right_target: Vector3 = idle_right_hand.lerp(
		run_right_hand,
		run_weight
	)
	var left_pole: Vector3 = idle_left_pole.lerp(
		run_left_pole,
		run_weight
	)
	var right_pole: Vector3 = idle_right_pole.lerp(
		run_right_pole,
		run_weight
	)

	var target_amount: float = clampf(
		ARM_TARGET_SMOOTH * delta,
		0.0,
		1.0
	)

	left_hand_target.position = left_hand_target.position.lerp(
		left_target,
		target_amount
	)
	right_hand_target.position = right_hand_target.position.lerp(
		right_target,
		target_amount
	)
	left_elbow_pole.position = left_elbow_pole.position.lerp(
		left_pole,
		target_amount
	)
	right_elbow_pole.position = right_elbow_pole.position.lerp(
		right_pole,
		target_amount
	)



func _stabilize_brc_shoulders() -> void:
	if target_skeleton == null or arm_ik_blend <= 0.001:
		return
	if shoulder_rest_rotation.is_empty():
		return

	var shld_l: int = target_skeleton.find_bone("shldl")
	var shld_r: int = target_skeleton.find_bone("shldr")

	if shld_l >= 0 and shoulder_rest_rotation.has("left"):
		var current_l: Quaternion = target_skeleton.get_bone_pose_rotation(shld_l)
		var rest_l: Quaternion = shoulder_rest_rotation["left"]
		target_skeleton.set_bone_pose_rotation(
			shld_l,
			current_l.slerp(rest_l, clampf(arm_ik_blend * 0.95, 0.0, 1.0))
		)

	if shld_r >= 0 and shoulder_rest_rotation.has("right"):
		var current_r: Quaternion = target_skeleton.get_bone_pose_rotation(shld_r)
		var rest_r: Quaternion = shoulder_rest_rotation["right"]
		target_skeleton.set_bone_pose_rotation(
			shld_r,
			current_r.slerp(rest_r, clampf(arm_ik_blend * 0.95, 0.0, 1.0))
		)



func _stabilize_brc_hand_rotations() -> void:
	if target_skeleton == null or arm_ik_blend <= 0.001:
		return
	if hand_rest_rotation.is_empty():
		return

	var hand_l: int = target_skeleton.find_bone("handl")
	var hand_r: int = target_skeleton.find_bone("handr")

	if hand_l >= 0:
		var current_l: Quaternion = target_skeleton.get_bone_pose_rotation(hand_l)
		var rest_l: Quaternion = hand_rest_rotation["left"]
		target_skeleton.set_bone_pose_rotation(
			hand_l,
			current_l.slerp(rest_l, arm_ik_blend)
		)

	if hand_r >= 0:
		var current_r: Quaternion = target_skeleton.get_bone_pose_rotation(hand_r)
		var rest_r: Quaternion = hand_rest_rotation["right"]
		target_skeleton.set_bone_pose_rotation(
			hand_r,
			current_r.slerp(rest_r, arm_ik_blend)
		)



func _apply_idle_stance_correction(delta: float) -> void:
	if target_skeleton == null:
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var grounded: bool = is_on_floor()
	var wanted_blend: float = 1.0 if grounded and horizontal_speed <= IDLE_STANCE_ACTIVE_MAX_SPEED else 0.0
	idle_stance_blend = move_toward(
		idle_stance_blend,
		wanted_blend,
		IDLE_STANCE_BLEND_SPEED * delta
	)

	if idle_stance_blend <= 0.001:
		return

	_apply_leg_pose("leg1l", Vector3(0.0, IDLE_LEG_BEND, -IDLE_THIGH_SPREAD_Z), idle_stance_blend)
	_apply_leg_pose("leg1r", Vector3(0.0, IDLE_LEG_BEND, IDLE_THIGH_SPREAD_Z), idle_stance_blend)
	_apply_leg_pose("leg2l", Vector3(0.0, -IDLE_LEG_BEND * 0.55, 0.0), idle_stance_blend)
	_apply_leg_pose("leg2r", Vector3(0.0, -IDLE_LEG_BEND * 0.55, 0.0), idle_stance_blend)
	_apply_leg_pose("footl", Vector3(0.0, IDLE_FOOT_BEND, -IDLE_FOOT_OUT_Z), idle_stance_blend)
	_apply_leg_pose("footr", Vector3(0.0, IDLE_FOOT_BEND, IDLE_FOOT_OUT_Z), idle_stance_blend)
	_apply_leg_pose("toesl", Vector3(0.0, IDLE_TOE_BEND, 0.0), idle_stance_blend)
	_apply_leg_pose("toesr", Vector3(0.0, IDLE_TOE_BEND, 0.0), idle_stance_blend)


func _apply_leg_pose(bone_name: String, euler_delta: Vector3, blend: float) -> void:
	var bone: int = target_skeleton.find_bone(bone_name)
	if bone < 0:
		return

	var current: Quaternion = target_skeleton.get_bone_pose_rotation(bone)
	var delta_q: Quaternion = Quaternion.from_euler(euler_delta)
	target_skeleton.set_bone_pose_rotation(
		bone,
		current.slerp(current * delta_q, clampf(blend, 0.0, 1.0))
	)


func _count_profile_bones(skeleton_value: Skeleton3D) -> int:
	var count: int = 0
	if humanoid_profile == null:
		return count

	for profile_index in range(humanoid_profile.bone_size):
		var profile_name: StringName = humanoid_profile.get_bone_name(profile_index)
		if skeleton_value.find_bone(String(profile_name)) >= 0:
			count += 1

	return count


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D

	for child_value: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child_value)
		if found != null:
			return found

	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child_value: Node in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child_value)
		if found != null:
			return found

	return null


func _set_source_visibility(visible_value: bool) -> void:
	if source_instance == null:
		return
	_set_geometry_visibility_recursive(source_instance, visible_value)


func _set_geometry_visibility_recursive(
	node: Node,
	visible_value: bool
) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.visible = visible_value

	for child_value: Node in node.get_children():
		_set_geometry_visibility_recursive(child_value, visible_value)


func _update_animation_state(horizontal_speed: float) -> void:
	if source_animation_player == null:
		return

	var wanted: StringName

	if not is_on_floor():
		wanted = &"jump" if velocity.y > 0.0 else &"falling"
	elif horizontal_speed > 0.25:
		wanted = &"run"
	else:
		wanted = &"idle"

	if wanted != current_animation:
		_play_if_available(wanted, 0.12)


func _play_if_available(animation_name: StringName, blend_time: float) -> void:
	if source_animation_player == null:
		return

	if source_animation_player.has_animation(animation_name):
		source_animation_player.play(animation_name, blend_time)
		current_animation = animation_name
		return

	var suffix: String = "/" + String(animation_name)

	for candidate: StringName in source_animation_player.get_animation_list():
		if String(candidate).ends_with(suffix):
			source_animation_player.play(candidate, blend_time)
			current_animation = candidate
			return

	push_warning(
		"[NATIVE RETARGET] Animation not found: " + String(animation_name)
	)


func _update_status() -> void:
	if status_label == null:
		return

	status_label.text = (
		"NATIVE RETARGET + RELAXED IDLE STANCE V8\n"
		+ "WASD move | SPACE jump | mouse camera | ESC mouse | F2 donor\n"
		+ "anim="
		+ String(current_animation)
		+ " | native frames="
		+ str(retarget_frame_count)
		+ "\nMain game files are untouched."
	)


func _fail(message: String) -> void:
	push_error("[NATIVE RETARGET] " + message)
	if status_label != null:
		status_label.text = "NATIVE RETARGET FAILED\n" + message
