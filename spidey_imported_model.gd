extends RefCounted

# The gameplay visual now comes directly from the Blender source that contains
# SpideyCleanRig + the authored Run_FromReference_01 Action.
const MODEL_PATH: String = (
    "res://assets/characters/spidey/blender/"
    + "spidey_run_from_reference_v1.blend"
)
const ANIMATION_DRIVER_SCRIPT: Script = preload(
    "res://spidey_blender_animation_driver.gd"
)

const TEX_COMIC: Texture2D = preload(
    "res://art/spidey/spidey_comic.png"
)
const TEX_CLASSIC: Texture2D = preload(
    "res://art/spidey/spidey_classic.png"
)
const TEX_NOIR: Texture2D = preload(
    "res://art/spidey/spidey_noir.png"
)
const TEX_ULTIMATE: Texture2D = preload(
    "res://art/spidey/spidey_ultimate.png"
)
const TEX_IRON: Texture2D = preload(
    "res://art/spidey/spidey_iron.png"
)

# The clean Blender rig was built from the same original visible mesh, so keep
# the established player presentation calibration for the first in-game test.
const MODEL_SCALE: float = 1.62
const MODEL_Y_OFFSET: float = -1.34


static func build(parent: Node3D, data: Dictionary) -> Dictionary:
    var refs: Dictionary = _create_compatibility_proxies(parent)

    var packed_model: PackedScene = _load_model_scene()
    if packed_model == null:
        return refs

    var trick_pivot := Node3D.new()
    trick_pivot.name = "BlenderTraversalPivot"
    parent.add_child(trick_pivot)

    var model: Node3D = packed_model.instantiate() as Node3D
    if model == null:
        push_error("[SPIDEY BLENDER] Blender scene could not instantiate.")
        return refs

    model.name = "BlenderSpidey"
    model.position = Vector3(0.0, MODEL_Y_OFFSET, 0.0)
    model.rotation.y = PI
    model.scale = Vector3.ONE * MODEL_SCALE
    trick_pivot.add_child(model)

    var skeleton: Skeleton3D = _find_skeleton(model)
    var animation_player: AnimationPlayer = _find_animation_player(model)

    var character_id: String = String(data.get("id", "crimson"))
    _apply_character_material(
        model,
        _texture_for_character(character_id),
        _tint_for_character(character_id)
    )

    if skeleton == null:
        push_warning(
            "[SPIDEY BLENDER] Model loaded, but Skeleton3D was not found."
        )

    if animation_player == null:
        push_error(
            "[SPIDEY BLENDER] Model loaded, but AnimationPlayer was not found."
        )
    else:
        var driver := Node.new()
        driver.name = "SpideyBlenderAnimationDriver"
        driver.set_script(ANIMATION_DRIVER_SCRIPT)
        parent.add_child(driver)
        driver.call(
            "setup",
            animation_player,
            parent.get_parent()
        )

    refs["model"] = model
    refs["skeleton"] = skeleton
    refs["animation_player"] = animation_player
    return refs


static func build_preview(parent: Node3D, data: Dictionary) -> Dictionary:
    var packed_model: PackedScene = _load_model_scene()
    if packed_model == null:
        return {
            "model": null,
            "skeleton": null,
            "animation_player": null
        }

    var model: Node3D = packed_model.instantiate() as Node3D
    if model == null:
        return {
            "model": null,
            "skeleton": null,
            "animation_player": null
        }

    model.name = "BlenderSpideyPreview"
    model.position = Vector3(0.0, MODEL_Y_OFFSET, 0.0)
    model.rotation.y = PI
    model.scale = Vector3.ONE * MODEL_SCALE
    parent.add_child(model)

    var skeleton: Skeleton3D = _find_skeleton(model)
    var animation_player: AnimationPlayer = _find_animation_player(model)

    var character_id: String = String(data.get("id", "crimson"))
    _apply_character_material(
        model,
        _texture_for_character(character_id),
        _tint_for_character(character_id)
    )

    # The old preview script targets the previous skeleton names. Until a
    # dedicated Blender idle exists, a slower in-place run is a safe preview
    # and avoids showing the new rig in a T-pose.
    _start_preview_animation(animation_player)

    return {
        "model": model,
        "skeleton": skeleton,
        "animation_player": animation_player
    }


static func _load_model_scene() -> PackedScene:
    var resource: Resource = load(MODEL_PATH)
    var packed_scene := resource as PackedScene
    if packed_scene == null:
        push_error(
            "[SPIDEY BLENDER] Could not load "
            + MODEL_PATH
            + ". Make sure Godot's Blender importer is enabled and Blender "
            + "is configured in Editor Settings."
        )
    return packed_scene


static func _create_compatibility_proxies(parent: Node3D) -> Dictionary:
    # player.gd still keeps these references for legacy pose code. They are
    # invisible and never deform the Blender mesh.
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

    return {
        "torso_root": torso_proxy,
        "left_arm": arm_l_proxy,
        "right_arm": arm_r_proxy,
        "left_leg": leg_l_proxy,
        "right_leg": leg_r_proxy
    }


static func _start_preview_animation(
    animation_player: AnimationPlayer
) -> void:
    if animation_player == null:
        return

    var run_name: StringName = _find_run_animation(animation_player)
    if run_name == &"":
        return

    var animation: Animation = animation_player.get_animation(run_name)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR

    animation_player.speed_scale = 0.62
    animation_player.play(run_name)


static func _find_run_animation(
    animation_player: AnimationPlayer
) -> StringName:
    if animation_player == null:
        return &""

    var names: PackedStringArray = animation_player.get_animation_list()

    for clip_name: String in names:
        if clip_name == "Run_FromReference_01":
            return StringName(clip_name)

    for clip_name: String in names:
        var lowered: String = clip_name.to_lower()
        if lowered.contains("run_fromreference_01"):
            return StringName(clip_name)

    for clip_name: String in names:
        var lowered: String = clip_name.to_lower()
        if lowered.contains("run") and lowered != "reset":
            return StringName(clip_name)

    return &""


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


static func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer

    for child_value in node.get_children():
        var child: Node = child_value
        var result: AnimationPlayer = _find_animation_player(child)
        if result != null:
            return result

    return null


static func _apply_character_material(
    node: Node,
    texture: Texture2D,
    tint: Color
) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface_index in range(
                mesh_instance.mesh.get_surface_count()
            ):
                var material := StandardMaterial3D.new()
                material.albedo_texture = texture
                material.albedo_color = tint
                material.roughness = 0.84
                material.metallic = 0.0
                material.cull_mode = BaseMaterial3D.CULL_DISABLED
                material.texture_filter = (
                    BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
                )
                mesh_instance.set_surface_override_material(
                    surface_index,
                    material
                )

    for child_value in node.get_children():
        var child: Node = child_value
        _apply_character_material(child, texture, tint)
