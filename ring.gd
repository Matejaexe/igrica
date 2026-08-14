extends Area3D

signal passed(ring)

var used = false
var pulse = 0.0

func _ready():
    collision_layer = 0
    collision_mask = 1

    var torus_instance = MeshInstance3D.new()
    torus_instance.name = "RingMesh"
    var torus = TorusMesh.new()
    torus.inner_radius = 2.35
    torus.outer_radius = 2.72
    torus.rings = 24
    torus.ring_segments = 12
    torus_instance.mesh = torus
    torus_instance.rotation.x = PI * 0.5
    torus_instance.material_override = _glow_material(Color("#ffd34e"), 2.6)
    add_child(torus_instance)

    var collision = CollisionShape3D.new()
    var shape = SphereShape3D.new()
    shape.radius = 2.25
    collision.shape = shape
    add_child(collision)

    body_entered.connect(_on_body_entered)

func _process(delta):
    pulse += delta
    var ring_mesh = get_node_or_null("RingMesh")
    if ring_mesh != null:
        ring_mesh.rotation.z += delta * 0.45
        var s = 1.0 + sin(pulse * 4.0) * 0.025
        ring_mesh.scale = Vector3(s, s, s)

func _on_body_entered(body):
    if used:
        return
    if body != null and body.name == "Player":
        used = true
        passed.emit(self)
        queue_free()

func _glow_material(color, energy):
    var mat = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    mat.roughness = 0.25
    return mat
