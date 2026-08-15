extends Node

# Main-game BRC Spider animation controller.
#
# Locomotion architecture:
#   official Godot platformer animation rig
#       -> donor proxy
#       -> native RetargetModifier3D
#       -> BRC proxy
#       -> real BRC Skeleton3D
#
# Then BRC-specific TwoBoneIK3D modifiers clean up the arms and give idle
# stance a slightly wider pair of legs.
#
# This intentionally replaces the old hand-authored procedural ground run.
# Gameplay physics remain owned by player.gd.

const SOURCE_GLTF_PATH: String = "res://third_party/godot_platformer/player.glb"

# Official platformer donor -> SkeletonProfileHumanoid names.
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

# BRC Spider -> SkeletonProfileHumanoid names.
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

# Ground arm targets in BRC skeleton space.
# BRC faces approximately +Z and character-left is +X.
const IDLE_HAND_SIDE: float = 0.305
const IDLE_HAND_Y: float = 0.900
const IDLE_HAND_Z: float = 0.020
const IDLE_ELBOW_SIDE: float = 0.250
const IDLE_ELBOW_Y: float = 1.055
const IDLE_ELBOW_Z: float = -0.010

# Run hands are placed relative to the animated shoulder. Their reach is
# derived from the real upper-arm/forearm lengths so the IK elbow remains at
# 90 degrees throughout the stride instead of straightening at the extremes.
const RUN_HAND_OUTWARD_FROM_SHOULDER: float = 0.100
const RUN_HAND_SWING_Z: float = 0.170
const RUN_POLE_OUTWARD_FROM_SHOULDER: float = 0.060
const RUN_POLE_DOWN_FROM_SHOULDER: float = 0.160
const RUN_POLE_BEHIND_SHOULDER: float = 0.280

const ARM_TARGET_SMOOTH: float = 12.0
const ARM_IK_BLEND_SPEED: float = 9.0

# Idle leg stance. The actual target positions are derived from THIS BRC
# skeleton's own rest/global pose, then only moved sideways.
const IDLE_FOOT_EXTRA_SIDE: float = 0.085
const IDLE_KNEE_POLE_FORWARD: float = 0.34
const IDLE_LEG_IK_BLEND_SPEED: float = 8.0
const IDLE_LEG_IK_MAX_SPEED: float = 0.75

# Donor clip playback speed follows gameplay horizontal speed.
const DONOR_RUN_REFERENCE_SPEED: float = 7.5
const DONOR_WALK_REFERENCE_SPEED: float = 3.0

var skeleton: Skeleton3D = null
var player: CharacterBody3D = null
var web_origin_l: Marker3D = null
var web_origin_r: Marker3D = null

var source_instance: Node3D = null
var source_skeleton: Skeleton3D = null
var source_animation_player: AnimationPlayer = null

var source_proxy: Skeleton3D = null
var target_proxy: Skeleton3D = null
var retarget_modifier: RetargetModifier3D = null
var humanoid_profile: SkeletonProfileHumanoid = null
var target_proxy_to_real: Dictionary = {}

var current_animation: StringName = &""
var native_retarget_ready: bool = false

var left_arm_ik: TwoBoneIK3D = null
var right_arm_ik: TwoBoneIK3D = null
var left_hand_target: Marker3D = null
var right_hand_target: Marker3D = null
var left_elbow_pole: Marker3D = null
var right_elbow_pole: Marker3D = null
var arm_ik_blend: float = 0.0
var arm_stride: float = 0.0
var shoulder_rest_rotation: Dictionary = {}
var hand_rest_rotation: Dictionary = {}
var left_arm_root_bone: int = -1
var right_arm_root_bone: int = -1
var left_arm_right_angle_reach: float = 0.0
var right_arm_right_angle_reach: float = 0.0

var left_leg_ik: TwoBoneIK3D = null
var right_leg_ik: TwoBoneIK3D = null
var left_foot_target: Marker3D = null
var right_foot_target: Marker3D = null
var left_knee_pole: Marker3D = null
var right_knee_pole: Marker3D = null
var left_foot_idle_position: Vector3 = Vector3.ZERO
var right_foot_idle_position: Vector3 = Vector3.ZERO
var left_knee_idle_position: Vector3 = Vector3.ZERO
var right_knee_idle_position: Vector3 = Vector3.ZERO
var leg_ik_blend: float = 0.0

var active_web_hand: int = -1
var was_grappling: bool = false


func setup(
	target_skeleton: Skeleton3D,
	target_player: Node,
	target_web_origin_l: Marker3D,
	target_web_origin_r: Marker3D
) -> void:
	skeleton = target_skeleton
	player = target_player as CharacterBody3D
	web_origin_l = target_web_origin_l
	web_origin_r = target_web_origin_r

	if skeleton == null or player == null:
		push_error("[SPIDEY NATIVE] Missing target skeleton/player.")
		return

	process_priority = 100

	_load_source_animation_rig()

	if source_skeleton == null or source_animation_player == null:
		push_error(
			"[SPIDEY NATIVE] Donor rig unavailable. "
			+ "Run the installer again."
		)
		return

	_build_native_retarget_pipeline()
	_build_brc_arm_ik()
	_build_brc_idle_leg_ik()
	_force_donor_loops()

	_play_if_available(&"idle", 0.0)
	was_grappling = bool(player.get("grappling"))

	print(
		"[SPIDEY NATIVE] Main-game locomotion enabled. "
		+ "Donor run/walk clips are forced to loop."
	)


func _process(delta: float) -> void:
	if not native_retarget_ready or player == null or skeleton == null:
		return

	var horizontal_speed: float = Vector2(
		player.velocity.x,
		player.velocity.z
	).length()

	_update_animation_state(horizontal_speed)

	# Safety: even if a donor clip import unexpectedly stops, replay the
	# intended locomotion clip instead of allowing the character to slide.
	if (
		source_animation_player != null
		and current_animation != &""
		and not source_animation_player.is_playing()
	):
		_play_if_available(current_animation, 0.0)

	_copy_complete_pose(source_skeleton, source_proxy)
	source_proxy.advance(delta)

	_update_ground_arm_targets(delta, horizontal_speed)
	_stabilize_brc_shoulders()
	_stabilize_brc_hands()
	_update_idle_leg_targets(delta, horizontal_speed)

	# Execute BRC-specific IK modifiers after native retargeting.
	skeleton.advance(delta)

	_update_web_hand_state()
	_update_web_origins()
	_override_player_web_line()


func _load_source_animation_rig() -> void:
	if not ResourceLoader.exists(SOURCE_GLTF_PATH):
		push_error("[SPIDEY NATIVE] Missing donor: " + SOURCE_GLTF_PATH)
		return

	var source_scene: PackedScene = load(SOURCE_GLTF_PATH) as PackedScene
	if source_scene == null:
		return

	source_instance = source_scene.instantiate() as Node3D
	if source_instance == null:
		return

	source_instance.name = "HiddenGodotPlatformerDonor"
	add_child(source_instance)

	source_skeleton = _find_skeleton(source_instance)
	source_animation_player = _find_animation_player(source_instance)
	_set_geometry_visibility_recursive(source_instance, false)


func _build_native_retarget_pipeline() -> void:
	source_proxy = _duplicate_skeleton_as_proxy(
		source_skeleton,
		SOURCE_CANONICAL,
		"SourceHumanoidProxy"
	)
	target_proxy = _duplicate_skeleton_as_proxy(
		skeleton,
		TARGET_CANONICAL,
		"TargetHumanoidProxy"
	)

	if source_proxy == null or target_proxy == null:
		push_error("[SPIDEY NATIVE] Could not create retarget proxies.")
		return

	add_child(source_proxy)
	source_proxy.modifier_callback_mode_process = (
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	)
	source_proxy.motion_scale = source_skeleton.motion_scale
	target_proxy.motion_scale = skeleton.motion_scale

	humanoid_profile = SkeletonProfileHumanoid.new()

	retarget_modifier = RetargetModifier3D.new()
	retarget_modifier.name = "NativeRetargetModifier3D"
	retarget_modifier.profile = humanoid_profile
	retarget_modifier.set_position_enabled(false)
	retarget_modifier.set_rotation_enabled(true)
	retarget_modifier.set_scale_enabled(false)
	retarget_modifier.use_global_pose = false

	source_proxy.add_child(retarget_modifier)
	retarget_modifier.add_child(target_proxy)

	target_proxy_to_real.clear()

	for brc_name_value: Variant in TARGET_CANONICAL.keys():
		var brc_name: String = String(brc_name_value)
		var canonical_name: String = String(TARGET_CANONICAL[brc_name_value])

		var proxy_index: int = target_proxy.find_bone(canonical_name)
		var real_index: int = skeleton.find_bone(brc_name)

		if proxy_index >= 0 and real_index >= 0:
			target_proxy_to_real[proxy_index] = real_index

	retarget_modifier.modification_processed.connect(
		_on_native_retarget_processed
	)

	native_retarget_ready = target_proxy_to_real.size() >= 17

	if not native_retarget_ready:
		push_error(
			"[SPIDEY NATIVE] Incomplete target mapping: "
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

	for bone_index in range(bone_count):
		var original_name: String = original.get_bone_name(bone_index)
		var proxy_name_for_bone: String = original_name

		if canonical_map.has(original_name):
			proxy_name_for_bone = String(canonical_map[original_name])

		var added_index: int = proxy.add_bone(proxy_name_for_bone)

		if added_index != bone_index:
			push_error(
				"[SPIDEY NATIVE] Proxy index mismatch: " + original_name
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


func _copy_complete_pose(
	from_skeleton: Skeleton3D,
	to_skeleton: Skeleton3D
) -> void:
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
	if target_proxy == null or skeleton == null:
		return

	for proxy_index_value: Variant in target_proxy_to_real.keys():
		var proxy_index: int = int(proxy_index_value)
		var real_index: int = int(target_proxy_to_real[proxy_index_value])

		skeleton.set_bone_pose_rotation(
			real_index,
			target_proxy.get_bone_pose_rotation(proxy_index)
		)


func _force_donor_loops() -> void:
	if source_animation_player == null:
		return

	for clip_name: StringName in source_animation_player.get_animation_list():
		var short_name: String = String(clip_name).get_file()

		if (
			short_name == "idle"
			or short_name == "walk"
			or short_name == "run"
		):
			var animation: Animation = source_animation_player.get_animation(
				clip_name
			)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR


func _update_animation_state(horizontal_speed: float) -> void:
	if source_animation_player == null:
		return

	var grappling: bool = bool(player.get("grappling"))
	var wall_riding: bool = bool(player.get("wall_riding"))
	var wanted: StringName

	if grappling:
		wanted = &"falling"
	elif wall_riding:
		# Temporary main-game integration: use the looping run body as the
		# baseline. A dedicated wall-run layer can replace this next.
		wanted = &"run"
	elif not player.is_on_floor():
		wanted = &"jump" if player.velocity.y > 0.0 else &"falling"
	elif horizontal_speed > 4.0:
		wanted = &"run"
	elif horizontal_speed > 0.35:
		wanted = &"walk"
	else:
		wanted = &"idle"

	if wanted != current_animation:
		_play_if_available(wanted, 0.10)

	if current_animation == &"run":
		source_animation_player.speed_scale = clampf(
			horizontal_speed / DONOR_RUN_REFERENCE_SPEED,
			0.85,
			1.65
		)
	elif current_animation == &"walk":
		source_animation_player.speed_scale = clampf(
			horizontal_speed / DONOR_WALK_REFERENCE_SPEED,
			0.70,
			1.45
		)
	else:
		source_animation_player.speed_scale = 1.0


func _play_if_available(
	animation_name: StringName,
	blend_time: float
) -> void:
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
		"[SPIDEY NATIVE] Donor clip missing: " + String(animation_name)
	)


func _build_brc_arm_ik() -> void:
	var arm1_l: int = skeleton.find_bone("arm1l")
	var arm2_l: int = skeleton.find_bone("arm2l")
	var hand_l: int = skeleton.find_bone("handl")
	var arm1_r: int = skeleton.find_bone("arm1r")
	var arm2_r: int = skeleton.find_bone("arm2r")
	var hand_r: int = skeleton.find_bone("handr")

	if (
		arm1_l < 0
		or arm2_l < 0
		or hand_l < 0
		or arm1_r < 0
		or arm2_r < 0
		or hand_r < 0
	):
		push_error("[SPIDEY NATIVE] BRC arm chain incomplete.")
		return

	left_arm_root_bone = arm1_l
	right_arm_root_bone = arm1_r
	left_arm_right_angle_reach = _get_right_angle_arm_reach(
		arm1_l,
		arm2_l,
		hand_l
	)
	right_arm_right_angle_reach = _get_right_angle_arm_reach(
		arm1_r,
		arm2_r,
		hand_r
	)

	skeleton.modifier_callback_mode_process = (
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	)

	left_hand_target = Marker3D.new()
	left_hand_target.name = "LeftGroundHandTarget"
	skeleton.add_child(left_hand_target)

	right_hand_target = Marker3D.new()
	right_hand_target.name = "RightGroundHandTarget"
	skeleton.add_child(right_hand_target)

	left_elbow_pole = Marker3D.new()
	left_elbow_pole.name = "LeftGroundElbowPole"
	skeleton.add_child(left_elbow_pole)

	right_elbow_pole = Marker3D.new()
	right_elbow_pole.name = "RightGroundElbowPole"
	skeleton.add_child(right_elbow_pole)

	left_arm_ik = TwoBoneIK3D.new()
	left_arm_ik.name = "LeftGroundArmIK"
	left_arm_ik.setting_count = 1
	left_arm_ik.set_root_bone_name(0, "arm1l")
	left_arm_ik.set_middle_bone_name(0, "arm2l")
	left_arm_ik.set_end_bone_name(0, "handl")
	skeleton.add_child(left_arm_ik)
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
	right_arm_ik.name = "RightGroundArmIK"
	right_arm_ik.setting_count = 1
	right_arm_ik.set_root_bone_name(0, "arm1r")
	right_arm_ik.set_middle_bone_name(0, "arm2r")
	right_arm_ik.set_end_bone_name(0, "handr")
	skeleton.add_child(right_arm_ik)
	right_arm_ik.set_target_node(
		0,
		right_arm_ik.get_path_to(right_hand_target)
	)
	right_arm_ik.set_pole_node(
		0,
		right_arm_ik.get_path_to(right_elbow_pole)
	)
	right_arm_ik.influence = 0.0

	hand_rest_rotation["left"] = (
		skeleton
		.get_bone_rest(hand_l)
		.basis
		.orthonormalized()
		.get_rotation_quaternion()
	)
	hand_rest_rotation["right"] = (
		skeleton
		.get_bone_rest(hand_r)
		.basis
		.orthonormalized()
		.get_rotation_quaternion()
	)

	var shld_l: int = skeleton.find_bone("shldl")
	var shld_r: int = skeleton.find_bone("shldr")

	if shld_l >= 0:
		shoulder_rest_rotation["left"] = (
			skeleton
			.get_bone_rest(shld_l)
			.basis
			.orthonormalized()
			.get_rotation_quaternion()
		)

	if shld_r >= 0:
		shoulder_rest_rotation["right"] = (
			skeleton
			.get_bone_rest(shld_r)
			.basis
			.orthonormalized()
			.get_rotation_quaternion()
		)

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


func _update_ground_arm_targets(
	delta: float,
	horizontal_speed: float
) -> void:
	if (
		left_arm_ik == null
		or right_arm_ik == null
		or left_hand_target == null
		or right_hand_target == null
	):
		return

	var grappling: bool = bool(player.get("grappling"))
	var wall_riding: bool = bool(player.get("wall_riding"))
	var grounded: bool = player.is_on_floor() and not grappling and not wall_riding

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

	var run_weight: float = clampf(
		(horizontal_speed - 0.35) / 4.0,
		0.0,
		1.0
	)
	var raw_stride: float = 0.0

	if run_weight > 0.001:
		var foot_l: int = skeleton.find_bone("footl")
		var foot_r: int = skeleton.find_bone("footr")

		if foot_l >= 0 and foot_r >= 0:
			var left_foot: Vector3 = (
				skeleton.get_bone_global_pose(foot_l).origin
			)
			var right_foot: Vector3 = (
				skeleton.get_bone_global_pose(foot_r).origin
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

	var left_shoulder: Vector3 = (
		skeleton.get_bone_global_pose(left_arm_root_bone).origin
	)
	var right_shoulder: Vector3 = (
		skeleton.get_bone_global_pose(right_arm_root_bone).origin
	)
	var run_left_hand: Vector3 = _get_run_hand_target(
		left_shoulder,
		1.0,
		left_forwardness,
		left_arm_right_angle_reach
	)
	var run_right_hand: Vector3 = _get_run_hand_target(
		right_shoulder,
		-1.0,
		right_forwardness,
		right_arm_right_angle_reach
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

	# Both poles stay on mirrored sagittal planes behind the shoulders. This
	# prevents inward/outward forearm twisting and lateral bird-wing poses.
	var run_left_pole := left_shoulder + Vector3(
		RUN_POLE_OUTWARD_FROM_SHOULDER,
		-RUN_POLE_DOWN_FROM_SHOULDER,
		-RUN_POLE_BEHIND_SHOULDER
	)
	var run_right_pole := right_shoulder + Vector3(
		-RUN_POLE_OUTWARD_FROM_SHOULDER,
		-RUN_POLE_DOWN_FROM_SHOULDER,
		-RUN_POLE_BEHIND_SHOULDER
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

	var amount: float = clampf(
		ARM_TARGET_SMOOTH * delta,
		0.0,
		1.0
	)

	# arm_stride is already smoothed. At full run, assign the spherical targets
	# directly so an extra Cartesian lerp cannot shorten the shoulder-hand
	# distance and over-bend the elbows between stride extremes.
	if run_weight >= 0.999:
		left_hand_target.position = left_target
		right_hand_target.position = right_target
	else:
		left_hand_target.position = left_hand_target.position.lerp(
			left_target,
			amount
		)
		right_hand_target.position = right_hand_target.position.lerp(
			right_target,
			amount
		)
	left_elbow_pole.position = left_elbow_pole.position.lerp(
		left_pole,
		amount
	)
	right_elbow_pole.position = right_elbow_pole.position.lerp(
		right_pole,
		amount
	)


func _get_right_angle_arm_reach(
	root_bone: int,
	middle_bone: int,
	end_bone: int
) -> float:
	var shoulder: Vector3 = skeleton.get_bone_global_rest(root_bone).origin
	var elbow: Vector3 = skeleton.get_bone_global_rest(middle_bone).origin
	var hand: Vector3 = skeleton.get_bone_global_rest(end_bone).origin
	var upper_length: float = shoulder.distance_to(elbow)
	var forearm_length: float = elbow.distance_to(hand)
	return sqrt(
		upper_length * upper_length + forearm_length * forearm_length
	)


func _get_run_hand_target(
	shoulder: Vector3,
	side: float,
	forwardness: float,
	right_angle_reach: float
) -> Vector3:
	var side_offset: float = RUN_HAND_OUTWARD_FROM_SHOULDER
	var forward_offset: float = forwardness * RUN_HAND_SWING_Z
	var vertical_squared: float = (
		right_angle_reach * right_angle_reach
		- side_offset * side_offset
		- forward_offset * forward_offset
	)
	var downward_offset: float = sqrt(maxf(vertical_squared, 0.0))
	return shoulder + Vector3(
		side * side_offset,
		-downward_offset,
		forward_offset
	)


func _stabilize_brc_shoulders() -> void:
	if skeleton == null or arm_ik_blend <= 0.001:
		return

	var shld_l: int = skeleton.find_bone("shldl")
	var shld_r: int = skeleton.find_bone("shldr")

	if shld_l >= 0 and shoulder_rest_rotation.has("left"):
		var current_l: Quaternion = skeleton.get_bone_pose_rotation(shld_l)
		var rest_l: Quaternion = shoulder_rest_rotation["left"]
		skeleton.set_bone_pose_rotation(
			shld_l,
			current_l.slerp(
				rest_l,
				clampf(arm_ik_blend * 0.95, 0.0, 1.0)
			)
		)

	if shld_r >= 0 and shoulder_rest_rotation.has("right"):
		var current_r: Quaternion = skeleton.get_bone_pose_rotation(shld_r)
		var rest_r: Quaternion = shoulder_rest_rotation["right"]
		skeleton.set_bone_pose_rotation(
			shld_r,
			current_r.slerp(
				rest_r,
				clampf(arm_ik_blend * 0.95, 0.0, 1.0)
			)
		)


func _stabilize_brc_hands() -> void:
	if skeleton == null or arm_ik_blend <= 0.001:
		return

	var hand_l: int = skeleton.find_bone("handl")
	var hand_r: int = skeleton.find_bone("handr")

	if hand_l >= 0 and hand_rest_rotation.has("left"):
		var current_l: Quaternion = skeleton.get_bone_pose_rotation(hand_l)
		var rest_l: Quaternion = hand_rest_rotation["left"]
		skeleton.set_bone_pose_rotation(
			hand_l,
			current_l.slerp(rest_l, arm_ik_blend)
		)

	if hand_r >= 0 and hand_rest_rotation.has("right"):
		var current_r: Quaternion = skeleton.get_bone_pose_rotation(hand_r)
		var rest_r: Quaternion = hand_rest_rotation["right"]
		skeleton.set_bone_pose_rotation(
			hand_r,
			current_r.slerp(rest_r, arm_ik_blend)
		)


func _build_brc_idle_leg_ik() -> void:
	var leg1_l: int = skeleton.find_bone("leg1l")
	var leg2_l: int = skeleton.find_bone("leg2l")
	var foot_l: int = skeleton.find_bone("footl")
	var leg1_r: int = skeleton.find_bone("leg1r")
	var leg2_r: int = skeleton.find_bone("leg2r")
	var foot_r: int = skeleton.find_bone("footr")

	if (
		leg1_l < 0
		or leg2_l < 0
		or foot_l < 0
		or leg1_r < 0
		or leg2_r < 0
		or foot_r < 0
	):
		push_warning("[SPIDEY NATIVE] Idle leg IK unavailable.")
		return

	var left_foot_rest: Transform3D = _calculate_global_rest(
		skeleton,
		foot_l
	)
	var right_foot_rest: Transform3D = _calculate_global_rest(
		skeleton,
		foot_r
	)
	var left_knee_rest: Transform3D = _calculate_global_rest(
		skeleton,
		leg2_l
	)
	var right_knee_rest: Transform3D = _calculate_global_rest(
		skeleton,
		leg2_r
	)

	left_foot_idle_position = left_foot_rest.origin
	right_foot_idle_position = right_foot_rest.origin

	left_foot_idle_position.x += IDLE_FOOT_EXTRA_SIDE
	right_foot_idle_position.x -= IDLE_FOOT_EXTRA_SIDE

	left_knee_idle_position = left_knee_rest.origin + Vector3(
		IDLE_FOOT_EXTRA_SIDE * 0.55,
		0.0,
		IDLE_KNEE_POLE_FORWARD
	)
	right_knee_idle_position = right_knee_rest.origin + Vector3(
		-IDLE_FOOT_EXTRA_SIDE * 0.55,
		0.0,
		IDLE_KNEE_POLE_FORWARD
	)

	left_foot_target = Marker3D.new()
	left_foot_target.name = "LeftIdleFootTarget"
	left_foot_target.position = left_foot_idle_position
	skeleton.add_child(left_foot_target)

	right_foot_target = Marker3D.new()
	right_foot_target.name = "RightIdleFootTarget"
	right_foot_target.position = right_foot_idle_position
	skeleton.add_child(right_foot_target)

	left_knee_pole = Marker3D.new()
	left_knee_pole.name = "LeftIdleKneePole"
	left_knee_pole.position = left_knee_idle_position
	skeleton.add_child(left_knee_pole)

	right_knee_pole = Marker3D.new()
	right_knee_pole.name = "RightIdleKneePole"
	right_knee_pole.position = right_knee_idle_position
	skeleton.add_child(right_knee_pole)

	left_leg_ik = TwoBoneIK3D.new()
	left_leg_ik.name = "LeftIdleLegIK"
	left_leg_ik.setting_count = 1
	left_leg_ik.set_root_bone_name(0, "leg1l")
	left_leg_ik.set_middle_bone_name(0, "leg2l")
	left_leg_ik.set_end_bone_name(0, "footl")
	skeleton.add_child(left_leg_ik)
	left_leg_ik.set_target_node(
		0,
		left_leg_ik.get_path_to(left_foot_target)
	)
	left_leg_ik.set_pole_node(
		0,
		left_leg_ik.get_path_to(left_knee_pole)
	)
	left_leg_ik.influence = 0.0

	right_leg_ik = TwoBoneIK3D.new()
	right_leg_ik.name = "RightIdleLegIK"
	right_leg_ik.setting_count = 1
	right_leg_ik.set_root_bone_name(0, "leg1r")
	right_leg_ik.set_middle_bone_name(0, "leg2r")
	right_leg_ik.set_end_bone_name(0, "footr")
	skeleton.add_child(right_leg_ik)
	right_leg_ik.set_target_node(
		0,
		right_leg_ik.get_path_to(right_foot_target)
	)
	right_leg_ik.set_pole_node(
		0,
		right_leg_ik.get_path_to(right_knee_pole)
	)
	right_leg_ik.influence = 0.0


func _update_idle_leg_targets(
	delta: float,
	horizontal_speed: float
) -> void:
	if left_leg_ik == null or right_leg_ik == null:
		return

	var grappling: bool = bool(player.get("grappling"))
	var wall_riding: bool = bool(player.get("wall_riding"))

	var idle_stance: bool = (
		player.is_on_floor()
		and not grappling
		and not wall_riding
		and horizontal_speed <= IDLE_LEG_IK_MAX_SPEED
	)

	var target_blend: float = 1.0 if idle_stance else 0.0
	leg_ik_blend = move_toward(
		leg_ik_blend,
		target_blend,
		IDLE_LEG_IK_BLEND_SPEED * delta
	)

	left_leg_ik.influence = leg_ik_blend
	right_leg_ik.influence = leg_ik_blend


func _calculate_global_rest(
	skeleton_value: Skeleton3D,
	bone_index: int
) -> Transform3D:
	var chain: Array[int] = []
	var current: int = bone_index

	while current >= 0:
		chain.push_front(current)
		current = skeleton_value.get_bone_parent(current)

	var result := Transform3D.IDENTITY

	for chain_index: int in chain:
		result = result * skeleton_value.get_bone_rest(chain_index)

	return result


func _update_web_hand_state() -> void:
	var grappling: bool = bool(player.get("grappling"))

	if grappling and not was_grappling:
		active_web_hand = _choose_web_hand()

	was_grappling = grappling


func _choose_web_hand() -> int:
	var grapple_value: Variant = player.get("grapple_point")

	if typeof(grapple_value) != TYPE_VECTOR3:
		return active_web_hand

	var camera_value: Variant = player.get("camera")
	var camera_node: Camera3D = camera_value as Camera3D

	if camera_node == null:
		return active_web_hand

	var local_target: Vector3 = camera_node.to_local(
		grapple_value as Vector3
	)

	if local_target.x < -0.08:
		return -1
	if local_target.x > 0.08:
		return 1

	return -active_web_hand


func _update_web_origins() -> void:
	_update_web_marker(
		web_origin_l,
		skeleton.find_bone("handl"),
		-1.0
	)
	_update_web_marker(
		web_origin_r,
		skeleton.find_bone("handr"),
		1.0
	)


func _update_web_marker(
	marker: Marker3D,
	hand_bone: int,
	side: float
) -> void:
	if marker == null or hand_bone < 0:
		return

	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_bone)
	var side_offset: Vector3 = (
		hand_pose.basis.x.normalized() * (0.045 * side)
	)
	var front_offset: Vector3 = (
		-hand_pose.basis.z.normalized() * 0.07
	)

	marker.global_position = skeleton.to_global(
		hand_pose.origin + side_offset + front_offset
	)


func _override_player_web_line() -> void:
	var grappling: bool = bool(player.get("grappling"))

	if not grappling:
		return

	var line_value: Variant = player.get("web_line")
	var mesh_value: Variant = player.get("web_mesh")
	var grapple_value: Variant = player.get("grapple_point")

	if (
		line_value == null
		or mesh_value == null
		or typeof(grapple_value) != TYPE_VECTOR3
	):
		return

	var line: MeshInstance3D = line_value as MeshInstance3D
	var box: BoxMesh = mesh_value as BoxMesh

	if line == null or box == null:
		return

	var marker: Marker3D = (
		web_origin_l if active_web_hand < 0 else web_origin_r
	)

	if marker == null:
		return

	var start: Vector3 = marker.global_position
	var target: Vector3 = grapple_value as Vector3
	var difference: Vector3 = target - start
	var length: float = difference.length()

	if length < 0.05:
		line.visible = false
		return

	line.visible = true
	line.global_position = start + difference * 0.5
	box.size = Vector3(0.045, 0.045, length)
	line.look_at(target, Vector3.UP)


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


func _set_geometry_visibility_recursive(
	node: Node,
	visible_value: bool
) -> void:
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		geometry.visible = visible_value

	for child_value: Node in node.get_children():
		_set_geometry_visibility_recursive(child_value, visible_value)
