extends CharacterBody3D

const ROSTER = preload("res://character_roster.gd")

signal health_changed(value)
signal player_died()

const WALK_SPEED = 10.0
const SPRINT_SPEED = 17.0
const GROUND_ACCEL = 50.0
const AIR_ACCEL = 19.0
const JUMP_SPEED = 12.0
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

var active = false
var character_index = 0
var character_data = {}
var speed_mult = 1.0
var accel_mult = 1.0
var air_mult = 1.0
var swing_mult = 1.0
var zip_mult = 1.0
var defense_mult = 1.0
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
    camera_kick = move_toward(camera_kick, 0.0, 5.0 * delta)

    camera_pivot.rotation = Vector3(pitch - camera_kick * 0.02, yaw, 0.0)

    var wish_dir = _get_camera_relative_input()

    _handle_grapple_input()
    _handle_attack_input()
    _handle_movement(delta, wish_dir)

    if grappling:
        _apply_swing_physics(delta, wish_dir)

    move_and_slide()

    _remember_wall_normal()
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
    capsule.radius = 0.46
    capsule.height = 2.85
    collision.shape = capsule
    add_child(collision)

func _build_detailed_character():
    visual_root = Node3D.new()
    visual_root.name = "DetailedWebHero"
    add_child(visual_root)

    var red = _material(Color(character_data["primary"]), 0.70)
    var red_dark = _material(Color(character_data["primary_dark"]), 0.78)
    var blue = _material(Color(character_data["secondary"]), 0.75)
    var blue_light = _material(Color(character_data["secondary_light"]), 0.68)
    var black = _material(Color("#08090d"), 0.86)
    var white = _material(Color(character_data["accent"]), 0.35)
    var sole = _material(Color("#d8d5ca"), 0.82)

    torso_root = Node3D.new()
    torso_root.name = "Torso"
    torso_root.position = Vector3(0.0, 0.30, 0.0)
    visual_root.add_child(torso_root)

    # Rounded high-poly torso and abdomen.
    _sphere_part(torso_root, Vector3(0, 0.22, 0), Vector3(0.62, 0.56, 0.34), red, 20, 10)
    _sphere_part(torso_root, Vector3(0, -0.20, 0.02), Vector3(0.48, 0.32, 0.29), red_dark, 18, 9)
    _sphere_part(torso_root, Vector3(0, -0.48, 0.02), Vector3(0.44, 0.25, 0.27), blue, 18, 9)

    # Blue side panels and clavicle details.
    _sphere_part(torso_root, Vector3(-0.45, 0.15, 0.03), Vector3(0.14, 0.40, 0.29), blue, 14, 7)
    _sphere_part(torso_root, Vector3(0.45, 0.15, 0.03), Vector3(0.14, 0.40, 0.29), blue, 14, 7)
    _cylinder_part(torso_root, Vector3(-0.23, 0.43, -0.29), 0.025, 0.32, Vector3(0,0,0.95), black, 10)
    _cylinder_part(torso_root, Vector3(0.23, 0.43, -0.29), 0.025, 0.32, Vector3(0,0,-0.95), black, 10)

    # Neck.
    _cylinder_part(visual_root, Vector3(0, 0.91, 0), 0.20, 0.24, Vector3.ZERO, red, 16)

    # More rounded head with enough segments to read as a character instead of a blockout.
    var head = _sphere_part(visual_root, Vector3(0, 1.23, 0), Vector3(0.43, 0.50, 0.40), red, 24, 12)
    head.name = "Head"

    # Large lenses with layered black frame + white inset.
    _lens(visual_root, -1.0, black, white)
    _lens(visual_root, 1.0, black, white)

    # Mask webbing: center + horizontal arcs approximated with thin pieces.
    _box_part(visual_root, Vector3(0.0, 1.24, -0.399), Vector3(0.022, 0.70, 0.018), black)
    for y in [1.05, 1.22, 1.39]:
        _box_part_rotated(visual_root, Vector3(-0.19, y, -0.400), Vector3(0.36, 0.020, 0.018), Vector3(0,0,-0.10), black)
        _box_part_rotated(visual_root, Vector3(0.19, y, -0.400), Vector3(0.36, 0.020, 0.018), Vector3(0,0,0.10), black)

    # Chest emblem with body and eight legs.
    _sphere_part(torso_root, Vector3(0.0, 0.12, -0.34), Vector3(0.075, 0.15, 0.025), black, 12, 6)
    _sphere_part(torso_root, Vector3(0.0, -0.05, -0.34), Vector3(0.10, 0.10, 0.025), black, 12, 6)
    for side in [-1.0, 1.0]:
        _box_part_rotated(torso_root, Vector3(0.12 * side, 0.18, -0.35), Vector3(0.28, 0.035, 0.026), Vector3(0,0,0.62 * side), black)
        _box_part_rotated(torso_root, Vector3(0.15 * side, 0.03, -0.35), Vector3(0.32, 0.035, 0.026), Vector3(0,0,0.24 * side), black)
        _box_part_rotated(torso_root, Vector3(0.14 * side, -0.10, -0.35), Vector3(0.30, 0.035, 0.026), Vector3(0,0,-0.30 * side), black)
        _box_part_rotated(torso_root, Vector3(0.11 * side, -0.20, -0.35), Vector3(0.26, 0.035, 0.026), Vector3(0,0,-0.72 * side), black)

    left_arm = _make_detailed_arm(-1.0, red, red_dark, blue, black)
    right_arm = _make_detailed_arm(1.0, red, red_dark, blue, black)
    left_leg = _make_detailed_leg(-1.0, blue, blue_light, red, red_dark, white, sole, black)
    right_leg = _make_detailed_leg(1.0, blue, blue_light, red, red_dark, white, sole, black)

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
    camera.fov = 82.0
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
    var speed = WALK_SPEED * speed_mult
    if Input.is_action_pressed("sprint"):
        speed = SPRINT_SPEED * speed_mult

    var desired = wish_dir * speed
    var accel = AIR_ACCEL * air_mult
    if is_on_floor():
        accel = GROUND_ACCEL * accel_mult

    if not grappling:
        velocity.x = move_toward(velocity.x, desired.x, accel * delta)
        velocity.z = move_toward(velocity.z, desired.z, accel * delta)
    else:
        velocity.x = move_toward(velocity.x, velocity.x + desired.x * 0.10, AIR_ACCEL * air_mult * 0.22 * delta)
        velocity.z = move_toward(velocity.z, velocity.z + desired.z * 0.10, AIR_ACCEL * air_mult * 0.22 * delta)

    if wish_dir.length() > 0.05:
        var target_yaw = atan2(-wish_dir.x, -wish_dir.z)
        visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, min(1.0, 13.0 * delta))

    if not is_on_floor():
        velocity.y = max(velocity.y - GRAVITY_FORCE * delta, -MAX_FALL_SPEED)

    if Input.is_action_just_pressed("jump"):
        if grappling:
            var tangent = _swing_tangent_direction()
            grappling = false
            velocity.y = max(velocity.y, 7.0)
            if tangent.length() > 0.1:
                velocity += tangent * 8.5
            camera_kick = 0.8
        elif is_on_floor():
            velocity.y = JUMP_SPEED * lerp(0.96, 1.05, air_mult - 0.82)
        elif wall_normal_memory.length() > 0.1:
            velocity.x = wall_normal_memory.x * WALL_JUMP_OUT + desired.x * 0.35
            velocity.z = wall_normal_memory.z * WALL_JUMP_OUT + desired.z * 0.35
            velocity.y = WALL_JUMP_UP
            wall_normal_memory = Vector3.ZERO

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
        camera_kick = 0.65
        return

    var distance = global_position.distance_to(grapple_point)
    rope_length = clamp(distance * 0.94, MIN_ROPE_LENGTH, MAX_ROPE_LENGTH)
    grappling = true

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
        if tangent.length() > 0.2:
            velocity += tangent.normalized() * SWING_TANGENT_BOOST * swing_mult * delta

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
        attack_cooldown = 0.34
        var best = null
        var best_distance = ATTACK_RANGE
        for enemy in get_tree().get_nodes_in_group("enemies"):
            if enemy == null or not is_instance_valid(enemy):
                continue
            var distance = global_position.distance_to(enemy.global_position)
            if distance < best_distance:
                best = enemy
                best_distance = distance
        if best != null and best.has_method("hit"):
            var hit_dir = best.global_position - global_position
            best.hit(1, hit_dir)
            velocity += hit_dir.normalized() * 2.0
            camera_kick = 0.7

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

func _remember_wall_normal():
    if is_on_floor():
        wall_normal_memory = Vector3.ZERO
        return
    for i in range(get_slide_collision_count()):
        var collision = get_slide_collision(i)
        if collision == null:
            continue
        var normal = collision.get_normal()
        if abs(normal.y) < 0.45:
            wall_normal_memory = normal
            return

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
    var amount = min(1.0, 10.0 * delta)

    if grappling:
        left_arm.rotation.x = lerp(left_arm.rotation.x, -1.55, amount)
        right_arm.rotation.x = lerp(right_arm.rotation.x, -1.25, amount)
        left_arm.rotation.z = lerp(left_arm.rotation.z, -0.18, amount)
        right_arm.rotation.z = lerp(right_arm.rotation.z, 0.18, amount)
        left_leg.rotation.x = lerp(left_leg.rotation.x, 0.45, amount)
        right_leg.rotation.x = lerp(right_leg.rotation.x, -0.28, amount)
        torso_root.rotation.z = lerp(torso_root.rotation.z, clamp(-velocity.x * 0.012, -0.22, 0.22), amount)
    elif moving:
        run_time += delta * clamp(horizontal_speed * 0.85, 5.5, 13.5)
        var swing = sin(run_time) * 0.80
        left_arm.rotation.x = lerp(left_arm.rotation.x, swing, amount)
        right_arm.rotation.x = lerp(right_arm.rotation.x, -swing, amount)
        left_leg.rotation.x = lerp(left_leg.rotation.x, -swing * 0.78, amount)
        right_leg.rotation.x = lerp(right_leg.rotation.x, swing * 0.78, amount)
        left_arm.rotation.z = lerp(left_arm.rotation.z, 0.0, amount)
        right_arm.rotation.z = lerp(right_arm.rotation.z, 0.0, amount)
        torso_root.rotation.z = lerp(torso_root.rotation.z, 0.0, amount)
    elif not is_on_floor():
        left_arm.rotation.x = lerp(left_arm.rotation.x, -0.65, amount)
        right_arm.rotation.x = lerp(right_arm.rotation.x, -0.35, amount)
        left_leg.rotation.x = lerp(left_leg.rotation.x, 0.20, amount)
        right_leg.rotation.x = lerp(right_leg.rotation.x, -0.24, amount)
        torso_root.rotation.z = lerp(torso_root.rotation.z, 0.0, amount)
    else:
        left_arm.rotation.x = lerp(left_arm.rotation.x, 0.0, amount)
        right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, amount)
        left_leg.rotation.x = lerp(left_leg.rotation.x, 0.0, amount)
        right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, amount)
        left_arm.rotation.z = lerp(left_arm.rotation.z, 0.0, amount)
        right_arm.rotation.z = lerp(right_arm.rotation.z, 0.0, amount)
        torso_root.rotation.z = lerp(torso_root.rotation.z, 0.0, amount)

func _respawn(fall_damage):
    grappling = false
    global_position = spawn_position
    velocity = Vector3.ZERO
    if fall_damage:
        health = max(35, health - 20)
    else:
        health = 100
    health_changed.emit(health)
