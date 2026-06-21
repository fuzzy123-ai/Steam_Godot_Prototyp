extends Resource
class_name CapturePointSettings

@export_range(0.5, 60.0, 0.5) var capture_seconds: float = 5.0
@export_range(0.5, 60.0, 0.5) var neutralize_seconds: float = 4.0
@export_range(1.0, 16.0, 0.5) var radius: float = 4.0
@export_range(0.0, 10.0, 0.1) var score_per_second: float = 1.0
@export var requires_stationary: bool = false
@export var contest_blocks_progress: bool = true
