extends CharacterBody3D

signal defeated(drone)

var target = null
var windup = 0.0
var stagger = 0.0
var defeated_once = false
var health_label: Label3D
var eye_material: StandardMaterial3D
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
    attack_cooldown = maxf(0,attack_cooldown-delta)
    stagger = maxf(0,stagger-delta)
    bob_time += delta
    if defeated_once or not is_instance_valid(target) or not target.active:
        return
    var offset = target.global_position-global_position
    var flat = Vector3(offset.x,0,offset.z)
    var distance = offset.length()
    var desired = flat.normalized()*SPEED if flat.length() > 2.0 else Vector3.ZERO
    if stagger > 0:
        windup = 0
        velocity = velocity.move_toward(Vector3.ZERO,delta*8)
    elif windup > 0:
        velocity = velocity.move_toward(Vector3.ZERO,delta*30)
        windup = maxf(0,windup-delta)
        if windup == 0:
            attack_cooldown = 1.3
            if distance < 3.2 and _clear_to_target():
                target.take_damage(15,global_position)
    else:
        velocity.x = move_toward(velocity.x,desired.x,ACCEL*delta)
        velocity.z = move_toward(velocity.z,desired.z,ACCEL*delta)
        var desired_y = target.global_position.y+.65+sin(bob_time*2.2)*.2
        velocity.y = clampf((desired_y-global_position.y)*2,-4,4)
        if distance < 3.0 and attack_cooldown <= 0 and _clear_to_target():
            windup = .65
    if flat.length() > .2: look_at(global_position+flat,Vector3.UP)
    move_and_slide()
    eye_material.albedo_color = Color("ffd85a") if windup > 0 else Color("ff3e55")
    eye_material.emission = eye_material.albedo_color
    var eye = get_node("Eye")
    eye.scale = Vector3(1.3,.8,.45)*(1.0+(.4+sin(bob_time*30)*.15 if windup > 0 else 0))
    health_label.text = "! EVADE !" if windup > 0 else ("STUN" if stagger > 0 else "■".repeat(maxi(0,health)))
    health_label.modulate = Color("ffe16b") if windup > 0 else Color("d7edf2")

func _clear_to_target() -> bool:
    if not is_instance_valid(target): return false
    var ray = PhysicsRayQueryParameters3D.create(global_position,target.global_position,1,[get_rid(),target.get_rid()])
    return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func hit(amount, hit_direction):
    if defeated_once: return
    health -= amount
    stagger = .35
    windup = 0
    velocity += hit_direction.normalized()*9+Vector3.UP*2
    if health <= 0:
        defeated_once = true
        remove_from_group("enemies")
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
    eye_material = red

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
    health_label = Label3D.new()
    health_label.position.y = 1.3
    health_label.font_size = 32
    health_label.pixel_size = .013
    health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    health_label.no_depth_test = false
    add_child(health_label)

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
