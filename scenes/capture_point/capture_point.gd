extends Node3D

signal owner_changed(point_id: StringName, owner_id: StringName)
signal progress_changed(point_id: StringName, progress: float, state: StringName)

const CapturePointSettingsScript := preload("res://scenes/capture_point/capture_point_settings.gd")

@export var point_id: StringName = &"alpha"
@export var settings: Resource
@export var accepted_body_group: StringName = &"capture_unit"
@export var local_team_id: StringName = &"local_player"
@export var neutral_owner_id: StringName = &"neutral"
@export var neutral_material: Material
@export var capturing_material: Material
@export var contested_material: Material
@export var owned_material: Material

@onready var area: Area3D = %Area3D
@onready var collision_shape: CollisionShape3D = %CollisionShape3D
@onready var marker: MeshInstance3D = %Marker
@onready var label: Label3D = %Label3D

var owner_id: StringName = &"neutral"
var capture_progress: float = 0.0
var state: StringName = &"neutral"
var _occupants: Dictionary[int, StringName] = {}


func _ready() -> void:
	if settings == null:
		settings = CapturePointSettingsScript.new()
	_apply_radius()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	_update_visuals()


func _process(delta: float) -> void:
	var previous_owner := owner_id
	var previous_progress := capture_progress
	var previous_state := state
	var team := _active_team()

	if team == &"contested":
		state = &"contested"
	elif team == neutral_owner_id:
		state = &"owned" if owner_id != neutral_owner_id else &"neutral"
	elif team == owner_id:
		state = &"owned"
		capture_progress = 1.0
	else:
		state = &"capturing"
		var seconds: float = float(settings.get(&"capture_seconds")) if owner_id == neutral_owner_id else float(settings.get(&"neutralize_seconds"))
		capture_progress = clampf(capture_progress + delta / maxf(0.1, seconds), 0.0, 1.0)
		if capture_progress >= 1.0:
			owner_id = team
			state = &"owned"

	if previous_owner != owner_id:
		owner_changed.emit(point_id, owner_id)
	if previous_progress != capture_progress or previous_state != state:
		progress_changed.emit(point_id, capture_progress, state)
		_update_visuals()


func reset_point() -> void:
	owner_id = neutral_owner_id
	capture_progress = 0.0
	state = &"neutral"
	_occupants.clear()
	_update_visuals()
	owner_changed.emit(point_id, owner_id)
	progress_changed.emit(point_id, capture_progress, state)


func _active_team() -> StringName:
	if _occupants.is_empty():
		return neutral_owner_id

	var seen_team: StringName
	var has_team := false
	for occupant_team: StringName in _occupants.values():
		if not has_team:
			seen_team = occupant_team
			has_team = true
		elif occupant_team != seen_team and bool(settings.get(&"contest_blocks_progress")):
			return &"contested"
	return seen_team


func _on_body_entered(body: Node3D) -> void:
	if not _accepts_body(body):
		return
	_occupants[body.get_instance_id()] = _team_for_body(body)


func _on_body_exited(body: Node3D) -> void:
	_occupants.erase(body.get_instance_id())


func _accepts_body(body: Node3D) -> bool:
	if not accepted_body_group.is_empty() and body.is_in_group(accepted_body_group):
		return true
	return accepted_body_group.is_empty() and body is CharacterBody3D


func _team_for_body(body: Node3D) -> StringName:
	var body_team = body.get("team_id")
	if body_team is StringName:
		return body_team
	if body_team is String:
		return StringName(body_team)
	return local_team_id


func _apply_radius() -> void:
	var radius: float = float(settings.get(&"radius"))
	var cylinder_shape := collision_shape.shape as CylinderShape3D
	if cylinder_shape != null:
		cylinder_shape.radius = radius

	var cylinder_mesh := marker.mesh as CylinderMesh
	if cylinder_mesh != null:
		cylinder_mesh.top_radius = radius
		cylinder_mesh.bottom_radius = radius


func _update_visuals() -> void:
	match state:
		&"contested":
			marker.material_override = contested_material
		&"capturing":
			marker.material_override = capturing_material
		&"owned":
			marker.material_override = owned_material
		_:
			marker.material_override = neutral_material

	label.text = "%s\n%s%%\n%s" % [
		String(point_id).to_upper(),
		str(roundi(capture_progress * 100.0)),
		String(state).replace("_", " ")
	]
