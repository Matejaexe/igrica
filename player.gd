extends CharacterBody3D

const ROSTER = preload("res://character_roster.gd")
const SPIDEY_IMPORTED = preload("res://spidey_imported_model.gd")
const HERO_MODEL = preload("res://hero_model.gd")

signal health_changed(value)
signal player_died()

enum MovementState { GROUND, AIR, SWING, WALL_RIDE, ZIP }

const RUN_SPEED = 17.0
const GROUND_ACCEL = 50.0
const AIR_ACCEL = 19.0
const JUMP_SPEED = 12.0
const DOUBLE_JUMP_SPEED = 11.4
const DOUBLE_JUMP_POSE_DURATION = 0.50
const WALL_JUMP_UP = 10.8
const WALL_JUMP_OUT = 10.0
const GRAVITY_FORCE = 27.5
const MAX_FALL_SPEED = 52.0
const MOUSE_SENSITIVITY = 0.0024

const GRAPPLE_RANGE = 105.0
const MIN_ROPE_LENGTH = 4.5
const MAX_ROPE_LENGTH = 54.0
const ROPE_STIFFNESS = 52.0
const SWING_INPUT_ACCEL = 25.0
const SWING_TANGENT_BOOST = 13.0
const REEL_IN_SPEED = 11.0
const REEL_OUT_SPEED = 13.0
const ZIP_SPEED = 36.0
const ZIP_UPWARD = 5.5
const ATTACK_RANGE = 3.4
const WALL_RIDE_MIN_SPEED = 7.5
const WALL_RIDE_MIN_TANGENT_SPEED = 5.0
const WALL_RIDE_MAX_FALL_SPEED = 3.5
const WALL_RIDE_GRAVITY = 3.8
const WALL_RIDE_ACCEL = 6.0
const WALL_RIDE_STICK_FORCE = 2.8
const WALL_RIDE_SPEED_BLEED = 0.65
const WALL_CONTACT_GRACE = 0.18
const BASE_CAMERA_FOV = 82.0
const PLAYER_CAPSULE_RADIUS = 0.46
const WALL_MESH_SAFE_MARGIN = 0.06
# The imported bind AABB includes T-pose fingertips and is much wider than the
# compact wall-run silhouette. Using that full width pushed the torso a metre
# from the facade and forced both legs into a seated reach. This posed envelope
# includes the compact wall lean while keeping the torso and shoes outside.
const WALL_RUN_POSED_HALF_WIDTH = 0.58

var active = false
var character_index = 0
var character_data = {}
var speed_mult = 1.0
var accel_mult = 1.0
var air_mult = 1.0
var swing_mult = 1.0
var zip_mult = 1.0
var defense_mult = 1.0
var combat_mult = 1.0
var yaw = 0.0
var pitch = -0.20
var camera_pivot = null
var camera = null
var visual_root = null
var web_line = null
var web_mesh = null
var grappling = false
var grapple_point = Vector3.ZERO
var rope_length = 0.0
var spawn_position = Vector3.ZERO
var wall_normal_memory = Vector3.ZERO
var run_time = 0.0
var health = 100
var invuln_time = 0.0
var attack_cooldown = 0.0
var camera_kick = 0.0
var wall_riding = false
var wall_ride_normal = Vector3.ZERO
var wall_ride_time = 0.0
var wall_contact_grace = 0.0
var combo_step = 0
var combo_window = 0.0
var special_cooldown = 0.0
var movement_state = MovementState.AIR
var zip_pose_time = 0.0
var swing_release_pose_time = 0.0
var wall_jump_pose_time = 0.0
var double_jump_pose_time = 0.0
var double_jump_sequence = 0
var air_jumps_remaining = 1
var attack_pose_time = 0.0
var attack_pose_duration = 0.0
var special_pose = ""
# Traversal root presentation has one writer: this script. The real BRC rig
# controller supplies only a desired pitch/yaw for states such as DIVE/ZIP.
var brc_traversal_root_override_active = false
var brc_traversal_root_pitch = 0.0
var brc_traversal_root_yaw = 0.0
var was_on_floor = false
var landing_feedback = 0.0
var last_vertical_speed = 0.0
var swing_pose_time = 0.0
var wall_visual_offset = max(
	0.0,
	WALL_RUN_POSED_HALF_WIDTH - PLAYER_CAPSULE_RADIUS + WALL_MESH_SAFE_MARGIN
)

var left_arm = null
var right_arm = null
var left_leg = null
var right_leg = null
var torso_root = null

func _ready():
	character_data = ROSTER.get_character(character_index)
	_apply_character_stats()
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.35
	spawn_position = global_position
	_build_collision()
	_build_detailed_character()
	_build_camera()
	_build_web_line()

func set_character(index):
	character_index = posmod(index, ROSTER.count())
	character_data = ROSTER.get_character(character_index)
	_apply_character_stats()
	if visual_root != null and is_instance_valid(visual_root):
		visual_root.queue_free()
		visual_root = null
	_build_detailed_character()

func _apply_character_stats():
	speed_mult = float(character_data.get("speed_mult", 1.0))
	accel_mult = float(character_data.get("accel_mult", 1.0))
	air_mult = float(character_data.get("air_mult", 1.0))
	swing_mult = float(character_data.get("swing_mult", 1.0))
	zip_mult = float(character_data.get("zip_mult", 1.0))
	defense_mult = float(character_data.get("defense_mult", 1.0))
	combat_mult = float(character_data.get("combat_mult", 1.0))

func set_active(value):
	active = value
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_spawn_position(pos):
	spawn_position = pos

func _unhandled_input(event):
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch -= event.relative.y * MOUSE_SENSITIVITY
		pitch = clamp(pitch, -1.18, 0.72)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if not active:
		velocity = Vector3.ZERO
		return

	invuln_time = max(0.0, invuln_time - delta)
	attack_cooldown = max(0.0, attack_cooldown - delta)
	special_cooldown = max(0.0, special_cooldown - delta)
	combo_window = max(0.0, combo_window - delta)
	if combo_window <= 0.0:
		combo_step = 0
	camera_kick = move_toward(camera_kick, 0.0, 5.0 * delta)
	zip_pose_time = max(0.0, zip_pose_time - delta)
	swing_release_pose_time = max(0.0, swing_release_pose_time - delta)
	wall_jump_pose_time = max(0.0, wall_jump_pose_time - delta)
	double_jump_pose_time = max(0.0, double_jump_pose_time - delta)
	attack_pose_time = max(0.0, attack_pose_time - delta)
	landing_feedback = move_toward(landing_feedback, 0.0, 7.0 * delta)
	swing_pose_time = swing_pose_time + delta if grappling else 0.0

	var wall_roll = 0.0
	if wall_riding:
		wall_roll = clamp(wall_ride_normal.dot(camera_pivot.global_transform.basis.x) * 0.075, -0.075, 0.075)
	camera_pivot.rotation.x = pitch - camera_kick * 0.02 + landing_feedback * 0.018
	camera_pivot.rotation.y = yaw
	camera_pivot.rotation.z = lerp(camera_pivot.rotation.z, wall_roll, min(1.0, 6.0 * delta))

	var wish_dir = _get_camera_relative_input()

	_handle_grapple_input()
	_handle_attack_input()
	_handle_movement(delta, wish_dir)

	if grappling:
		_apply_swing_physics(delta, wish_dir)

	move_and_slide()

	_remember_wall_normal(delta)
	_update_wall_ride(delta)
	_update_movement_state()
	_update_camera_feedback(delta)
	if is_on_floor() and not was_on_floor and last_vertical_speed < -8.0:
		landing_feedback = clamp(abs(last_vertical_speed) / 24.0, 0.25, 0.85)
	was_on_floor = is_on_floor()
	last_vertical_speed = velocity.y
	_update_web_visual()
	_animate_character(delta)

	if global_position.y < -28.0:
		_respawn(true)

func _get_camera_relative_input():
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward = -camera_pivot.global_transform.basis.z
	var right = camera_pivot.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var wish_dir = right * input_vec.x + forward * (-input_vec.y)
	if wish_dir.length() > 1.0:
		wish_dir = wish_dir.normalized()
	return wish_dir

func _build_collision():
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = PLAYER_CAPSULE_RADIUS
	capsule.height = 2.85
	collision.shape = capsule
	add_child(collision)

func _build_detailed_character():
	visual_root = Node3D.new()
	visual_root.name = "ImportedBRCSpidey"
	add_child(visual_root)

	var refs: Dictionary = SPIDEY_IMPORTED.build(visual_root, character_data)
	torso_root = refs["torso_root"]
	left_arm = refs["left_arm"]
	right_arm = refs["right_arm"]
	left_leg = refs["left_leg"]
	right_leg = refs["right_leg"]

func _make_detailed_arm(side, red, red_dark, blue, black):
	var pivot = Node3D.new()
	pivot.name = "ArmL" if side < 0.0 else "ArmR"
	pivot.position = Vector3(0.56 * side, 0.60, 0.0)
	visual_root.add_child(pivot)

	# Shoulder joint, upper arm, elbow, forearm and glove are all rounded.
	_sphere_part(pivot, Vector3(0.03 * side, 0.0, 0.0), Vector3(0.23, 0.25, 0.22), red, 16, 8)
	_cylinder_part(pivot, Vector3(0.08 * side, -0.30, 0.0), 0.18, 0.52, Vector3(0,0,-0.10 * side), red, 16)
	_sphere_part(pivot, Vector3(0.11 * side, -0.56, 0.0), Vector3(0.18,0.18,0.18), red_dark, 14, 7)
	_cylinder_part(pivot, Vector3(0.14 * side, -0.78, -0.01), 0.16, 0.42, Vector3(0,0,0.07 * side), red_dark, 16)
	_sphere_part(pivot, Vector3(0.17 * side, -1.04, -0.02), Vector3(0.22,0.20,0.23), red, 16, 8)

	# Suit panel and web bands.
	_sphere_part(pivot, Vector3(-0.10 * side, -0.22, 0.02), Vector3(0.08,0.23,0.19), blue, 12, 6)
	_box_part_rotated(pivot, Vector3(0.14 * side, -0.70, -0.16), Vector3(0.22,0.020,0.018), Vector3(0,0,0.12 * side), black)
	_box_part_rotated(pivot, Vector3(0.16 * side, -0.86, -0.16), Vector3(0.22,0.020,0.018), Vector3(0,0,0.12 * side), black)
	return pivot

func _make_detailed_leg(side, blue, blue_light, red, red_dark, white, sole, black):
	var pivot = Node3D.new()
	pivot.name = "LegL" if side < 0.0 else "LegR"
	pivot.position = Vector3(0.23 * side, -0.34, 0.0)
	visual_root.add_child(pivot)

	_sphere_part(pivot, Vector3(0.0, -0.08, 0), Vector3(0.24,0.27,0.24), blue, 16, 8)
	_cylinder_part(pivot, Vector3(0.02 * side, -0.38, 0), 0.22, 0.56, Vector3(0,0,0.04 * side), blue, 16)
	_sphere_part(pivot, Vector3(0.02 * side, -0.66, 0), Vector3(0.21,0.19,0.21), blue_light, 14, 7)
	_cylinder_part(pivot, Vector3(0.01 * side, -0.89, -0.01), 0.18, 0.42, Vector3.ZERO, blue_light, 16)

	# Boot shaft and rounded sneaker.
	_cylinder_part(pivot, Vector3(0.01 * side, -1.12, -0.02), 0.185, 0.30, Vector3.ZERO, red_dark, 16)
	var shoe = Node3D.new()
	shoe.position = Vector3(0.0, -1.34, -0.15)
	pivot.add_child(shoe)
	_sphere_part(shoe, Vector3(0,0,-0.11), Vector3(0.29,0.19,0.44), red, 18, 8)
	_sphere_part(shoe, Vector3(0,-0.13,-0.11), Vector3(0.31,0.08,0.46), sole, 18, 6)
	_sphere_part(shoe, Vector3(0,0.03,-0.39), Vector3(0.27,0.15,0.20), white, 16, 7)
	_box_part(shoe, Vector3(0,0.13,-0.10), Vector3(0.28,0.026,0.036), white)
	_box_part(shoe, Vector3(0,0.13,-0.19), Vector3(0.28,0.026,0.036), white)
	_box_part(shoe, Vector3(0,0.13,-0.28), Vector3(0.26,0.026,0.036), white)
	_sphere_part(shoe, Vector3(0,0.02,0.27), Vector3(0.22,0.12,0.08), black, 12, 6)
	return pivot

func _lens(parent, side, black, white):
	var x = 0.17 * side
	var rot = -0.22 * side
	var frame = _sphere_part(parent, Vector3(x, 1.25, -0.385), Vector3(0.14,0.24,0.035), black, 16, 8)
	frame.rotation.z = rot
	var lens = _sphere_part(parent, Vector3(x + 0.005 * side, 1.255, -0.410), Vector3(0.095,0.19,0.022), white, 16, 8)
	lens.rotation.z = rot

func _sphere_part(parent, pos, scale_value, material, radial_segments, rings):
	var instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _cylinder_part(parent, pos, radius, height, rotation_value, material, segments):
	var instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rotation_value
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _box_part(parent, pos, size, material):
	var instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _box_part_rotated(parent, pos, size, rotation_value, material):
	var part = _box_part(parent, pos, size, material)
	part.rotation = rotation_value
	return part

func _material(color, roughness):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _build_camera():
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0.0, 0.70, 0.0)
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 1.35, 7.2)
	camera.fov = BASE_CAMERA_FOV
	camera.current = true
	camera_pivot.add_child(camera)

func _build_web_line():
	web_line = MeshInstance3D.new()
	web_line.name = "WebLine"
	web_mesh = BoxMesh.new()
	web_mesh.size = Vector3(0.045, 0.045, 1.0)
	web_line.mesh = web_mesh

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#f7fbff")
	mat.emission_enabled = true
	mat.emission = Color("#dcecff")
	mat.emission_energy_multiplier = 1.25
	web_line.material_override = mat
	web_line.visible = false
	get_parent().add_child(web_line)

func _handle_movement(delta, wish_dir):
	var speed = RUN_SPEED * speed_mult
	if is_on_floor():
		air_jumps_remaining = 1
		double_jump_pose_time = 0.0

	var desired = wish_dir * speed
	var accel = AIR_ACCEL * air_mult
	if is_on_floor():
		accel = GROUND_ACCEL * accel_mult

	if wall_riding:
		desired -= wall_ride_normal * desired.dot(wall_ride_normal)

	if not grappling and not wall_riding:
		velocity.x = move_toward(velocity.x, desired.x, accel * delta)
		velocity.z = move_toward(velocity.z, desired.z, accel * delta)
	elif wall_riding:
		var along_wall = Vector3(velocity.x, 0.0, velocity.z)
		along_wall -= wall_ride_normal * along_wall.dot(wall_ride_normal)
		if desired.length() > 0.05:
			along_wall = along_wall.move_toward(desired, WALL_RIDE_ACCEL * air_mult * delta)
		velocity.x = along_wall.x - wall_ride_normal.x * WALL_RIDE_STICK_FORCE
		velocity.z = along_wall.z - wall_ride_normal.z * WALL_RIDE_STICK_FORCE
	else:
		velocity.x = move_toward(velocity.x, velocity.x + desired.x * 0.10, AIR_ACCEL * air_mult * 0.22 * delta)
		velocity.z = move_toward(velocity.z, velocity.z + desired.z * 0.10, AIR_ACCEL * air_mult * 0.22 * delta)

	var facing_direction = wish_dir
	if wall_riding:
		var wall_tangent = Vector3(velocity.x, 0.0, velocity.z)
		wall_tangent -= wall_ride_normal * wall_tangent.dot(wall_ride_normal)
		if wall_tangent.length() > 0.1:
			facing_direction = wall_tangent.normalized()
	if (
		facing_direction.length() > 0.05
		and not brc_traversal_root_override_active
	):
		var target_yaw = atan2(-facing_direction.x, -facing_direction.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, min(1.0, 13.0 * delta))

	if wall_riding:
		velocity.y = max(velocity.y - WALL_RIDE_GRAVITY * delta, -WALL_RIDE_MAX_FALL_SPEED)
	elif not is_on_floor():
		velocity.y = max(velocity.y - GRAVITY_FORCE * delta, -MAX_FALL_SPEED)

	if Input.is_action_just_pressed("jump"):
		if grappling:
			grappling = false
			movement_state = MovementState.AIR
			# Releasing keeps the velocity earned from the rope simulation.
			# The visual extension, not a synthetic launch impulse, sells a good release.
			swing_release_pose_time = 0.34 if velocity.length() > 20.0 else 0.20
			camera_kick = 0.8
		elif wall_riding:
			velocity = wall_ride_normal * WALL_JUMP_OUT + desired * 0.35
			velocity.y = WALL_JUMP_UP
			wall_riding = false
			wall_jump_pose_time = 0.30
			wall_normal_memory = Vector3.ZERO
		elif is_on_floor():
			velocity.y = JUMP_SPEED * lerp(0.96, 1.05, air_mult - 0.82)
		elif wall_normal_memory.length() > 0.1:
			# Animation metadata only: preserve the wall side before the coyote
			# normal is cleared so the real BRC rig can mirror its push-off pose.
			wall_ride_normal = wall_normal_memory
			velocity.x = wall_normal_memory.x * WALL_JUMP_OUT + desired.x * 0.35
			velocity.z = wall_normal_memory.z * WALL_JUMP_OUT + desired.z * 0.35
			velocity.y = WALL_JUMP_UP
			wall_jump_pose_time = 0.30
			wall_normal_memory = Vector3.ZERO
		elif zip_pose_time <= 0.0 and air_jumps_remaining > 0:
			# One clean air jump per ground contact. Preserve all horizontal
			# momentum; only the vertical component gets the Rivals-like upward pop.
			air_jumps_remaining -= 1
			velocity.y = maxf(
				velocity.y,
				DOUBLE_JUMP_SPEED * lerp(0.96, 1.05, air_mult - 0.82)
			)
			double_jump_pose_time = DOUBLE_JUMP_POSE_DURATION
			double_jump_sequence += 1
			camera_kick = maxf(camera_kick, 0.32)

func _handle_grapple_input():
	if Input.is_action_just_pressed("grapple"):
		_start_grapple(false)
	if Input.is_action_just_released("grapple"):
		grappling = false
	if Input.is_action_just_pressed("zip"):
		_start_grapple(true)

func _start_grapple(zip_mode):
	if camera == null:
		return

	var ray_from = camera.global_position
	var ray_to = ray_from + (-camera.global_transform.basis.z) * GRAPPLE_RANGE
	var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collision_mask = 1
	query.exclude = [get_rid()]

	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	grapple_point = hit["position"]

	if zip_mode:
		var zip_dir = (grapple_point - global_position).normalized()
		velocity = velocity.lerp(zip_dir * ZIP_SPEED * zip_mult, 0.86)
		velocity.y += ZIP_UPWARD
		grappling = false
		zip_pose_time = 0.34
		camera_kick = 0.65
		return

	var distance = global_position.distance_to(grapple_point)
	rope_length = clamp(distance * 0.94, MIN_ROPE_LENGTH, MAX_ROPE_LENGTH)
	grappling = true
	swing_pose_time = 0.0

	var launch_dir = (grapple_point - global_position).normalized()
	velocity += launch_dir * 5.5
	camera_kick = 0.45

func _apply_swing_physics(delta, wish_dir):
	var anchor_origin = global_position + Vector3(0.0, 0.72, 0.0)
	var to_anchor = grapple_point - anchor_origin
	var distance = to_anchor.length()
	if distance < 0.05:
		grappling = false
		return

	var inward = to_anchor / distance

	if Input.is_action_pressed("move_forward"):
		rope_length = max(MIN_ROPE_LENGTH, rope_length - REEL_IN_SPEED * delta)
	elif Input.is_action_pressed("move_back"):
		rope_length = min(MAX_ROPE_LENGTH, rope_length + REEL_OUT_SPEED * delta)

	# Spring-like rope only pulls, never pushes.
	if distance > rope_length:
		var stretch = distance - rope_length
		velocity += inward * stretch * ROPE_STIFFNESS * delta

		# Remove only OUTWARD radial velocity. This preserves natural tangential momentum.
		var radial_speed = velocity.dot(inward)
		if radial_speed < 0.0:
			velocity -= inward * radial_speed * 0.96

	# Player input is projected onto the swing plane so anchor choice really matters.
	if wish_dir.length() > 0.05:
		var tangential_input = wish_dir - inward * wish_dir.dot(inward)
		if tangential_input.length() > 0.01:
			velocity += tangential_input.normalized() * SWING_INPUT_ACCEL * swing_mult * delta

	if Input.is_action_pressed("move_forward"):
		var tangent = velocity - inward * velocity.dot(inward)
		var useful_arc = clamp(-velocity.y / 18.0, 0.0, 1.0)
		if tangent.length() > 0.2 and useful_arc > 0.05:
			velocity += tangent.normalized() * SWING_TANGENT_BOOST * swing_mult * useful_arc * delta

	var max_speed = 44.0
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

func _swing_tangent_direction():
	if not grappling:
		return Vector3.ZERO
	var inward = (grapple_point - global_position).normalized()
	var tangent = velocity - inward * velocity.dot(inward)
	if tangent.length() > 0.1:
		return tangent.normalized()
	return Vector3.ZERO

func _handle_attack_input():
	if Input.is_action_just_pressed("attack") and attack_cooldown <= 0.0:
		combo_step = combo_step + 1 if combo_window > 0.0 else 1
		combo_step = min(combo_step, 3)
		combo_window = 0.62
		attack_cooldown = 0.25 if combo_step < 3 else 0.42
		attack_pose_duration = attack_cooldown
		attack_pose_time = attack_pose_duration
		special_pose = ""
		var damage = max(1, int(ceil(combat_mult)))
		if combo_step == 3 and combat_mult >= 1.0:
			damage += 1
		_strike_nearest(ATTACK_RANGE, damage, 2.0 + combo_step)
	if Input.is_action_just_pressed("special_attack") and special_cooldown <= 0.0:
		_use_character_special()

func _strike_nearest(hit_range, damage, impulse):
	var best = null
	var best_distance = hit_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	if best != null and best.has_method("hit"):
		var hit_dir = best.global_position - global_position
		best.hit(damage, hit_dir)
		velocity += hit_dir.normalized() * impulse
		camera_kick = 0.7

func _use_character_special():
	special_cooldown = 1.8
	var id = String(character_data.get("id", "crimson"))
	special_pose = id
	attack_pose_duration = 0.46
	attack_pose_time = attack_pose_duration
	match id:
		"crimson":
			var forward = -camera_pivot.global_transform.basis.z
			velocity += forward.normalized() * 9.0 + Vector3.UP * 2.0
			_strike_nearest(4.2, 1, 5.0)
		"azure":
			_start_grapple(true)
			special_cooldown = 1.15
		"violet":
			velocity.y = max(velocity.y, 11.0)
			var forward = -camera_pivot.global_transform.basis.z
			velocity += Vector3(forward.x, 0.0, forward.z).normalized() * 7.0
		"gold":
			_strike_nearest(5.2, 3, 8.0)
			velocity.y = max(velocity.y, 3.5)
			special_cooldown = 2.4
	camera_kick = 1.0

func _update_wall_ride(delta):
	if is_on_floor() or grappling:
		wall_riding = false
		wall_ride_time = 0.0
		return

	var horizontal_velocity = Vector3(velocity.x, 0.0, velocity.z)
	if wall_contact_grace > 0.0 and wall_normal_memory.length() > 0.1 and horizontal_velocity.length() >= WALL_RIDE_MIN_SPEED:
		var approach_speed = -horizontal_velocity.normalized().dot(wall_normal_memory)
		var tangent_speed = (horizontal_velocity - wall_normal_memory * horizontal_velocity.dot(wall_normal_memory)).length()
		# move_and_slide has usually removed most inward velocity by this point,
		# so wall contact + tangential speed is the reliable entry signal.
		if wall_riding or (approach_speed > -0.08 and approach_speed < 0.96 and tangent_speed >= WALL_RIDE_MIN_TANGENT_SPEED):
			wall_riding = true
			wall_ride_normal = wall_normal_memory
			wall_ride_time += delta
			var tangent = horizontal_velocity - wall_ride_normal * horizontal_velocity.dot(wall_ride_normal)
			tangent = tangent.move_toward(Vector3.ZERO, WALL_RIDE_SPEED_BLEED * delta)
			velocity.x = tangent.x - wall_ride_normal.x * WALL_RIDE_STICK_FORCE
			velocity.z = tangent.z - wall_ride_normal.z * WALL_RIDE_STICK_FORCE
			return

	wall_riding = false
	wall_ride_time = 0.0

func take_damage(amount, source_position):
	if invuln_time > 0.0:
		return
	invuln_time = 0.75
	health = max(0, health - int(round(float(amount) / defense_mult)))
	health_changed.emit(health)
	var knock = global_position - source_position
	knock.y = 0.0
	if knock.length() > 0.1:
		velocity += knock.normalized() * 9.0 + Vector3.UP * 5.5
	camera_kick = 1.4
	if health <= 0:
		player_died.emit()
		_respawn(false)

func heal_full():
	health = 100
	health_changed.emit(health)

func _remember_wall_normal(delta):
	if is_on_floor():
		wall_normal_memory = Vector3.ZERO
		wall_contact_grace = 0.0
		return
	var found_wall = false
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision == null:
			continue
		var normal = collision.get_normal()
		if abs(normal.y) < 0.45:
			wall_normal_memory = normal
			wall_contact_grace = WALL_CONTACT_GRACE
			found_wall = true
			break
	if not found_wall:
		wall_contact_grace = max(0.0, wall_contact_grace - delta)
		if wall_contact_grace <= 0.0:
			wall_normal_memory = Vector3.ZERO

func _update_movement_state():
	if zip_pose_time > 0.0:
		movement_state = MovementState.ZIP
	elif grappling:
		movement_state = MovementState.SWING
	elif wall_riding:
		movement_state = MovementState.WALL_RIDE
	elif is_on_floor():
		movement_state = MovementState.GROUND
	else:
		movement_state = MovementState.AIR

func get_movement_state_name():
	return ["GROUND", "AIR", "SWING", "WALL RIDE", "ZIP"][movement_state]

func _update_camera_feedback(delta):
	if camera == null:
		return
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var speed_fov = clamp((horizontal_speed - 18.0) / 24.0, 0.0, 1.0) * 7.0
	camera.fov = lerp(camera.fov, BASE_CAMERA_FOV + speed_fov, min(1.0, 3.5 * delta))

func _update_web_visual():
	if web_line == null:
		return
	if not grappling:
		web_line.visible = false
		return

	var start = global_position + Vector3(0.36, 0.75, -0.05)
	var delta_vec = grapple_point - start
	var length = delta_vec.length()
	if length < 0.05:
		web_line.visible = false
		return

	web_line.visible = true
	web_line.global_position = start + delta_vec * 0.5
	web_mesh.size = Vector3(0.045, 0.045, length)
	web_line.look_at(grapple_point, Vector3.UP)

func _animate_character(delta):
	if visual_root == null:
		return

	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var moving = horizontal_speed > 0.7 and is_on_floor()
	var root_pose = Vector3.ZERO
	var torso_pose = Vector3.ZERO
	var arm_l = Vector3.ZERO
	var arm_r = Vector3.ZERO
	var leg_l = Vector3.ZERO
	var leg_r = Vector3.ZERO
	var pose_speed = 10.0
	var body_bob = 0.0

	if attack_pose_time > 0.0:
		var progress = 1.0 - attack_pose_time / max(attack_pose_duration, 0.01)
		var strike = sin(progress * PI)
		pose_speed = 18.0
		if special_pose == "crimson":
			arm_l = Vector3(-1.35, 0.0, -0.28)
			arm_r = Vector3(-1.35, 0.0, 0.28)
			torso_pose = Vector3(-0.24, 0.0, 0.0)
		elif special_pose == "azure":
			arm_l = Vector3(-1.65, 0.0, -0.12)
			arm_r = Vector3(-1.65, 0.0, 0.12)
			leg_l.x = 0.48
			leg_r.x = 0.28
			root_pose.x = -0.38
		elif special_pose == "violet":
			root_pose.z = progress * TAU
			arm_l.z = -1.05
			arm_r.z = 1.05
			leg_l.x = 0.55
			leg_r.x = -0.55
		elif special_pose == "gold":
			arm_l = Vector3(-1.55, 0.0, -0.32)
			arm_r = Vector3(-1.55, 0.0, 0.32)
			torso_pose.x = 0.45 * strike
			leg_l.x = 0.35
			leg_r.x = 0.35
		elif combo_step == 1:
			arm_r.x = -1.65 * strike
			torso_pose.y = -0.45 * strike
			arm_l.x = 0.35
		elif combo_step == 2:
			arm_l.x = -1.45 * strike
			arm_l.z = -0.35 * strike
			torso_pose.y = 0.58 * strike
			arm_r.x = 0.25
		else:
			arm_r.x = -1.85 * strike
			arm_r.z = 0.34
			torso_pose = Vector3(-0.22, -0.72 * strike, 0.0)
			leg_l.x = 0.30
	elif grappling:
		var rope_direction = (grapple_point - global_position).normalized()
		var local_rope = visual_root.global_transform.basis.inverse() * rope_direction
		var fast = clamp(velocity.length() / 38.0, 0.0, 1.0)
		var descending = clamp(-velocity.y / 18.0, 0.0, 1.0)
		var bottom_arc = 1.0 - clamp(abs(velocity.y) / 10.0, 0.0, 1.0)
		var anchor_lean = clamp(local_rope.x * 0.42, -0.42, 0.42)
		root_pose = Vector3(clamp(-local_rope.y * 0.32 - fast * 0.18, -0.62, 0.25), 0.0, -anchor_lean)
		torso_pose.z = -anchor_lean * 0.55
		if swing_pose_time < 0.18:
			arm_l = Vector3(-1.55, 0.0, -0.18 - anchor_lean)
			arm_r = Vector3(-1.30, 0.0, 0.22 - anchor_lean)
			leg_l.x = 0.30
			leg_r.x = -0.18
		elif descending > 0.30 or bottom_arc > 0.62:
			arm_l = Vector3(-1.72, 0.0, -0.16 - anchor_lean)
			arm_r = Vector3(-1.72, 0.0, 0.16 - anchor_lean)
			leg_l.x = lerp(-0.40, 0.58, bottom_arc)
			leg_r.x = lerp(-0.58, 0.42, bottom_arc)
			torso_pose.x = lerp(-0.12, 0.30, bottom_arc)
		else:
			var use_left = local_rope.x < 0.0
			arm_l.x = -1.68 if use_left else -0.48
			arm_r.x = -0.48 if use_left else -1.68
			arm_l.z = -0.20 - anchor_lean
			arm_r.z = 0.20 - anchor_lean
			leg_l.x = -0.46 * fast
			leg_r.x = -0.68 * fast
		pose_speed = 12.0
	elif movement_state == MovementState.ZIP:
		var zip_local = visual_root.global_transform.basis.inverse() * velocity.normalized()
		root_pose.x = clamp(-zip_local.y * 0.65 - 0.30, -0.82, 0.40)
		arm_l = Vector3(-1.62, 0.0, -0.16)
		arm_r = Vector3(-1.62, 0.0, 0.16)
		leg_l.x = 0.62
		leg_r.x = 0.42
		pose_speed = 14.0
	elif wall_riding:
		run_time += delta * clamp(horizontal_speed, 8.0, 15.0)
		var wall_stride = sin(run_time) * 0.72
		var ride_side = sign(wall_ride_normal.dot(visual_root.global_transform.basis.x))
		# The wall-side hand and planted shoe support the pose. Lean the upper
		# body modestly away from the facade, as in a billboard wall run, rather
		# than rotating the whole model into the wall like a climbing pose.
		root_pose.x = -0.20
		root_pose.z = -ride_side * 0.18
		torso_pose = Vector3(-0.15, 0.0, ride_side * 0.32)
		arm_l = Vector3(-wall_stride * 0.72, 0.0, -0.22)
		arm_r = Vector3(wall_stride * 0.72, 0.0, 0.22)
		leg_l.x = wall_stride
		leg_r.x = -wall_stride
		body_bob = (1.0 - absf(wall_stride / 0.72)) * 0.045 - 0.015
		pose_speed = 14.0
	elif wall_jump_pose_time > 0.0:
		root_pose.x = -0.24
		arm_l = Vector3(-0.82, 0.0, -0.48)
		arm_r = Vector3(-0.82, 0.0, 0.48)
		leg_l.x = 0.72
		leg_r.x = 0.72
		pose_speed = 15.0
	elif swing_release_pose_time > 0.0:
		root_pose.x = -0.32
		arm_l.x = -1.20
		arm_r.x = -1.20
		leg_l.x = -0.62
		leg_r.x = -0.48
		torso_pose.x = -0.20
		pose_speed = 12.0
	elif moving:
		run_time += delta * clamp(horizontal_speed * 0.78, 6.0, 15.0)
		var stride = sin(run_time) * clamp(horizontal_speed / RUN_SPEED, 0.55, 1.0)
		arm_l.x = stride * 0.95
		arm_r.x = -stride * 0.95
		leg_l.x = -stride * 0.88
		leg_r.x = stride * 0.88
		torso_pose.x = -0.13 - horizontal_speed * 0.004
		torso_pose.y = sin(run_time) * 0.045
		body_bob = abs(sin(run_time)) * 0.055
	elif not is_on_floor():
		if velocity.y > 3.5:
			root_pose.x = -0.14
			arm_l.x = -0.62
			arm_r.x = -0.62
			leg_l.x = -0.48
			leg_r.x = -0.48
		else:
			arm_l = Vector3(-0.32, 0.0, -0.48)
			arm_r = Vector3(-0.32, 0.0, 0.48)
			leg_l = Vector3(0.24, 0.0, -0.18)
			leg_r = Vector3(-0.18, 0.0, 0.18)

	_blend_procedural_pose(delta, pose_speed, root_pose, torso_pose, arm_l, arm_r, leg_l, leg_r, body_bob)

func _blend_procedural_pose(delta, blend_speed, root_pose, torso_pose, arm_l, arm_r, leg_l, leg_r, body_bob):
	var amount = min(1.0, blend_speed * delta)
	var wall_offset = Vector3.ZERO
	if wall_riding:
		wall_offset = wall_ride_normal * wall_visual_offset
	var target_root_pitch = (
		brc_traversal_root_pitch
		if brc_traversal_root_override_active
		else root_pose.x
	)
	visual_root.rotation.x = lerp_angle(
		visual_root.rotation.x,
		target_root_pitch,
		amount
	)
	visual_root.rotation.z = lerp_angle(visual_root.rotation.z, root_pose.z, amount)
	if brc_traversal_root_override_active:
		visual_root.rotation.y = lerp_angle(
			visual_root.rotation.y,
			brc_traversal_root_yaw,
			amount
		)
	visual_root.position.x = lerp(visual_root.position.x, wall_offset.x, amount)
	visual_root.position.y = lerp(visual_root.position.y, body_bob, amount)
	visual_root.position.z = lerp(visual_root.position.z, wall_offset.z, amount)

	# The imported BRC mesh is driven by its real Skeleton3D controller. These
	# compatibility proxies are intentionally inert in that path; retaining
	# the visible root transform above preserves lean, wall clearance, bob and
	# Violet's presentation spin without a second limb-animation owner.
	if visual_root.get_node_or_null("SpideyRigController") != null:
		return

	torso_root.rotation = torso_root.rotation.lerp(torso_pose, amount)
	left_arm.rotation = left_arm.rotation.lerp(arm_l, amount)
	right_arm.rotation = right_arm.rotation.lerp(arm_r, amount)
	left_leg.rotation = left_leg.rotation.lerp(leg_l, amount)
	right_leg.rotation = right_leg.rotation.lerp(leg_r, amount)

func _respawn(fall_damage):
	grappling = false
	wall_riding = false
	global_position = spawn_position
	velocity = Vector3.ZERO
	air_jumps_remaining = 1
	double_jump_pose_time = 0.0
	if fall_damage:
		health = max(35, health - 20)
	else:
		health = 100
	health_changed.emit(health)
