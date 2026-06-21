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
	var debug_menu := game.get_node("UI/DebugMenu")
	var definition: Resource = tank.get("vehicle_definition")
	var terrain_fingerprint_before := str(terrain.call("get_generation_fingerprint"))
	print("STEP visible world=", game.get_node("World").visible, " hud=", game.get_node("UI/MatchHud").visible)
	print("STEP terrain=", terrain_fingerprint_before)
	print("STEP tank=", definition.get("vehicle_id") if definition != null else "none")
	print("STEP ammo=", tank.get("current_ammo"), "/", tank.get("ammo_capacity"))
	print("STEP hp=", tank.get("health"), "/", tank.get("max_health"))
	if debug_menu == null or not debug_menu.has_method("toggle_debug"):
		print("FAIL debug menu missing")
		quit(1)
		return
	debug_menu.call("toggle_debug")
	await process_frame
	print("STEP debug menu visible=", debug_menu.visible)
	if not debug_menu.visible:
		print("FAIL debug menu toggle")
		quit(1)
		return
	debug_menu.call("toggle_debug")

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
	if not terrain.has_method("get_crater_events") or not terrain.has_method("apply_crater_events") or not terrain.has_method("get_deformation_fingerprint"):
		print("FAIL terrain crater replay API missing")
		quit(1)
		return
	var crater_events: Array = terrain.call("get_crater_events")
	if crater_events.size() != 1:
		print("FAIL crater event count=", crater_events.size())
		quit(1)
		return
	var first_event: Dictionary = crater_events[0]
	for key: String in ["x", "z", "radius", "depth"]:
		if not first_event.has(key):
			print("FAIL crater event missing key=", key)
			quit(1)
			return

	var terrain_scene := load("res://scenes/terrain/terrain_world.tscn") as PackedScene
	if terrain_scene == null:
		print("FAIL terrain scene")
		quit(1)
		return
	var replay_terrain := terrain_scene.instantiate()
	root.add_child(replay_terrain)
	await process_frame
	if replay_terrain.has_method("apply_seed"):
		replay_terrain.call("apply_seed", int(terrain.get("seed")))
	replay_terrain.call("apply_crater_events", crater_events, true, false)
	var replay_height := float(replay_terrain.call("get_height_at", crater_center))
	var replay_fingerprint := str(replay_terrain.call("get_generation_fingerprint"))
	print("STEP crater replay height=", replay_height, " terrain=", replay_fingerprint)
	if absf(replay_height - height_after) > 0.01 or replay_fingerprint != terrain_fingerprint_after:
		print("FAIL crater replay mismatch")
		quit(1)
		return
	replay_terrain.call("apply_crater_events", crater_events, true, false)
	var replay_again_fingerprint := str(replay_terrain.call("get_generation_fingerprint"))
	if replay_again_fingerprint != replay_fingerprint:
		print("FAIL crater replay idempotence")
		quit(1)
		return
	replay_terrain.queue_free()

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
	if terrain.has_method("clear_deformations"):
		terrain.call("clear_deformations")

	var visual_projectile: Node = projectile_scene.instantiate()
	game.get_node("World/Projectiles").add_child(visual_projectile)
	var visual_projectile_node := visual_projectile as Node3D
	var visual_center := Vector3(3.0, 0.0, -5.0)
	var visual_height_before := float(terrain.call("get_height_at", visual_center))
	var visual_fingerprint_before := str(terrain.call("get_generation_fingerprint"))
	visual_projectile_node.global_position = Vector3(visual_center.x, visual_height_before + 3.0, visual_center.z)
	if visual_projectile.has_method("set_terrain_probe"):
		visual_projectile.call("set_terrain_probe", terrain)
	visual_projectile.set("gameplay_effects_enabled", false)
	visual_projectile.set("crater_radius", 2.5)
	visual_projectile.set("crater_depth", 0.9)
	visual_projectile.call("launch", tank, Vector3.DOWN, 24.0, 10.0)
	await create_timer(0.35).timeout
	var visual_height_after := float(terrain.call("get_height_at", visual_center))
	var visual_fingerprint_after := str(terrain.call("get_generation_fingerprint"))
	print("STEP visual projectile terrain=", visual_height_before, "->", visual_height_after, " fingerprint=", visual_fingerprint_after)
	if absf(visual_height_after - visual_height_before) > 0.01 or visual_fingerprint_after != visual_fingerprint_before:
		print("FAIL visual projectile changed terrain")
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
