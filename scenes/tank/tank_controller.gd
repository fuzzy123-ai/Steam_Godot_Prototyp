extends CharacterBody3D

@export var forward_speed: float = 8.0
@export var reverse_speed: float = 4.0
@export var track_turn_speed: float = 1.8
@export var health: float = 100.0
@export var aim_line_width: float = 0.08
@export var aim_line_height: float = 0.08
@export_flags_3d_physics var aim_obstruction_mask: int = 0xFFFFFFFF
@export var aim_clear_material: Material
@export var aim_blocked_material: Material

@onready var turret_pivot: Node3D = %TurretPivot
@onready var muzzle: Marker3D = %Muzzle
@onready var aim_line: MeshInstance3D = %AimLine

var _aim_target: Vector3
var _has_aim_target := false
var _aim_is_blocked := false


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var drive_input := Input.get_axis("tank_reverse", "tank_forward")
	var turn_input := Input.get_axis("tank_turn_right", "tank_turn_left")
	var left_track := clampf(drive_input + turn_input, -1.0, 1.0)
	var right_track := clampf(drive_input - turn_input, -1.0, 1.0)
	var linear_input := (left_track + right_track) * 0.5
	var angular_input := (left_track - right_track) * 0.5

	rotate_y(angular_input * track_turn_speed * delta)

	var speed := forward_speed if linear_input >= 0.0 else reverse_speed
	velocity = -global_basis.z * linear_input * speed
	move_and_slide()

	_aim_turret_at_mouse()
	_update_aim_line()


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
	_aim_target = target
	_has_aim_target = true

	var to_target := target - turret_pivot.global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.001:
		return
	turret_pivot.look_at(turret_pivot.global_position + to_target, Vector3.UP)


func _update_aim_line() -> void:
	if not _has_aim_target:
		aim_line.hide()
		return

	var start := muzzle.global_position
	var end := Vector3(_aim_target.x, start.y, _aim_target.z)
	var to_end := end - start
	if to_end.length_squared() <= 0.001:
		aim_line.hide()
		return

	var query := PhysicsRayQueryParameters3D.create(start, end, aim_obstruction_mask, [get_rid()])
	query.hit_from_inside = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_aim_is_blocked = not hit.is_empty()
	if _aim_is_blocked:
		end = hit["position"]

	aim_line.show()
	aim_line.material_override = aim_blocked_material if _aim_is_blocked else aim_clear_material
	_draw_aim_line(
		aim_line.to_local(start + Vector3.UP * aim_line_height),
		aim_line.to_local(end + Vector3.UP * aim_line_height)
	)


func _draw_aim_line(start: Vector3, end: Vector3) -> void:
	var mesh := aim_line.mesh as ImmediateMesh
	if mesh == null:
		mesh = ImmediateMesh.new()
		aim_line.mesh = mesh

	var direction := end - start
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var side := direction.cross(Vector3.UP).normalized() * aim_line_width * 0.5

	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.surface_add_vertex(start - side)
	mesh.surface_add_vertex(start + side)
	mesh.surface_add_vertex(end + side)
	mesh.surface_add_vertex(start - side)
	mesh.surface_add_vertex(end + side)
	mesh.surface_add_vertex(end - side)
	mesh.surface_end()
