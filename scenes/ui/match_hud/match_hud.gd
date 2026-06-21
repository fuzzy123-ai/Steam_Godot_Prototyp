extends Control

@onready var tank_name_label: Label = %TankNameLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var reload_bar: ProgressBar = %ReloadBar
@onready var capture_label: Label = %CaptureLabel

var _capture_states: Dictionary[StringName, Dictionary] = {}


func bind_tank(tank: Node) -> void:
	if tank == null:
		return

	if tank.has_signal("health_changed"):
		tank.health_changed.connect(_on_tank_health_changed)
	if tank.has_signal("ammo_changed"):
		tank.ammo_changed.connect(_on_tank_ammo_changed)
	if tank.has_signal("reload_changed"):
		tank.reload_changed.connect(_on_tank_reload_changed)

	var vehicle_definition: Resource = tank.get("vehicle_definition")
	if vehicle_definition != null:
		tank_name_label.text = str(vehicle_definition.get(&"display_name"))
	elif tank.get("stats") != null:
		tank_name_label.text = str(tank.get("stats").get(&"vehicle_name"))
	else:
		tank_name_label.text = "Tank"

	_on_tank_health_changed(float(tank.get("health")), float(tank.get("max_health")))
	_on_tank_ammo_changed(int(tank.get("current_ammo")), int(tank.get("ammo_capacity")))
	_on_tank_reload_changed(0.0, 1.0)


func bind_capture_points(root: Node) -> void:
	_capture_states.clear()
	if root == null:
		_update_capture_label()
		return
	for child: Node in root.get_children():
		if child.has_signal("progress_changed"):
			child.progress_changed.connect(_on_capture_progress_changed)
		if child.has_signal("owner_changed"):
			child.owner_changed.connect(_on_capture_owner_changed)
		var point_id: StringName = child.get("point_id")
		_capture_states[point_id] = {
			"owner": child.get("owner_id"),
			"progress": child.get("capture_progress"),
			"state": child.get("state")
		}
	_update_capture_label()


func _on_tank_health_changed(current_health: float, max_health: float) -> void:
	hp_bar.max_value = maxf(1.0, max_health)
	hp_bar.value = clampf(current_health, 0.0, hp_bar.max_value)
	hp_label.text = "HP %s / %s" % [roundi(current_health), roundi(max_health)]


func _on_tank_ammo_changed(current_ammo: int, ammo_capacity: int) -> void:
	ammo_label.text = "Ammo %s / %s" % [current_ammo, ammo_capacity]


func _on_tank_reload_changed(reload_remaining: float, reload_seconds: float) -> void:
	reload_bar.max_value = maxf(0.01, reload_seconds)
	reload_bar.value = clampf(reload_bar.max_value - reload_remaining, 0.0, reload_bar.max_value)


func _on_capture_progress_changed(point_id: StringName, progress: float, state: StringName) -> void:
	if not _capture_states.has(point_id):
		_capture_states[point_id] = {}
	_capture_states[point_id]["progress"] = progress
	_capture_states[point_id]["state"] = state
	_update_capture_label()


func _on_capture_owner_changed(point_id: StringName, owner_id: StringName) -> void:
	if not _capture_states.has(point_id):
		_capture_states[point_id] = {}
	_capture_states[point_id]["owner"] = owner_id
	_update_capture_label()


func _update_capture_label() -> void:
	if _capture_states.is_empty():
		capture_label.text = "Capture: -"
		return

	var parts: Array[String] = []
	for point_id: StringName in _capture_states:
		var data := _capture_states[point_id]
		parts.append("%s %s%% %s" % [
			String(point_id).to_upper(),
			roundi(float(data.get("progress", 0.0)) * 100.0),
			String(data.get("state", &"neutral"))
		])
	capture_label.text = "Capture: " + " | ".join(parts)
