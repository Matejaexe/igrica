extends RefCounted

const MODEL: PackedScene = preload("res://models/spidey/spidey_funk_alt_v2.glb")
const RIG_CONTROLLER_SCRIPT: Script = preload("res://spidey_rig_controller.gd")

const TEX_COMIC: Texture2D = preload("res://art/spidey/spidey_comic.png")
const TEX_CLASSIC: Texture2D = preload("res://art/spidey/spidey_classic.png")
const TEX_NOIR: Texture2D = preload("res://art/spidey/spidey_noir.png")
const TEX_ULTIMATE: Texture2D = preload("res://art/spidey/spidey_ultimate.png")
const TEX_IRON: Texture2D = preload("res://art/spidey/spidey_iron.png")

const MODEL_SCALE: float = 1.62
const MODEL_Y_OFFSET: float = -1.34
# Bind-pose mesh accessor spans X=-0.593679..0.595940. This is the
# conservative horizontal half-width used for wall-run visual clearance.
const MODEL_BIND_HALF_WIDTH: float = 0.596
const MODEL_SCALED_HALF_WIDTH: float = MODEL_BIND_HALF_WIDTH * MODEL_SCALE

static func build(parent: Node3D, data: Dictionary) -> Dictionary:
    var model: Node3D = MODEL.instantiate() as Node3D
    model.name = "BRCSpidey"
    model.position = Vector3(0.0, MODEL_Y_OFFSET, 0.0)
    model.rotation.y = PI
    model.scale = Vector3.ONE * MODEL_SCALE
    parent.add_child(model)

    var skeleton: Skeleton3D = _find_skeleton(model)
    var character_id: String = String(data.get("id", "crimson"))
    var texture: Texture2D = _texture_for_character(character_id)
    var tint: Color = _tint_for_character(character_id)
    _apply_character_material(model, texture, tint)

    # Invisible compatibility proxies expected by player.gd.
    var torso_proxy := Node3D.new()
    torso_proxy.name = "ImportedTorsoProxy"
    parent.add_child(torso_proxy)

    var arm_l_proxy := Node3D.new()
    arm_l_proxy.name = "ImportedArmLProxy"
    parent.add_child(arm_l_proxy)

    var arm_r_proxy := Node3D.new()
    arm_r_proxy.name = "ImportedArmRProxy"
    parent.add_child(arm_r_proxy)

    var leg_l_proxy := Node3D.new()
    leg_l_proxy.name = "ImportedLegLProxy"
    parent.add_child(leg_l_proxy)

    var leg_r_proxy := Node3D.new()
    leg_r_proxy.name = "ImportedLegRProxy"
    parent.add_child(leg_r_proxy)

    # Two real web origins, one for each hand.
    var web_origin_l := Marker3D.new()
    web_origin_l.name = "WebOriginL"
    parent.add_child(web_origin_l)

    var web_origin_r := Marker3D.new()
    web_origin_r.name = "WebOriginR"
    parent.add_child(web_origin_r)

    if skeleton != null:
        var controller := Node.new()
        controller.name = "SpideyRigController"
        controller.set_script(RIG_CONTROLLER_SCRIPT)
        parent.add_child(controller)
        controller.call(
            "setup",
            skeleton,
            parent.get_parent(),
            web_origin_l,
            web_origin_r
        )
    else:
        push_warning("BRC Spidey model loaded, but Skeleton3D was not found.")

    return {
        "torso_root": torso_proxy,
        "left_arm": arm_l_proxy,
        "right_arm": arm_r_proxy,
        "left_leg": leg_l_proxy,
        "right_leg": leg_r_proxy
    }

static func _texture_for_character(character_id: String) -> Texture2D:
    match character_id:
        "azure":
            return TEX_NOIR
        "gold":
            return TEX_IRON
        "violet":
            return TEX_NOIR
        _:
            return TEX_COMIC

static func _tint_for_character(character_id: String) -> Color:
    match character_id:
        "azure":
            return Color(0.72, 0.86, 1.0, 1.0)
        "violet":
            return Color(0.76, 0.53, 1.0, 1.0)
        _:
            return Color.WHITE

static func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child_value in node.get_children():
        var child: Node = child_value
        var result: Skeleton3D = _find_skeleton(child)
        if result != null:
            return result
    return null

static func _apply_character_material(node: Node, texture: Texture2D, tint: Color) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface_index in range(mesh_instance.mesh.get_surface_count()):
                var material := StandardMaterial3D.new()
                material.albedo_texture = texture
                material.albedo_color = tint
                material.roughness = 0.84
                material.metallic = 0.0
                material.cull_mode = BaseMaterial3D.CULL_DISABLED
                material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
                mesh_instance.set_surface_override_material(surface_index, material)

    for child_value in node.get_children():
        var child: Node = child_value
        _apply_character_material(child, texture, tint)
