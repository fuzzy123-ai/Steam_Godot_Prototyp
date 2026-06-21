extends Node3D

@export var placeholder_size: Vector2 = Vector2(48.0, 48.0)


func get_height_at(_world_position: Vector3) -> float:
	return 0.0


func get_normal_at(_world_position: Vector3) -> Vector3:
	return Vector3.UP
