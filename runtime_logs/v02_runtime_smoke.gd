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
	print("STEP visible world=", game.get_node("World").visible, " hud=", game.get_node("UI/MatchHud").visible)
	print("STEP terrain=", terrain.call("get_generation_fingerprint"))
	print("STEP tank=", definition.get("vehicle_id") if definition != null else "none")
	print("STEP ammo=", tank.get("current_ammo"), "/", tank.get("ammo_capacity"))
	print("STEP hp=", tank.get("health"), "/", tank.get("max_health"))

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
