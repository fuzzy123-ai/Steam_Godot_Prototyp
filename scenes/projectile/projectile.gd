extends Area3D

@export var speed: float = 40.0
@export var lifetime_seconds: float = 4.0
@export var explosion_radius: float = 5.0
@export var max_damage: float = 35.0

var _age: float = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime_seconds:
		queue_free()
		return
	global_position += -global_basis.z * speed * delta
