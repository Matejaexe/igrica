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
# The real BRC skeleton has one authoritative traversal pipeline:
# donor base -> native retarget -> BRC state pose -> required IK -> final locks.
# The compatibility limb proxies in player.gd are deliberately not part of
# this pipeline. They remain only so older callers keep their expected nodes.
#
# This intentionally replaces the old hand-authored procedural ground run.
# Gameplay physics remain owned by player.gd.

const SOURCE_GLTF_PATH: String = "res://third_party/godot_platformer/player.glb"
const FINAL_POSE_MODIFIER_SCRIPT: Script = preload(
	"res://spidey_final_pose_modifier.gd"
)

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

# Idle arm targets in BRC skeleton space.
# BRC faces approximately +Z and character-left is +X.
const IDLE_HAND_SIDE: float = 0.305
const IDLE_HAND_Y: float = 0.900
const IDLE_HAND_Z: float = 0.020
const IDLE_ELBOW_SIDE: float = 0.250
const IDLE_ELBOW_Y: float = 1.055
const IDLE_ELBOW_Z: float = -0.010

# Direct BRC run-arm calibration, measured from the imported rest matrices.
# Shoulder local X/Z create a compact, low run shoulder rather than retaining
# the imported T-pose abduction. arm1 local X fixes the elbow-hinge plane while
# its local Y is the sole stride-dependent sagittal swing. arm2 local Z is the
# mirrored elbow hinge and remains constant throughout the stride.
const RUN_SHOULDER_FORWARD: float = 0.262 # 15.0 degrees.
const RUN_SHOULDER_ADDUCTION: float = 0.384 # 22.0 degrees.
const RUN_UPPER_ARM_HINGE_PLANE: float = 1.571 # 90.0 degrees.
const RUN_UPPER_ARM_SWING: float = 0.500 # 28.6 degrees.
const RUN_FIXED_ELBOW_FLEX: float = 1.58
# hand local X follows wrist -> fingers. Mirrored quarter turns keep the
# wrists straight while rotating the palms from the current palms-up run pose
# into a compact inward/downward athletic orientation.
const RUN_HAND_ROLL: float = PI * 0.5

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

# Traversal presentation thresholds. These never change player velocity.
const SWING_ATTACH_DURATION: float = 0.18
const SWING_RELEASE_DURATION: float = 0.28
const DOUBLE_JUMP_POSE_DURATION: float = 0.50
const DIVE_MIN_FALL_TIME: float = 0.58
const DIVE_MIN_DOWN_SPEED: float = 18.0
const DIVE_IMMEDIATE_DOWN_SPEED: float = 24.0
const LAND_POSE_MIN_TIME: float = 0.14
const LAND_POSE_MAX_TIME: float = 0.30
const SWING_FLIP_MIN_SPEED: float = 11.0
const SWING_FLIP_APEX_MIN_TIME: float = 0.36
const SWING_FLIP_APEX_MIN_VERTICAL_SPEED: float = -3.0
const SWING_FLIP_APEX_MAX_VERTICAL_SPEED: float = 6.0
const SWING_FLIP_APEX_MAX_ROPE_UPNESS: float = 0.88
const SWING_FLIP_DURATION: float = 0.66
const DIVE_LANDING_ROLL_DURATION: float = 0.70
const DIVE_LANDING_ROLL_LIFT: float = 0.20
const POSE_BLEND_SPEED: float = 11.0
const FAST_POSE_BLEND_SPEED: float = 17.0
const RUN_ARM_BLEND_SPEED: float = 12.0

# Native IK uses reachable hand targets rather than the distant world anchor.
# Keeping some bend in the elbow avoids the near-singular broken-arm result
# produced by the previous 96%-of-full-extension target.
const SWING_ONE_HAND_REACH_RATIO: float = 0.88
const SWING_TWO_HAND_REACH_RATIO: float = 0.82
const ZIP_ARM_REACH_RATIO: float = 0.86
const SWING_ELBOW_POLE_SIDE: float = 0.25
const SWING_ELBOW_POLE_DOWN: float = 0.14
const SECOND_HAND_JOIN_DELAY: float = 0.08
const TWO_HAND_CENTER_LIMIT: float = 0.38

# BRC-style wall-run arm contact. The wall-side hand stays on the facade and
# slides slightly behind/ahead of its shoulder while the outside arm pumps.
# Positions are derived from the detected wall plane and the real BRC arm
# length; they are not world-axis guesses.
const WALL_HAND_SURFACE_CLEARANCE: float = 0.025
const WALL_HAND_BASE_TRAIL: float = 0.18
const WALL_HAND_STRIDE_SLIDE: float = 0.20
const WALL_HAND_LIFT: float = 0.12
const WALL_HAND_REACH_RATIO: float = 0.86
const WALL_ELBOW_OUT_CLEARANCE: float = 0.16
const WALL_ELBOW_TRAIL: float = 0.06
const WALL_HAND_IK_INFLUENCE: float = 1.0

# Wall foot targets are derived from the real capsule radius and rest heights.
const WALL_ANKLE_SURFACE_CLEARANCE: float = 0.12
const WALL_CONTACT_LIFT: float = 0.14
const WALL_STEP_LENGTH: float = 0.50
const WALL_FOOT_PHASE_SEPARATION: float = 0.14
const WALL_RECOVERY_LIFT: float = 0.62
const WALL_RECOVERY_CLEARANCE: float = 0.50
const WALL_KNEE_CLEARANCE: float = 0.31
const WALL_SUPPORT_REACH_RATIO: float = 0.86
const WALL_RECOVERY_REACH_RATIO: float = 0.62

enum TraversalPoseState {
	BASE,
	RUN,
	JUMP,
	DOUBLE_JUMP,
	FALL,
	DIVE,
	SWING_ATTACH,
	SWING_ONE_HAND,
	SWING_TWO_HAND,
	SWING_RELEASE,
	SWING_FLIP,
	ZIP,
	WALL_RUN,
	WALL_JUMP,
	LAND,
	LAND_ROLL,
}

var skeleton: Skeleton3D = null
var player: CharacterBody3D = null
var web_origin_l: Marker3D = null
var web_origin_r: Marker3D = null
var trick_model_pivot: Node3D = null

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
var pending_retarget_delta: float = 0.0
var pending_horizontal_speed: float = 0.0
var final_pose_modifier: SkeletonModifier3D = null

var left_arm_ik: TwoBoneIK3D = null
var right_arm_ik: TwoBoneIK3D = null
var left_hand_target: Marker3D = null
var right_hand_target: Marker3D = null
var left_elbow_pole: Marker3D = null
var right_elbow_pole: Marker3D = null
var left_arm_ik_blend: float = 0.0
var right_arm_ik_blend: float = 0.0
var arm_stride: float = 0.0
var run_arm_blend: float = 0.0
var left_shoulder_bone: int = -1
var right_shoulder_bone: int = -1
var left_arm_root_bone: int = -1
var right_arm_root_bone: int = -1
var left_forearm_bone: int = -1
var right_forearm_bone: int = -1
var left_hand_bone: int = -1
var right_hand_bone: int = -1
var left_stride_foot_bone: int = -1
var right_stride_foot_bone: int = -1
var brc_arm_rest_rotation: Dictionary = {}
var fixed_run_shoulder_rotation: Dictionary = {}
var fixed_run_upper_arm_plane: Dictionary = {}
var fixed_run_forearm_rotation: Dictionary = {}
var fixed_run_hand_rotation: Dictionary = {}
var left_arm_length: float = 0.0
var right_arm_length: float = 0.0
var was_idle_arm_stance: bool = false

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
var player_capsule_radius: float = 0.46
var left_leg_root_bone: int = -1
var right_leg_root_bone: int = -1
var left_leg_length: float = 0.0
var right_leg_length: float = 0.0
var left_foot_player_height: float = -1.0
var right_foot_player_height: float = -1.0
var left_knee_player_height: float = -0.4
var right_knee_player_height: float = -0.4

var active_web_hand: int = -1
var was_grappling: bool = false
var use_two_hand_swing: bool = false
var swing_sequence: int = 0
var swing_elapsed: float = 0.0
var was_zip_active: bool = false
var previous_zip_time: float = 0.0
var last_zip_target_world: Vector3 = Vector3.ZERO
var zip_reach_direction_world: Vector3 = Vector3.ZERO

var traversal_bones: Dictionary = {}
var traversal_rest_rotation: Dictionary = {}
var pose_layer_rotation: Dictionary = {}
var pose_state: TraversalPoseState = TraversalPoseState.BASE
var airborne_fall_time: float = 0.0
var dive_active: bool = false
var release_pose_remaining: float = 0.0
var landing_pose_remaining: float = 0.0
var swing_flip_remaining: float = 0.0
var landing_roll_remaining: float = 0.0
var trick_start_pitch: float = 0.0
var trick_facing_yaw: float = 0.0
var landing_roll_side: float = 1.0
var jump_sequence: int = 0
var jump_variant: int = 0
var jump_elapsed: float = 0.0
var double_jump_elapsed: float = 0.0
var double_jump_side: float = 1.0
var last_double_jump_sequence: int = 0
var previous_on_floor: bool = false
var last_wall_normal: Vector3 = Vector3.ZERO


func setup(
	target_skeleton: Skeleton3D,
	target_player: Node,
	target_web_origin_l: Marker3D,
	target_web_origin_r: Marker3D,
	target_trick_pivot: Node3D
) -> void:
	skeleton = target_skeleton
	player = target_player as CharacterBody3D
	web_origin_l = target_web_origin_l
	web_origin_r = target_web_origin_r
	trick_model_pivot = target_trick_pivot

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
	_cache_traversal_bones()
	_build_brc_arm_ik()
	_build_brc_leg_ik()
	_build_final_pose_modifier()
	_cache_player_collision_radius()
	_force_donor_loops()

	_play_if_available(&"idle", 0.0)
	was_grappling = bool(player.get("grappling"))
	previous_on_floor = player.is_on_floor()

	print(
		"[SPIDEY NATIVE] Traversal animation pipeline enabled. "
		+ "Donor locomotion is retargeted before BRC pose/IK layers."
	)


func _process(delta: float) -> void:
	if not native_retarget_ready or player == null or skeleton == null:
		return

	var horizontal_speed: float = Vector2(
		player.velocity.x,
		player.velocity.z
	).length()

	_update_traversal_context(delta, horizontal_speed)
	_update_animation_state(horizontal_speed)
	_update_trick_pivot_presentation(delta)

	_keep_looping_donor_alive()

	_copy_complete_pose(source_skeleton, source_proxy)
	pending_retarget_delta += delta
	pending_horizontal_speed = horizontal_speed
	source_proxy.advance(delta)
	_update_root_presentation_request()


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

	# Skeleton3D.advance() is deferred in Godot 4.7. Continue the pipeline from
	# the retarget modifier callback so state poses cannot be overwritten later
	# in the same deferred skeleton update.
	var frame_delta: float = pending_retarget_delta
	pending_retarget_delta = 0.0
	if frame_delta <= 0.0 or not native_retarget_ready:
		return

	_update_run_arm_stride(frame_delta)
	_apply_traversal_pose_layer(frame_delta, pending_horizontal_speed)
	_update_arm_ik(frame_delta, pending_horizontal_speed)
	_update_leg_ik(frame_delta, pending_horizontal_speed)
	skeleton.advance(frame_delta)


func _cache_traversal_bones() -> void:
	traversal_bones.clear()
	traversal_rest_rotation.clear()

	for bone_name_value: Variant in TARGET_CANONICAL.keys():
		var bone_name: String = String(bone_name_value)
		var bone_index: int = skeleton.find_bone(bone_name)
		if bone_index < 0:
			push_warning("[SPIDEY NATIVE] Missing BRC bone: " + bone_name)
			continue

		traversal_bones[bone_name] = bone_index
		traversal_rest_rotation[bone_index] = (
			skeleton
			.get_bone_rest(bone_index)
			.basis
			.orthonormalized()
			.get_rotation_quaternion()
		)


func _cache_player_collision_radius() -> void:
	for child_value: Node in player.get_children():
		if child_value is not CollisionShape3D:
			continue
		var collision := child_value as CollisionShape3D
		if collision.shape is CapsuleShape3D:
			player_capsule_radius = (
				collision.shape as CapsuleShape3D
			).radius
			return


func _force_donor_loops() -> void:
	if source_animation_player == null:
		return

	for clip_name: StringName in source_animation_player.get_animation_list():
		var short_name: String = String(clip_name).get_file()

		if (
			short_name == "idle"
			or short_name == "walk"
			or short_name == "run"
			or short_name == "falling"
		):
			var animation: Animation = source_animation_player.get_animation(
				clip_name
			)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR


func _keep_looping_donor_alive() -> void:
	if (
		source_animation_player == null
		or current_animation == &""
		or source_animation_player.is_playing()
	):
		return

	var short_name: String = String(current_animation).get_file()
	if short_name in ["idle", "walk", "run", "falling"]:
		_play_if_available(StringName(short_name), 0.0)


func _update_traversal_context(
	delta: float,
	horizontal_speed: float
) -> void:
	var grappling: bool = bool(player.get("grappling"))
	var wall_riding: bool = bool(player.get("wall_riding"))
	var zip_time: float = float(player.get("zip_pose_time"))
	var zip_active: bool = zip_time > 0.0
	var wall_jump_time: float = float(player.get("wall_jump_pose_time"))
	var double_jump_time: float = float(player.get("double_jump_pose_time"))
	var double_jump_sequence: int = int(player.get("double_jump_sequence"))
	var on_floor: bool = player.is_on_floor()

	release_pose_remaining = maxf(0.0, release_pose_remaining - delta)
	swing_flip_remaining = maxf(0.0, swing_flip_remaining - delta)
	landing_roll_remaining = maxf(0.0, landing_roll_remaining - delta)
	# Preserve a touchdown until a higher-priority ZIP/swing pose releases it.
	if not zip_active and not grappling:
		landing_pose_remaining = maxf(0.0, landing_pose_remaining - delta)

	# Latch hand and grip family once. Nothing rerolls during the swing.
	if grappling and not was_grappling:
		swing_elapsed = 0.0
		active_web_hand = _choose_web_hand()
		swing_sequence += 1
		use_two_hand_swing = (
			swing_sequence % 3 == 0
			and absf(_get_camera_anchor_lateral()) <= TWO_HAND_CENTER_LIMIT
		)
		# A grapple is a hard animation interrupt for any old wall-jump pose.
		player.set("wall_jump_pose_time", 0.0)
		player.set("double_jump_pose_time", 0.0)
		wall_jump_time = 0.0
		double_jump_time = 0.0
		swing_flip_remaining = 0.0
		landing_roll_remaining = 0.0
		dive_active = false
		airborne_fall_time = 0.0
	if grappling:
		swing_elapsed += delta

	var began_ground_jump: bool = (
		previous_on_floor
		and not on_floor
		and player.velocity.y > 0.8
		and not grappling
		and not wall_riding
		and zip_time <= 0.0
	)
	if began_ground_jump:
		jump_variant = jump_sequence % 4
		jump_sequence += 1
		jump_elapsed = 0.0
	if (
		not on_floor
		and player.velocity.y > 0.8
		and not grappling
		and not wall_riding
		and zip_time <= 0.0
	):
		jump_elapsed += delta
	elif on_floor:
		jump_elapsed = 0.0

	if double_jump_sequence != last_double_jump_sequence:
		last_double_jump_sequence = double_jump_sequence
		double_jump_elapsed = 0.0
		double_jump_side = -double_jump_side
		# A deliberate second jump replaces any stale fall/release presentation,
		# but never changes horizontal movement or another traversal force.
		release_pose_remaining = 0.0
		swing_flip_remaining = 0.0
		landing_roll_remaining = 0.0
		dive_active = false
		airborne_fall_time = 0.0
	if double_jump_time > 0.0 and not on_floor:
		double_jump_elapsed += delta
	elif on_floor:
		double_jump_elapsed = 0.0

	var zip_target_value: Variant = player.get("grapple_point")
	var zip_target_world: Vector3 = (
		zip_target_value as Vector3
		if typeof(zip_target_value) == TYPE_VECTOR3
		else last_zip_target_world
	)
	var zip_restarted: bool = (
		zip_active
		and (
			not was_zip_active
			or zip_time > previous_zip_time + delta * 0.50
			or zip_target_world.distance_squared_to(last_zip_target_world) > 0.01
		)
	)
	if zip_restarted:
		zip_reach_direction_world = player.velocity.normalized()
		if zip_reach_direction_world.length_squared() < 0.01:
			if typeof(zip_target_value) == TYPE_VECTOR3:
				zip_reach_direction_world = (
					(zip_target_value as Vector3) - player.global_position
				).normalized()
		last_zip_target_world = zip_target_world

	# Releasing Shift, reaching the rope endpoint, and pressing Space all share
	# one interruptible visual release. Zip deliberately wins over this edge.
	if was_grappling and not grappling and zip_time <= 0.0:
		release_pose_remaining = maxf(
			release_pose_remaining,
			SWING_RELEASE_DURATION
		)
		if _is_apex_swing_flip_release():
			swing_flip_remaining = SWING_FLIP_DURATION
			release_pose_remaining = maxf(
				release_pose_remaining,
				SWING_FLIP_DURATION
			)
			_latch_trick_orientation()

	release_pose_remaining = maxf(
		release_pose_remaining,
		float(player.get("swing_release_pose_time"))
	)

	if wall_riding or wall_jump_time > 0.0:
		player.set("double_jump_pose_time", 0.0)
		double_jump_time = 0.0
		var wall_value: Variant = player.get("wall_ride_normal")
		if typeof(wall_value) == TYPE_VECTOR3:
			last_wall_normal = wall_value as Vector3
	if wall_riding:
		swing_flip_remaining = 0.0
		landing_roll_remaining = 0.0
		dive_active = false
		airborne_fall_time = 0.0

	if on_floor and not previous_on_floor:
		var landed_from_dive: bool = dive_active
		swing_flip_remaining = 0.0
		release_pose_remaining = 0.0
		var landing_strength: float = clampf(
			float(player.get("landing_feedback")),
			0.0,
			1.0
		)
		landing_pose_remaining = lerpf(
			LAND_POSE_MIN_TIME,
			LAND_POSE_MAX_TIME,
			landing_strength
		)
		if landed_from_dive:
			landing_roll_side = -landing_roll_side
			landing_roll_remaining = DIVE_LANDING_ROLL_DURATION
			landing_pose_remaining = maxf(
				landing_pose_remaining,
				DIVE_LANDING_ROLL_DURATION
			)
			_latch_trick_orientation()

	var free_fall: bool = (
		not on_floor
		and not grappling
		and not wall_riding
		and zip_time <= 0.0
		and release_pose_remaining <= 0.0
	)
	if free_fall and player.velocity.y < -1.0:
		airborne_fall_time += delta
		var down_speed: float = -player.velocity.y
		if (
			(
				airborne_fall_time >= DIVE_MIN_FALL_TIME
				and down_speed >= DIVE_MIN_DOWN_SPEED
			)
			or down_speed >= DIVE_IMMEDIATE_DOWN_SPEED
		):
			dive_active = true
	elif on_floor or grappling or wall_riding or zip_time > 0.0:
		airborne_fall_time = 0.0
		dive_active = false
	elif player.velocity.y > 0.0:
		airborne_fall_time = 0.0
		dive_active = false

	if zip_active:
		player.set("double_jump_pose_time", 0.0)
		double_jump_time = 0.0
		swing_flip_remaining = 0.0
		landing_roll_remaining = 0.0
	elif not on_floor and previous_on_floor:
		# Jumping out of a landing recovery immediately returns animation control
		# to the airborne state instead of finishing the cosmetic ground roll.
		landing_roll_remaining = 0.0

	pose_state = _select_traversal_pose_state(
		horizontal_speed,
		grappling,
		wall_riding,
		zip_time,
		on_floor
	)

	was_grappling = grappling
	was_zip_active = zip_active
	previous_zip_time = zip_time
	previous_on_floor = on_floor


func _is_apex_swing_flip_release() -> bool:
	# Timing, not a random per-frame roll, earns the trick. Even an eligible
	# apex produces a flip only on every second swing so ordinary releases keep
	# their clean extension silhouette and the trick remains occasional.
	if swing_sequence % 2 == 0:
		return false
	if swing_elapsed < SWING_FLIP_APEX_MIN_TIME:
		return false
	if player.velocity.length() < SWING_FLIP_MIN_SPEED:
		return false
	if (
		player.velocity.y < SWING_FLIP_APEX_MIN_VERTICAL_SPEED
		or player.velocity.y > SWING_FLIP_APEX_MAX_VERTICAL_SPEED
	):
		return false

	var anchor_value: Variant = player.get("grapple_point")
	if typeof(anchor_value) != TYPE_VECTOR3:
		return false
	var rope_direction: Vector3 = (
		(anchor_value as Vector3) - player.global_position
	)
	if rope_direction.length_squared() < 0.01:
		return false
	var rope_upness: float = rope_direction.normalized().y
	# At the bottom of the arc the anchor is almost straight overhead. Near the
	# top the rope has a stronger sideways component, separating the two moments
	# even though both can briefly have a small vertical velocity.
	return rope_upness <= SWING_FLIP_APEX_MAX_ROPE_UPNESS


func _latch_trick_orientation() -> void:
	var presentation_root: Node3D = get_parent() as Node3D
	if presentation_root != null:
		trick_start_pitch = presentation_root.rotation.x
		trick_facing_yaw = presentation_root.rotation.y
	var horizontal := Vector2(player.velocity.x, player.velocity.z)
	if horizontal.length() > 1.0:
		trick_facing_yaw = atan2(-player.velocity.x, -player.velocity.z)


func _update_trick_pivot_presentation(delta: float) -> void:
	if trick_model_pivot == null:
		return
	if float(player.get("attack_pose_time")) > 0.0:
		trick_model_pivot.rotation.x = 0.0
		trick_model_pivot.rotation.z = 0.0
		trick_model_pivot.position.y = 0.0
		return
	if pose_state not in [
		TraversalPoseState.SWING_FLIP,
		TraversalPoseState.LAND_ROLL,
	]:
		var hard_interrupt: bool = (
			pose_state in [
				TraversalPoseState.JUMP,
				TraversalPoseState.DOUBLE_JUMP,
				TraversalPoseState.SWING_ATTACH,
				TraversalPoseState.SWING_ONE_HAND,
				TraversalPoseState.SWING_TWO_HAND,
				TraversalPoseState.ZIP,
				TraversalPoseState.WALL_RUN,
				TraversalPoseState.WALL_JUMP,
			]
		)
		if hard_interrupt:
			trick_model_pivot.rotation.x = 0.0
			trick_model_pivot.rotation.z = 0.0
			trick_model_pivot.position.y = 0.0
			return
		var recover: float = clampf(18.0 * delta, 0.0, 1.0)
		trick_model_pivot.rotation.x = lerp_angle(
			trick_model_pivot.rotation.x,
			0.0,
			recover
		)
		trick_model_pivot.rotation.z = lerp_angle(
			trick_model_pivot.rotation.z,
			0.0,
			recover
		)
		trick_model_pivot.position.y = lerpf(
			trick_model_pivot.position.y,
			0.0,
			recover
		)
		return

	var duration: float = (
		SWING_FLIP_DURATION
		if pose_state == TraversalPoseState.SWING_FLIP
		else DIVE_LANDING_ROLL_DURATION
	)
	var remaining: float = (
		swing_flip_remaining
		if pose_state == TraversalPoseState.SWING_FLIP
		else landing_roll_remaining
	)
	var progress: float = clampf(1.0 - remaining / duration, 0.0, 1.0)
	var eased: float = smoothstep(0.0, 1.0, progress)
	trick_model_pivot.rotation.x = -TAU * eased
	trick_model_pivot.rotation.z = (
		landing_roll_side * sin(progress * PI) * 0.16
		if pose_state == TraversalPoseState.LAND_ROLL
		else 0.0
	)
	trick_model_pivot.position.y = (
		sin(progress * PI) * DIVE_LANDING_ROLL_LIFT
		if pose_state == TraversalPoseState.LAND_ROLL
		else 0.0
	)


func _select_traversal_pose_state(
	horizontal_speed: float,
	grappling: bool,
	wall_riding: bool,
	zip_time: float,
	on_floor: bool
) -> TraversalPoseState:
	if zip_time > 0.0:
		return TraversalPoseState.ZIP
	if grappling:
		var swing_time: float = float(player.get("swing_pose_time"))
		if swing_time < SWING_ATTACH_DURATION:
			return TraversalPoseState.SWING_ATTACH
		return (
			TraversalPoseState.SWING_TWO_HAND
			if use_two_hand_swing
			else TraversalPoseState.SWING_ONE_HAND
		)
	if wall_riding:
		return TraversalPoseState.WALL_RUN
	if on_floor:
		if landing_roll_remaining > 0.0:
			return TraversalPoseState.LAND_ROLL
		if landing_pose_remaining > 0.0:
			return TraversalPoseState.LAND
		if horizontal_speed > 4.0:
			return TraversalPoseState.RUN
		return TraversalPoseState.BASE
	if release_pose_remaining > 0.0:
		if swing_flip_remaining > 0.0:
			return TraversalPoseState.SWING_FLIP
		return TraversalPoseState.SWING_RELEASE
	if float(player.get("wall_jump_pose_time")) > 0.0:
		return TraversalPoseState.WALL_JUMP
	if float(player.get("double_jump_pose_time")) > 0.0:
		return TraversalPoseState.DOUBLE_JUMP
	if player.velocity.y > 0.8:
		return TraversalPoseState.JUMP
	if dive_active:
		return TraversalPoseState.DIVE
	return TraversalPoseState.FALL


func _update_animation_state(horizontal_speed: float) -> void:
	if source_animation_player == null:
		return

	var wanted: StringName

	match pose_state:
		TraversalPoseState.RUN, TraversalPoseState.WALL_RUN:
			wanted = &"run"
		TraversalPoseState.JUMP, TraversalPoseState.DOUBLE_JUMP, TraversalPoseState.WALL_JUMP:
			wanted = &"jump"
		TraversalPoseState.FALL, TraversalPoseState.DIVE:
			wanted = &"falling"
		TraversalPoseState.SWING_ATTACH, TraversalPoseState.SWING_ONE_HAND, TraversalPoseState.SWING_TWO_HAND, TraversalPoseState.SWING_RELEASE, TraversalPoseState.SWING_FLIP, TraversalPoseState.ZIP:
			wanted = &"falling"
		TraversalPoseState.LAND, TraversalPoseState.LAND_ROLL:
			wanted = &"run" if horizontal_speed > 4.0 else &"idle"
		_:
			if horizontal_speed > 4.0:
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


func _apply_traversal_pose_layer(
	delta: float,
	horizontal_speed: float
) -> void:
	var targets: Dictionary = _build_traversal_pose_targets(horizontal_speed)
	var affected_bones: Array = pose_layer_rotation.keys()

	for bone_value: Variant in targets.keys():
		if bone_value not in affected_bones:
			affected_bones.append(bone_value)

	var blend_speed: float = POSE_BLEND_SPEED
	if pose_state in [
		TraversalPoseState.JUMP,
		TraversalPoseState.DOUBLE_JUMP,
		TraversalPoseState.SWING_ATTACH,
		TraversalPoseState.WALL_RUN,
		TraversalPoseState.WALL_JUMP,
		TraversalPoseState.LAND,
		TraversalPoseState.SWING_FLIP,
		TraversalPoseState.LAND_ROLL,
	]:
		blend_speed = FAST_POSE_BLEND_SPEED
	var amount: float = clampf(blend_speed * delta, 0.0, 1.0)

	for bone_value: Variant in affected_bones:
		var bone_index: int = int(bone_value)
		if bone_index < 0:
			continue
		var donor_rotation: Quaternion = skeleton.get_bone_pose_rotation(
			bone_index
		)
		var goal_rotation: Quaternion = donor_rotation
		if targets.has(bone_index):
			goal_rotation = targets[bone_index]
		var previous_rotation: Quaternion = pose_layer_rotation.get(
			bone_index,
			donor_rotation
		)
		var blended_rotation: Quaternion = previous_rotation.slerp(
			goal_rotation,
			amount
		)
		skeleton.set_bone_pose_rotation(bone_index, blended_rotation)

		if (
			not targets.has(bone_index)
			and absf(blended_rotation.dot(donor_rotation)) > 0.9998
		):
			pose_layer_rotation.erase(bone_index)
		else:
			pose_layer_rotation[bone_index] = blended_rotation


func _build_traversal_pose_targets(
	horizontal_speed: float
) -> Dictionary:
	var targets: Dictionary = {}

	match pose_state:
		TraversalPoseState.RUN:
			# Keep the authored donor stride; add only calibrated forward intent.
			_set_current_pose_offset(targets, "hips", 0.0, -0.06, 0.0)
			_set_current_pose_offset(targets, "s1", 0.0, -0.08, 0.0)
			_set_current_pose_offset(targets, "s2", 0.0, -0.06, 0.0)
			_set_current_pose_offset(targets, "neck", 0.0, 0.04, 0.0)
		TraversalPoseState.JUMP:
			_build_jump_pose(targets)
		TraversalPoseState.DOUBLE_JUMP:
			_build_double_jump_pose(targets)
		TraversalPoseState.FALL:
			_build_fall_pose(targets)
		TraversalPoseState.DIVE:
			_build_dive_pose(targets)
		TraversalPoseState.SWING_ATTACH:
			_build_swing_pose(targets, true)
		TraversalPoseState.SWING_ONE_HAND, TraversalPoseState.SWING_TWO_HAND:
			_build_swing_pose(targets, false)
		TraversalPoseState.SWING_RELEASE:
			_build_swing_release_pose(targets)
		TraversalPoseState.SWING_FLIP:
			_build_swing_flip_pose(targets)
		TraversalPoseState.ZIP:
			_build_zip_pose(targets)
		TraversalPoseState.WALL_RUN:
			_build_wall_run_pose(targets, horizontal_speed)
		TraversalPoseState.WALL_JUMP:
			_build_wall_jump_pose(targets)
		TraversalPoseState.LAND:
			_build_landing_pose(targets)
		TraversalPoseState.LAND_ROLL:
			_build_landing_roll_pose(targets)

	return targets


func _build_jump_pose(targets: Dictionary) -> void:
	var ascent_phase: float = clampf(
		1.0 - maxf(player.velocity.y, 0.0) / 12.0,
		0.0,
		1.0
	)
	var pose_amount: float = clampf(0.45 + jump_elapsed * 3.2, 0.0, 1.0)
	var near_apex: float = smoothstep(0.62, 1.0, ascent_phase)
	var torso_twist: float = 0.0
	match jump_variant:
		0:
			torso_twist = 0.045
		1:
			torso_twist = -0.025
		2:
			torso_twist = -0.060
		3:
			torso_twist = 0.060

	_set_rest_pose_target(
		targets,
		"hips",
		torso_twist * 0.30,
		-0.08 - pose_amount * 0.05,
		0.0
	)
	_set_rest_pose_target(
		targets,
		"s1",
		torso_twist * 0.65,
		-0.10 - pose_amount * 0.07,
		0.0
	)
	_set_rest_pose_target(
		targets,
		"s2",
		torso_twist,
		-0.06 - pose_amount * 0.05,
		0.0
	)
	_set_rest_pose_target(
		targets,
		"neck",
		-torso_twist * 0.35,
		0.06 + near_apex * 0.03,
		0.0
	)

	match jump_variant:
		0:
			# Athletic left-knee drive with the opposite arm leading.
			_set_jump_arm_pose(targets, true, 0.28 * pose_amount, 1.34)
			_set_jump_arm_pose(targets, false, -0.62 * pose_amount, 1.26)
			_set_leg_pose(
				targets, true,
				(-0.76 + near_apex * 0.16) * pose_amount,
				lerpf(0.30, 1.52, pose_amount),
				-0.16 * pose_amount
			)
			_set_leg_pose(
				targets, false,
				(0.38 - near_apex * 0.16) * pose_amount,
				lerpf(0.22, 0.58, pose_amount),
				-0.06 * pose_amount
			)
		1:
			# Compact two-knee hop with both forearms protecting the torso.
			_set_jump_arm_pose(targets, true, -0.34 * pose_amount, 1.42)
			_set_jump_arm_pose(targets, false, -0.28 * pose_amount, 1.38)
			_set_leg_pose(
				targets, true,
				-0.58 * pose_amount,
				lerpf(0.30, 1.52, pose_amount),
				-0.18 * pose_amount
			)
			_set_leg_pose(
				targets, false,
				-0.50 * pose_amount,
				lerpf(0.28, 1.42, pose_amount),
				-0.16 * pose_amount
			)
		2:
			# Long split-stride silhouette: lead leg reaches, rear leg trails.
			_set_jump_arm_pose(targets, true, 0.36 * pose_amount, 1.30)
			_set_jump_arm_pose(targets, false, -0.58 * pose_amount, 1.24)
			_set_leg_pose(
				targets, true,
				-0.56 * pose_amount,
				lerpf(0.22, 0.76, pose_amount),
				-0.12 * pose_amount
			)
			_set_leg_pose(
				targets, false,
				0.60 * pose_amount,
				lerpf(0.18, 0.42 + near_apex * 0.22, pose_amount),
				0.04 * pose_amount
			)
		3:
			# Mirrored high right-knee drive with a looser trailing leg.
			_set_jump_arm_pose(targets, true, -0.64 * pose_amount, 1.26)
			_set_jump_arm_pose(targets, false, 0.30 * pose_amount, 1.36)
			_set_leg_pose(
				targets, true,
				0.14 * pose_amount,
				lerpf(0.22, 0.78, pose_amount),
				-0.06 * pose_amount
			)
			_set_leg_pose(
				targets, false,
				(-0.80 + near_apex * 0.18) * pose_amount,
				lerpf(0.30, 1.58, pose_amount),
				-0.18 * pose_amount
			)


func _build_double_jump_pose(targets: Dictionary) -> void:
	# Original BRC interpretation of the Rivals movement silhouette: a fast
	# upward pop, a compact asymmetric coil, then a controlled opening. The
	# articulation stays inside the real shoulder/elbow and hip/knee/ankle chains.
	var progress: float = clampf(
		double_jump_elapsed / DOUBLE_JUMP_POSE_DURATION,
		0.0,
		1.0
	)
	var lead_left: bool = double_jump_side < 0.0
	var torso_twist: float
	var hips_flex: float
	var lower_spine_flex: float
	var upper_spine_flex: float
	var lead_arm_swing: float
	var free_arm_swing: float
	var lead_elbow: float
	var free_elbow: float
	var lead_thigh: float
	var lead_knee: float
	var lead_ankle: float
	var free_thigh: float
	var free_knee: float
	var free_ankle: float

	if progress < 0.44:
		var coil: float = smoothstep(0.0, 1.0, progress / 0.44)
		torso_twist = lerpf(0.10, 0.38, coil) * double_jump_side
		hips_flex = lerpf(-0.16, -0.30, coil)
		lower_spine_flex = lerpf(-0.18, -0.34, coil)
		upper_spine_flex = lerpf(-0.10, -0.22, coil)
		lead_arm_swing = lerpf(0.22, 0.46, coil)
		free_arm_swing = lerpf(-0.52, -0.78, coil)
		lead_elbow = lerpf(1.40, 1.52, coil)
		free_elbow = lerpf(1.38, 1.46, coil)
		lead_thigh = lerpf(-0.72, -1.05, coil)
		lead_knee = lerpf(1.36, 1.82, coil)
		lead_ankle = lerpf(-0.16, -0.28, coil)
		free_thigh = lerpf(-0.32, -0.48, coil)
		free_knee = lerpf(1.10, 1.68, coil)
		free_ankle = lerpf(-0.10, -0.24, coil)
	else:
		var opening: float = smoothstep(
			0.0,
			1.0,
			(progress - 0.44) / 0.56
		)
		torso_twist = lerpf(0.38, 0.08, opening) * double_jump_side
		hips_flex = lerpf(-0.30, -0.06, opening)
		lower_spine_flex = lerpf(-0.34, -0.10, opening)
		upper_spine_flex = lerpf(-0.22, -0.04, opening)
		lead_arm_swing = lerpf(0.46, 0.10, opening)
		free_arm_swing = lerpf(-0.78, -0.24, opening)
		lead_elbow = lerpf(1.52, 1.24, opening)
		free_elbow = lerpf(1.46, 1.20, opening)
		lead_thigh = lerpf(-1.05, -0.34, opening)
		lead_knee = lerpf(1.82, 0.82, opening)
		lead_ankle = lerpf(-0.28, -0.14, opening)
		free_thigh = lerpf(-0.48, 0.22, opening)
		free_knee = lerpf(1.68, 0.62, opening)
		free_ankle = lerpf(-0.24, -0.08, opening)

	_set_rest_pose_target(
		targets, "hips", torso_twist * 0.42, hips_flex, 0.0
	)
	_set_rest_pose_target(
		targets, "s1", torso_twist * 0.74, lower_spine_flex, 0.0
	)
	_set_rest_pose_target(
		targets, "s2", torso_twist, upper_spine_flex, 0.0
	)
	_set_rest_pose_target(
		targets,
		"neck",
		-torso_twist * 0.38,
		0.08,
		0.0
	)
	_set_rest_pose_target(
		targets,
		"head",
		-torso_twist * 0.16,
		0.03,
		0.0
	)

	# The arm opposite the high knee drives forward. Both hands reuse the
	# approved running-wrist orientation instead of turning palm-up.
	_set_jump_arm_pose(
		targets, lead_left, lead_arm_swing, lead_elbow
	)
	_set_jump_arm_pose(
		targets, not lead_left, free_arm_swing, free_elbow
	)
	_set_leg_pose(
		targets, lead_left, lead_thigh, lead_knee, lead_ankle
	)
	_set_leg_pose(
		targets, not lead_left, free_thigh, free_knee, free_ankle
	)


func _set_jump_arm_pose(
	targets: Dictionary,
	left_side: bool,
	upper_arm_swing: float,
	elbow_flex: float
) -> void:
	_set_compact_arm_pose(
		targets,
		left_side,
		upper_arm_swing,
		elbow_flex
	)
	var hand_bone: int = left_hand_bone if left_side else right_hand_bone
	if hand_bone >= 0 and fixed_run_hand_rotation.has(hand_bone):
		# Reuse the visually approved running wrist orientation. The arm still
		# articulates at shoulder/elbow, but the hand no longer turns palm-up into
		# the old "holding an invisible object" silhouette.
		targets[hand_bone] = fixed_run_hand_rotation[hand_bone]


func _build_fall_pose(targets: Dictionary) -> void:
	_set_rest_pose_target(targets, "hips", 0.0, -0.04, 0.0)
	_set_rest_pose_target(targets, "s1", 0.0, -0.06, 0.0)
	_set_rest_pose_target(targets, "s2", 0.0, 0.02, 0.0)
	_set_rest_pose_target(targets, "neck", 0.0, 0.05, 0.0)
	_set_compact_arm_pose(targets, true, -0.08, 1.18)
	_set_compact_arm_pose(targets, false, 0.10, 1.18)
	_set_leg_pose(targets, true, -0.16, 0.48, -0.12)
	_set_leg_pose(targets, false, 0.10, 0.38, -0.12)


func _build_dive_pose(targets: Dictionary) -> void:
	# The visual root supplies the strong head-first angle. Keep the articulated
	# torso comparatively long so that increasing that angle does not fold the
	# upper body past the hips and create a broken-back silhouette.
	_set_rest_pose_target(targets, "hips", 0.0, -0.08, 0.0)
	_set_rest_pose_target(targets, "s1", 0.0, -0.10, 0.0)
	_set_rest_pose_target(targets, "s2", 0.0, -0.06, 0.0)
	_set_rest_pose_target(targets, "neck", 0.0, 0.10, 0.0)
	_set_rest_pose_target(targets, "head", 0.0, 0.05, 0.0)
	_set_compact_arm_pose(targets, true, 0.56, 0.55)
	_set_compact_arm_pose(targets, false, 0.56, 0.55)
	_set_leg_pose(targets, true, 0.16, 0.18, -0.14)
	_set_leg_pose(targets, false, 0.12, 0.20, -0.14)


func _build_swing_pose(targets: Dictionary, attaching: bool) -> void:
	var rope_local: Vector3 = _get_local_rope_direction()
	var speed_factor: float = clampf(player.velocity.length() / 38.0, 0.0, 1.0)
	var descending: float = clampf(-player.velocity.y / 18.0, 0.0, 1.0)
	var ascending: float = clampf(player.velocity.y / 18.0, 0.0, 1.0)
	var bottom_arc: float = clampf(
		(1.0 - absf(player.velocity.y) / 11.0)
		* clampf((player.velocity.length() - 13.0) / 21.0, 0.0, 1.0)
		* clampf((rope_local.y + 0.15) / 0.85, 0.0, 1.0),
		0.0,
		1.0
	)
	var tuck: float = maxf(bottom_arc, ascending * 0.82)
	var trail: float = descending * (1.0 - tuck)
	# visual_root already rolls toward the rope in player.gd. Keep only a small
	# articulated counter-twist here; the previous hips+s1+s2 accumulation made
	# the torso look corkscrewed at side anchors.
	var rope_twist: float = clampf(rope_local.x * 0.10, -0.10, 0.10)

	_set_rest_pose_target(targets, "hips", 0.0, -0.10, 0.0)
	_set_rest_pose_target(
		targets,
		"s1",
		rope_twist * 0.35,
		-0.12 - speed_factor * 0.06 + bottom_arc * 0.08,
		0.0
	)
	_set_rest_pose_target(
		targets,
		"s2",
		rope_twist * 0.65,
		-0.08 + bottom_arc * 0.08,
		0.0
	)
	_set_rest_pose_target(targets, "neck", -rope_twist * 0.25, 0.08, 0.0)

	if attaching:
		_set_compact_arm_pose(
			targets,
			active_web_hand < 0,
			-0.42,
			0.88
		)
		_set_compact_arm_pose(
			targets,
			active_web_hand > 0,
			-0.42,
			0.88
		)
	else:
		var selected_left: bool = active_web_hand < 0
		_set_compact_arm_pose(targets, selected_left, -0.38, 0.92)
		if use_two_hand_swing:
			_set_compact_arm_pose(targets, not selected_left, -0.34, 0.98)
		else:
			var free_swing: float = lerpf(0.34, -0.18, ascending)
			_set_compact_arm_pose(targets, not selected_left, free_swing, 1.42)

	var left_bias: float = -0.08 if active_web_hand < 0 else 0.08
	var left_thigh: float = lerpf(0.42 + left_bias, -0.46, tuck)
	var right_thigh: float = lerpf(0.34 - left_bias, -0.34, tuck)
	left_thigh += trail * 0.12
	right_thigh += trail * 0.18
	_set_leg_pose(
		targets,
		true,
		left_thigh,
		lerpf(0.24, 1.34, tuck),
		lerpf(-0.06, -0.18, tuck)
	)
	_set_leg_pose(
		targets,
		false,
		right_thigh,
		lerpf(0.22, 1.18, tuck),
		lerpf(-0.06, -0.16, tuck)
	)


func _build_swing_release_pose(targets: Dictionary) -> void:
	_set_rest_pose_target(targets, "hips", 0.0, -0.14, 0.0)
	_set_rest_pose_target(targets, "s1", 0.0, -0.20, 0.0)
	_set_rest_pose_target(targets, "s2", 0.0, -0.12, 0.0)
	_set_rest_pose_target(targets, "neck", 0.0, 0.10, 0.0)
	var selected_left: bool = active_web_hand < 0
	_set_compact_arm_pose(targets, selected_left, -0.58, 0.34)
	_set_compact_arm_pose(targets, not selected_left, -0.30, 0.62)
	_set_leg_pose(targets, true, 0.34, 0.18, -0.10)
	_set_leg_pose(targets, false, 0.26, 0.22, -0.10)


func _build_swing_flip_pose(targets: Dictionary) -> void:
	var progress: float = clampf(
		1.0 - swing_flip_remaining / SWING_FLIP_DURATION,
		0.0,
		1.0
	)
	# Authored phases: preserve release extension briefly, pull every joint into
	# a readable compact tuck, hold it through the inversion, then open before
	# the next traversal state. The skeleton therefore changes silhouette while
	# the model pivot supplies the somersault's global revolution.
	var tuck_in: float = smoothstep(0.10, 0.38, progress)
	var opening: float = smoothstep(0.68, 0.97, progress)
	var tuck: float = tuck_in * (1.0 - opening)
	var extension: float = 1.0 - tuck_in
	_set_rest_pose_target(
		targets,
		"hips",
		0.0,
		-0.12 - tuck * 0.22 + opening * 0.06,
		0.0
	)
	_set_rest_pose_target(
		targets,
		"s1",
		0.0,
		-0.16 - tuck * 0.34 + opening * 0.08,
		0.0
	)
	_set_rest_pose_target(
		targets,
		"s2",
		0.0,
		-0.10 - tuck * 0.22 + opening * 0.06,
		0.0
	)
	_set_rest_pose_target(
		targets,
		"neck",
		0.0,
		0.08 * extension - 0.16 * tuck + 0.06 * opening,
		0.0
	)
	_set_compact_arm_pose(
		targets,
		true,
		-0.52 * extension + 0.08 * tuck - 0.18 * opening,
		0.44 * extension + 1.64 * tuck + 0.98 * opening
	)
	_set_compact_arm_pose(
		targets,
		false,
		-0.46 * extension + 0.12 * tuck - 0.14 * opening,
		0.48 * extension + 1.58 * tuck + 0.94 * opening
	)
	_set_leg_pose(
		targets,
		true,
		0.26 * extension - 0.88 * tuck - 0.16 * opening,
		0.24 * extension + 1.90 * tuck + 0.58 * opening,
		-0.08 - tuck * 0.18 + opening * 0.04
	)
	_set_leg_pose(
		targets,
		false,
		0.18 * extension - 0.82 * tuck + 0.10 * opening,
		0.28 * extension + 1.82 * tuck + 0.48 * opening,
		-0.08 - tuck * 0.16 + opening * 0.04
	)


func _build_zip_pose(targets: Dictionary) -> void:
	_set_rest_pose_target(targets, "hips", 0.0, -0.22, 0.0)
	_set_rest_pose_target(targets, "s1", 0.0, -0.28, 0.0)
	_set_rest_pose_target(targets, "s2", 0.0, -0.16, 0.0)
	_set_rest_pose_target(targets, "neck", 0.0, 0.12, 0.0)
	_set_compact_arm_pose(targets, true, -0.44, 0.86)
	_set_compact_arm_pose(targets, false, -0.44, 0.86)
	_set_leg_pose(targets, true, 0.48, 0.24, -0.12)
	_set_leg_pose(targets, false, 0.38, 0.28, -0.12)


func _build_wall_run_pose(
	targets: Dictionary,
	horizontal_speed: float
) -> void:
	var wall_on_left: bool = _is_wall_on_left(last_wall_normal)
	var wall_side_sign: float = 1.0 if wall_on_left else -1.0
	var stride: float = _get_wall_run_stride(horizontal_speed)

	# Keep the pelvis travelling along the wall, but build the silhouette from
	# the contact points outward: the wall-side hand and planted shoe stay near
	# the facade while the chest/head arc modestly away from it. This matches the
	# readable supported sprint silhouette instead of making the whole body look
	# pasted flat against the wall.
	_set_rest_pose_target(
		targets,
		"hips",
		wall_side_sign * 0.020 - stride * 0.025,
		-0.18,
		wall_side_sign * 0.025
	)
	_set_rest_pose_target(
		targets,
		"s1",
		wall_side_sign * 0.045 + stride * 0.030,
		-0.20,
		wall_side_sign * 0.060
	)
	_set_rest_pose_target(
		targets,
		"s2",
		wall_side_sign * 0.080 + stride * 0.040,
		-0.12,
		wall_side_sign * 0.085
	)
	_set_rest_pose_target(
		targets,
		"neck",
		-wall_side_sign * 0.040 - stride * 0.020,
		0.09,
		-wall_side_sign * 0.070
	)
	_set_rest_pose_target(
		targets,
		"head",
		-wall_side_sign * 0.020,
		0.03,
		-wall_side_sign * 0.035
	)

	var left_swing: float = stride * 0.86
	var right_swing: float = -stride * 0.86
	if wall_on_left:
		# The IK layer places this hand on the wall. This authored seed keeps
		# the elbow softly bent before the modifier solves the exact contact.
		left_swing *= 0.10
		_set_compact_arm_pose(targets, true, left_swing - 0.22, 0.98)
		_set_compact_arm_pose(targets, false, right_swing + 0.08, 1.30)
	else:
		right_swing *= 0.10
		_set_compact_arm_pose(targets, true, left_swing + 0.08, 1.30)
		_set_compact_arm_pose(targets, false, right_swing - 0.22, 0.98)

	var left_phase: float = stride if wall_on_left else -stride
	var right_phase: float = -left_phase
	_set_wall_run_leg_pose(targets, true, left_phase)
	_set_wall_run_leg_pose(targets, false, right_phase)


func _get_wall_run_stride(horizontal_speed: float) -> float:
	var wall_time: float = float(player.get("wall_ride_time"))
	return sin(
		wall_time * clampf(horizontal_speed * 0.76, 7.0, 13.0)
	)


func _set_wall_run_leg_pose(
	targets: Dictionary,
	left_side: bool,
	phase: float
) -> void:
	# Negative phase is wall contact/push. Around the crossover the planted leg
	# compresses under the body; positive phase then folds the shin sharply and
	# carries the knee forward. Each joint remains independently readable.
	var recovery: float = smoothstep(-0.18, 0.78, phase)
	var support: float = smoothstep(0.05, 1.0, -phase)
	var compression: float = (
		maxf(0.0, 1.0 - absf(phase) * 1.45) * (1.0 - recovery)
	)
	var thigh_swing: float = lerpf(
		0.18 + support * 0.10,
		-0.58,
		recovery
	) - compression * 0.08
	var knee_flex: float = (
		lerpf(0.46 + support * 0.06, 1.70, recovery)
		+ compression * 0.24
	)
	var ankle_flex: float = lerpf(0.04, -0.22, recovery) - compression * 0.05
	_set_leg_pose(
		targets,
		left_side,
		thigh_swing,
		knee_flex,
		ankle_flex
	)


func _build_wall_jump_pose(targets: Dictionary) -> void:
	var wall_on_left: bool = _is_wall_on_left(last_wall_normal)
	var away_twist: float = -0.14 if wall_on_left else 0.14
	_set_rest_pose_target(targets, "hips", away_twist * 0.35, -0.14, 0.0)
	_set_rest_pose_target(targets, "s1", away_twist * 0.65, -0.18, 0.0)
	_set_rest_pose_target(targets, "s2", away_twist, -0.10, 0.0)
	_set_rest_pose_target(targets, "neck", -away_twist * 0.40, 0.08, 0.0)
	if wall_on_left:
		# Left leg finishes the facade push while the outside leg recovers.
		_set_compact_arm_pose(targets, true, -0.18, 1.24)
		_set_compact_arm_pose(targets, false, -0.48, 0.82)
		_set_leg_pose(targets, true, 0.16, 0.42, -0.08)
		_set_leg_pose(targets, false, -0.38, 1.40, -0.16)
	else:
		_set_compact_arm_pose(targets, true, -0.48, 0.82)
		_set_compact_arm_pose(targets, false, -0.18, 1.24)
		_set_leg_pose(targets, true, -0.38, 1.40, -0.16)
		_set_leg_pose(targets, false, 0.16, 0.42, -0.08)


func _build_landing_pose(targets: Dictionary) -> void:
	_set_rest_pose_target(targets, "hips", 0.0, -0.12, 0.0)
	_set_rest_pose_target(targets, "s1", 0.0, -0.18, 0.0)
	_set_rest_pose_target(targets, "s2", 0.0, -0.10, 0.0)
	_set_rest_pose_target(targets, "neck", 0.0, 0.10, 0.0)
	_set_compact_arm_pose(targets, true, 0.12, 1.34)
	_set_compact_arm_pose(targets, false, 0.12, 1.34)
	_set_leg_pose(targets, true, -0.34, 1.02, -0.12)
	_set_leg_pose(targets, false, -0.34, 1.02, -0.12)


func _build_landing_roll_pose(targets: Dictionary) -> void:
	var progress: float = clampf(
		1.0 - landing_roll_remaining / DIVE_LANDING_ROLL_DURATION,
		0.0,
		1.0
	)
	# Brace with the arms, roll diagonally over one shoulder in a compact ball,
	# then unfold into an asymmetric running step. This is deliberately not the
	# same airborne tuck pasted onto the ground.
	var tuck_in: float = smoothstep(0.0, 0.20, progress)
	var recovery: float = smoothstep(0.72, 0.97, progress)
	var tuck: float = tuck_in * (1.0 - recovery)
	var shoulder_turn: float = landing_roll_side * tuck * 0.13
	_set_rest_pose_target(
		targets,
		"hips",
		shoulder_turn * 0.35,
		-0.18 - tuck * 0.38 + recovery * 0.08,
		landing_roll_side * tuck * 0.04
	)
	_set_rest_pose_target(
		targets,
		"s1",
		shoulder_turn * 0.70,
		-0.22 - tuck * 0.50 + recovery * 0.10,
		landing_roll_side * tuck * 0.07
	)
	_set_rest_pose_target(
		targets,
		"s2",
		shoulder_turn,
		-0.14 - tuck * 0.38 + recovery * 0.08,
		landing_roll_side * tuck * 0.08
	)
	_set_rest_pose_target(
		targets,
		"neck",
		-shoulder_turn * 0.35,
		-0.32 * tuck + 0.08 * recovery,
		-landing_roll_side * tuck * 0.06
	)
	var left_contact: float = 1.0 if landing_roll_side > 0.0 else 0.0
	_set_compact_arm_pose(
		targets,
		true,
		lerpf(-0.42, -0.48, tuck) - recovery * 0.18,
		lerpf(1.18, lerpf(1.82, 1.70, left_contact), tuck)
	)
	_set_compact_arm_pose(
		targets,
		false,
		lerpf(-0.38, -0.44, tuck) + recovery * 0.12,
		lerpf(1.14, lerpf(1.70, 1.82, left_contact), tuck)
	)
	var left_recovery_thigh: float = -0.30 if landing_roll_side > 0.0 else 0.14
	var right_recovery_thigh: float = 0.14 if landing_roll_side > 0.0 else -0.30
	_set_leg_pose(
		targets,
		true,
		lerpf(-0.38 - tuck * 0.92, left_recovery_thigh, recovery),
		lerpf(1.04 + tuck * 1.08, 0.72, recovery),
		-0.14 - tuck * 0.22
	)
	_set_leg_pose(
		targets,
		false,
		lerpf(-0.34 - tuck * 0.88, right_recovery_thigh, recovery),
		lerpf(1.00 + tuck * 1.08, 0.62, recovery),
		-0.14 - tuck * 0.20
	)


func _set_compact_arm_pose(
	targets: Dictionary,
	left_side: bool,
	upper_arm_swing: float,
	elbow_flex: float
) -> void:
	var side_sign: float = 1.0 if left_side else -1.0
	var shoulder_bone: int = (
		left_shoulder_bone if left_side else right_shoulder_bone
	)
	var arm_bone: int = (
		left_arm_root_bone if left_side else right_arm_root_bone
	)
	var forearm_bone: int = (
		left_forearm_bone if left_side else right_forearm_bone
	)
	var hand_bone: int = left_hand_bone if left_side else right_hand_bone
	if (
		shoulder_bone < 0
		or arm_bone < 0
		or forearm_bone < 0
		or hand_bone < 0
	):
		return

	targets[shoulder_bone] = fixed_run_shoulder_rotation[shoulder_bone]
	var arm_rest: Quaternion = brc_arm_rest_rotation[arm_bone]
	var arm_plane: Quaternion = fixed_run_upper_arm_plane[arm_bone]
	targets[arm_bone] = (
		arm_rest
		* Quaternion(Vector3.UP, upper_arm_swing)
		* arm_plane
	).normalized()
	targets[forearm_bone] = (
		brc_arm_rest_rotation[forearm_bone]
		* Quaternion(Vector3.BACK, -elbow_flex * side_sign)
	).normalized()
	targets[hand_bone] = brc_arm_rest_rotation[hand_bone]


func _set_leg_pose(
	targets: Dictionary,
	left_side: bool,
	thigh_swing: float,
	knee_flex: float,
	ankle_flex: float
) -> void:
	var suffix: String = "l" if left_side else "r"
	_set_rest_pose_target(targets, "leg1" + suffix, 0.0, thigh_swing, 0.0)
	_set_rest_pose_target(targets, "leg2" + suffix, 0.0, knee_flex, 0.0)
	_set_rest_pose_target(targets, "foot" + suffix, 0.0, ankle_flex, 0.0)
	_set_rest_pose_target(targets, "toes" + suffix, 0.0, 0.0, 0.0)


func _set_rest_pose_target(
	targets: Dictionary,
	bone_name: String,
	x_angle: float,
	y_angle: float,
	z_angle: float
) -> void:
	if not traversal_bones.has(bone_name):
		return
	var bone_index: int = int(traversal_bones[bone_name])
	var rest_rotation: Quaternion = traversal_rest_rotation[bone_index]
	targets[bone_index] = (
		rest_rotation * _local_rotation_offset(x_angle, y_angle, z_angle)
	).normalized()


func _set_current_pose_offset(
	targets: Dictionary,
	bone_name: String,
	x_angle: float,
	y_angle: float,
	z_angle: float
) -> void:
	if not traversal_bones.has(bone_name):
		return
	var bone_index: int = int(traversal_bones[bone_name])
	var current: Quaternion = skeleton.get_bone_pose_rotation(bone_index)
	targets[bone_index] = (
		current * _local_rotation_offset(x_angle, y_angle, z_angle)
	).normalized()


func _local_rotation_offset(
	x_angle: float,
	y_angle: float,
	z_angle: float
) -> Quaternion:
	return (
		Quaternion(Vector3.RIGHT, x_angle)
		* Quaternion(Vector3.UP, y_angle)
		* Quaternion(Vector3.BACK, z_angle)
	).normalized()


func _get_local_rope_direction() -> Vector3:
	var grapple_value: Variant = player.get("grapple_point")
	if typeof(grapple_value) != TYPE_VECTOR3:
		return Vector3.UP
	var anchor_local: Vector3 = skeleton.to_local(grapple_value as Vector3)
	var body_origin: Vector3 = Vector3.ZERO
	if traversal_bones.has("s2"):
		body_origin = skeleton.get_bone_global_pose(
			int(traversal_bones["s2"])
		).origin
	var direction: Vector3 = anchor_local - body_origin
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP


func _is_wall_on_left(wall_normal: Vector3) -> bool:
	if wall_normal.length_squared() < 0.01:
		return active_web_hand < 0
	var character_left: Vector3 = (
		skeleton.global_transform.basis.x.normalized()
	)
	# The wall surface lies opposite its outward collision normal.
	return wall_normal.normalized().dot(character_left) < 0.0


func _build_brc_arm_ik() -> void:
	var shld_l: int = skeleton.find_bone("shldl")
	var arm1_l: int = skeleton.find_bone("arm1l")
	var arm2_l: int = skeleton.find_bone("arm2l")
	var hand_l: int = skeleton.find_bone("handl")
	var shld_r: int = skeleton.find_bone("shldr")
	var arm1_r: int = skeleton.find_bone("arm1r")
	var arm2_r: int = skeleton.find_bone("arm2r")
	var hand_r: int = skeleton.find_bone("handr")

	if (
		shld_l < 0
		or arm1_l < 0
		or arm2_l < 0
		or hand_l < 0
		or shld_r < 0
		or arm1_r < 0
		or arm2_r < 0
		or hand_r < 0
	):
		push_error("[SPIDEY NATIVE] BRC arm chain incomplete.")
		return

	left_shoulder_bone = shld_l
	right_shoulder_bone = shld_r
	left_arm_root_bone = arm1_l
	right_arm_root_bone = arm1_r
	left_forearm_bone = arm2_l
	right_forearm_bone = arm2_r
	left_hand_bone = hand_l
	right_hand_bone = hand_r
	for bone_index in [
		shld_l, arm1_l, arm2_l, hand_l,
		shld_r, arm1_r, arm2_r, hand_r
	]:
		brc_arm_rest_rotation[bone_index] = (
			skeleton
			.get_bone_rest(bone_index)
			.basis
			.orthonormalized()
			.get_rotation_quaternion()
		)
	var shoulder_rest_l: Quaternion = brc_arm_rest_rotation[
		left_shoulder_bone
	]
	var shoulder_rest_r: Quaternion = brc_arm_rest_rotation[
		right_shoulder_bone
	]
	var forearm_rest_l: Quaternion = brc_arm_rest_rotation[
		left_forearm_bone
	]
	var forearm_rest_r: Quaternion = brc_arm_rest_rotation[
		right_forearm_bone
	]
	var hand_rest_l: Quaternion = brc_arm_rest_rotation[left_hand_bone]
	var hand_rest_r: Quaternion = brc_arm_rest_rotation[right_hand_bone]

	# Mirrored fixed shoulder pose: local X carries the arm slightly forward;
	# local Z adducts it. This moves the neutral elbows from roughly +/-0.28
	# to +/-0.19 in model space without changing during the stride.
	fixed_run_shoulder_rotation[left_shoulder_bone] = (
		shoulder_rest_l
		* Quaternion(Vector3.RIGHT, RUN_SHOULDER_FORWARD)
		* Quaternion(Vector3.BACK, -RUN_SHOULDER_ADDUCTION)
	).normalized()
	fixed_run_shoulder_rotation[right_shoulder_bone] = (
		shoulder_rest_r
		* Quaternion(Vector3.RIGHT, -RUN_SHOULDER_FORWARD)
		* Quaternion(Vector3.BACK, RUN_SHOULDER_ADDUCTION)
	).normalized()

	# arm1's local X follows the bone length. This constant mirrored roll puts
	# the fixed elbow hinge in the forward/back plane; it never follows stride.
	fixed_run_upper_arm_plane[left_arm_root_bone] = Quaternion(
		Vector3.RIGHT,
		-RUN_UPPER_ARM_HINGE_PLANE
	)
	fixed_run_upper_arm_plane[right_arm_root_bone] = Quaternion(
		Vector3.RIGHT,
		RUN_UPPER_ARM_HINGE_PLANE
	)
	fixed_run_forearm_rotation[left_forearm_bone] = (
		forearm_rest_l
		* Quaternion(Vector3.BACK, -RUN_FIXED_ELBOW_FLEX)
	).normalized()
	fixed_run_forearm_rotation[right_forearm_bone] = (
		forearm_rest_r
		* Quaternion(Vector3.BACK, RUN_FIXED_ELBOW_FLEX)
	).normalized()
	fixed_run_hand_rotation[left_hand_bone] = (
		hand_rest_l * Quaternion(Vector3.RIGHT, RUN_HAND_ROLL)
	).normalized()
	fixed_run_hand_rotation[right_hand_bone] = (
		hand_rest_r * Quaternion(Vector3.RIGHT, -RUN_HAND_ROLL)
	).normalized()
	left_arm_length = (
		skeleton.get_bone_rest(arm2_l).origin.length()
		+ skeleton.get_bone_rest(hand_l).origin.length()
	)
	right_arm_length = (
		skeleton.get_bone_rest(arm2_r).origin.length()
		+ skeleton.get_bone_rest(hand_r).origin.length()
	)

	skeleton.modifier_callback_mode_process = (
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	)

	left_hand_target = Marker3D.new()
	left_hand_target.name = "LeftTraversalHandTarget"
	skeleton.add_child(left_hand_target)

	right_hand_target = Marker3D.new()
	right_hand_target.name = "RightTraversalHandTarget"
	skeleton.add_child(right_hand_target)

	left_elbow_pole = Marker3D.new()
	left_elbow_pole.name = "LeftTraversalElbowPole"
	skeleton.add_child(left_elbow_pole)

	right_elbow_pole = Marker3D.new()
	right_elbow_pole.name = "RightTraversalElbowPole"
	skeleton.add_child(right_elbow_pole)

	left_arm_ik = TwoBoneIK3D.new()
	left_arm_ik.name = "LeftTraversalArmIK"
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
	right_arm_ik.name = "RightTraversalArmIK"
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

	_restore_idle_arm_targets()


func _build_final_pose_modifier() -> void:
	final_pose_modifier = FINAL_POSE_MODIFIER_SCRIPT.new()
	final_pose_modifier.name = "FinalTraversalPoseModifier"
	skeleton.add_child(final_pose_modifier)
	final_pose_modifier.call("setup", self)


func _update_run_arm_stride(delta: float) -> void:
	var target_stride: float = 0.0
	if (
		_is_ground_run_active()
		and left_stride_foot_bone >= 0
		and right_stride_foot_bone >= 0
	):
		var left_foot: Vector3 = (
			skeleton.get_bone_global_pose(left_stride_foot_bone).origin
		)
		var right_foot: Vector3 = (
			skeleton.get_bone_global_pose(right_stride_foot_bone).origin
		)
		target_stride = clampf(
			(left_foot.z - right_foot.z) / 0.34,
			-1.0,
			1.0
		)

	arm_stride = lerpf(
		arm_stride,
		target_stride,
		clampf(ARM_TARGET_SMOOTH * delta, 0.0, 1.0)
	)
	run_arm_blend = move_toward(
		run_arm_blend,
		1.0 if _is_ground_run_active() else 0.0,
		RUN_ARM_BLEND_SPEED * delta
	)


func _update_arm_ik(delta: float, horizontal_speed: float) -> void:
	if left_arm_ik == null or right_arm_ik == null:
		return

	var idle_stance: bool = (
		pose_state == TraversalPoseState.BASE
		and horizontal_speed <= 0.35
	)
	var wall_stance: bool = pose_state == TraversalPoseState.WALL_RUN
	var left_target_blend: float = 1.0 if idle_stance else 0.0
	var right_target_blend: float = 1.0 if idle_stance else 0.0
	if not wall_stance:
		# Preserve the pre-existing idle/swing/zip solver behavior outside the
		# dedicated wall-contact state.
		left_arm_ik.set_pole_direction(
			0, SkeletonModifier3D.SECONDARY_DIRECTION_NONE
		)
		right_arm_ik.set_pole_direction(
			0, SkeletonModifier3D.SECONDARY_DIRECTION_NONE
		)
	if idle_stance and not was_idle_arm_stance:
		# Swing and zip move these same IK markers. Reset them before blending idle
		# IK back in so the arms cannot keep reaching for the previous web anchor.
		left_arm_ik_blend = 0.0
		right_arm_ik_blend = 0.0
		_restore_idle_arm_targets()

	if wall_stance:
		# The calibrated BRC elbow hinge is mirrored. Supplying its secondary
		# direction only for wall contact prevents the arm chain from corkscrewing
		# while the pole keeps the elbow outside the facade.
		left_arm_ik.set_pole_direction(
			0, SkeletonModifier3D.SECONDARY_DIRECTION_MINUS_Y
		)
		right_arm_ik.set_pole_direction(
			0, SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_Y
		)
		var wall_on_left: bool = _configure_wall_run_hand_target(delta)
		left_target_blend = WALL_HAND_IK_INFLUENCE if wall_on_left else 0.0
		right_target_blend = WALL_HAND_IK_INFLUENCE if not wall_on_left else 0.0
	elif _is_swing_pose_state() or pose_state == TraversalPoseState.ZIP:
		var anchor_value: Variant = player.get("grapple_point")
		if typeof(anchor_value) == TYPE_VECTOR3:
			var anchor_world: Vector3 = anchor_value as Vector3
			if (
				pose_state == TraversalPoseState.ZIP
				and zip_reach_direction_world.length_squared() > 0.01
			):
				# Keep both bent arms facing the latched travel direction even if
				# the body passes the original zip point before its pose timer ends.
				anchor_world = (
					skeleton.global_position
					+ zip_reach_direction_world * 10.0
				)
			var anchor_local: Vector3 = skeleton.to_local(anchor_world)
			if pose_state == TraversalPoseState.ZIP:
				left_target_blend = 1.0
				right_target_blend = 1.0
				_configure_reachable_arm_target(
					true, anchor_local, ZIP_ARM_REACH_RATIO, delta
				)
				_configure_reachable_arm_target(
					false, anchor_local, ZIP_ARM_REACH_RATIO, delta
				)
			else:
				var second_hand_active: bool = (
					use_two_hand_swing
					and float(player.get("swing_pose_time"))
						>= SECOND_HAND_JOIN_DELAY
				)
				var swing_reach_ratio: float = (
					SWING_TWO_HAND_REACH_RATIO
					if second_hand_active
					else SWING_ONE_HAND_REACH_RATIO
				)
				left_target_blend = (
					1.0
					if active_web_hand < 0 or second_hand_active
					else 0.0
				)
				right_target_blend = (
					1.0
					if active_web_hand > 0 or second_hand_active
					else 0.0
				)
				if left_target_blend > 0.0:
					_configure_reachable_arm_target(
						true, anchor_local, swing_reach_ratio, delta
					)
				if right_target_blend > 0.0:
					_configure_reachable_arm_target(
						false, anchor_local, swing_reach_ratio, delta
					)

	left_arm_ik_blend = move_toward(
		left_arm_ik_blend,
		left_target_blend,
		ARM_IK_BLEND_SPEED * delta
	)
	right_arm_ik_blend = move_toward(
		right_arm_ik_blend,
		right_target_blend,
		ARM_IK_BLEND_SPEED * delta
	)
	if wall_stance:
		# A grapple can hand off directly into wall run. Kill the old free-arm
		# target immediately so only the actual wall-side hand remains constrained.
		if left_target_blend > 0.0:
			right_arm_ik_blend = 0.0
		else:
			left_arm_ik_blend = 0.0

	# State changes are gameplay interrupts, not clip-completion waits. Only
	# idle, wall contact, swing and zip retain arm IK; every other authored
	# transition disables a stale previous target before modifiers run.
	if (
		not idle_stance
		and not wall_stance
		and not _is_swing_pose_state()
		and pose_state != TraversalPoseState.ZIP
	):
		left_arm_ik_blend = 0.0
		right_arm_ik_blend = 0.0

	left_arm_ik.influence = left_arm_ik_blend
	right_arm_ik.influence = right_arm_ik_blend

	if idle_stance:
		_stabilize_idle_shoulders(
			maxf(left_arm_ik_blend, right_arm_ik_blend)
		)
	was_idle_arm_stance = idle_stance


func _configure_wall_run_hand_target(delta: float) -> bool:
	var normal_value: Variant = player.get("wall_ride_normal")
	if typeof(normal_value) != TYPE_VECTOR3:
		return _is_wall_on_left(last_wall_normal)

	var wall_normal: Vector3 = normal_value as Vector3
	wall_normal.y = 0.0
	if wall_normal.length_squared() < 0.01:
		return _is_wall_on_left(last_wall_normal)
	wall_normal = wall_normal.normalized()

	var tangent := Vector3(player.velocity.x, 0.0, player.velocity.z)
	tangent -= wall_normal * tangent.dot(wall_normal)
	if tangent.length_squared() < 0.01:
		tangent = Vector3.UP.cross(wall_normal)
	else:
		tangent = tangent.normalized()

	var wall_on_left: bool = _is_wall_on_left(wall_normal)
	var stride: float = _get_wall_run_stride(
		Vector2(player.velocity.x, player.velocity.z).length()
	)
	_configure_wall_side_hand_contact(
		wall_on_left,
		wall_normal,
		tangent,
		stride,
		delta
	)
	return wall_on_left


func _configure_wall_side_hand_contact(
	left_side: bool,
	wall_normal: Vector3,
	tangent: Vector3,
	stride: float,
	delta: float
) -> void:
	var arm_root: int = (
		left_arm_root_bone if left_side else right_arm_root_bone
	)
	var target: Marker3D = (
		left_hand_target if left_side else right_hand_target
	)
	var pole: Marker3D = (
		left_elbow_pole if left_side else right_elbow_pole
	)
	var arm_length: float = left_arm_length if left_side else right_arm_length
	if arm_root < 0 or target == null or pole == null or arm_length <= 0.0:
		return

	var shoulder_local: Vector3 = skeleton.get_bone_global_pose(arm_root).origin
	var shoulder_world: Vector3 = skeleton.to_global(shoulder_local)
	var wall_surface: Vector3 = (
		player.global_position - wall_normal * player_capsule_radius
	)
	var contact_plane: Vector3 = (
		wall_surface + wall_normal * WALL_HAND_SURFACE_CLEARANCE
	)
	# Project the shoulder onto the facade, then author only motion within the
	# wall plane. This makes the hand visibly drag on arbitrary wall headings.
	var projected_shoulder: Vector3 = (
		shoulder_world
		- wall_normal * (shoulder_world - contact_plane).dot(wall_normal)
	)
	var slide: float = -WALL_HAND_BASE_TRAIL + stride * WALL_HAND_STRIDE_SLIDE
	var plane_offset: Vector3 = (
		tangent * slide + Vector3.UP * WALL_HAND_LIFT
	)

	# Preserve facade contact while keeping the target inside the measured BRC
	# arm reach. The elbow stays bent instead of snapping into a singular line.
	var skeleton_scale: Vector3 = skeleton.global_transform.basis.get_scale()
	var arm_world_scale: float = maxf(
		(absf(skeleton_scale.x) + absf(skeleton_scale.y) + absf(skeleton_scale.z))
		/ 3.0,
		0.001
	)
	var usable_reach: float = (
		arm_length * arm_world_scale * WALL_HAND_REACH_RATIO
	)
	var wall_gap: float = absf(
		(shoulder_world - projected_shoulder).dot(wall_normal)
	)
	var available_plane_reach: float = sqrt(maxf(
		usable_reach * usable_reach - wall_gap * wall_gap,
		0.0
	))
	if plane_offset.length() > available_plane_reach:
		plane_offset = plane_offset.normalized() * available_plane_reach

	var desired_hand_world: Vector3 = projected_shoulder + plane_offset
	var desired_elbow_world: Vector3 = (
		(shoulder_world + desired_hand_world) * 0.5
		+ wall_normal * WALL_ELBOW_OUT_CLEARANCE
		- tangent * WALL_ELBOW_TRAIL
		+ Vector3.DOWN * 0.04
	)
	var desired_hand_local: Vector3 = skeleton.to_local(desired_hand_world)
	var desired_elbow_local: Vector3 = skeleton.to_local(desired_elbow_world)
	var follow: float = clampf(FAST_POSE_BLEND_SPEED * delta, 0.0, 1.0)
	target.position = target.position.lerp(desired_hand_local, follow)
	pole.position = pole.position.lerp(desired_elbow_local, follow)
	target.force_update_transform()
	pole.force_update_transform()


func _restore_idle_arm_targets() -> void:
	if (
		left_hand_target == null
		or right_hand_target == null
		or left_elbow_pole == null
		or right_elbow_pole == null
	):
		return
	left_hand_target.position = Vector3(
		IDLE_HAND_SIDE, IDLE_HAND_Y, IDLE_HAND_Z
	)
	right_hand_target.position = Vector3(
		-IDLE_HAND_SIDE, IDLE_HAND_Y, IDLE_HAND_Z
	)
	left_elbow_pole.position = Vector3(
		IDLE_ELBOW_SIDE, IDLE_ELBOW_Y, IDLE_ELBOW_Z
	)
	right_elbow_pole.position = Vector3(
		-IDLE_ELBOW_SIDE, IDLE_ELBOW_Y, IDLE_ELBOW_Z
	)
	for marker: Marker3D in [
		left_hand_target,
		right_hand_target,
		left_elbow_pole,
		right_elbow_pole,
	]:
		marker.force_update_transform()


func _configure_reachable_arm_target(
	left_side: bool,
	anchor_local: Vector3,
	reach_ratio: float,
	delta: float
) -> void:
	var arm_root: int = (
		left_arm_root_bone if left_side else right_arm_root_bone
	)
	var target: Marker3D = (
		left_hand_target if left_side else right_hand_target
	)
	var pole: Marker3D = (
		left_elbow_pole if left_side else right_elbow_pole
	)
	var arm_length: float = left_arm_length if left_side else right_arm_length
	if arm_root < 0 or target == null or pole == null or arm_length <= 0.0:
		return

	var shoulder: Vector3 = skeleton.get_bone_global_pose(arm_root).origin
	var reach_direction: Vector3 = anchor_local - shoulder
	if reach_direction.length_squared() < 0.0001:
		reach_direction = Vector3.BACK
	else:
		reach_direction = reach_direction.normalized()

	var side_sign: float = 1.0 if left_side else -1.0
	# A small downward component keeps the pole projection well-defined when a
	# side anchor nearly lines up with character-left/right. This removes the
	# old abrupt lateral -> fore/aft fallback that could flip the elbow plane.
	var outward := (
		Vector3.RIGHT * side_sign
		+ Vector3.DOWN * 0.32
	)
	outward -= reach_direction * outward.dot(reach_direction)
	if outward.length_squared() < 0.01:
		outward = Vector3.BACK - reach_direction * Vector3.BACK.dot(
			reach_direction
		)
	if outward.length_squared() < 0.01:
		outward = Vector3.DOWN
	outward = outward.normalized()

	var desired_target: Vector3 = (
		shoulder
		+ reach_direction * arm_length * reach_ratio
	)
	var desired_pole: Vector3 = (
		shoulder
		+ outward * SWING_ELBOW_POLE_SIDE
		+ Vector3.DOWN * SWING_ELBOW_POLE_DOWN
		- reach_direction * 0.04
	)
	var follow_blend: float = clampf(FAST_POSE_BLEND_SPEED * delta, 0.0, 1.0)
	target.position = target.position.lerp(desired_target, follow_blend)
	pole.position = pole.position.lerp(desired_pole, follow_blend)
	# Marker transforms are consumed by manual Skeleton3D.advance() in this
	# same frame, before Node3D's normal deferred transform notification.
	target.force_update_transform()
	pole.force_update_transform()


func _stabilize_idle_shoulders(blend: float) -> void:
	for shoulder_bone: int in [left_shoulder_bone, right_shoulder_bone]:
		if shoulder_bone < 0 or not brc_arm_rest_rotation.has(shoulder_bone):
			continue
		var current: Quaternion = skeleton.get_bone_pose_rotation(
			shoulder_bone
		)
		var rest: Quaternion = brc_arm_rest_rotation[shoulder_bone]
		skeleton.set_bone_pose_rotation(
			shoulder_bone,
			current.slerp(rest, clampf(blend * 0.95, 0.0, 1.0))
		)


func _is_swing_pose_state() -> bool:
	return pose_state in [
		TraversalPoseState.SWING_ATTACH,
		TraversalPoseState.SWING_ONE_HAND,
		TraversalPoseState.SWING_TWO_HAND,
	]


func _is_ground_run_active() -> bool:
	return pose_state == TraversalPoseState.RUN


func _apply_brc_run_arm_pose() -> void:
	if not _is_ground_run_active() or run_arm_blend <= 0.001:
		return
	if (
		skeleton == null
		or left_shoulder_bone < 0
		or right_shoulder_bone < 0
		or left_arm_root_bone < 0
		or right_arm_root_bone < 0
		or left_forearm_bone < 0
		or right_forearm_bone < 0
		or left_hand_bone < 0
		or right_hand_bone < 0
		or not fixed_run_shoulder_rotation.has(left_shoulder_bone)
		or not fixed_run_shoulder_rotation.has(right_shoulder_bone)
		or not fixed_run_upper_arm_plane.has(left_arm_root_bone)
		or not fixed_run_upper_arm_plane.has(right_arm_root_bone)
		or not fixed_run_forearm_rotation.has(left_forearm_bone)
		or not fixed_run_forearm_rotation.has(right_forearm_bone)
		or not fixed_run_hand_rotation.has(left_hand_bone)
		or not fixed_run_hand_rotation.has(right_hand_bone)
	):
		return

	var left_swing := Quaternion(Vector3.UP, arm_stride * RUN_UPPER_ARM_SWING)
	var right_swing := Quaternion(Vector3.UP, -arm_stride * RUN_UPPER_ARM_SWING)
	var left_upper_rest: Quaternion = brc_arm_rest_rotation[
		left_arm_root_bone
	]
	var right_upper_rest: Quaternion = brc_arm_rest_rotation[
		right_arm_root_bone
	]
	var left_upper_plane: Quaternion = fixed_run_upper_arm_plane[
		left_arm_root_bone
	]
	var right_upper_plane: Quaternion = fixed_run_upper_arm_plane[
		right_arm_root_bone
	]

	# Everything except arm1 is a cached, stride-independent pose. This runs
	# after skeleton.advance(), so donor retargeting and IK cannot reintroduce
	# shoulder abduction, changing elbow bend, or an uncalibrated wrist pose.
	_set_final_bone_rotation(
		left_shoulder_bone,
		fixed_run_shoulder_rotation[left_shoulder_bone],
		run_arm_blend
	)
	_set_final_bone_rotation(
		right_shoulder_bone,
		fixed_run_shoulder_rotation[right_shoulder_bone],
		run_arm_blend
	)
	_set_final_bone_rotation(
		left_arm_root_bone,
		(left_upper_rest * left_swing * left_upper_plane).normalized(),
		run_arm_blend
	)
	_set_final_bone_rotation(
		right_arm_root_bone,
		(right_upper_rest * right_swing * right_upper_plane).normalized(),
		run_arm_blend
	)
	_set_final_bone_rotation(
		left_forearm_bone,
		fixed_run_forearm_rotation[left_forearm_bone],
		run_arm_blend
	)
	_set_final_bone_rotation(
		right_forearm_bone,
		fixed_run_forearm_rotation[right_forearm_bone],
		run_arm_blend
	)
	_set_final_bone_rotation(
		left_hand_bone,
		fixed_run_hand_rotation[left_hand_bone],
		run_arm_blend
	)
	_set_final_bone_rotation(
		right_hand_bone,
		fixed_run_hand_rotation[right_hand_bone],
		run_arm_blend
	)


func apply_final_skeleton_pose() -> void:
	# This is called by the last SkeletonModifier3D child, after both arm and leg
	# IK stages. Run arms therefore remain genuinely final, and web markers read
	# the exact transient pose that Godot sends to the skin this frame.
	_apply_brc_run_arm_pose()
	_update_web_origins()
	_override_player_web_line()


func _set_final_bone_rotation(
	bone_index: int,
	target_rotation: Quaternion,
	blend: float
) -> void:
	if bone_index < 0:
		return
	var current: Quaternion = skeleton.get_bone_pose_rotation(bone_index)
	var final_rotation: Quaternion = current.slerp(
		target_rotation,
		clampf(blend, 0.0, 1.0)
	)
	skeleton.set_bone_pose_rotation(bone_index, final_rotation)
	pose_layer_rotation[bone_index] = final_rotation


func _build_brc_leg_ik() -> void:
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

	left_stride_foot_bone = foot_l
	right_stride_foot_bone = foot_r
	left_leg_root_bone = leg1_l
	right_leg_root_bone = leg1_r
	left_leg_length = (
		skeleton.get_bone_rest(leg2_l).origin.length()
		+ skeleton.get_bone_rest(foot_l).origin.length()
	)
	right_leg_length = (
		skeleton.get_bone_rest(leg2_r).origin.length()
		+ skeleton.get_bone_rest(foot_r).origin.length()
	)

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
	left_foot_player_height = (
		skeleton.to_global(left_foot_rest.origin).y
		- player.global_position.y
	)
	right_foot_player_height = (
		skeleton.to_global(right_foot_rest.origin).y
		- player.global_position.y
	)
	left_knee_player_height = (
		skeleton.to_global(left_knee_rest.origin).y
		- player.global_position.y
	)
	right_knee_player_height = (
		skeleton.to_global(right_knee_rest.origin).y
		- player.global_position.y
	)

	left_foot_target = Marker3D.new()
	left_foot_target.name = "LeftTraversalFootTarget"
	left_foot_target.position = left_foot_idle_position
	skeleton.add_child(left_foot_target)

	right_foot_target = Marker3D.new()
	right_foot_target.name = "RightTraversalFootTarget"
	right_foot_target.position = right_foot_idle_position
	skeleton.add_child(right_foot_target)

	left_knee_pole = Marker3D.new()
	left_knee_pole.name = "LeftTraversalKneePole"
	left_knee_pole.position = left_knee_idle_position
	skeleton.add_child(left_knee_pole)

	right_knee_pole = Marker3D.new()
	right_knee_pole.name = "RightTraversalKneePole"
	right_knee_pole.position = right_knee_idle_position
	skeleton.add_child(right_knee_pole)

	left_leg_ik = TwoBoneIK3D.new()
	left_leg_ik.name = "LeftTraversalLegIK"
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
	right_leg_ik.name = "RightTraversalLegIK"
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


func _update_leg_ik(
	delta: float,
	horizontal_speed: float
) -> void:
	if left_leg_ik == null or right_leg_ik == null:
		return

	var idle_stance: bool = (
		pose_state == TraversalPoseState.BASE
		and horizontal_speed <= IDLE_LEG_IK_MAX_SPEED
	)
	var wall_stance: bool = pose_state == TraversalPoseState.WALL_RUN

	if idle_stance:
		left_foot_target.position = left_foot_idle_position
		right_foot_target.position = right_foot_idle_position
		left_knee_pole.position = left_knee_idle_position
		right_knee_pole.position = right_knee_idle_position
		left_foot_target.force_update_transform()
		right_foot_target.force_update_transform()
		left_knee_pole.force_update_transform()
		right_knee_pole.force_update_transform()
	elif wall_stance:
		_configure_wall_leg_targets(horizontal_speed)

	var target_blend: float = 1.0 if idle_stance or wall_stance else 0.0
	var blend_speed: float = (
		FAST_POSE_BLEND_SPEED
		if wall_stance
		else IDLE_LEG_IK_BLEND_SPEED
	)
	leg_ik_blend = move_toward(
		leg_ik_blend,
		target_blend,
		blend_speed * delta
	)
	if not idle_stance and not wall_stance:
		leg_ik_blend = 0.0

	if wall_stance:
		var stride: float = _get_wall_run_stride(horizontal_speed)
		var wall_on_left: bool = _is_wall_on_left(last_wall_normal)
		var left_phase: float = stride if wall_on_left else -stride
		var left_contact: float = _get_wall_contact_weight(left_phase)
		var right_contact: float = _get_wall_contact_weight(-left_phase)
		# Only the planted leg strongly reaches the facade. The recovering leg is
		# mostly authored, so its heel can fold toward the body instead of both feet
		# being dragged into the same seated pose. Full contact on the planted foot
		# makes the BRC-style wall step read clearly at gameplay distance.
		left_leg_ik.influence = leg_ik_blend * lerpf(
			0.0, 0.94, left_contact
		)
		right_leg_ik.influence = leg_ik_blend * lerpf(
			0.0, 0.94, right_contact
		)
	else:
		left_leg_ik.influence = leg_ik_blend
		right_leg_ik.influence = leg_ik_blend


func _get_wall_contact_weight(phase: float) -> float:
	# Only one shoe is strongly planted at a time. At the stride crossover both
	# IK influences release briefly so the authored knees can exchange roles
	# without both legs being pulled into the facade at once.
	return smoothstep(0.08, 0.78, -phase)


func _configure_wall_leg_targets(horizontal_speed: float) -> void:
	var normal_value: Variant = player.get("wall_ride_normal")
	if typeof(normal_value) != TYPE_VECTOR3:
		return
	var wall_normal: Vector3 = normal_value as Vector3
	wall_normal.y = 0.0
	if wall_normal.length_squared() < 0.01:
		return
	wall_normal = wall_normal.normalized()

	var tangent := Vector3(player.velocity.x, 0.0, player.velocity.z)
	tangent -= wall_normal * tangent.dot(wall_normal)
	if tangent.length_squared() < 0.01:
		tangent = Vector3.UP.cross(wall_normal)
	else:
		tangent = tangent.normalized()

	var stride: float = _get_wall_run_stride(horizontal_speed)
	var wall_on_left: bool = _is_wall_on_left(wall_normal)
	var left_phase: float = stride if wall_on_left else -stride
	_configure_wall_leg_target(true, left_phase, wall_normal, tangent)
	_configure_wall_leg_target(false, -left_phase, wall_normal, tangent)


func _configure_wall_leg_target(
	left_side: bool,
	phase: float,
	wall_normal: Vector3,
	tangent: Vector3
) -> void:
	var foot_target: Marker3D = (
		left_foot_target if left_side else right_foot_target
	)
	var knee_pole: Marker3D = (
		left_knee_pole if left_side else right_knee_pole
	)
	if foot_target == null or knee_pole == null:
		return

	var foot_height: float = (
		left_foot_player_height if left_side else right_foot_player_height
	)
	var knee_height: float = (
		left_knee_player_height if left_side else right_knee_player_height
	)
	var leg_root: int = (
		left_leg_root_bone if left_side else right_leg_root_bone
	)
	var leg_length: float = left_leg_length if left_side else right_leg_length
	if leg_root < 0 or leg_length <= 0.0:
		return
	var side_sign: float = 1.0 if left_side else -1.0
	var recovery: float = smoothstep(-0.30, 0.75, phase)
	var surface_point: Vector3 = (
		player.global_position - wall_normal * player_capsule_radius
	)
	var desired_ankle_world: Vector3 = (
		surface_point
		+ wall_normal
			* (
				WALL_ANKLE_SURFACE_CLEARANCE
				+ recovery * WALL_RECOVERY_CLEARANCE
			)
		+ Vector3.UP
			* (
				foot_height
				+ WALL_CONTACT_LIFT
				+ recovery * WALL_RECOVERY_LIFT
			)
		# A small authored phase separation prevents both ankle targets from
		# collapsing onto one point at the sine-wave crossover. The larger
		# stride still comes from the alternating contact/recovery phase.
		+ tangent
			* (
				phase * WALL_STEP_LENGTH
				+ side_sign * WALL_FOOT_PHASE_SEPARATION
			)
	)
	var ankle_local: Vector3 = skeleton.to_local(desired_ankle_world)
	var hip_local: Vector3 = skeleton.get_bone_global_pose(leg_root).origin
	var horizontal_delta := Vector3(
		ankle_local.x - hip_local.x,
		0.0,
		ankle_local.z - hip_local.z
	)
	var reach_ratio: float = lerpf(
		WALL_SUPPORT_REACH_RATIO,
		WALL_RECOVERY_REACH_RATIO,
		recovery
	)
	var usable_reach: float = leg_length * reach_ratio
	var horizontal_length: float = horizontal_delta.length()
	if horizontal_length < usable_reach:
		# Preserve the wall-plane contact exactly, but raise an unreachable
		# ground-height ankle until the current BRC chain can bend to it.
		var maximum_drop: float = sqrt(
			maxf(
				usable_reach * usable_reach
				- horizontal_length * horizontal_length,
				0.0
			)
		)
		ankle_local.y = maxf(ankle_local.y, hip_local.y - maximum_drop)
	else:
		# Extreme visual-root offsets still keep the target safely reachable.
		horizontal_delta = horizontal_delta.normalized() * usable_reach * 0.96
		ankle_local.x = hip_local.x + horizontal_delta.x
		ankle_local.z = hip_local.z + horizontal_delta.z
		ankle_local.y = hip_local.y - usable_reach * 0.20
	var knee_world: Vector3 = (
		player.global_position
		+ Vector3.UP * (knee_height + recovery * 0.35)
		+ wall_normal * (WALL_KNEE_CLEARANCE + recovery * 0.18)
		+ tangent * (phase * 0.13 + side_sign * 0.07)
	)

	foot_target.position = ankle_local
	knee_pole.global_position = knee_world
	foot_target.force_update_transform()
	knee_pole.force_update_transform()


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


func _choose_web_hand() -> int:
	var camera_lateral: float = _get_camera_anchor_lateral()
	if camera_lateral < -0.10:
		return -1
	if camera_lateral > 0.10:
		return 1
	return -active_web_hand


func _get_camera_anchor_lateral() -> float:
	var grapple_value: Variant = player.get("grapple_point")

	if typeof(grapple_value) != TYPE_VECTOR3:
		return 0.0

	var camera_value: Variant = player.get("camera")
	var camera_node: Camera3D = camera_value as Camera3D

	if camera_node == null:
		return 0.0

	var local_target: Vector3 = camera_node.to_local(
		grapple_value as Vector3
	)
	if local_target.length_squared() < 0.0001:
		return 0.0
	return local_target.normalized().x


func _update_web_origins() -> void:
	_update_web_marker(
		web_origin_l,
		left_hand_bone,
		-1.0
	)
	_update_web_marker(
		web_origin_r,
		right_hand_bone,
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
	_position_web_marker(marker, hand_pose, side)


func _position_web_marker(
	marker: Marker3D,
	hand_pose: Transform3D,
	side: float
) -> void:
	if marker == null:
		return
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


func _update_root_presentation_request() -> void:
	# player.gd remains the one visual-root writer. This controller supplies
	# only state-aware targets so render and physics ticks cannot fight.
	var override_active: bool = (
		pose_state == TraversalPoseState.DIVE
		or pose_state == TraversalPoseState.ZIP
		or pose_state == TraversalPoseState.SWING_FLIP
		or pose_state == TraversalPoseState.LAND_ROLL
	)
	if float(player.get("attack_pose_time")) > 0.0:
		override_active = false
	player.set("brc_traversal_root_override_active", override_active)
	if not override_active:
		return

	var horizontal := Vector2(player.velocity.x, player.velocity.z)
	var target_pitch: float = 0.0
	var target_yaw: float = trick_facing_yaw
	if pose_state == TraversalPoseState.DIVE:
		var downwardness: float = clampf(
			maxf(-player.velocity.y, 0.0)
			/ maxf(player.velocity.length(), 0.1),
			0.0,
			1.0
		)
		# 125-145 degrees from upright. Passing 90 degrees is intentional: a
		# vertical fall must place the head below the hips instead of going flat.
		target_pitch = -lerpf(2.18, 2.53, downwardness)
		if horizontal.length() > 1.0:
			target_yaw = atan2(-player.velocity.x, -player.velocity.z)
	elif pose_state == TraversalPoseState.ZIP:
		var travel_length: float = maxf(player.velocity.length(), 0.1)
		target_pitch = clampf(
			-player.velocity.y / travel_length * 0.65 - 0.30,
			-0.82,
			0.40
		)
		if horizontal.length() > 1.0:
			target_yaw = atan2(-player.velocity.x, -player.velocity.z)
	else:
		var duration: float = (
			SWING_FLIP_DURATION
			if pose_state == TraversalPoseState.SWING_FLIP
			else DIVE_LANDING_ROLL_DURATION
		)
		var remaining: float = (
			swing_flip_remaining
			if pose_state == TraversalPoseState.SWING_FLIP
			else landing_roll_remaining
		)
		var progress: float = clampf(1.0 - remaining / duration, 0.0, 1.0)
		var eased: float = smoothstep(0.0, 1.0, progress)
		# Blend the incoming body angle toward neutral while adding one complete
		# forward revolution. A dive therefore finishes the remaining arc into a
		# roll instead of snapping upright at contact.
		target_pitch = lerpf(trick_start_pitch, 0.0, eased)
	player.set("brc_traversal_root_pitch", target_pitch)
	player.set("brc_traversal_root_yaw", target_yaw)


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
