@tool
extends Node3D

@export var terrain_path: NodePath = NodePath("Terrain3D")
@export var preview_mesh_path: NodePath = NodePath("PreviewMesh")
@export var region_centers: Array[Vector3] = [
	Vector3(-32.0, 0.0, -32.0),
	Vector3(-32.0, 0.0, 32.0),
	Vector3(32.0, 0.0, -32.0),
	Vector3(32.0, 0.0, 32.0)
]
@export_range(16, 64, 1) var generation_radius: int = 30
@export_range(8, 96, 1) var preview_subdivisions: int = 56
@export_range(0.2, 8.0, 0.1) var height_scale: float = 1.8
@export_range(0.25, 4.0, 0.05) var sample_step: float = 1.0
@export var low_color: Color = Color(0.16, 0.19, 0.22, 1.0)
@export var mid_color: Color = Color(0.36, 0.39, 0.25, 1.0)
@export var high_color: Color = Color(0.66, 0.56, 0.35, 1.0)
@export var steep_color: Color = Color(0.46, 0.44, 0.40, 1.0)
@export var preview_material: Material
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if value and is_inside_tree():
			_rebuild_terrain()

var _terrain: Terrain3D
var _preview_mesh: MeshInstance3D


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain3D
	_preview_mesh = get_node_or_null(preview_mesh_path) as MeshInstance3D
	_rebuild_terrain()


func get_height_at(world_position: Vector3) -> float:
	if _terrain != null and _terrain.data != null:
		var height := _terrain.data.get_height(world_position)
		if not is_nan(height) and not is_inf(height):
			return height
	return _height(world_position.x, world_position.z)


func get_normal_at(world_position: Vector3) -> Vector3:
	if _terrain == null or _terrain.data == null:
		return Vector3.UP

	var left := get_height_at(world_position + Vector3.LEFT * sample_step)
	var right := get_height_at(world_position + Vector3.RIGHT * sample_step)
	var back := get_height_at(world_position + Vector3.BACK * sample_step)
	var forward := get_height_at(world_position + Vector3.FORWARD * sample_step)
	var normal := Vector3(left - right, sample_step * 2.0, back - forward)
	if not normal.is_finite() or normal.length_squared() <= 0.001:
		return Vector3.UP
	return normal.normalized()


func _rebuild_terrain() -> void:
	if _terrain == null:
		return

	_terrain.region_size = Terrain3D.SIZE_64
	if _terrain.material != null:
		_terrain.material.show_checkered = false

	for center: Vector3 in region_centers:
		_terrain.data.add_region_blankp(center, true)
	for x: int in range(-generation_radius, generation_radius + 1):
		for z: int in range(-generation_radius, generation_radius + 1):
			var position := Vector3(float(x), 0.0, float(z))
			_terrain.data.set_height(position, _height(position.x, position.z))

	_terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)
	if not Engine.is_editor_hint():
		_terrain.collision.mode = Terrain3DCollision.DYNAMIC_GAME
		_terrain.collision.build()
	_rebuild_preview_mesh()


func _rebuild_preview_mesh() -> void:
	if _preview_mesh == null:
		return

	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var colors: Array[Color] = []
	var uvs: Array[Vector2] = []
	var indices: Array[int] = []
	var size := float(generation_radius * 2)
	var step := size / float(preview_subdivisions)

	for z_index: int in range(preview_subdivisions + 1):
		for x_index: int in range(preview_subdivisions + 1):
			var x := -float(generation_radius) + float(x_index) * step
			var z := -float(generation_radius) + float(z_index) * step
			var position := Vector3(x, _height(x, z), z)
			var normal := _normal_from_height(position)
			vertices.append(position)
			normals.append(normal)
			colors.append(_terrain_color(position.y, normal))
			uvs.append(Vector2(float(x_index) / float(preview_subdivisions), float(z_index) / float(preview_subdivisions)))

	for z_index: int in range(preview_subdivisions):
		for x_index: int in range(preview_subdivisions):
			var row := preview_subdivisions + 1
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

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals)
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(colors)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if preview_material != null:
		mesh.surface_set_material(0, preview_material)
		_preview_mesh.material_override = preview_material
	_preview_mesh.mesh = mesh


func _height(x: float, z: float) -> float:
	var blocker_ridge := exp(-pow((x - 5.0) / 2.6, 2.0) - pow((z + 6.0) / 4.6, 2.0)) * 3.15
	var left_ridge := exp(-pow((x + 10.0) / 3.8, 2.0) - pow((z - 2.0) / 10.0, 2.0)) * 2.4
	var plateau := exp(-pow((x - 9.0) / 7.5, 2.0) - pow((z + 12.0) / 6.5, 2.0)) * 1.4
	var trench := -exp(-pow((x + 1.0) / 4.0, 2.0) - pow((z - 9.0) / 5.0, 2.0)) * 1.0
	var waves := sin(x * 0.35) * cos(z * 0.28) * 0.28
	return (blocker_ridge + left_ridge + plateau + trench + waves) * height_scale


func _normal_from_height(position: Vector3) -> Vector3:
	var left := _height(position.x - sample_step, position.z)
	var right := _height(position.x + sample_step, position.z)
	var back := _height(position.x, position.z - sample_step)
	var forward := _height(position.x, position.z + sample_step)
	var normal := Vector3(left - right, sample_step * 2.0, back - forward)
	if not normal.is_finite() or normal.length_squared() <= 0.001:
		return Vector3.UP
	return normal.normalized()


func _terrain_color(height: float, normal: Vector3) -> Color:
	var height_t := clampf(inverse_lerp(-1.2 * height_scale, 3.8 * height_scale, height), 0.0, 1.0)
	var base := low_color.lerp(mid_color, smoothstep(0.1, 0.55, height_t))
	base = base.lerp(high_color, smoothstep(0.52, 1.0, height_t))
	var slope_t := 1.0 - clampf(normal.dot(Vector3.UP), 0.0, 1.0)
	return base.lerp(steep_color, smoothstep(0.15, 0.55, slope_t))
