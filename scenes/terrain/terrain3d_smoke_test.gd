extends Node3D

@export var crater_radius: int = 6
@export var crater_depth: float = 4.0
@export var base_height: float = 6.0
@export var test_center: Vector3 = Vector3(32.0, 0.0, 32.0)

var terrain: Terrain3D


func _ready() -> void:
	var success := _run_smoke_test()
	if success:
		print("TERRAIN3D_SMOKE_OK")
	else:
		push_error("TERRAIN3D_SMOKE_FAILED")
		get_tree().quit(1)


func _run_smoke_test() -> bool:
	if not ClassDB.class_exists("Terrain3D"):
		push_error("Terrain3D class is not registered.")
		return false

	terrain = Terrain3D.new()
	terrain.name = "RuntimeTerrain3D"
	terrain.region_size = Terrain3D.SIZE_64
	add_child(terrain, true)

	terrain.data.add_region_blankp(test_center, true)
	_seed_mound(test_center, 16)
	terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)
	terrain.collision.mode = Terrain3DCollision.DYNAMIC_GAME
	terrain.collision.build()

	var before_height := terrain.data.get_height(test_center)
	_apply_crater(test_center, crater_radius, crater_depth)
	var after_height := terrain.data.get_height(test_center)

	print("Terrain3D smoke height before=%s after=%s" % [before_height, after_height])
	return after_height < before_height


func _seed_mound(center: Vector3, radius: int) -> void:
	for x: int in range(-radius, radius + 1):
		for z: int in range(-radius, radius + 1):
			var offset := Vector2(float(x), float(z))
			var distance := offset.length()
			if distance > float(radius):
				continue
			var position := center + Vector3(float(x), 0.0, float(z))
			var falloff := 1.0 - distance / float(radius)
			terrain.data.set_height(position, base_height * falloff)


func _apply_crater(center: Vector3, radius: int, depth: float) -> void:
	for x: int in range(-radius, radius + 1):
		for z: int in range(-radius, radius + 1):
			var offset := Vector2(float(x), float(z))
			var distance := offset.length()
			if distance > float(radius):
				continue
			var position := center + Vector3(float(x), 0.0, float(z))
			var current_height := terrain.data.get_height(position)
			var falloff := 1.0 - distance / float(radius)
			terrain.data.set_height(position, current_height - depth * falloff)

	terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, true, false)
	terrain.collision.update(true)
