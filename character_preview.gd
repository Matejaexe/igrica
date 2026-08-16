extends Node3D

# Lightweight menu/loading preview controller. It drives the real BRC skeleton
# directly from imported Bone Rest rotations and never starts the gameplay rig.

const ROSTER = preload("res://character_roster.gd")
const SPIDEY_IMPORTED = preload("res://spidey_imported_model.gd")

const SHOULDER_FORWARD: float = 0.262
const SHOULDER_ADDUCTION: float = 0.384
const UPPER_ARM_PLANE: float = PI * 0.5
const HAND_ROLL: float = PI * 0.5
const IDLE_TEMPOS: Array[float] = [1.55, 1.05, 1.32, 0.82]
const IDLE_BOB: Array[float] = [0.032, 0.020, 0.042, 0.026]
const IDLE_SWAY: Array[float] = [0.030, 0.020, 0.055, 0.026]
const IDLE_KNEE: Array[float] = [0.20, 0.14, 0.22, 0.28]
const IDLE_ELBOW: Array[float] = [1.18, 1.10, 1.24, 1.30]
const IDLE_ARM_MOTION: Array[float] = [0.12, 0.08, 0.16, 0.09]
const IDLE_TORSO_TWIST: Array[float] = [0.050, 0.032, 0.080, 0.040]

var character_index: int = 0
var model_root: Node3D = null
var skeleton: Skeleton3D = null
var rotation_speed: float = TAU / 28.0
var auto_rotate: bool = true
var idle_time: float = 0.0
var phase_offset: float = 0.0
var presentation_scale: float = 1.0
var _rest_rotations: Dictionary = {}
var _bone_indices: Dictionary = {}


func configure_preview(
	index: int,
	rotate_model: bool = true,
	phase: float = 0.0,
	display_scale: float = 1.0
) -> void:
	character_index = posmod(index, ROSTER.count())
	auto_rotate = rotate_model
	phase_offset = phase
	presentation_scale = display_scale
	if is_inside_tree():
		rebuild(character_index)


func _ready() -> void:
	# Loading-screen previews are configured before entering the SceneTree,
	# whereas character-select previews enter first. Both paths build once here.
	process_priority = 100
	rebuild(character_index)


func _process(delta: float) -> void:
	idle_time += delta
	if auto_rotate:
		rotation.y += rotation_speed * delta
	_apply_idle_pose()


func rebuild(index: int) -> void:
	character_index = posmod(index, ROSTER.count())
	if model_root != null and is_instance_valid(model_root):
		remove_child(model_root)
		model_root.queue_free()

	model_root = Node3D.new()
	model_root.name = "PreviewCharacter"
	model_root.scale = Vector3.ONE * presentation_scale
	add_child(model_root)

	var refs: Dictionary = SPIDEY_IMPORTED.build_preview(
		model_root,
		ROSTER.get_character(character_index)
	)
	skeleton = refs.get("skeleton") as Skeleton3D
	_cache_rest_rotations()
	idle_time = 0.0
	_apply_idle_pose()


func rotate_manual(amount: float) -> void:
	rotation.y += amount


func _cache_rest_rotations() -> void:
	_rest_rotations.clear()
	_bone_indices.clear()
	if skeleton == null:
		return
	for bone_name in [
		"hips", "s1", "s2", "neck", "head",
		"shldl", "arm1l", "arm2l", "handl",
		"shldr", "arm1r", "arm2r", "handr",
		"leg1l", "leg2l", "footl", "toesl",
		"leg1r", "leg2r", "footr", "toesr"
	]:
		var bone_index: int = skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		_bone_indices[bone_name] = bone_index
		_rest_rotations[bone_index] = (
			skeleton
			.get_bone_rest(bone_index)
			.basis
			.orthonormalized()
			.get_rotation_quaternion()
		)


func _apply_idle_pose() -> void:
	if skeleton == null:
		return

	var style: int = character_index % 4
	var tempo: float = IDLE_TEMPOS[style]
	var phase: float = idle_time * tempo + phase_offset
	var breath: float = sin(phase)
	var weight: float = sin(phase * 0.47 + float(style) * 0.8)
	var secondary: float = sin(phase * 0.73 + 1.1)
	# Twenty seconds leaves calm breathing gaps between authored gestures instead
	# of making the runner perform continuously like a menu attract loop.
	var presentation_cycle: float = fposmod(idle_time, 20.0) / 20.0
	var head_scratch: float = _cycle_pulse(presentation_cycle, 0.18, 0.085)
	var stretch_pose: float = _cycle_pulse(presentation_cycle, 0.44, 0.10)
	var web_check: float = _cycle_pulse(presentation_cycle, 0.67, 0.08)
	var spider_pose: float = _cycle_pulse(presentation_cycle, 0.86, 0.09)

	var bob_amount: float = IDLE_BOB[style]
	var sway_amount: float = IDLE_SWAY[style]
	var knee_base: float = IDLE_KNEE[style] + spider_pose * 0.54
	var elbow_base: float = (
		IDLE_ELBOW[style]
		- stretch_pose * 0.44
		+ spider_pose * 0.08
		+ web_check * 0.10
	)
	var arm_motion: float = IDLE_ARM_MOTION[style]
	var torso_twist: float = weight * IDLE_TORSO_TWIST[style]

	model_root.position.y = breath * bob_amount
	model_root.rotation.z = weight * sway_amount

	_set_rest_offset(
		"hips",
		torso_twist * 0.35,
		-0.035 - spider_pose * 0.10 + stretch_pose * 0.035,
		weight * 0.012
	)
	_set_rest_offset(
		"s1",
		torso_twist * 0.60,
		-0.025 - breath * 0.012 - spider_pose * 0.10 + stretch_pose * 0.06,
		0.0
	)
	_set_rest_offset(
		"s2",
		torso_twist + spider_pose * 0.045,
		breath * 0.022 - spider_pose * 0.08 + stretch_pose * 0.08,
		0.0
	)
	_set_rest_offset(
		"neck",
		-torso_twist * 0.42,
		-breath * 0.010 - web_check * 0.045,
		head_scratch * -0.055
	)
	_set_rest_offset(
		"head",
		-torso_twist * 0.22,
		-web_check * 0.09,
		secondary * 0.012 + head_scratch * -0.10
	)

	# The calibrated shoulder/arm chain lowers the imported T-pose while keeping
	# elbows and hands safely outside the torso. Character style changes only the
	# small forward/back idle gesture, never lateral wing motion.
	var left_arm_swing: float = breath * arm_motion
	var right_arm_swing: float = -breath * arm_motion
	# Stretch: both arms rise and open. Scratch: the right bent arm reaches near
	# the temple while the head leans toward it. Web check: both hands come into
	# the lower-chest workspace. Hero pose finishes the sequence asymmetrically.
	left_arm_swing += (
		stretch_pose * -0.88
		+ web_check * -0.34
		+ spider_pose * -0.54
	)
	right_arm_swing += (
		head_scratch * -1.02
		+ stretch_pose * -0.80
		+ web_check * -0.42
		+ spider_pose * 0.42
	)
	_set_idle_arm(
		true,
		left_arm_swing,
		elbow_base + secondary * 0.035 + web_check * 0.12
	)
	_set_idle_arm(
		false,
		right_arm_swing,
		elbow_base - secondary * 0.035 + head_scratch * 0.26 + web_check * 0.14
	)

	var stance_shift: float = weight * 0.035
	_set_rest_offset(
		"leg1l", 0.0,
		stance_shift - spider_pose * 0.20 + stretch_pose * 0.04,
		0.0
	)
	_set_rest_offset(
		"leg1r", 0.0,
		-stance_shift + spider_pose * 0.12 + stretch_pose * 0.04,
		0.0
	)
	_set_rest_offset("leg2l", 0.0, knee_base + breath * 0.025, 0.0)
	_set_rest_offset("leg2r", 0.0, knee_base - breath * 0.025, 0.0)
	_set_rest_offset("footl", 0.0, -0.045 - stance_shift * 0.25, 0.0)
	_set_rest_offset("footr", 0.0, -0.045 + stance_shift * 0.25, 0.0)
	_set_rest_offset("toesl", 0.0, 0.0, 0.0)
	_set_rest_offset("toesr", 0.0, 0.0, 0.0)


func _cycle_pulse(cycle: float, center: float, half_width: float) -> float:
	var distance: float = absf(cycle - center)
	distance = minf(distance, 1.0 - distance)
	var linear: float = 1.0 - clampf(distance / half_width, 0.0, 1.0)
	return smoothstep(0.0, 1.0, linear)


func _set_idle_arm(
	left_side: bool,
	upper_arm_swing: float,
	elbow_flex: float
) -> void:
	var suffix: String = "l" if left_side else "r"
	var side_sign: float = 1.0 if left_side else -1.0
	var shoulder_index: int = int(_bone_indices.get("shld" + suffix, -1))
	var upper_index: int = int(_bone_indices.get("arm1" + suffix, -1))
	var forearm_index: int = int(_bone_indices.get("arm2" + suffix, -1))
	var hand_index: int = int(_bone_indices.get("hand" + suffix, -1))
	if (
		shoulder_index < 0
		or upper_index < 0
		or forearm_index < 0
		or hand_index < 0
	):
		return

	var shoulder_rest: Quaternion = _rest_rotations[shoulder_index]
	var upper_rest: Quaternion = _rest_rotations[upper_index]
	var forearm_rest: Quaternion = _rest_rotations[forearm_index]
	var hand_rest: Quaternion = _rest_rotations[hand_index]
	skeleton.set_bone_pose_rotation(
		shoulder_index,
		(
			shoulder_rest
			* Quaternion(Vector3.RIGHT, SHOULDER_FORWARD * side_sign)
			* Quaternion(Vector3.BACK, -SHOULDER_ADDUCTION * side_sign)
		).normalized()
	)
	skeleton.set_bone_pose_rotation(
		upper_index,
		(
			upper_rest
			* Quaternion(Vector3.UP, upper_arm_swing)
			* Quaternion(Vector3.RIGHT, -UPPER_ARM_PLANE * side_sign)
		).normalized()
	)
	skeleton.set_bone_pose_rotation(
		forearm_index,
		(
			forearm_rest
			* Quaternion(Vector3.BACK, -elbow_flex * side_sign)
		).normalized()
	)
	skeleton.set_bone_pose_rotation(
		hand_index,
		(
			hand_rest
			* Quaternion(Vector3.RIGHT, HAND_ROLL * side_sign)
		).normalized()
	)


func _set_rest_offset(
	bone_name: String,
	x_angle: float,
	y_angle: float,
	z_angle: float
) -> void:
	var bone_index: int = int(_bone_indices.get(bone_name, -1))
	if bone_index < 0 or not _rest_rotations.has(bone_index):
		return
	var rest: Quaternion = _rest_rotations[bone_index]
	var offset := (
		Quaternion(Vector3.RIGHT, x_angle)
		* Quaternion(Vector3.UP, y_angle)
		* Quaternion(Vector3.BACK, z_angle)
	).normalized()
	skeleton.set_bone_pose_rotation(
		bone_index,
		(rest * offset).normalized()
	)
