extends Control

signal preview_ready(texture: Texture2D)

const DEFAULT_PREVIEW_SEED := 1001
const TERRAIN_CAPTURE_LAYER := 1 << 19

@export var preview_seed: int = DEFAULT_PREVIEW_SEED
@export_range(16, 160, 1) var preview_generation_radius: int = 72
@export_range(16.0, 160.0, 1.0) var camera_height: float = 90.0
@export_range(0.0, 32.0, 0.5) var map_padding: float = 8.0
@export var terrain_only_cull_mask: int = TERRAIN_CAPTURE_LAYER
@export var update_when_visible: bool = true

@onready var viewport: SubViewport = %PreviewViewport
@onready var terrain: Node3D = %PreviewTerrain
@onready var camera: Camera3D = %PreviewCamera

var _last_seed: int = 0


func _ready() -> void:
	_prepare_preview_terrain()
	apply_seed(preview_seed)


func apply_seed(new_seed: int) -> void:
	var next_seed := DEFAULT_PREVIEW_SEED if new_seed == 0 else new_seed
	if _last_seed == next_seed:
		return
	preview_seed = next_seed
	_last_seed = next_seed
	if terrain.has_method("apply_preview_seed"):
		terrain.call("apply_preview_seed", next_seed)
	elif terrain.has_method("apply_seed"):
		terrain.call("apply_seed", next_seed)
	_frame_entire_map()
	preview_ready.emit(get_preview_texture())


func refresh_preview() -> void:
	_last_seed = 0
	apply_seed(preview_seed)


func get_preview_texture() -> Texture2D:
	return viewport.get_texture()


func get_preview_terrain() -> Node3D:
	return terrain


func _prepare_preview_terrain() -> void:
	if terrain == null:
		return
	if terrain.get("use_imported_terrain3d_data") != null:
		terrain.set("use_imported_terrain3d_data", false)
	if terrain.get("rebuild_preview_mesh_enabled") != null:
		terrain.set("rebuild_preview_mesh_enabled", true)
	if terrain.get("build_preview_collision") != null:
		terrain.set("build_preview_collision", false)
	if terrain.get("generation_radius") != null:
		terrain.set("generation_radius", preview_generation_radius)
	var generation_settings = terrain.get("generation_settings")
	if generation_settings != null and generation_settings.get("generation_radius") != null:
		generation_settings.set("generation_radius", preview_generation_radius)
	var terrain3d := terrain.get_node_or_null("Terrain3D")
	if terrain3d is VisualInstance3D:
		(terrain3d as VisualInstance3D).visible = false
	var preview_mesh := terrain.get_node_or_null("PreviewMesh")
	if preview_mesh is MeshInstance3D:
		var mesh_instance := preview_mesh as MeshInstance3D
		mesh_instance.visible = true
		mesh_instance.layers = terrain_only_cull_mask


func _frame_entire_map() -> void:
	var radius := 30.0
	if terrain.get("generation_radius") != null:
		radius = float(terrain.get("generation_radius"))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.cull_mask = terrain_only_cull_mask
	camera.size = maxf(8.0, radius * 2.0 + map_padding)
	camera.global_position = terrain.global_position + Vector3(0.0, camera_height, 0.0)
	camera.global_rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.make_current()
