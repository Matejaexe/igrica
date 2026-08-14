extends Area3D

signal collected()

var time_passed = 0.0
var taken = false

func _ready():
    collision_layer = 0
    collision_mask = 1

    var outer = MeshInstance3D.new()
    outer.name = "OrbMesh"
    var sphere = SphereMesh.new()
    sphere.radius = 0.48
    sphere.height = 0.96
    sphere.radial_segments = 16
    sphere.rings = 8
    outer.mesh = sphere
    outer.material_override = _glow_material(Color("#51f7ff"), 2.4)
    add_child(outer)

    var core = MeshInstance3D.new()
    var core_mesh = SphereMesh.new()
    core_mesh.radius = 0.22
    core_mesh.height = 0.44
    core_mesh.radial_segments = 12
    core_mesh.rings = 6
    core.mesh = core_mesh
    core.material_override = _glow_material(Color("#f7ffff"), 3.2)
    add_child(core)

    var collision = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 0.8
    collision.shape = shape
    add_child(collision)

    body_entered.connect(_on_body_entered)

func _process(delta):
    time_passed += delta
    rotation.y += delta * 2.0
    var mesh_node = get_node_or_null("OrbMesh")
    if mesh_node != null:
        mesh_node.position.y = sin(time_passed * 3.2) * 0.15
        mesh_node.rotation.x += delta * 0.7

func _on_body_entered(body):
    if taken:
        return
    if body != null and body.name == "Player":
        taken = true
        collected.emit()
        queue_free()

func _glow_material(color, energy):
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    mat.roughness = 0.35
    return mat
