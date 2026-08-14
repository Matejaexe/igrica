extends Node3D

# Texture-first city pass. The building collision/blockout stays simple while
# large facade cards sell a dense stylized skyline cheaply.

const FACADE_TEXTURES = [
	preload("res://art/facades/facade_01.svg"),
	preload("res://art/facades/facade_02.svg"),
	preload("res://art/facades/facade_03.svg"),
	preload("res://art/facades/facade_04.svg"),
	preload("res://art/facades/facade_05.svg"),
	preload("res://art/facades/facade_06.svg")
]

const ACCENTS = [
	Color("#45f0d0"),
	Color("#ff4f9a"),
	Color("#ffd34e"),
	Color("#68a7ff"),
	Color("#b36cff")
]

var _decorated: bool = false
var _solid_material_cache: Dictionary = {}
var _facade_material_cache: Dictionary = {}

func decorate_city(city_root: Node3D) -> void:
	if _decorated or city_root == null:
		return
	_decorated = true

	var buildings: Array[StaticBody3D] = []
	for child_value in city_root.get_children():
		var child: Node = child_value
		if child is StaticBody3D:
			var body := child as StaticBody3D
			if body.name.begins_with("Building_") or body.name == "StartTower":
				buildings.append(body)

	for index in range(buildings.size()):
		_skin_building(buildings[index], index)

	_add_rooftop_route_props(city_root, buildings)
	_add_city_cables(city_root)
	_add_center_sign(city_root)

func _skin_building(body: StaticBody3D, index: int) -> void:
	var size: Vector3 = _find_building_size(body)
	if size == Vector3.ZERO:
		return

	# Each face can use a different facade from the small atlas pool. The cards
	# sit just outside the old procedural windows, visually replacing them.
	var front_texture: Texture2D = FACADE_TEXTURES[index % FACADE_TEXTURES.size()]
	var side_texture: Texture2D = FACADE_TEXTURES[(index + 2) % FACADE_TEXTURES.size()]
	var back_texture: Texture2D = FACADE_TEXTURES[(index + 4) % FACADE_TEXTURES.size()]

	_add_facade(body, "FacadeFront", front_texture, Vector2(size.x, size.y), Vector3(0, 0, size.z * 0.5 + 0.13), Vector3.ZERO)
	_add_facade(body, "FacadeBack", back_texture, Vector2(size.x, size.y), Vector3(0, 0, -size.z * 0.5 - 0.13), Vector3(0, 180, 0))
	_add_facade(body, "FacadeRight", side_texture, Vector2(size.z, size.y), Vector3(size.x * 0.5 + 0.13, 0, 0), Vector3(0, 90, 0))
	_add_facade(body, "FacadeLeft", front_texture, Vector2(size.z, size.y), Vector3(-size.x * 0.5 - 0.13, 0, 0), Vector3(0, -90, 0))

	var accent: Color = ACCENTS[index % ACCENTS.size()]
	var roof_y: float = size.y * 0.5

	# Only a few chunky silhouette props stay in 3D.
	_add_visual_box(body, "RoofLip", Vector3(0, roof_y + 0.12, 0), Vector3(size.x * 0.90, 0.24, size.z * 0.90), Color("#151b27"), false)
	_add_visual_box(body, "RoofGlow", Vector3(0, roof_y + 0.25, size.z * 0.38), Vector3(size.x * 0.54, 0.10, 0.08), accent, true)

	if index % 3 == 0:
		_add_water_tank(body, Vector3(-size.x * 0.18, roof_y + 1.65, size.z * 0.16))
	elif index % 3 == 1:
		_add_antenna_cluster(body, Vector3(size.x * 0.20, roof_y + 0.20, -size.z * 0.18), accent)
	else:
		_add_rooftop_box_cluster(body, size, accent)

	# A single bold sign every few buildings keeps the city readable without
	# covering every wall in noise.
	if index % 5 == 0:
		_add_neon_sign(body, size, index, accent)

func _add_facade(
	parent: Node3D,
	node_name: String,
	texture: Texture2D,
	quad_size: Vector2,
	pos: Vector3,
	rotation_deg: Vector3
) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var quad := QuadMesh.new()
	quad.size = quad_size
	instance.mesh = quad
	instance.position = pos
	instance.rotation_degrees = rotation_deg
	instance.material_override = _facade_material(texture)
	parent.add_child(instance)

func _facade_material(texture: Texture2D) -> StandardMaterial3D:
	var key: String = texture.resource_path
	if _facade_material_cache.has(key):
		return _facade_material_cache[key] as StandardMaterial3D

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.90
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	_facade_material_cache[key] = material
	return material

func _find_building_size(body: StaticBody3D) -> Vector3:
	var best_size := Vector3.ZERO
	var best_volume: float = 0.0
	for child_value in body.get_children():
		var child: Node = child_value
		if child is MeshInstance3D:
			var instance := child as MeshInstance3D
			if instance.mesh is BoxMesh:
				var box := instance.mesh as BoxMesh
				var size: Vector3 = box.size
				var volume: float = size.x * size.y * size.z
				if volume > best_volume:
					best_volume = volume
					best_size = size
	return best_size

func _add_water_tank(parent: Node3D, pos: Vector3) -> void:
	var tank := MeshInstance3D.new()
	tank.name = "WaterTank"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.45
	mesh.bottom_radius = 1.45
	mesh.height = 2.25
	mesh.radial_segments = 10
	tank.mesh = mesh
	tank.position = pos
	tank.material_override = _solid_material(Color("#343c49"), false)
	parent.add_child(tank)

	for x_value in [-0.80, 0.80]:
		var x: float = float(x_value)
		for z_value in [-0.80, 0.80]:
			var z: float = float(z_value)
			_add_visual_box(parent, "TankLeg", pos + Vector3(x, -1.45, z), Vector3(0.15, 1.10, 0.15), Color("#222834"), false)

func _add_antenna_cluster(parent: Node3D, pos: Vector3, accent: Color) -> void:
	for index in range(3):
		var antenna := MeshInstance3D.new()
		antenna.name = "Antenna_%d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.055
		mesh.bottom_radius = 0.075
		mesh.height = 2.5 + float(index) * 0.8
		mesh.radial_segments = 7
		antenna.mesh = mesh
		antenna.position = pos + Vector3(float(index) * 0.42, mesh.height * 0.5, float(index) * 0.18)
		antenna.material_override = _solid_material(Color("#7e8999"), false)
		parent.add_child(antenna)

	var beacon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.30
	sphere.radial_segments = 8
	sphere.rings = 4
	beacon.mesh = sphere
	beacon.position = pos + Vector3(0.84, 3.70, 0.36)
	beacon.material_override = _solid_material(accent, true)
	parent.add_child(beacon)

func _add_rooftop_box_cluster(parent: Node3D, size: Vector3, accent: Color) -> void:
	var y: float = size.y * 0.5 + 0.55
	_add_visual_box(parent, "HVAC_A", Vector3(-size.x * 0.20, y, -size.z * 0.12), Vector3(2.9, 0.95, 2.1), Color("#323a48"), false)
	_add_visual_box(parent, "HVAC_B", Vector3(size.x * 0.15, y - 0.05, size.z * 0.18), Vector3(2.2, 0.80, 2.5), Color("#29313e"), false)
	_add_visual_box(parent, "HVAC_Glow", Vector3(size.x * 0.15, y + 0.10, size.z * 0.18 - 1.27), Vector3(1.4, 0.16, 0.05), accent, true)

func _add_neon_sign(body: StaticBody3D, size: Vector3, index: int, accent: Color) -> void:
	var sign_texts := ["MDK3", "NIGHT RUN", "24H", "CITY LOOP", "NO BRAKES"]
	var label := Label3D.new()
	label.name = "BuildingSign"
	label.text = String(sign_texts[index % sign_texts.size()])
	label.font_size = 58
	label.outline_size = 10
	label.pixel_size = 0.012
	label.modulate = accent
	label.outline_modulate = Color("#0d1018")
	label.position = Vector3(0, minf(size.y * 0.24, 8.0), size.z * 0.5 + 0.19)
	body.add_child(label)

func _add_rooftop_route_props(city_root: Node3D, buildings: Array[StaticBody3D]) -> void:
	var indices: Array[int] = [3, 8, 14, 20]
	for index in indices:
		if index < 0 or index >= buildings.size():
			continue
		var body: StaticBody3D = buildings[index]
		var size: Vector3 = _find_building_size(body)
		if size == Vector3.ZERO:
			continue

		var world_pos: Vector3 = body.global_position + Vector3(0, size.y * 0.5 + 0.62, 0)
		var ramp: StaticBody3D = _add_static_box(
			city_root,
			"TraversalRamp_%02d" % index,
			world_pos + Vector3(0, 0.18, size.z * 0.10),
			Vector3(5.0, 0.55, 7.0),
			Color("#202837"),
			Vector3(-12.0, 0, 0)
		)
		_add_visual_box(ramp, "RampStripe", Vector3(0, 0.31, 0), Vector3(3.9, 0.05, 5.8), ACCENTS[index % ACCENTS.size()], true)

func _add_city_cables(city_root: Node3D) -> void:
	var pairs: Array = [
		[Vector3(-58, 27, -82), Vector3(-22, 21, -82)],
		[Vector3(22, 31, -26), Vector3(62, 29, -26)],
		[Vector3(-60, 33, 26), Vector3(-22, 23, 26)],
		[Vector3(22, 25, 82), Vector3(62, 31, 66)]
	]
	for pair_value in pairs:
		var pair: Array = pair_value
		var from_point: Vector3 = pair[0]
		var to_point: Vector3 = pair[1]
		_add_cable(city_root, from_point, to_point)

func _add_cable(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var delta_vec: Vector3 = to - from
	var distance: float = delta_vec.length()
	if distance <= 0.01:
		return

	var cable := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.045
	mesh.height = distance
	mesh.radial_segments = 6
	cable.mesh = mesh
	cable.position = (from + to) * 0.5
	cable.material_override = _solid_material(Color("#121722"), false)

	var direction: Vector3 = delta_vec.normalized()
	var up := Vector3.UP
	if absf(direction.dot(up)) > 0.99:
		up = Vector3.RIGHT
	cable.transform.basis = Basis.looking_at(direction, up).rotated(Vector3.RIGHT, PI * 0.5)
	parent.add_child(cable)

func _add_center_sign(city_root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "MDK3_CenterSign"
	holder.position = Vector3(0, 0, -15)
	city_root.add_child(holder)

	_add_visual_box(holder, "PillarL", Vector3(-5.2, 3.0, 0), Vector3(0.9, 6.0, 0.9), Color("#181e2a"), false)
	_add_visual_box(holder, "PillarR", Vector3(5.2, 3.0, 0), Vector3(0.9, 6.0, 0.9), Color("#181e2a"), false)
	_add_visual_box(holder, "Header", Vector3(0, 5.6, 0), Vector3(11.2, 0.9, 0.9), Color("#121722"), false)

	var label := Label3D.new()
	label.text = "MDK3 // NIGHT RUN"
	label.font_size = 62
	label.outline_size = 10
	label.pixel_size = 0.012
	label.modulate = Color("#45f0d0")
	label.outline_modulate = Color("#0b0e15")
	label.position = Vector3(0, 4.75, 0.52)
	holder.add_child(label)

func _add_static_box(
	parent: Node3D,
	node_name: String,
	pos: Vector3,
	size: Vector3,
	color: Color,
	rotation_deg: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees = rotation_deg
	parent.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _solid_material(color, false)
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _add_visual_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, emission: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _solid_material(color, emission)
	parent.add_child(instance)
	return instance

func _solid_material(color: Color, emission: bool) -> StandardMaterial3D:
	var key: String = "%s|%s" % [color.to_html(true), str(emission)]
	if _solid_material_cache.has(key):
		return _solid_material_cache[key] as StandardMaterial3D
		

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
	_solid_material_cache[key] = material
	return material
