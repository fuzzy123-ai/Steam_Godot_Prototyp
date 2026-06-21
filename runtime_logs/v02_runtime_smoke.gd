extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/tank_game/tank_game.tscn") as PackedScene
	if packed == null:
		print("FAIL load tank_game")
		quit(1)
		return

	var game := packed.instantiate()
	root.add_child(game)
	await process_frame

	print("STEP ready")
	var lobby := game.get_node("UI/LobbyStartScreen")
	var setup: Dictionary = lobby.call("get_match_setup")
	print("STEP setup tank=", setup.get("tank_id", ""), " seed=", setup.get("seed", -1))

	var prepared: Dictionary = game.call("_prepare_match_setup", setup)
	print("STEP prepared vehicle=", prepared.get("vehicle_id", ""), " seed=", prepared.get("seed", -1))

	print("STEP start")
	game.call("_start_match", prepared)
	await create_timer(0.8).timeout

	var terrain := game.get_node("World/Terrain")
	var tank := game.get_node("World/Tanks/PreviewTank")
	var definition: Resource = tank.get("vehicle_definition")
	var terrain_fingerprint_before := str(terrain.call("get_generation_fingerprint"))
	print("STEP visible world=", game.get_node("World").visible, " hud=", game.get_node("UI/MatchHud").visible)
	print("STEP terrain=", terrain_fingerprint_before)
	print("STEP tank=", definition.get("vehicle_id") if definition != null else "none")
	print("STEP ammo=", tank.get("current_ammo"), "/", tank.get("ammo_capacity"))
	print("STEP hp=", tank.get("health"), "/", tank.get("max_health"))

	if not terrain.has_method("apply_crater") or not terrain.has_method("get_height_at") or not terrain.has_method("get_generation_fingerprint"):
		print("FAIL terrain deformation API missing; HANDOFF Charlie: wire apply_crater/get_height_at/get_generation_fingerprint on World/Terrain")
		quit(1)
		return

	var crater_center := Vector3(6.0, 0.0, 6.0)
	var crater_radius := 3.0
	var crater_depth := 1.25
	var height_before := float(terrain.call("get_height_at", crater_center))
	var crater_applied := bool(terrain.call("apply_crater", crater_center, crater_radius, crater_depth))
	var height_after := float(terrain.call("get_height_at", crater_center))
	var terrain_fingerprint_after := str(terrain.call("get_generation_fingerprint"))
	print("STEP crater applied=", crater_applied, " height=", height_before, "->", height_after, " terrain=", terrain_fingerprint_after)
	if not crater_applied or height_after >= height_before:
		print("FAIL crater height")
		quit(1)
		return
	if terrain_fingerprint_after == terrain_fingerprint_before:
		print("FAIL crater fingerprint")
		quit(1)
		return

	if terrain.has_method("clear_deformations"):
		terrain.call("clear_deformations")

	var projectile_scene := load("res://scenes/projectile/projectile.tscn") as PackedScene
	if projectile_scene == null:
		print("FAIL projectile scene")
		quit(1)
		return
	var projectile: Node = projectile_scene.instantiate()
	game.get_node("World/Projectiles").add_child(projectile)
	var projectile_node := projectile as Node3D
	var projectile_center := Vector3(-4.0, 0.0, -4.0)
	var projectile_height_before := float(terrain.call("get_height_at", projectile_center))
	var projectile_fingerprint_before := str(terrain.call("get_generation_fingerprint"))
	projectile_node.global_position = Vector3(projectile_center.x, projectile_height_before + 3.0, projectile_center.z)
	if projectile.has_method("set_terrain_probe"):
		projectile.call("set_terrain_probe", terrain)
	projectile.set("crater_radius", 2.5)
	projectile.set("crater_depth", 0.9)
	projectile.call("launch", tank, Vector3.DOWN, 24.0, 10.0)
	await create_timer(0.35).timeout
	var projectile_height_after := float(terrain.call("get_height_at", projectile_center))
	var projectile_fingerprint_after := str(terrain.call("get_generation_fingerprint"))
	print("STEP projectile crater height=", projectile_height_before, "->", projectile_height_after, " terrain=", projectile_fingerprint_after)
	if projectile_height_after >= projectile_height_before:
		print("FAIL projectile crater height")
		quit(1)
		return
	if projectile_fingerprint_after == projectile_fingerprint_before:
		print("FAIL projectile crater fingerprint")
		quit(1)
		return

	var ammo_before := int(tank.get("current_ammo"))
	tank.set("_aim_is_blocked", false)
	tank.call("_try_fire")
	await process_frame
	var ammo_after := int(tank.get("current_ammo"))
	var reload_remaining := float(tank.get("_fire_cooldown_remaining"))
	print("STEP fire ammo=", ammo_before, "->", ammo_after, " reload=", reload_remaining)
	if ammo_after != ammo_before - 1 or reload_remaining <= 0.0:
		print("FAIL ammo/reload")
		quit(1)
		return

	var alpha := game.get_node("World/CapturePoints/Alpha")
	var progress_before := float(alpha.get("capture_progress"))
	alpha.call("_on_body_entered", tank)
	await create_timer(0.35).timeout
	var progress_after := float(alpha.get("capture_progress"))
	print("STEP capture=", progress_before, "->", progress_after, " state=", alpha.get("state"))
	if progress_after <= progress_before:
		print("FAIL capture progress")
		quit(1)
		return

	print("PASS v02 runtime smoke")
	quit(0)
