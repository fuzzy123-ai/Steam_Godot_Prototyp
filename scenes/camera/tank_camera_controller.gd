extends Node3D

@export var target_path: NodePath
@export var camera_path: NodePath = NodePath("Camera3D")
@export var follow_offset: Vector3 = Vector3.ZERO
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 8.0
@export_range(0.1, 60.0, 0.1) var zoom_speed: float = 12.0
@export_range(4.0, 80.0, 0.5) var min_orthographic_size: float = 10.0
@export_range(4.0, 120.0, 0.5) var max_orthographic_size: float = 36.0
@export_range(0.5, 12.0, 0.5) var zoom_step: float = 2.0

@onready var target: Node3D = get_node_or_null(target_path) as Node3D
@onready var camera: Camera3D = get_node_or_null(camera_path) as Camera3D

var _desired_orthographic_size: float = 22.0


func _ready() -> void:
	if camera != null:
		_desired_orthographic_size = clampf(
			camera.size,
			min_orthographic_size,
			max_orthographic_size
		)
		camera.size = _desired_orthographic_size
		if not camera.current:
			camera.make_current()
	if target != null:
		global_position = target.global_position + follow_offset


func _process(delta: float) -> void:
	if target != null:
		var desired_position := target.global_position + follow_offset
		global_position = global_position.lerp(
			desired_position,
			1.0 - exp(-follow_speed * delta)
		)

	if camera != null:
		camera.size = lerpf(
			camera.size,
			_desired_orthographic_size,
			1.0 - exp(-zoom_speed * delta)
		)


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(-zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(zoom_step)


func _zoom_by(amount: float) -> void:
	_desired_orthographic_size = clampf(
		_desired_orthographic_size + amount,
		min_orthographic_size,
		max_orthographic_size
	)
