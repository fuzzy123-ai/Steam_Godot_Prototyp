extends Area3D

signal impacted(hit_data: Dictionary)

@export var speed: float = 40.0
@export var lifetime_seconds: float = 4.0
@export var explosion_radius: float = 5.0
@export var max_damage: float = 35.0
@export_flags_3d_physics var collision_query_mask: int = 0xFFFFFFFF

var _age: float = 0.0
var _direction := Vector3.FORWARD
var _source: Node
var _source_rid: RID


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime_seconds:
		queue_free()
		return

	var start := global_position
	var end := start + _direction * speed * delta
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
		look_at(global_position + _direction, Vector3.UP)


func _handle_impact(hit: Dictionary) -> void:
	global_position = hit["position"]
	var target: Node = hit.get("collider")
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
