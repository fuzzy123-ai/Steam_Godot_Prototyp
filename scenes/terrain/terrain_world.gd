@tool
extends Node3D

signal crater_applied(event: Dictionary)

@export var terrain_path: NodePath = NodePath("Terrain3D")
@export var preview_mesh_path: NodePath = NodePath("PreviewMesh")
@export var preview_collision_shape_path: NodePath = NodePath("PreviewCollision/CollisionShape3D")
@export var generation_settings: Resource
@export var region_centers: Array[Vector3] = [
	Vector3(-32.0, 0.0, -32.0),
	Vector3(-32.0, 0.0, 32.0),
	Vector3(32.0, 0.0, -32.0),
	Vector3(32.0, 0.0, 32.0)
]
@export_range(16, 64, 1) var generation_radius: int = 30
@export_range(8, 96, 1) var preview_subdivisions: int = 56
@export_range(0.2, 8.0, 0.1) var height_scale: float = 1.8
@export var seed: int = 1001
@export_range(0, 12, 1) var ridge_count: int = 5
@export_range(0.0, 8.0, 0.1) var ridge_strength: float = 2.4
@export_range(0.01, 1.0, 0.01) var noise_frequency: float = 0.18
@export_range(0.0, 4.0, 0.1) var noise_strength: float = 0.35
@export_range(0.25, 4.0, 0.05) var sample_step: float = 1.0
@export var low_color: Color = Color(0.16, 0.19, 0.22, 1.0)
@export var mid_color: Color = Color(0.36, 0.39, 0.25, 1.0)
@export var high_color: Color = Color(0.66, 0.56, 0.35, 1.0)
@export var steep_color: Color = Color(0.46, 0.44, 0.40, 1.0)
@export var preview_material: Material
@export var use_imported_terrain3d_data: bool = false
@export var rebuild_preview_mesh_enabled: bool = true
@export var apply_craters_to_terrain3d_data: bool = true
@export_range(0.25, 2.0, 0.25) var terrain3d_crater_step: float = 1.0
@export var build_terrain3d_collision: bool = false
@export var build_preview_collision: bool = true
@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if value and is_inside_tree():
			_rebuild_terrain()

var _terrain: Terrain3D
var _preview_mesh: MeshInstance3D
var _preview_collision_shape: CollisionShape3D
var _features: Array[Dictionary] = []
var _has_built_once := false
var _crater_events: Array[Dictionary] = []


func _ready() -> void:
	_terrain = get_node_or_null(terrain_path) as Terrain3D
	_preview_mesh = get_node_or_null(preview_mesh_path) as MeshInstance3D
	_preview_collision_shape = get_node_or_null(preview_collision_shape_path) as CollisionShape3D
	_apply_exported_settings()
	_rebuild_terrain()


func apply_generation_settings(settings: Resource) -> void:
	generation_settings = settings
	_apply_exported_settings()
	_rebuild_terrain()


func apply_seed(new_seed: int) -> void:
	if _has_built_once and seed == new_seed:
		return
	seed = new_seed
	if generation_settings != null:
		generation_settings.seed = new_seed
	_rebuild_terrain()


func get_generation_fingerprint() -> String:
	return "%s:%s:%s:%s:%s:%s:%s:def:%s" % [
		seed,
		generation_radius,
		preview_subdivisions,
		height_scale,
		ridge_count,
		ridge_strength,
		noise_frequency,
		get_deformation_fingerprint()
	]


func get_deformation_fingerprint() -> String:
	var parts: Array[String] = []
	for event: Dictionary in _crater_events:
		parts.append("%s,%s,%s,%s" % [
			event.get("x", 0.0),
			event.get("z", 0.0),
			event.get("radius", 0.0),
			event.get("depth", 0.0)
		])
	return "%s:%s" % [_crater_events.size(), ";".join(parts)]


func get_crater_events() -> Array[Dictionary]:
	return _crater_events.duplicate(true)


func get_height_at(world_position: Vector3) -> float:
	if _terrain != null and _terrain.data != null:
		var height := _terrain.data.get_height(world_position)
		if not is_nan(height) and not is_inf(height):
			if use_imported_terrain3d_data and not apply_craters_to_terrain3d_data:
				return _apply_deformation_to_height(height, world_position.x, world_position.z)
			return height
	return _deformed_height(world_position.x, world_position.z)


func get_normal_at(world_position: Vector3) -> Vector3:
	var left := get_height_at(world_position + Vector3.LEFT * sample_step)
	var right := get_height_at(world_position + Vector3.RIGHT * sample_step)
	var back := get_height_at(world_position + Vector3.BACK * sample_step)
	var forward := get_height_at(world_position + Vector3.FORWARD * sample_step)
	var normal := Vector3(left - right, sample_step * 2.0, back - forward)
	if not normal.is_finite() or normal.length_squared() <= 0.001:
		return Vector3.UP
	return normal.normalized()


func apply_crater(center: Vector3, radius: float, depth: float, emit_event: bool = true) -> bool:
	return apply_crater_event({
		"x": snappedf(center.x, 0.001),
		"z": snappedf(center.z, 0.001),
		"radius": snappedf(radius, 0.001),
		"depth": snappedf(depth, 0.001)
	}, emit_event)


func apply_crater_event(event: Dictionary, emit_event: bool = true) -> bool:
	var crater_event := _sanitize_crater_event(event)
	if crater_event.is_empty():
		return false

	_crater_events.append(crater_event)
	_apply_crater_visuals(crater_event)
	if emit_event:
		crater_applied.emit(crater_event.duplicate(true))
	return true


func apply_crater_events(events: Array, clear_existing: bool = true, emit_events: bool = false) -> int:
	if clear_existing:
		_crater_events.clear()
		if use_imported_terrain3d_data:
			_reload_imported_terrain3d_data()

	var applied_count := 0
	for raw_event: Variant in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue
		var crater_event := _sanitize_crater_event(raw_event)
		if crater_event.is_empty():
			continue
		_crater_events.append(crater_event)
		_apply_crater_visuals(crater_event)
		applied_count += 1
		if emit_events:
			crater_applied.emit(crater_event.duplicate(true))

	if not use_imported_terrain3d_data and (clear_existing or applied_count > 0):
		_rebuild_preview_mesh()
	return applied_count


func clear_deformations() -> void:
	if _crater_events.is_empty():
		return
	_crater_events.clear()
	if use_imported_terrain3d_data:
		_reload_imported_terrain3d_data()
	else:
		_rebuild_preview_mesh()


func _sanitize_crater_event(event: Dictionary) -> Dictionary:
	var radius := snappedf(float(event.get("radius", 0.0)), 0.001)
	var depth := snappedf(float(event.get("depth", 0.0)), 0.001)
	if radius <= 0.0 or depth <= 0.0:
		return {}
	return {
		"x": snappedf(float(event.get("x", 0.0)), 0.001),
		"z": snappedf(float(event.get("z", 0.0)), 0.001),
		"radius": radius,
		"depth": depth
	}


func _rebuild_terrain() -> void:
	_build_features()
	_crater_events.clear()

	if _terrain != null and _terrain.data != null:
		if _terrain.material != null:
			_terrain.material.show_checkered = false
		if use_imported_terrain3d_data:
			_rebuild_preview_mesh()
			_has_built_once = true
			return

		_terrain.region_size = Terrain3D.SIZE_64

		for center: Vector3 in region_centers:
			_terrain.data.add_region_blankp(center, true)
		for x: int in range(-generation_radius, generation_radius + 1):
			for z: int in range(-generation_radius, generation_radius + 1):
				var position := Vector3(float(x), 0.0, float(z))
				_terrain.data.set_height(position, _height(position.x, position.z))

		_terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)
		if build_terrain3d_collision and not Engine.is_editor_hint():
			_terrain.collision.mode = Terrain3DCollision.DYNAMIC_GAME
			_terrain.collision.build()
	_rebuild_preview_mesh()
	_has_built_once = true


func _apply_exported_settings() -> void:
	if generation_settings == null:
		return
	seed = generation_settings.seed
	generation_radius = generation_settings.generation_radius
	preview_subdivisions = generation_settings.preview_subdivisions
	height_scale = generation_settings.height_scale
	ridge_count = generation_settings.ridge_count
	ridge_strength = generation_settings.ridge_strength
	noise_frequency = generation_settings.noise_frequency
	noise_strength = generation_settings.noise_strength


func _build_features() -> void:
	_features.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed)
	for index: int in range(ridge_count):
		_features.append({
			"center": Vector2(
				rng.randf_range(-float(generation_radius) * 0.75, float(generation_radius) * 0.75),
				rng.randf_range(-float(generation_radius) * 0.75, float(generation_radius) * 0.75)
			),
			"radius_x": rng.randf_range(2.4, 8.0),
			"radius_z": rng.randf_range(3.0, 12.0),
			"strength": rng.randf_range(0.55, 1.0) * ridge_strength,
			"sign": -1.0 if rng.randf() < 0.25 else 1.0
		})


func _rebuild_preview_mesh() -> void:
	if not rebuild_preview_mesh_enabled or _preview_mesh == null:
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
			var position := Vector3(x, _deformed_height(x, z), z)
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
	_update_preview_collision(mesh)


func _update_preview_collision(mesh: ArrayMesh) -> void:
	if not build_preview_collision or _preview_collision_shape == null:
		return
	var shape := ConcavePolygonShape3D.new()
	shape.data = mesh.get_faces()
	_preview_collision_shape.shape = shape


func _height(x: float, z: float) -> float:
	var feature_height := 0.0
	for feature: Dictionary in _features:
		var center: Vector2 = feature["center"]
		var radius_x := float(feature["radius_x"])
		var radius_z := float(feature["radius_z"])
		var strength := float(feature["strength"])
		var sign := float(feature["sign"])
		feature_height += exp(
			-pow((x - center.x) / radius_x, 2.0)
			- pow((z - center.y) / radius_z, 2.0)
		) * strength * sign

	var seeded_phase := float(abs(seed) % 997) * 0.01
	var waves := (
		sin((x + seeded_phase) * noise_frequency)
		* cos((z - seeded_phase) * noise_frequency * 0.83)
	) * noise_strength
	return (feature_height + waves) * height_scale


func _deformed_height(x: float, z: float) -> float:
	var height := _height(x, z)
	return _apply_deformation_to_height(height, x, z)


func _apply_deformation_to_height(base_height: float, x: float, z: float) -> float:
	var height := base_height
	for event: Dictionary in _crater_events:
		var center := Vector2(float(event.get("x", 0.0)), float(event.get("z", 0.0)))
		var radius := float(event.get("radius", 0.0))
		if radius <= 0.0:
			continue
		var distance := Vector2(x - center.x, z - center.y).length()
		if distance > radius:
			continue
		var falloff := 1.0 - smoothstep(0.0, radius, distance)
		height -= float(event.get("depth", 0.0)) * falloff
	return height


func _apply_crater_visuals(event: Dictionary) -> void:
	if use_imported_terrain3d_data and apply_craters_to_terrain3d_data and _terrain != null and _terrain.data != null:
		_apply_crater_to_terrain3d_data(event)
		return
	_rebuild_preview_mesh()


func _apply_crater_to_terrain3d_data(event: Dictionary) -> void:
	var center := Vector3(float(event.get("x", 0.0)), 0.0, float(event.get("z", 0.0)))
	var radius := float(event.get("radius", 0.0))
	var depth := float(event.get("depth", 0.0))
	var step := maxf(0.25, terrain3d_crater_step)
	var sample_radius := ceili(radius / step)
	for x_index: int in range(-sample_radius, sample_radius + 1):
		for z_index: int in range(-sample_radius, sample_radius + 1):
			var offset := Vector2(float(x_index) * step, float(z_index) * step)
			var distance := offset.length()
			if distance > radius:
				continue
			var position := Vector3(center.x + offset.x, 0.0, center.z + offset.y)
			var current_height := _terrain.data.get_height(position)
			if is_nan(current_height) or is_inf(current_height):
				continue
			var falloff := 1.0 - smoothstep(0.0, radius, distance)
			_terrain.data.set_height(position, current_height - depth * falloff)
	_terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)
	if build_terrain3d_collision and not Engine.is_editor_hint():
		_terrain.collision.mode = Terrain3DCollision.DYNAMIC_GAME
		_terrain.collision.build()


func _reload_imported_terrain3d_data() -> void:
	if _terrain == null:
		return
	var data_directory := _terrain.data_directory
	if data_directory.is_empty():
		return
	_terrain.data_directory = ""
	_terrain.data_directory = data_directory
	if _terrain.data != null:
		_terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)


func _normal_from_height(position: Vector3) -> Vector3:
	var left := _deformed_height(position.x - sample_step, position.z)
	var right := _deformed_height(position.x + sample_step, position.z)
	var back := _deformed_height(position.x, position.z - sample_step)
	var forward := _deformed_height(position.x, position.z + sample_step)
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
