@tool
extends Node3D

@export var mech_material: Material:
	set(value):
		mech_material = value
		if is_inside_tree():
			_apply_materials()


func _ready() -> void:
	_apply_materials()


func get_mesh_count() -> int:
	return _collect_meshes(self).size()


func _apply_materials() -> void:
	if mech_material == null:
		return
	for mesh_instance: MeshInstance3D in _collect_meshes(self):
		mesh_instance.material_override = mech_material


func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		meshes.append_array(_collect_meshes(child))
	return meshes
