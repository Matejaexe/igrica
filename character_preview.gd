extends Node3D

const ROSTER = preload("res://character_roster.gd")
const SPIDEY_IMPORTED = preload("res://spidey_imported_model.gd")
const HERO_MODEL = preload("res://hero_model.gd")

var character_index = 0
var model_root = null
var rotation_speed = 0.48
var idle_time = 0.0
var left_arm = null
var right_arm = null

func _ready():
    rebuild(0)

func _process(delta):
    idle_time += delta
    rotation.y += rotation_speed * delta
    if model_root != null:
        model_root.position.y = sin(idle_time * 1.7) * 0.035
    if left_arm != null and right_arm != null:
        left_arm.rotation.z = sin(idle_time * 1.4) * 0.035
        right_arm.rotation.z = -sin(idle_time * 1.4) * 0.035

func rebuild(index):
    character_index = posmod(index, ROSTER.count())
    if model_root != null and is_instance_valid(model_root):
        model_root.queue_free()
    model_root = Node3D.new()
    model_root.name = "PreviewCharacter"
    add_child(model_root)
    _build_character(ROSTER.get_character(character_index))

func rotate_manual(amount):
    rotation.y += amount

func _build_character(data):
    var refs: Dictionary = SPIDEY_IMPORTED.build(model_root, data)
    left_arm = refs["left_arm"]
    right_arm = refs["right_arm"]

func _arm(side, primary, primary_dark, secondary, black):
    var pivot = Node3D.new()
    pivot.position = Vector3(0.58 * side, 0.50, 0.0)
    model_root.add_child(pivot)
    _sphere(pivot, Vector3(0.03 * side, 0.0, 0.0), Vector3(0.23, 0.25, 0.22), primary, 18, 9)
    _cylinder(pivot, Vector3(0.08 * side, -0.31, 0.0), 0.18, 0.54, Vector3(0,0,-0.10 * side), primary, 18)
    _sphere(pivot, Vector3(0.11 * side, -0.58, 0.0), Vector3(0.18,0.18,0.18), primary_dark, 16, 8)
    _cylinder(pivot, Vector3(0.14 * side, -0.80, -0.01), 0.16, 0.42, Vector3(0,0,0.07 * side), primary_dark, 18)
    _sphere(pivot, Vector3(0.17 * side, -1.06, -0.02), Vector3(0.22,0.20,0.23), primary, 18, 9)
    _sphere(pivot, Vector3(-0.10 * side, -0.22, 0.02), Vector3(0.08,0.23,0.19), secondary, 14, 7)
    _box_rot(pivot, Vector3(0.14 * side, -0.71, -0.16), Vector3(0.22,0.020,0.018), Vector3(0,0,0.12 * side), black)
    return pivot

func _leg(side, secondary, secondary_light, primary, primary_dark, white, sole, black):
    var pivot = Node3D.new()
    pivot.position = Vector3(0.23 * side, -0.43, 0.0)
    model_root.add_child(pivot)
    _sphere(pivot, Vector3(0.0, -0.08, 0), Vector3(0.24,0.27,0.24), secondary, 18, 9)
    _cylinder(pivot, Vector3(0.02 * side, -0.39, 0), 0.22, 0.58, Vector3(0,0,0.04 * side), secondary, 18)
    _sphere(pivot, Vector3(0.02 * side, -0.68, 0), Vector3(0.21,0.19,0.21), secondary_light, 16, 8)
    _cylinder(pivot, Vector3(0.01 * side, -0.91, -0.01), 0.18, 0.42, Vector3.ZERO, secondary_light, 18)
    _cylinder(pivot, Vector3(0.01 * side, -1.14, -0.02), 0.185, 0.30, Vector3.ZERO, primary_dark, 18)
    var shoe = Node3D.new()
    shoe.position = Vector3(0.0, -1.36, -0.15)
    pivot.add_child(shoe)
    _sphere(shoe, Vector3(0,0,-0.11), Vector3(0.29,0.19,0.44), primary, 20, 10)
    _sphere(shoe, Vector3(0,-0.13,-0.11), Vector3(0.31,0.08,0.46), sole, 18, 8)
    _sphere(shoe, Vector3(0,0.03,-0.39), Vector3(0.27,0.15,0.20), white, 18, 8)
    _box(shoe, Vector3(0,0.13,-0.10), Vector3(0.28,0.026,0.036), white)
    _box(shoe, Vector3(0,0.13,-0.20), Vector3(0.28,0.026,0.036), white)
    _sphere(shoe, Vector3(0,0.02,0.27), Vector3(0.22,0.12,0.08), black, 14, 7)

func _lens(parent, side, black, white):
    var x = 0.17 * side
    var rot = -0.22 * side
    var frame = _sphere(parent, Vector3(x, 1.20, -0.395), Vector3(0.145,0.245,0.035), black, 18, 9)
    frame.rotation.z = rot
    var lens = _sphere(parent, Vector3(x + 0.005 * side, 1.205, -0.422), Vector3(0.098,0.194,0.022), white, 18, 9)
    lens.rotation.z = rot

func _sphere(parent, pos, scale_value, material, radial_segments, rings):
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

func _cylinder(parent, pos, radius, height, rotation_value, material, segments):
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

func _box(parent, pos, size, material):
    var instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = pos
    instance.material_override = material
    parent.add_child(instance)
    return instance

func _box_rot(parent, pos, size, rotation_value, material):
    var part = _box(parent, pos, size, material)
    part.rotation = rotation_value
    return part

func _material(color, roughness):
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    return mat
