extends Node

@onready var world: Node3D = %World
@onready var lobby_start_screen: Control = %LobbyStartScreen
@onready var match_status_label: Label = %MatchStatusLabel
@onready var match_hud: Control = %MatchHud
@onready var preview_tank: Node3D = %PreviewTank
@onready var terrain: Node3D = %Terrain
@onready var capture_points: Node3D = %CapturePoints

@export var default_vehicle_definition: Resource
@export var vehicle_definitions: Array[Resource] = []

var match_started: bool = false


func _ready() -> void:
	world.hide()
	match_status_label.hide()
	match_hud.hide()
	lobby_start_screen.start_match_requested.connect(_on_start_match_requested)


func _on_start_match_requested(match_setup: Dictionary = {}) -> void:
	match_setup = _prepare_match_setup(match_setup)
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return
		_start_match.rpc(match_setup)
	else:
		_start_match(match_setup)


@rpc("authority", "reliable", "call_local")
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


func _apply_match_setup(match_setup: Dictionary) -> void:
	var seed_value := int(match_setup.get("seed", terrain.get("seed") if terrain != null else 1001))
	if terrain != null and terrain.has_method("apply_seed"):
		terrain.call("apply_seed", seed_value)

	var selected_vehicle := _find_vehicle_definition(_match_vehicle_id(match_setup))
	if selected_vehicle == null:
		selected_vehicle = default_vehicle_definition
	if selected_vehicle != null and preview_tank.has_method("apply_vehicle_definition"):
		preview_tank.call("apply_vehicle_definition", selected_vehicle)


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
