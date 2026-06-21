extends StaticBody3D

signal health_changed(health: float, max_health: float)
signal hit_received(hit_data: Dictionary)

@export var max_health: float = 100.0
@export var alive_material: Material
@export var damaged_material: Material

@onready var mesh_instance: MeshInstance3D = %MeshInstance3D

var health: float
var last_hit_data: Dictionary = {}


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func apply_hit(hit_data: Dictionary) -> void:
	last_hit_data = hit_data.duplicate()
	var damage := float(hit_data.get("damage", 0.0))
	health = maxf(0.0, health - damage)
	if damaged_material != null:
		mesh_instance.material_override = damaged_material
	hit_received.emit(last_hit_data)
	health_changed.emit(health, max_health)


func reset_health() -> void:
	health = max_health
	if alive_material != null:
		mesh_instance.material_override = alive_material
	health_changed.emit(health, max_health)
