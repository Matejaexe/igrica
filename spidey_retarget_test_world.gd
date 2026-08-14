extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://spidey_retarget_player.tscn")


func _ready() -> void:
	_build_environment()
	_build_floor()
	_build_platform(Vector3(4.0, 0.5, -5.0), Vector3(3.0, 1.0, 3.0))
	_build_platform(Vector3(-4.0, 1.0, -9.0), Vector3(3.0, 2.0, 3.0))
	_build_platform(Vector3(0.0, 1.5, -14.0), Vector3(5.0, 3.0, 4.0))

	var player: Node3D = PLAYER_SCENE.instantiate() as Node3D
	player.position = Vector3(0.0, 0.05, 4.0)
	add_child(player)


func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.10, 0.13, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.82, 0.95)
	environment.ambient_light_energy = 0.75
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _build_floor() -> void:
	_build_platform(Vector3(0.0, -0.15, -5.0), Vector3(30.0, 0.3, 40.0))


func _build_platform(center: Vector3, size_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = center
	add_child(body)

	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size_value
	mesh_instance.mesh = box_mesh
	body.add_child(mesh_instance)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.31, 0.42)
	material.roughness = 0.9
	mesh_instance.material_override = material

	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size_value
	collision.shape = box_shape
	body.add_child(collision)
