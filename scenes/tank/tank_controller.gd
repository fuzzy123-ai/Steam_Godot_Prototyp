extends CharacterBody3D

@export var forward_speed: float = 8.0
@export var reverse_speed: float = 4.0
@export var turn_speed: float = 1.8
@export var health: float = 100.0

@onready var turret_pivot: Node3D = %TurretPivot


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var drive_input := Input.get_axis("tank_reverse", "tank_forward")
	var turn_input := Input.get_axis("tank_turn_right", "tank_turn_left")
	rotate_y(turn_input * turn_speed * delta)

	var speed := forward_speed if drive_input >= 0.0 else reverse_speed
	velocity = -global_basis.z * drive_input * speed
	move_and_slide()

	_aim_turret_at_mouse()


func _aim_turret_at_mouse() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	var hit = ground_plane.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return

	var target := hit as Vector3
	var to_target := target - turret_pivot.global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.001:
		return
	turret_pivot.look_at(turret_pivot.global_position + to_target, Vector3.UP)
