extends Control

const CURSOR_SEND_INTERVAL := 1.0 / 30.0
const LOCAL_CURSOR_ID := 0
const ERROR_NO_RESPONSE := 0
const ERROR_SUCCESS := 1
const ERROR_FAILED := 2
const ERROR_CURRENTLY_BUSY := 3
const ERROR_JOIN_FAILED_SAME_OWNER_ID := 4
const ERROR_STEAM_CONNECTION_ERROR := 5

var _joined := false
var _send_timer := 0.0
var _cursor_nodes: Dictionary[int, Control] = {}
var _cursor_labels: Dictionary[int, Label] = {}
var _cursor_swatches: Dictionary[int, ColorRect] = {}
var _cursor_positions: Dictionary[int, Vector2] = {}

var _cursor_layer: Control
var _menu_panel: PanelContainer
var _session_panel: PanelContainer
var _status_label: Label
var _identity_label: Label
var _lobby_label: Label
var _join_input: LineEdit
var _host_button: Button
var _join_button: Button
var _leave_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_signals()
	_set_joined(multiplayer.has_multiplayer_peer())
	_update_status("Ready. Start Steam before hosting or joining.")


func _process(delta: float) -> void:
	_update_identity()
	if not _joined or not multiplayer.has_multiplayer_peer():
		_update_local_preview_cursor()
		return

	_send_timer += delta
	if _send_timer >= CURSOR_SEND_INTERVAL:
		_send_timer = 0.0
		_send_local_cursor()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cursors()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.055, 0.06, 0.068, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)

	_cursor_layer = Control.new()
	_cursor_layer.name = "CursorLayer"
	_cursor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cursor_layer)
	_cursor_layer.set_anchors_preset(Control.PRESET_FULL_RECT)

	_menu_panel = _create_panel("MenuPanel", Vector2(26, 26), Vector2(520, 0))
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	_menu_panel.add_child(menu)

	var title := Label.new()
	title.text = "Steam Cursor MVP"
	title.add_theme_font_size_override("font_size", 28)
	menu.add_child(title)

	_identity_label = Label.new()
	_identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(_identity_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(_status_label)

	_host_button = Button.new()
	_host_button.text = "Host Steam Lobby"
	menu.add_child(_host_button)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	menu.add_child(join_row)

	_join_input = LineEdit.new()
	_join_input.placeholder_text = "Steam Lobby ID"
	_join_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_join_input)

	_join_button = Button.new()
	_join_button.text = "Join"
	join_row.add_child(_join_button)

	var hint := Label.new()
	hint.text = "Host copies the lobby ID. Client pastes it here. The connection uses SteamMultiplayerPeer, not IP/port."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.78, 0.82, 0.88, 1.0)
	menu.add_child(hint)

	_session_panel = _create_panel("SessionPanel", Vector2(26, 26), Vector2(520, 0))
	var session := VBoxContainer.new()
	session.add_theme_constant_override("separation", 10)
	_session_panel.add_child(session)

	var session_title := Label.new()
	session_title.text = "Live Session"
	session_title.add_theme_font_size_override("font_size", 24)
	session.add_child(session_title)

	_lobby_label = Label.new()
	_lobby_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session.add_child(_lobby_label)

	_leave_button = Button.new()
	_leave_button.text = "Leave Lobby"
	session.add_child(_leave_button)


func _create_panel(node_name: String, position: Vector2, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.position = position
	panel.custom_minimum_size = min_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	return panel


func _connect_signals() -> void:
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_join_input.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())

	var online = _online()
	if not online:
		_update_status("Online autoload missing. Check project.godot autoloads.")
		return
	online.joined_lobby.connect(_on_joined_lobby)
	online.connection_failed.connect(_on_connection_failed)
	online.server_disconnected.connect(_on_server_disconnected)
	online.player_connected.connect(_on_player_connected)
	online.player_disconnected.connect(_on_player_disconnected)


func _on_host_pressed() -> void:
	var online = _online()
	if not online:
		_update_status("Online autoload missing.")
		return
	_set_busy(true)
	_update_status("Creating Steam lobby...")
	var error = await online.host_steam_lobby()
	_set_busy(false)
	if error != ERROR_SUCCESS:
		_update_status("Host failed: %s" % _error_name(error))


func _on_join_pressed() -> void:
	var online = _online()
	if not online:
		_update_status("Online autoload missing.")
		return
	var lobby_text := _join_input.text.strip_edges()
	if not lobby_text.is_valid_int():
		_update_status("Enter a numeric Steam lobby ID.")
		return

	_set_busy(true)
	_update_status("Joining Steam lobby %s..." % lobby_text)
	var error = await online.join_steam_lobby(int(lobby_text))
	_set_busy(false)
	if error != ERROR_SUCCESS:
		_update_status("Join failed: %s" % _error_name(error))


func _on_leave_pressed() -> void:
	var online = _online()
	if online:
		online.leave_lobby()
	_set_joined(false)
	_clear_remote_cursors()
	_update_status("Left lobby.")


func _on_joined_lobby() -> void:
	_set_joined(true)
	_refresh_player_cursors()
	_update_status("Connected. Move the mouse to broadcast your cursor.")


func _on_connection_failed() -> void:
	_set_joined(false)
	_clear_remote_cursors()
	_update_status("Connection failed.")


func _on_server_disconnected() -> void:
	_set_joined(false)
	_clear_remote_cursors()
	_update_status("Server disconnected.")


func _on_player_connected(player_data) -> void:
	if player_data.multiplayer_id <= 0:
		return
	_ensure_cursor(player_data.multiplayer_id)
	_update_cursor_visual(player_data.multiplayer_id)
	_update_lobby_label()


func _on_player_disconnected(player_data) -> void:
	_remove_cursor(player_data.multiplayer_id)
	_update_lobby_label()


func _set_busy(value: bool) -> void:
	_host_button.disabled = value
	_join_button.disabled = value
	_join_input.editable = not value


func _set_joined(value: bool) -> void:
	_joined = value
	_menu_panel.visible = not value
	_session_panel.visible = value
	_update_lobby_label()


func _update_status(text: String) -> void:
	_status_label.text = text


func _update_identity() -> void:
	var steam_state := "running" if _steam_is_running() else "not running"
	var persona := _steam_persona_name()
	var steam_id := _steam_id()
	_identity_label.text = "Steam: %s\nName: %s\nSteam ID: %s" % [steam_state, persona, steam_id]


func _update_lobby_label() -> void:
	if not _joined:
		_lobby_label.text = ""
		return

	var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var role := "Host" if multiplayer.is_server() else "Client"
	var online = _online()
	var lobby_id := int(online.steam_lobby_id) if online else 0
	var lobby_text := str(lobby_id) if lobby_id else "none"
	var player_lines: Array[String] = []
	var players := _players()
	for player_id: int in players:
		var data = players[player_id]
		if data:
			player_lines.append("%s: %s" % [player_id, data.display_name])
	_lobby_label.text = "Role: %s\nPeer ID: %s\nLobby ID: %s\nPlayers:\n%s" % [
		role,
		peer_id,
		lobby_text,
		"\n".join(player_lines)
	]


func _refresh_player_cursors() -> void:
	var players := _players()
	for player_id: int in players:
		if player_id > 0:
			_ensure_cursor(player_id)
			_update_cursor_visual(player_id)
	_update_lobby_label()


func _send_local_cursor() -> void:
	var peer_id := multiplayer.get_unique_id()
	if peer_id <= 0:
		return

	var norm_pos := _get_normalized_mouse_position()
	if multiplayer.is_server():
		_store_and_broadcast_cursor(peer_id, norm_pos)
	else:
		submit_cursor_position.rpc_id(1, norm_pos)


func _update_local_preview_cursor() -> void:
	var norm_pos := _get_normalized_mouse_position()
	_cursor_positions[LOCAL_CURSOR_ID] = norm_pos
	_ensure_cursor(LOCAL_CURSOR_ID)
	_update_cursor_visual(LOCAL_CURSOR_ID)
	_position_cursor(LOCAL_CURSOR_ID)


@rpc("any_peer", "unreliable")
func submit_cursor_position(norm_pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0:
		return
	_store_and_broadcast_cursor(sender_id, norm_pos)


func _store_and_broadcast_cursor(peer_id: int, norm_pos: Vector2) -> void:
	receive_cursor_state.rpc(peer_id, _clamp_normalized(norm_pos))


@rpc("authority", "unreliable", "call_local")
func receive_cursor_state(peer_id: int, norm_pos: Vector2) -> void:
	_cursor_positions[peer_id] = _clamp_normalized(norm_pos)
	_ensure_cursor(peer_id)
	_update_cursor_visual(peer_id)
	_position_cursor(peer_id)


func _get_normalized_mouse_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var pos := get_viewport().get_mouse_position()
	return _clamp_normalized(Vector2(pos.x / viewport_size.x, pos.y / viewport_size.y))


func _clamp_normalized(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 0.0, 1.0), clampf(pos.y, 0.0, 1.0))


func _ensure_cursor(peer_id: int) -> void:
	if _cursor_nodes.has(peer_id):
		return

	var marker := PanelContainer.new()
	marker.name = "Cursor_%s" % peer_id
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 20

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	marker.add_child(row)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 10)
	row.add_child(swatch)

	var label := Label.new()
	label.text = _cursor_name(peer_id)
	row.add_child(label)

	_cursor_layer.add_child(marker)
	_cursor_nodes[peer_id] = marker
	_cursor_labels[peer_id] = label
	_cursor_swatches[peer_id] = swatch


func _update_cursor_visual(peer_id: int) -> void:
	if not _cursor_nodes.has(peer_id):
		return

	var color := _cursor_color(peer_id)
	var label := _cursor_labels[peer_id]
	var swatch := _cursor_swatches[peer_id]
	label.text = "> %s" % _cursor_name(peer_id)
	label.add_theme_color_override("font_color", color)
	swatch.color = color


func _position_cursor(peer_id: int) -> void:
	if not _cursor_nodes.has(peer_id) or not _cursor_positions.has(peer_id):
		return

	var marker := _cursor_nodes[peer_id]
	var viewport_size := get_viewport_rect().size
	var norm_pos := _cursor_positions[peer_id]
	var pos := Vector2(norm_pos.x * viewport_size.x, norm_pos.y * viewport_size.y)
	marker.position = pos + Vector2(12, 12)


func _layout_cursors() -> void:
	for peer_id: int in _cursor_positions:
		_position_cursor(peer_id)


func _remove_cursor(peer_id: int) -> void:
	if not _cursor_nodes.has(peer_id):
		return
	_cursor_nodes[peer_id].queue_free()
	_cursor_nodes.erase(peer_id)
	_cursor_labels.erase(peer_id)
	_cursor_swatches.erase(peer_id)
	_cursor_positions.erase(peer_id)


func _clear_remote_cursors() -> void:
	for peer_id: int in _cursor_nodes.keys():
		_remove_cursor(peer_id)
	_cursor_positions.clear()


func _cursor_name(peer_id: int) -> String:
	if peer_id == LOCAL_CURSOR_ID:
		return "%s (local preview)" % _steam_persona_name()
	var data = _players().get(peer_id)
	if data and not data.display_name.is_empty():
		return data.display_name
	return "Peer %s" % peer_id


func _cursor_color(peer_id: int) -> Color:
	var data = _players().get(peer_id)
	if data and data.color != Color.WHITE:
		return data.color
	var hue := float(abs(peer_id * 37) % 360) / 360.0
	return Color.from_hsv(hue, 0.72, 1.0)


func _steam_singleton():
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null


func _online():
	return get_node_or_null("/root/Online")


func _players() -> Dictionary:
	var online = _online()
	if not online:
		return {}
	return online.players


func _steam_is_running() -> bool:
	var steam = _steam_singleton()
	if not steam:
		return false
	return bool(steam.call("isSteamRunning"))


func _steam_persona_name() -> String:
	var steam = _steam_singleton()
	if not steam or not _steam_is_running():
		return "Steam unavailable"
	return str(steam.call("getPersonaName"))


func _steam_id() -> int:
	var steam = _steam_singleton()
	if not steam or not _steam_is_running():
		return 0
	return int(steam.call("getSteamID"))


func _error_name(error) -> String:
	match error:
		ERROR_NO_RESPONSE:
			return "no response"
		ERROR_SUCCESS:
			return "success"
		ERROR_FAILED:
			return "failed"
		ERROR_CURRENTLY_BUSY:
			return "currently busy"
		ERROR_JOIN_FAILED_SAME_OWNER_ID:
			return "cannot join own lobby"
		ERROR_STEAM_CONNECTION_ERROR:
			return "Steam connection error"
		_:
			return "unknown error"
