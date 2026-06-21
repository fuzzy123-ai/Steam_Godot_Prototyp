extends PanelContainer

@export var tank_path: NodePath
@export var terrain_path: NodePath
@export var world_path: NodePath
@export_range(0.05, 2.0, 0.05) var update_interval_seconds: float = 0.25

@onready var stats_label: Label = %StatsLabel

var _time_since_update: float = 0.0


func _ready() -> void:
	visible = false
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_time_since_update += delta
	if _time_since_update >= update_interval_seconds:
		_time_since_update = 0.0
		_refresh()


func toggle_debug() -> void:
	set_debug_visible(not visible)


func set_debug_visible(should_show: bool) -> void:
	visible = should_show
	if visible:
		_time_since_update = 0.0
		_refresh()


func _refresh() -> void:
	var lines: Array[String] = []
	lines.append("Performance")
	lines.append("FPS: %d | Frame: %.2f ms" % [
		int(Performance.get_monitor(Performance.TIME_FPS)),
		float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
	])
	lines.append("Physics: %.2f ms | Nodes: %d | Objects: %d" % [
		float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT))
	])
	lines.append("Draw calls: %d | Primitives: %d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	])
	lines.append("Video mem: %s | Texture mem: %s" % [
		_format_bytes(float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))),
		_format_bytes(float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)))
	])

	lines.append("")
	lines.append("Network")
	lines.append(_network_summary())

	lines.append("")
	lines.append("Match")
	lines.append(_match_summary())
	lines.append(_tank_summary())
	lines.append(_terrain_summary())

	stats_label.text = "\n".join(lines)


func _network_summary() -> String:
	if not multiplayer.has_multiplayer_peer():
		return "Offline"
	var role := "Host" if multiplayer.is_server() else "Client"
	var peer_id := multiplayer.get_unique_id()
	var peers := multiplayer.get_peers()
	var lobby_id := "-"
	var online := get_node_or_null("/root/Online")
	if online != null:
		lobby_id = str(online.get("steam_lobby_id"))
	return "%s | Peer %d | Peers %d | Lobby %s" % [role, peer_id, peers.size(), lobby_id]


func _match_summary() -> String:
	var world := get_node_or_null(world_path) if not world_path.is_empty() else null
	var world_visible := world != null and bool(world.get("visible"))
	var projectile_count := 0
	var projectiles := get_tree().current_scene.get_node_or_null("World/Projectiles") if get_tree().current_scene != null else null
	if projectiles != null:
		projectile_count = projectiles.get_child_count()
	return "World visible: %s | Projectiles: %d" % ["yes" if world_visible else "no", projectile_count]


func _tank_summary() -> String:
	var tank := get_node_or_null(tank_path) if not tank_path.is_empty() else null
	if tank == null:
		return "Tank: missing"
	var position := Vector3.ZERO
	if tank is Node3D:
		position = (tank as Node3D).global_position
	var health := float(tank.get("health")) if tank.get("health") != null else 0.0
	var max_health := float(tank.get("max_health")) if tank.get("max_health") != null else 0.0
	var ammo := int(tank.get("current_ammo")) if tank.get("current_ammo") != null else 0
	var ammo_capacity := int(tank.get("ammo_capacity")) if tank.get("ammo_capacity") != null else 0
	var slope := float(tank.get("current_slope_angle_degrees")) if tank.get("current_slope_angle_degrees") != null else 0.0
	var speed_factor := float(tank.get("current_slope_speed_factor")) if tank.get("current_slope_speed_factor") != null else 1.0
	return "Tank pos: %.1f %.1f %.1f | HP: %.0f/%.0f | Ammo: %d/%d | Slope: %.1f deg | Move x%.2f" % [
		position.x,
		position.y,
		position.z,
		health,
		max_health,
		ammo,
		ammo_capacity,
		slope,
		speed_factor
	]


func _terrain_summary() -> String:
	var terrain := get_node_or_null(terrain_path) if not terrain_path.is_empty() else null
	if terrain == null:
		return "Terrain: missing"
	var seed_value := int(terrain.get("seed")) if terrain.get("seed") != null else 0
	var crater_count := 0
	var fingerprint := "-"
	if terrain.has_method("get_crater_events"):
		crater_count = (terrain.call("get_crater_events") as Array).size()
	if terrain.has_method("get_deformation_fingerprint"):
		fingerprint = str(terrain.call("get_deformation_fingerprint"))
	return "Terrain seed: %d | Craters: %d | Deformation: %s" % [seed_value, crater_count, fingerprint]


func _format_bytes(value: float) -> String:
	var megabytes := value / (1024.0 * 1024.0)
	if megabytes >= 1024.0:
		return "%.2f GB" % (megabytes / 1024.0)
	return "%.1f MB" % megabytes
