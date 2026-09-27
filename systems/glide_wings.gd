extends MeshInstance3D
var player: CharacterBody3D
var surface = ImmediateMesh.new()
func _ready():
    mesh = surface
    var material = StandardMaterial3D.new()
    material.albedo_color = Color("72bfcf")
    material.roughness = .72
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material_override = material
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    process_priority = 130
func _process(_delta):
    visible = is_instance_valid(player) and player.gliding
    if not visible or player.animation_driver == null: return
    var skeleton = player.animation_driver.skeleton
    if skeleton == null: return
    surface.clear_surfaces()
    surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for side in ["Left","Right"]:
        var points: Array[Vector3] = []
        for bone in [side+"Arm",side+"Hand",side+"UpLeg"]:
            var index = skeleton.find_bone(bone)
            points.append(to_local(skeleton.to_global(skeleton.get_bone_global_pose(index).origin)))
        var normal = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
        for point in points:
            surface.surface_set_normal(normal)
            surface.surface_add_vertex(point)
    surface.surface_end()
