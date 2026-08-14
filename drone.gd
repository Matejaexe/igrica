extends CharacterBody3D

signal defeated(drone)

var target = null
var health = 2
var attack_cooldown = 0.0
var bob_time = 0.0
var base_height = 0.0

const SPEED = 6.0
const ACCEL = 12.0

func _ready():
    collision_layer = 2
    collision_mask = 1
    base_height = global_position.y
    add_to_group("enemies")
    _build_drone()

func set_target(player):
    target = player

func _physics_process(delta):
    attack_cooldown = max(0.0, attack_cooldown - delta)
    bob_time += delta

    if target == null or not is_instance_valid(target):
        velocity = velocity.move_toward(Vector3.ZERO, ACCEL * delta)
        move_and_slide()
        return

    var delta_to_target = target.global_position - global_position
    var flat = Vector3(delta_to_target.x, 0.0, delta_to_target.z)
    var distance = flat.length()

    var desired = Vector3.ZERO
    if distance > 2.8:
        desired = flat.normalized() * SPEED

    velocity.x = move_toward(velocity.x, desired.x, ACCEL * delta)
    velocity.z = move_toward(velocity.z, desired.z, ACCEL * delta)

    var desired_y = target.global_position.y + 1.8 + sin(bob_time * 2.2) * 0.7
    velocity.y = clamp((desired_y - global_position.y) * 2.0, -4.0, 4.0)

    if flat.length() > 0.2:
        look_at(global_position + flat, Vector3.UP)

    move_and_slide()

    if global_position.distance_to(target.global_position) < 2.1 and attack_cooldown <= 0.0:
        attack_cooldown = 1.0
        if target.has_method("take_damage"):
            target.take_damage(15, global_position)

func hit(amount, hit_direction):
    health -= amount
    velocity += hit_direction.normalized() * 9.0 + Vector3.UP * 4.0
    _flash()
    if health <= 0:
        defeated.emit(self)
        queue_free()

func _build_drone():
    var collision = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 0.75
    collision.shape = shape
    add_child(collision)

    var dark = _material(Color("#1c2334"), false)
    var metal = _material(Color("#4f6179"), false)
    var red = _material(Color("#ff3e55"), true)

    var body = MeshInstance3D.new()
    body.name = "Body"
    var sphere = SphereMesh.new()
    sphere.radius = 0.7
    sphere.height = 1.0
    sphere.radial_segments = 12
    sphere.rings = 6
    body.mesh = sphere
    body.scale = Vector3(1.25, 0.62, 1.0)
    body.material_override = dark
    add_child(body)

    for side in [-1.0, 1.0]:
        var arm = MeshInstance3D.new()
        var arm_mesh = BoxMesh.new()
        arm_mesh.size = Vector3(0.9, 0.12, 0.18)
        arm.mesh = arm_mesh
        arm.position = Vector3(0.75 * side, 0.0, 0.0)
        arm.material_override = metal
        add_child(arm)

        var rotor = MeshInstance3D.new()
        var rotor_mesh = CylinderMesh.new()
        rotor_mesh.top_radius = 0.45
        rotor_mesh.bottom_radius = 0.45
        rotor_mesh.height = 0.06
        rotor_mesh.radial_segments = 12
        rotor.mesh = rotor_mesh
        rotor.position = Vector3(1.12 * side, 0.0, 0.0)
        rotor.material_override = metal
        add_child(rotor)

    var eye = MeshInstance3D.new()
    eye.name = "Eye"
    var eye_mesh = SphereMesh.new()
    eye_mesh.radius = 0.2
    eye_mesh.height = 0.28
    eye_mesh.radial_segments = 12
    eye_mesh.rings = 5
    eye.mesh = eye_mesh
    eye.position = Vector3(0.0, 0.0, -0.62)
    eye.scale = Vector3(1.3, 0.8, 0.45)
    eye.material_override = red
    add_child(eye)

func _flash():
    var eye = get_node_or_null("Eye")
    if eye != null:
        eye.scale *= 1.35

func _material(color, glow):
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.45
    mat.metallic = 0.2
    if glow:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 2.8
    return mat
