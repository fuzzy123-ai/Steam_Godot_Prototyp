extends Node3D

@export var visible_mesh_names: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			if not visible_mesh_names.has(child.name):
				child.queue_free()
		elif child is Node3D:
			child.queue_free()
