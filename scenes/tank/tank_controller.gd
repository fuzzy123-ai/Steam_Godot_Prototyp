extends CharacterBody3D

const VehicleStatsScript := preload("res://scenes/tank/vehicle_stats.gd")
const WeaponStatsScript := preload("res://scenes/tank/weapon_stats.gd")

signal health_changed(current_health: float, max_health: float)
signal ammo_changed(current_ammo: int, ammo_capacity: int)
signal reload_changed(reload_remaining: float, reload_seconds: float)

@export var stats: Resource
@export var weapon_stats: Resource
@export var vehicle_definition: Resource
@export var aim_line_width: float = 0.08
@export var aim_line_height: float = 0.08
@export var aim_target_tolerance: float = 0.35
@export_flags_3d_physics var aim_obstruction_mask: int = 0xFFFFFFFF
@export var aim_clear_material: Material
@export var aim_blocked_material: Material
@export var projectile_scene: PackedScene
@export var projectile_parent_path: NodePath
@export var terrain_probe_path: NodePath
@export var terrain_snap_enabled: bool = true
@export var terrain_snap_offset: float = 0.02
@export var terrain_sample_forward_extent: float = 0.95
@export var terrain_sample_side_extent: float = 0.65

@onready var turret_pivot: Node3D = %TurretPivot
@onready var muzzle: Marker3D = %Muzzle
@onready var aim_line: MeshInstance3D = %AimLine

var _aim_target: Vector3
var _has_aim_target := false
var _aim_is_blocked := false
var _active_stats: Resource
var _active_weapon_stats: Resource
var max_health: float = 100.0
var health: float = 100.0
var _fire_cooldown_remaining := 0.0
var current_ammo: int = 0
var ammo_capacity: int = 0
var _terrain_probe: Node
var current_slope_angle_degrees: float = 0.0
var current_slope_speed_factor: float = 1.0


func _ready() -> void:
	if vehicle_definition != null:
		apply_vehicle_definition(vehicle_definition)
	else:
		_active_stats = stats if stats != null else VehicleStatsScript.new()
		_active_weapon_stats = weapon_stats if weapon_stats != null else WeaponStatsScript.new()
		_reset_combat_state()
	_terrain_probe = get_node_or_null(terrain_probe_path) if not terrain_probe_path.is_empty() else null


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	_fire_cooldown_remaining = maxf(0.0, _fire_cooldown_remaining - delta)
	reload_changed.emit(_fire_cooldown_remaining, _weapon_float(&"reload_seconds", _stat_float(&"fire_cooldown_seconds", 0.8)))

	var drive_input := Input.get_axis("tank_reverse", "tank_forward")
	var turn_input := Input.get_axis("tank_turn_right", "tank_turn_left")
	var left_track := clampf(drive_input + turn_input, -1.0, 1.0)
	var right_track := clampf(drive_input - turn_input, -1.0, 1.0)
	var linear_input := (left_track + right_track) * 0.5
	var angular_input := (left_track - right_track) * 0.5

	rotate_y(angular_input * _stat_float(&"track_turn_speed", 1.8) * delta)
	_update_terrain_sample()

	var speed: float = _stat_float(&"max_forward_speed", 8.0) if linear_input >= 0.0 else _stat_float(&"max_reverse_speed", 4.0)
	velocity = -global_basis.z * linear_input * speed * current_slope_speed_factor
	move_and_slide()

	_aim_turret_at_mouse(delta)
	_update_aim_line()
	if Input.is_action_just_pressed("tank_fire"):
		_try_fire()


func _aim_turret_at_mouse(delta: float) -> void:
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

	_set_aim_target(hit as Vector3, delta)


func _set_aim_target(target: Vector3, delta: float) -> void:
	_aim_target = target
	_has_aim_target = true

	var to_target := target - turret_pivot.global_position
	to_target.y = 0.0
	if to_target.length_squared() <= 0.001:
		return
	var target_yaw := atan2(-to_target.x, -to_target.z)
	var turret_global_rotation := turret_pivot.global_rotation
	turret_global_rotation.y = rotate_toward(
		turret_global_rotation.y,
		target_yaw,
		_stat_float(&"turret_turn_speed", 8.0) * delta
	)
	turret_pivot.global_rotation = turret_global_rotation


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

	var line_offset := Vector3.UP * aim_line_height
	var query := PhysicsRayQueryParameters3D.create(start + line_offset, end + line_offset, aim_obstruction_mask, [get_rid()])
	query.hit_from_inside = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_aim_is_blocked = not hit.is_empty()
	if _aim_is_blocked:
		var hit_position: Vector3 = hit["position"]
		_aim_is_blocked = hit_position.distance_to(end) > aim_target_tolerance

	aim_line.show()
	aim_line.material_override = aim_blocked_material if _aim_is_blocked else aim_clear_material
	_draw_aim_line(
		aim_line.to_local(start + line_offset),
		aim_line.to_local(end + line_offset)
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


func _try_fire() -> void:
	var active_projectile_scene := _weapon_scene(&"spawned_projectile", projectile_scene)
	if active_projectile_scene == null or _fire_cooldown_remaining > 0.0:
		return
	if current_ammo <= 0:
		ammo_changed.emit(current_ammo, ammo_capacity)
		return
	if _weapon_bool(&"line_of_fire_required", false) and _aim_is_blocked:
		return

	var projectile := active_projectile_scene.instantiate()
	if not projectile is Node3D:
		projectile.queue_free()
		return

	var parent := get_node_or_null(projectile_parent_path) if not projectile_parent_path.is_empty() else null
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		parent = get_parent()

	parent.add_child(projectile)
	var projectile_node := projectile as Node3D
	projectile_node.global_transform = muzzle.global_transform
	if projectile.has_method("launch"):
		projectile.call(
			"launch",
			self,
			_get_turret_forward(),
			_weapon_float(&"projectile_speed", _stat_float(&"shot_speed", 42.0)),
			_weapon_float(&"damage", _stat_float(&"shot_damage", 35.0))
		)
	current_ammo = maxi(0, current_ammo - 1)
	ammo_changed.emit(current_ammo, ammo_capacity)
	_fire_cooldown_remaining = _weapon_float(&"reload_seconds", _stat_float(&"fire_cooldown_seconds", 0.8))
	reload_changed.emit(_fire_cooldown_remaining, _fire_cooldown_remaining)


func _get_turret_forward() -> Vector3:
	return -turret_pivot.global_basis.z.normalized()


func _update_terrain_sample() -> void:
	if _terrain_probe == null:
		current_slope_angle_degrees = 0.0
		current_slope_speed_factor = 1.0
		return

	var normal := _sample_terrain_normal()
	current_slope_angle_degrees = rad_to_deg(normal.angle_to(Vector3.UP))
	current_slope_speed_factor = _calculate_slope_speed_factor(current_slope_angle_degrees)

	if terrain_snap_enabled and _terrain_probe.has_method("get_height_at"):
		var height := float(_terrain_probe.call("get_height_at", global_position))
		global_position.y = height + terrain_snap_offset


func _sample_terrain_normal() -> Vector3:
	if not _terrain_probe.has_method("get_normal_at"):
		return Vector3.UP

	var forward := -global_basis.z.normalized()
	var right := global_basis.x.normalized()
	var sample_points: Array[Vector3] = [
		global_position,
		global_position + forward * terrain_sample_forward_extent,
		global_position - forward * terrain_sample_forward_extent,
		global_position + right * terrain_sample_side_extent,
		global_position - right * terrain_sample_side_extent
	]
	var normal_sum := Vector3.ZERO
	for point: Vector3 in sample_points:
		normal_sum += (_terrain_probe.call("get_normal_at", point) as Vector3).normalized()
	if normal_sum.length_squared() <= 0.001:
		return Vector3.UP
	return normal_sum.normalized()


func _calculate_slope_speed_factor(slope_angle_degrees: float) -> float:
	var start_angle := _stat_float(&"slope_start_angle_degrees", 8.0)
	var max_angle := maxf(start_angle + 0.001, _stat_float(&"max_climb_angle_degrees", 35.0))
	var slope_t := smoothstep(start_angle, max_angle, slope_angle_degrees)
	var strength := clampf(_stat_float(&"slope_slowdown_strength", 0.65), 0.0, 1.0)
	var min_factor := clampf(_stat_float(&"min_slope_speed_factor", 0.35), 0.05, 1.0)
	return lerpf(1.0, min_factor, clampf(slope_t * strength, 0.0, 1.0))


func apply_vehicle_definition(definition: Resource) -> void:
	vehicle_definition = definition
	var definition_stats = definition.get(&"stats")
	var definition_weapon_stats = definition.get(&"weapon_stats")
	_active_stats = definition_stats if definition_stats != null else (stats if stats != null else VehicleStatsScript.new())
	_active_weapon_stats = definition_weapon_stats if definition_weapon_stats != null else (weapon_stats if weapon_stats != null else WeaponStatsScript.new())
	stats = _active_stats
	weapon_stats = _active_weapon_stats
	_reset_combat_state()


func apply_hit(hit_data: Dictionary) -> void:
	var damage := float(hit_data.get("damage", 0.0))
	health = maxf(0.0, health - damage)
	health_changed.emit(health, max_health)


func reset_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func _reset_combat_state() -> void:
	max_health = _stat_float(&"health", 100.0)
	health = max_health
	ammo_capacity = _weapon_int(&"ammo_capacity", 0)
	current_ammo = ammo_capacity
	_fire_cooldown_remaining = 0.0
	health_changed.emit(health, max_health)
	ammo_changed.emit(current_ammo, ammo_capacity)
	reload_changed.emit(0.0, _weapon_float(&"reload_seconds", _stat_float(&"fire_cooldown_seconds", 0.8)))


func _stat_float(property_name: StringName, fallback: float) -> float:
	if _active_stats == null:
		return fallback
	var value = _active_stats.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _weapon_float(property_name: StringName, fallback: float) -> float:
	if _active_weapon_stats == null:
		return fallback
	var value = _active_weapon_stats.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _weapon_int(property_name: StringName, fallback: int) -> int:
	if _active_weapon_stats == null:
		return fallback
	var value = _active_weapon_stats.get(property_name)
	if value == null:
		return fallback
	return int(value)


func _weapon_bool(property_name: StringName, fallback: bool) -> bool:
	if _active_weapon_stats == null:
		return fallback
	var value = _active_weapon_stats.get(property_name)
	if value == null:
		return fallback
	return bool(value)


func _weapon_scene(property_name: StringName, fallback: PackedScene) -> PackedScene:
	if _active_weapon_stats == null:
		return fallback
	var value = _active_weapon_stats.get(property_name)
	if value is PackedScene:
		return value
	return fallback
