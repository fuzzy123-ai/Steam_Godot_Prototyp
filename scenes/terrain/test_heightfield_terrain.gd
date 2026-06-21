@tool
extends StaticBody3D

@export var terrain_size: Vector2 = Vector2(36.0, 36.0)
@export_range(4, 96, 1) var subdivisions: int = 32
@export var height_scale: float = 1.4
@export var material: Material

@onready var mesh_instance: MeshInstance3D = %MeshInstance3D
@onready var collision_shape: CollisionShape3D = %CollisionShape3D


func _ready() -> void:
	_rebuild()


func get_height_at(world_position: Vector3) -> float:
	var local := to_local(world_position)
	return global_transform.origin.y + _height(local.x, local.z)


func get_normal_at(world_position: Vector3) -> Vector3:
	var local := to_local(world_position)
	var sample_step := terrain_size.x / float(maxi(1, subdivisions))
	var h_left := _height(local.x - sample_step, local.z)
	var h_right := _height(local.x + sample_step, local.z)
	var h_back := _height(local.x, local.z - sample_step)
	var h_forward := _height(local.x, local.z + sample_step)
	var normal := Vector3(h_left - h_right, sample_step * 2.0, h_back - h_forward).normalized()
	return global_transform.basis * normal


func _rebuild() -> void:
	if mesh_instance == null or collision_shape == null:
		return

	var vertices: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var half_size := terrain_size * 0.5
	var step_x := terrain_size.x / float(subdivisions)
	var step_z := terrain_size.y / float(subdivisions)

	for z_index: int in range(subdivisions + 1):
		for x_index: int in range(subdivisions + 1):
			var x := -half_size.x + float(x_index) * step_x
			var z := -half_size.y + float(z_index) * step_z
			vertices.append(Vector3(x, _height(x, z), z))
			uvs.append(Vector2(float(x_index) / float(subdivisions), float(z_index) / float(subdivisions)))

	var indices: Array[int] = []
	for z_index: int in range(subdivisions):
		for x_index: int in range(subdivisions):
			var row := subdivisions + 1
			var a := z_index * row + x_index
			var b := a + 1
			var c := a + row
			var d := c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var normals: Array[Vector3] = []
	normals.resize(vertices.size())
	for i: int in range(normals.size()):
		normals[i] = Vector3.ZERO
	for i: int in range(0, indices.size(), 3):
		var ia := indices[i]
		var ib := indices[i + 1]
		var ic := indices[i + 2]
		var normal := (vertices[ib] - vertices[ia]).cross(vertices[ic] - vertices[ia]).normalized()
		normals[ia] += normal
		normals[ib] += normal
		normals[ic] += normal
	for i: int in range(normals.size()):
		normals[i] = normals[i].normalized()

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	mesh_instance.mesh = mesh

	var faces := PackedVector3Array()
	for index: int in indices:
		faces.append(vertices[index])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collision_shape.shape = shape


func _height(x: float, z: float) -> float:
	var ridge := exp(-pow((x + 8.0) / 4.5, 2.0)) * 1.1
	var valley := -exp(-pow((z - 5.0) / 5.0, 2.0)) * 0.45
	var waves := sin(x * 0.35) * cos(z * 0.24) * 0.28
	return (ridge + valley + waves) * height_scale
