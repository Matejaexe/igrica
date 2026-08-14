extends RefCounted

# Comic-focused Spider character pass.
# Goal: lean comic-book Spider-Man silhouette with smaller mask, bigger eyes,
# narrow waist, longer limbs, textured head/torso and no floating eye quads.

const SIDES := 12

const TEX_WEB_RED := preload("res://art/spider_textures/web_red_panel.svg")
const TEX_BLUE := preload("res://art/spider_textures/blue_panel.svg")
const TEX_CLASSIC_HEAD := preload("res://art/spider_textures/classic_head.svg")
const TEX_CLASSIC_TORSO := preload("res://art/spider_textures/classic_torso.svg")
const TEX_CLASSIC_BOOT := preload("res://art/spider_textures/classic_boot.svg")
const TEX_SHADOW_HEAD := preload("res://art/spider_textures/shadow_head.svg")
const TEX_SHADOW_TORSO := preload("res://art/spider_textures/shadow_torso.svg")
const TEX_HOODIE_TORSO := preload("res://art/spider_textures/hoodie_torso.svg")
const TEX_PURPLE_HEAD := preload("res://art/spider_textures/purple_head.svg")
const TEX_PURPLE_TORSO := preload("res://art/spider_textures/purple_torso.svg")

static func build(parent, data):
    var raw_id := str(data.get("id", "crimson"))
    var character_id := _normalize_id(raw_id)
    var cfg := _config_for(character_id)

    var torso_root := Node3D.new()
    torso_root.name = "Torso"
    torso_root.position = Vector3(0, 0.30, 0)
    parent.add_child(torso_root)

    _build_torso(torso_root, cfg)
    _build_head(parent, cfg)

    var left_arm = _build_arm(parent, -1.0, cfg)
    var right_arm = _build_arm(parent, 1.0, cfg)
    var left_leg = _build_leg(parent, -1.0, cfg)
    var right_leg = _build_leg(parent, 1.0, cfg)

    _build_shoulders(parent, cfg)
    _build_pelvis_cover(torso_root, cfg)

    parent.scale = Vector3.ONE * cfg.get("scale", 1.0)

    return {
        "torso_root": torso_root,
        "left_arm": left_arm,
        "right_arm": right_arm,
        "left_leg": left_leg,
        "right_leg": right_leg
    }

static func _normalize_id(value: String) -> String:
    match value:
        "tech":
            return "tech"
        "strong":
            return "gold"
        _:
            return value

static func _config_for(character_id: String) -> Dictionary:
    match character_id:
        "tech":
            return {
                "id": "tech",
                "scale": 0.98,
                "head_texture": TEX_SHADOW_HEAD,
                "torso_texture": TEX_SHADOW_TORSO,
                "arm_texture": TEX_WEB_RED,
                "leg_texture": TEX_BLUE,
                "boot_texture": TEX_CLASSIC_BOOT,
                "shoulder_x": 0.48,
                "torso_width": 0.98,
                "hip_width": 0.93,
                "baggy": 0.92,
                "boot_scale": 0.95,
                "suit_tint": Color.WHITE,
                "blue_tint": Color(0.08, 0.10, 0.14, 1.0)
            }
        "gold":
            return {
                "id": "gold",
                "scale": 1.05,
                "head_texture": TEX_CLASSIC_HEAD,
                "torso_texture": TEX_HOODIE_TORSO,
                "arm_texture": TEX_WEB_RED,
                "leg_texture": TEX_BLUE,
                "boot_texture": TEX_CLASSIC_BOOT,
                "shoulder_x": 0.54,
                "torso_width": 1.10,
                "hip_width": 1.05,
                "baggy": 1.18,
                "boot_scale": 1.12,
                "suit_tint": Color.WHITE,
                "blue_tint": Color.WHITE
            }
        "violet":
            return {
                "id": "violet",
                "scale": 1.00,
                "head_texture": TEX_PURPLE_HEAD,
                "torso_texture": TEX_PURPLE_TORSO,
                "arm_texture": TEX_WEB_RED,
                "leg_texture": TEX_BLUE,
                "boot_texture": TEX_CLASSIC_BOOT,
                "shoulder_x": 0.51,
                "torso_width": 1.01,
                "hip_width": 1.04,
                "baggy": 1.14,
                "boot_scale": 1.10,
                "suit_tint": Color(0.98, 0.38, 0.54, 1.0),
                "blue_tint": Color(0.51, 0.46, 0.90, 1.0)
            }
        _:
            return {
                "id": "crimson",
                "scale": 1.00,
                "head_texture": TEX_CLASSIC_HEAD,
                "torso_texture": TEX_CLASSIC_TORSO,
                "arm_texture": TEX_WEB_RED,
                "leg_texture": TEX_BLUE,
                "boot_texture": TEX_CLASSIC_BOOT,
                "shoulder_x": 0.50,
                "torso_width": 1.00,
                "hip_width": 1.00,
                "baggy": 1.00,
                "boot_scale": 1.00,
                "suit_tint": Color.WHITE,
                "blue_tint": Color.WHITE
            }

static func _build_torso(root: Node3D, cfg: Dictionary) -> void:
    var w := float(cfg["torso_width"])
    var h_ratio := 1.0 if cfg["id"] != "gold" else 1.06
    var torso_mesh := _tube_mesh([
        Vector3(0.18 * w, 0.56 * h_ratio, 0.16),
        Vector3(0.33 * w, 0.43 * h_ratio, 0.22),
        Vector3(0.40 * w, 0.16 * h_ratio, 0.26),
        Vector3(0.34 * w, -0.15 * h_ratio, 0.24),
        Vector3(0.27 * w, -0.42 * h_ratio, 0.19)
    ], SIDES, PI / 12.0, true, true)
    _mesh_instance(root, "Body", torso_mesh, Vector3.ZERO, _tex_material(cfg["torso_texture"], Color.WHITE))

    # back/side contour shell to soften joins and make one readable silhouette
    var shell_mesh := _tube_mesh([
        Vector3(0.20 * w, 0.56 * h_ratio, 0.18),
        Vector3(0.36 * w, 0.42 * h_ratio, 0.24),
        Vector3(0.42 * w, 0.14 * h_ratio, 0.28),
        Vector3(0.37 * w, -0.18 * h_ratio, 0.26),
        Vector3(0.29 * w, -0.45 * h_ratio, 0.21)
    ], SIDES, PI / 12.0, false, false)
    _mesh_instance(root, "ContourShell", shell_mesh, Vector3(0, 0, 0.01), _flat_color_material(Color(0,0,0,0)))

static func _build_head(parent: Node3D, cfg: Dictionary) -> void:
    var head_root := Node3D.new()
    head_root.name = "HeadRoot"
    head_root.position = Vector3(0, 1.24, 0)
    parent.add_child(head_root)

    var head_mesh := _tube_mesh([
        Vector3(0.15, 0.32, 0.14),
        Vector3(0.25, 0.22, 0.22),
        Vector3(0.29, 0.04, 0.28),
        Vector3(0.26, -0.14, 0.24),
        Vector3(0.19, -0.30, 0.18),
        Vector3(0.11, -0.40, 0.10)
    ], SIDES, 0.0, true, true)
    _mesh_instance(head_root, "Head", head_mesh, Vector3.ZERO, _tex_material(cfg["head_texture"], Color.WHITE))

    # neck and jaw transition
    var neck_mesh := _tube_mesh([
        Vector3(0.10, -0.02, 0.10),
        Vector3(0.11, -0.12, 0.11),
        Vector3(0.12, -0.22, 0.12)
    ], SIDES, 0.0, true, true)
    _mesh_instance(parent, "Neck", neck_mesh, Vector3(0, 0.97, 0.01), _flat_color_material(Color(0.77, 0.12, 0.20) if cfg["id"] in ["crimson", "gold"] else Color(0.08,0.09,0.12)))

static func _build_arm(parent: Node3D, side: float, cfg: Dictionary) -> Node3D:
    var arm_root := Node3D.new()
    arm_root.name = "ArmL" if side < 0.0 else "ArmR"
    arm_root.position = Vector3(float(cfg["shoulder_x"]) * side, 0.60, 0)
    parent.add_child(arm_root)

    var upper_mesh := _tube_mesh([
        Vector3(0.15, 0.05, 0.15),
        Vector3(0.16, -0.18, 0.16),
        Vector3(0.13, -0.40, 0.13)
    ], SIDES, 0.0, true, true)
    _mesh_instance(arm_root, "UpperArm", upper_mesh, Vector3(0.02 * side, 0, 0), _tex_material(cfg["arm_texture"], cfg["suit_tint"]))

    var fore_mesh := _tube_mesh([
        Vector3(0.12, -0.36, 0.12),
        Vector3(0.11, -0.62, 0.11),
        Vector3(0.10, -0.87, 0.10)
    ], SIDES, 0.0, true, true)
    _mesh_instance(arm_root, "ForeArm", fore_mesh, Vector3(0.04 * side, 0, -0.01), _tex_material(cfg["arm_texture"], cfg["suit_tint"]))

    var hand_mesh := _tube_mesh([
        Vector3(0.10, -0.88, 0.10),
        Vector3(0.12, -1.00, 0.12),
        Vector3(0.10, -1.12, 0.08)
    ], SIDES, 0.0, true, true)
    _mesh_instance(arm_root, "Hand", hand_mesh, Vector3(0.04 * side, 0, -0.02), _tex_material(cfg["arm_texture"], cfg["suit_tint"]))

    return arm_root

static func _build_leg(parent: Node3D, side: float, cfg: Dictionary) -> Node3D:
    var leg_root := Node3D.new()
    leg_root.name = "LegL" if side < 0.0 else "LegR"
    leg_root.position = Vector3(0.22 * side, -0.30, 0)
    parent.add_child(leg_root)

    var baggy := float(cfg["baggy"])
    var hip_w := float(cfg["hip_width"])

    var thigh_mesh := _tube_mesh([
        Vector3(0.16 * hip_w, 0.04, 0.16 * baggy),
        Vector3(0.22 * hip_w, -0.24, 0.21 * baggy),
        Vector3(0.19 * hip_w, -0.53, 0.18 * baggy)
    ], SIDES, 0.0, true, true)
    _mesh_instance(leg_root, "Thigh", thigh_mesh, Vector3.ZERO, _tex_material(cfg["leg_texture"], cfg["blue_tint"]))

    var shin_mesh := _tube_mesh([
        Vector3(0.17 * hip_w, -0.50, 0.16 * baggy),
        Vector3(0.15 * hip_w, -0.78, 0.14 * baggy),
        Vector3(0.13 * hip_w, -0.97, 0.12 * baggy)
    ], SIDES, 0.0, true, true)
    _mesh_instance(leg_root, "Shin", shin_mesh, Vector3.ZERO, _tex_material(cfg["leg_texture"], cfg["blue_tint"]))

    var boot_mesh := _tube_mesh([
        Vector3(0.14, -0.93, 0.14),
        Vector3(0.16, -1.07, 0.16),
        Vector3(0.15, -1.18, 0.14)
    ], SIDES, 0.0, true, true)
    _mesh_instance(leg_root, "BootUpper", boot_mesh, Vector3.ZERO, _tex_material(cfg["boot_texture"], Color.WHITE))

    _build_shoe(leg_root, cfg)
    return leg_root

static func _build_shoe(parent: Node3D, cfg: Dictionary) -> void:
    var scale_value := float(cfg["boot_scale"])
    var shoe_mesh := _shoe_mesh(Vector3(0.48 * scale_value, 0.22 * scale_value, 0.82 * scale_value))
    _mesh_instance(parent, "Shoe", shoe_mesh, Vector3(0, -1.17, -0.15), _tex_material(cfg["boot_texture"], Color.WHITE))

static func _build_shoulders(parent: Node3D, cfg: Dictionary) -> void:
    var w := float(cfg["torso_width"])
    var shell_mesh := _tube_mesh([
        Vector3(0.12, 0.08, 0.12),
        Vector3(0.16, -0.02, 0.16),
        Vector3(0.15, -0.12, 0.14)
    ], SIDES, 0.0, true, true)
    _mesh_instance(parent, "ShoulderCapL", shell_mesh, Vector3(-0.34 * w, 0.78, 0.02), _tex_material(cfg["arm_texture"], cfg["suit_tint"]))
    _mesh_instance(parent, "ShoulderCapR", shell_mesh, Vector3(0.34 * w, 0.78, 0.02), _tex_material(cfg["arm_texture"], cfg["suit_tint"]))

static func _build_pelvis_cover(root: Node3D, cfg: Dictionary) -> void:
    var baggy := float(cfg["baggy"])
    var pelvis_mesh := _tube_mesh([
        Vector3(0.23, -0.30, 0.18 * baggy),
        Vector3(0.30, -0.42, 0.24 * baggy),
        Vector3(0.25, -0.54, 0.20 * baggy)
    ], SIDES, 0.0, true, true)
    _mesh_instance(root, "PelvisCover", pelvis_mesh, Vector3(0, 0, 0.02), _tex_material(cfg["leg_texture"], cfg["blue_tint"]))

static func _mesh_instance(parent: Node3D, name: String, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = name
    instance.mesh = mesh
    instance.position = pos
    instance.material_override = material
    parent.add_child(instance)
    return instance

static func _flat_color_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
    mat.roughness = 0.95
    return mat

static func _tex_material(texture: Texture2D, tint: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = texture
    mat.albedo_color = tint
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    mat.roughness = 0.94
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
    return mat

static func _tube_mesh(rings: Array, sides: int, phase: float, close_top: bool, close_bottom: bool) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var ring_positions: Array = []
    var ring_uvs: Array = []
    for i in range(rings.size()):
        var ring: Vector3 = rings[i]
        var v := 0.0 if rings.size() == 1 else float(i) / float(rings.size() - 1)
        var positions: Array = []
        var uvs: Array = []
        for side_index in range(sides + 1):
            var t := float(side_index) / float(sides)
            var angle := phase + TAU * t
            positions.append(Vector3(cos(angle) * ring.x, ring.y, sin(angle) * ring.z))
            uvs.append(Vector2(t, v))
        ring_positions.append(positions)
        ring_uvs.append(uvs)

    for ring_index in range(rings.size() - 1):
        for side_index in range(sides):
            var a: Vector3 = ring_positions[ring_index][side_index]
            var b: Vector3 = ring_positions[ring_index + 1][side_index]
            var c: Vector3 = ring_positions[ring_index + 1][side_index + 1]
            var d: Vector3 = ring_positions[ring_index][side_index + 1]
            var uva: Vector2 = ring_uvs[ring_index][side_index]
            var uvb: Vector2 = ring_uvs[ring_index + 1][side_index]
            var uvc: Vector2 = ring_uvs[ring_index + 1][side_index + 1]
            var uvd: Vector2 = ring_uvs[ring_index][side_index + 1]
            _add_tri(st, a, uva, b, uvb, c, uvc)
            _add_tri(st, a, uva, c, uvc, d, uvd)

    if close_top:
        var top_ring: Array = ring_positions[0]
        var center_top := Vector3(0, rings[0].y, 0)
        for side_index in range(sides):
            _add_tri(st, center_top, Vector2(0.5, 0.0), top_ring[side_index + 1], Vector2(0.5, 0.0), top_ring[side_index], Vector2(0.5, 0.0))
    if close_bottom:
        var last_index := rings.size() - 1
        var bottom_ring: Array = ring_positions[last_index]
        var center_bottom := Vector3(0, rings[last_index].y, 0)
        for side_index in range(sides):
            _add_tri(st, center_bottom, Vector2(0.5, 1.0), bottom_ring[side_index], Vector2(0.5, 1.0), bottom_ring[side_index + 1], Vector2(0.5, 1.0))

    st.generate_normals()
    return st.commit()

static func _shoe_mesh(size: Vector3) -> ArrayMesh:
    var sx := size.x * 0.5
    var sy := size.y * 0.5
    var sz := size.z * 0.5
    var vertices := [
        Vector3(-sx * 0.76, -sy, sz), Vector3(sx * 0.76, -sy, sz),
        Vector3(-sx, -sy, -sz), Vector3(sx, -sy, -sz),
        Vector3(-sx * 0.62, sy, sz * 0.70), Vector3(sx * 0.62, sy, sz * 0.70),
        Vector3(-sx * 0.84, sy * 0.52, -sz), Vector3(sx * 0.84, sy * 0.52, -sz)
    ]
    var faces := [
        [0, 2, 3], [0, 3, 1],
        [4, 5, 7], [4, 7, 6],
        [0, 1, 5], [0, 5, 4],
        [2, 6, 7], [2, 7, 3],
        [0, 4, 6], [0, 6, 2],
        [1, 3, 7], [1, 7, 5]
    ]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for face in faces:
        _add_tri(st, vertices[face[0]], Vector2(0.0, 1.0), vertices[face[1]], Vector2(1.0, 1.0), vertices[face[2]], Vector2(1.0, 0.0))
    st.generate_normals()
    return st.commit()

static func _add_tri(st: SurfaceTool, a: Vector3, uva: Vector2, b: Vector3, uvb: Vector2, c: Vector3, uvc: Vector2) -> void:
    st.set_smooth_group(-1)
    st.set_uv(uva)
    st.add_vertex(a)
    st.set_uv(uvb)
    st.add_vertex(b)
    st.set_uv(uvc)
    st.add_vertex(c)
