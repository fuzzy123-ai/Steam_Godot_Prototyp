extends Resource
class_name TerrainGenerationSettings

@export var seed: int = 1001
@export_range(16, 96, 1) var generation_radius: int = 30
@export_range(8, 128, 1) var preview_subdivisions: int = 56
@export_range(0.2, 8.0, 0.1) var height_scale: float = 2.4
@export_range(0, 12, 1) var ridge_count: int = 5
@export_range(0.0, 8.0, 0.1) var ridge_strength: float = 2.4
@export_range(0.01, 1.0, 0.01) var noise_frequency: float = 0.18
@export_range(0.0, 4.0, 0.1) var noise_strength: float = 0.35
@export_range(0.0, 16.0, 0.5) var capture_flatten_radius: float = 5.0
@export_range(0.0, 16.0, 0.5) var spawn_flatten_radius: float = 4.0
