extends Node

@onready var world: Node3D = %World
@onready var lobby_start_screen: Control = %LobbyStartScreen
@onready var match_status_label: Label = %MatchStatusLabel
@onready var match_hud: Control = %MatchHud
@onready var debug_menu: Control = %DebugMenu
@onready var preview_tank: Node3D = %PreviewTank
@onready var terrain: Node3D = %Terrain
@onready var capture_points: Node3D = %CapturePoints
@onready var projectiles: Node3D = $World/Projectiles

@export var default_vehicle_definition: Resource
@export var vehicle_definitions: Array[Resource] = []
@export var sync_projectile_spawns: bool = true
@export var synced_projectile_scene: PackedScene

var match_started: bool = false


func _ready() -> void:
	world.hide()
	match_status_label.hide()
	match_hud.hide()
	lobby_start_screen.start_match_requested.connect(_on_start_match_requested)
	if terrain != null and terrain.has_signal("crater_applied"):
		terrain.crater_applied.connect(_on_terrain_crater_applied)
	if preview_tank != null and preview_tank.has_signal("projectile_fired"):
		preview_tank.connect("projectile_fired", Callable(self, "_on_tank_projectile_fired"))


func _on_start_match_requested(match_setup: Dictionary = {}) -> void:
	match_setup = _prepare_match_setup(match_setup)
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return
		_start_match(match_setup)
		_start_match.rpc(match_setup)
	else:
		_start_match(match_setup)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F1:
			if debug_menu != null and debug_menu.has_method("toggle_debug"):
				debug_menu.call("toggle_debug")
				get_viewport().set_input_as_handled()


@rpc("authority", "reliable")
func _start_match(match_setup: Dictionary = {}) -> void:
	if match_started:
		return
	match_started = true
	if lobby_start_screen.has_method("show_loading"):
		lobby_start_screen.call("show_loading", "Validating match setup", 30.0)
	await get_tree().create_timer(0.25).timeout
	_apply_match_setup(match_setup)
	if lobby_start_screen.has_method("show_loading"):
		lobby_start_screen.call("show_loading", "Preparing match world", 65.0)
	await get_tree().create_timer(0.25).timeout
	lobby_start_screen.hide()
	world.show()
	match_hud.show()
	if match_hud.has_method("bind_tank"):
		match_hud.call("bind_tank", preview_tank)
	if match_hud.has_method("bind_capture_points"):
		match_hud.call("bind_capture_points", capture_points)
	match_status_label.text = "Match loaded | Terrain seed %s | Tank %s" % [
		str(match_setup.get("seed", terrain.call("get", "seed") if terrain != null else "-")),
		_selected_vehicle_name(match_setup)
	]
	match_status_label.show()
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_request_terrain_deformation_state.rpc_id(1)


func _apply_match_setup(match_setup: Dictionary) -> void:
	var seed_value := int(match_setup.get("seed", terrain.get("seed") if terrain != null else 1001))
	if terrain != null and terrain.has_method("apply_seed"):
		terrain.call("apply_seed", seed_value)

	var selected_vehicle := _find_vehicle_definition(_match_vehicle_id(match_setup))
	if selected_vehicle == null:
		selected_vehicle = default_vehicle_definition
	if selected_vehicle != null and preview_tank.has_method("apply_vehicle_definition"):
		preview_tank.call("apply_vehicle_definition", selected_vehicle)


func _on_terrain_crater_applied(event: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_receive_terrain_crater.rpc(event)


@rpc("authority", "reliable")
func _receive_terrain_crater(event: Dictionary) -> void:
	if terrain == null or not terrain.has_method("apply_crater_event"):
		return
	terrain.call("apply_crater_event", event, false)


@rpc("any_peer", "reliable")
func _request_terrain_deformation_state() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0 or sender_id == multiplayer.get_unique_id():
		return
	var events: Array = []
	if terrain != null and terrain.has_method("get_crater_events"):
		events = terrain.call("get_crater_events")
	_receive_terrain_deformation_state.rpc_id(sender_id, events)


@rpc("authority", "reliable")
func _receive_terrain_deformation_state(events: Array) -> void:
	if terrain == null or not terrain.has_method("apply_crater_events"):
		return
	terrain.call("apply_crater_events", events, true, false)


func _on_tank_projectile_fired(spawn_data: Dictionary) -> void:
	if not sync_projectile_spawns or not multiplayer.has_multiplayer_peer():
		return
	var projectile_event := _sanitize_projectile_spawn(spawn_data)
	if projectile_event.is_empty():
		return
	if multiplayer.is_server():
		_receive_projectile_spawn.rpc(projectile_event)
	else:
		_request_projectile_spawn.rpc_id(1, projectile_event)


@rpc("any_peer", "reliable")
func _request_projectile_spawn(spawn_data: Dictionary) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var projectile_event := _sanitize_projectile_spawn(spawn_data)
	if projectile_event.is_empty():
		return
	_spawn_synced_projectile(projectile_event, true)
	_receive_projectile_spawn.rpc(projectile_event)


@rpc("authority", "reliable")
func _receive_projectile_spawn(spawn_data: Dictionary) -> void:
	var projectile_event := _sanitize_projectile_spawn(spawn_data)
	if projectile_event.is_empty():
		return
	_spawn_synced_projectile(projectile_event, false)


func _spawn_synced_projectile(spawn_data: Dictionary, gameplay_effects: bool) -> void:
	var projectile_scene := _projectile_scene_for_sync()
	if projectile_scene == null or projectiles == null:
		return
	var projectile := projectile_scene.instantiate()
	if not projectile is Node3D:
		projectile.queue_free()
		return

	projectiles.add_child(projectile)
	var projectile_node := projectile as Node3D
	projectile_node.global_position = spawn_data["position"]
	if projectile.has_method("set_terrain_probe"):
		projectile.call("set_terrain_probe", terrain)
	if projectile.get("gameplay_effects_enabled") != null:
		projectile.set("gameplay_effects_enabled", gameplay_effects)
	if not gameplay_effects and projectile.get("crater_on_terrain_hit") != null:
		projectile.set("crater_on_terrain_hit", false)
	if projectile.has_method("launch"):
		projectile.call(
			"launch",
			null,
			spawn_data["direction"],
			float(spawn_data["speed"]),
			float(spawn_data["damage"])
		)


func _projectile_scene_for_sync() -> PackedScene:
	if synced_projectile_scene != null:
		return synced_projectile_scene
	if preview_tank == null:
		return null
	var tank_projectile_scene = preview_tank.get("projectile_scene")
	if tank_projectile_scene is PackedScene:
		return tank_projectile_scene
	return null


func _sanitize_projectile_spawn(spawn_data: Dictionary) -> Dictionary:
	var raw_position: Variant = spawn_data.get("position", Vector3.ZERO)
	var raw_direction: Variant = spawn_data.get("direction", Vector3.FORWARD)
	if typeof(raw_position) != TYPE_VECTOR3 or typeof(raw_direction) != TYPE_VECTOR3:
		return {}
	var position := raw_position as Vector3
	var direction := (raw_direction as Vector3).normalized()
	var speed := snappedf(float(spawn_data.get("speed", 0.0)), 0.001)
	var damage := snappedf(float(spawn_data.get("damage", 0.0)), 0.001)
	if not position.is_finite() or not direction.is_finite() or direction.length_squared() <= 0.001 or speed <= 0.0:
		return {}
	return {
		"position": position,
		"direction": direction,
		"speed": speed,
		"damage": damage,
		"owner_peer_id": int(spawn_data.get("owner_peer_id", 1))
	}


func _prepare_match_setup(match_setup: Dictionary) -> Dictionary:
	var prepared := match_setup.duplicate()
	if prepared.is_empty() and lobby_start_screen.has_method("get_match_setup"):
		prepared = (lobby_start_screen.call("get_match_setup") as Dictionary).duplicate()

	var seed_value := int(prepared.get("seed", 0))
	if seed_value == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = Time.get_ticks_usec()
		seed_value = rng.randi_range(1, 2147483647)
	prepared["seed"] = seed_value
	prepared["vehicle_id"] = _match_vehicle_id(prepared)
	return prepared


func _match_vehicle_id(match_setup: Dictionary) -> StringName:
	var raw_id := StringName(match_setup.get("vehicle_id", match_setup.get("tank_id", &"")))
	match raw_id:
		&"basic":
			return &"basic_tank"
		&"light":
			return &"light_tank"
		&"heavy":
			return &"heavy_tank"
		_:
			return raw_id


func _find_vehicle_definition(vehicle_id: StringName) -> Resource:
	if vehicle_id.is_empty():
		return null
	for definition: Resource in vehicle_definitions:
		if definition != null and definition.get(&"vehicle_id") == vehicle_id:
			return definition
	return null


func _selected_vehicle_name(match_setup: Dictionary) -> String:
	var selected_vehicle := _find_vehicle_definition(_match_vehicle_id(match_setup))
	if selected_vehicle == null:
		selected_vehicle = default_vehicle_definition
	if selected_vehicle == null:
		return "Basic Tank"
	return str(selected_vehicle.get(&"display_name"))
