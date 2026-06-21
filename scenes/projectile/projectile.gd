extends Area3D

signal impacted(hit_data: Dictionary)

@export var speed: float = 40.0
@export var lifetime_seconds: float = 4.0
@export var explosion_radius: float = 5.0
@export var max_damage: float = 35.0
@export_flags_3d_physics var collision_query_mask: int = 1
@export var terrain_hit_enabled: bool = true
@export_range(0.0, 1.0, 0.05) var terrain_hit_clearance: float = 0.05
@export var crater_on_terrain_hit: bool = true
@export_range(0.25, 12.0, 0.25) var crater_radius: float = 3.0
@export_range(0.1, 6.0, 0.1) var crater_depth: float = 1.2

var _age: float = 0.0
var _direction := Vector3.FORWARD
var _source: Node
var _source_rid: RID
var _terrain_probe: Node


func _ready() -> void:
	_terrain_probe = get_tree().get_first_node_in_group("terrain_probe")


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime_seconds:
		queue_free()
		return

	var start := global_position
	var end := start + _direction * speed * delta
	var terrain_hit := _intersect_terrain(start, end)
	if terrain_hit.has("position"):
		_handle_impact(terrain_hit)
		return

	var exclude: Array[RID] = []
	if _source_rid.is_valid():
		exclude.append(_source_rid)
	var query := PhysicsRayQueryParameters3D.create(start, end, collision_query_mask, exclude)
	query.hit_from_inside = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_handle_impact(hit)
		return

	global_position = end


func launch(source: Node, direction: Vector3, launch_speed: float, damage: float) -> void:
	_source = source
	if source is CollisionObject3D:
		_source_rid = (source as CollisionObject3D).get_rid()
	_direction = direction.normalized()
	speed = launch_speed
	max_damage = damage
	if _direction.length_squared() > 0.001:
		var up_direction := Vector3.UP
		if absf(_direction.dot(Vector3.UP)) > 0.98:
			up_direction = Vector3.RIGHT
		look_at(global_position + _direction, up_direction)


func set_terrain_probe(terrain_probe: Node) -> void:
	_terrain_probe = terrain_probe


func _handle_impact(hit: Dictionary) -> void:
	global_position = hit["position"]
	var target: Node = hit.get("collider")
	if crater_on_terrain_hit and target != null and target.has_method("apply_crater"):
		target.call("apply_crater", global_position, crater_radius, crater_depth)
	var hit_data := {
		"position": hit["position"],
		"normal": hit["normal"],
		"target": target,
		"target_rid": hit.get("rid", RID()),
		"source": _source,
		"owner_peer_id": multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1,
		"damage": max_damage,
		"shot_direction": _direction,
		"projectile": self,
		"hit_zone": StringName(&"unknown")
	}
	impacted.emit(hit_data)
	if target != null and target.has_method("apply_hit"):
		target.call("apply_hit", hit_data)
	queue_free()


func _intersect_terrain(start: Vector3, end: Vector3) -> Dictionary:
	if not terrain_hit_enabled or _terrain_probe == null or not _terrain_probe.has_method("get_height_at"):
		return {}

	var start_height := float(_terrain_probe.call("get_height_at", start)) + terrain_hit_clearance
	var end_height := float(_terrain_probe.call("get_height_at", end)) + terrain_hit_clearance
	if start.y <= start_height:
		return {
			"position": start,
			"normal": _terrain_normal(start),
			"collider": _terrain_probe,
			"rid": RID()
		}
	if end.y > end_height:
		return {}

	var low := start
	var high := end
	for _step: int in range(6):
		var mid := low.lerp(high, 0.5)
		var mid_height := float(_terrain_probe.call("get_height_at", mid)) + terrain_hit_clearance
		if mid.y > mid_height:
			low = mid
		else:
			high = mid
	return {
		"position": high,
		"normal": _terrain_normal(high),
		"collider": _terrain_probe,
		"rid": RID()
	}


func _terrain_normal(position: Vector3) -> Vector3:
	if _terrain_probe != null and _terrain_probe.has_method("get_normal_at"):
		return (_terrain_probe.call("get_normal_at", position) as Vector3).normalized()
	return Vector3.UP
