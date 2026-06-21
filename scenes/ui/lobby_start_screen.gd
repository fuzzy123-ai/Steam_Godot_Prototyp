extends Control

signal start_match_requested

const ERROR_NO_RESPONSE := 0
const ERROR_SUCCESS := 1
const ERROR_FAILED := 2
const ERROR_CURRENTLY_BUSY := 3
const ERROR_JOIN_FAILED_SAME_OWNER_ID := 4
const ERROR_STEAM_CONNECTION_ERROR := 5
const PING_INTERVAL_SECONDS := 1.5

@onready var host_button: Button = %HostButton
@onready var lobby_id_input: LineEdit = %LobbyIdInput
@onready var copy_button: Button = %CopyButton
@onready var paste_button: Button = %PasteButton
@onready var join_button: Button = %JoinButton
@onready var start_match_button: Button = %StartMatchButton
@onready var status_label: Label = %StatusLabel
@onready var connection_status_label: Label = %ConnectionStatusLabel
@onready var role_status_label: Label = %RoleStatusLabel
@onready var ping_status_label: Label = %PingStatusLabel
@onready var peer_list_label: Label = %PeerListLabel
@onready var selected_map_label: Label = %SelectedMapLabel
@onready var loading_overlay: PanelContainer = %LoadingOverlay
@onready var loading_step_label: Label = %LoadingStepLabel
@onready var loading_bar: ProgressBar = %LoadingBar

var _busy := false
var _ping_timer := 0.0
var _ping_nonce := 1
var _pending_pings: Dictionary[int, int] = {}
var _peer_pings: Dictionary[int, int] = {}


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	paste_button.pressed.connect(_on_paste_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_match_button.pressed.connect(_on_start_match_pressed)
	lobby_id_input.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())

	var online := _online()
	if online:
		online.joined_lobby.connect(_on_joined_lobby)
		online.connection_failed.connect(_on_connection_failed)
		online.server_disconnected.connect(_on_server_disconnected)
		online.player_connected.connect(_on_player_state_changed)
		online.player_disconnected.connect(_on_player_state_changed)

	_set_status("Ready. Start Steam, host a lobby, or paste a lobby ID.")
	_set_loading(false)
	_refresh_controls()


func _process(delta: float) -> void:
	_ping_timer += delta
	if _ping_timer >= PING_INTERVAL_SECONDS:
		_ping_timer = 0.0
		_probe_lobby_ping()
	_refresh_controls()


func _on_host_pressed() -> void:
	var online := _online()
	if not online:
		_set_status("Online autoload missing.")
		return

	_set_busy(true, "Creating Steam lobby...")
	show_loading("Creating Steam lobby", 18.0)
	var error: int = await online.host_steam_lobby()
	_set_busy(false)
	if error == ERROR_SUCCESS:
		lobby_id_input.text = str(online.steam_lobby_id)
		_set_status("Lobby hosted. Copy the ID or start the match.")
		show_loading("Lobby hosted", 100.0)
		await get_tree().create_timer(0.35).timeout
		_set_loading(false)
	else:
		_set_status("Host failed: %s" % _error_name(error))
		_set_loading(false)


func _on_copy_pressed() -> void:
	var lobby_id := lobby_id_input.text.strip_edges()
	if lobby_id.is_empty():
		_set_status("No lobby ID to copy yet.")
		return
	DisplayServer.clipboard_set(lobby_id)
	_set_status("Lobby ID copied.")


func _on_paste_pressed() -> void:
	lobby_id_input.text = DisplayServer.clipboard_get().strip_edges()
	_set_status("Pasted lobby ID.")


func _on_join_pressed() -> void:
	var online := _online()
	if not online:
		_set_status("Online autoload missing.")
		return

	var lobby_id := lobby_id_input.text.strip_edges()
	if not lobby_id.is_valid_int():
		_set_status("Enter a numeric Steam lobby ID.")
		return

	_set_busy(true, "Joining lobby %s..." % lobby_id)
	show_loading("Joining Steam lobby %s" % lobby_id, 22.0)
	var error: int = await online.join_steam_lobby(int(lobby_id))
	_set_busy(false)
	if error == ERROR_SUCCESS:
		_set_status("Joined lobby. Waiting for host to start.")
		show_loading("Joined lobby", 100.0)
		await get_tree().create_timer(0.35).timeout
		_set_loading(false)
	else:
		_set_status("Join failed: %s" % _error_name(error))
		_set_loading(false)


func _on_start_match_pressed() -> void:
	if not _can_start_match():
		_set_status("Only the host can start the match.")
		return
	show_loading("Sending start signal", 15.0)
	start_match_requested.emit()


func _on_joined_lobby() -> void:
	var online := _online()
	if online and int(online.steam_lobby_id) != 0:
		lobby_id_input.text = str(online.steam_lobby_id)
	_set_status("Lobby connected.")
	_refresh_controls()


func _on_connection_failed() -> void:
	_set_status("Connection failed.")
	_refresh_controls()


func _on_server_disconnected() -> void:
	_set_status("Server disconnected.")
	_refresh_controls()


func _set_busy(is_busy: bool, message: String = "") -> void:
	_busy = is_busy
	host_button.disabled = is_busy
	join_button.disabled = is_busy
	paste_button.disabled = is_busy
	lobby_id_input.editable = not is_busy
	if not message.is_empty():
		_set_status(message)
	_refresh_controls()


func _refresh_controls() -> void:
	var online := _online()
	var has_lobby := online and int(online.steam_lobby_id) != 0
	var connected := multiplayer.has_multiplayer_peer() and has_lobby
	copy_button.disabled = lobby_id_input.text.strip_edges().is_empty()
	start_match_button.disabled = not connected or not _can_start_match()
	host_button.disabled = _busy or connected
	join_button.disabled = _busy or connected
	paste_button.disabled = _busy or connected
	lobby_id_input.editable = not _busy and not connected
	_update_connection_summary(online, connected)


func _can_start_match() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _set_status(message: String) -> void:
	status_label.text = message


func show_loading(message: String, progress: float) -> void:
	_set_loading(true)
	loading_step_label.text = message
	loading_bar.value = clampf(progress, 0.0, 100.0)


func hide_loading() -> void:
	_set_loading(false)


func _set_loading(visible: bool) -> void:
	loading_overlay.visible = visible


func _update_connection_summary(online: Node, connected: bool) -> void:
	var lobby_id := 0
	if online:
		lobby_id = int(online.steam_lobby_id)

	var peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var role := "Admin / Host" if multiplayer.has_multiplayer_peer() and multiplayer.is_server() else "Client"
	if not multiplayer.has_multiplayer_peer():
		role = "Offline"

	var transport := "Steam lobby" if lobby_id != 0 else "Not connected"
	connection_status_label.text = "Connection: %s | Lobby: %s | Peer: %s" % [
		transport,
		str(lobby_id) if lobby_id != 0 else "-",
		str(peer_id) if peer_id != 0 else "-"
	]
	role_status_label.text = "Role: %s | Start permission: %s" % [
		role,
		"yes" if _can_start_match() else "no"
	]
	ping_status_label.text = "Ping: %s" % _format_ping_summary()
	selected_map_label.text = "Map: Proving Grounds | Mode: sandbox test"
	peer_list_label.text = _format_peer_list(online, connected)


func _format_peer_list(online: Node, connected: bool) -> String:
	if not connected or not online:
		return "Players:\n- Waiting for lobby"

	var lines: Array[String] = ["Players:"]
	var players: Dictionary = online.get("players")
	for peer_id: int in players:
		var data = players[peer_id]
		var display_name := str(data.get("display_name")) if data else "Peer %s" % peer_id
		var role := "host" if peer_id == 1 else "client"
		var ping := _format_peer_ping(peer_id)
		lines.append("- %s | %s | %s | ping %s" % [display_name, peer_id, role, ping])

	if lines.size() == 1:
		lines.append("- Connected, waiting for player registry")
	return "\n".join(lines)


func _format_ping_summary() -> String:
	if not multiplayer.has_multiplayer_peer():
		return "offline"
	if multiplayer.get_peers().is_empty():
		return "local host"

	var parts: Array[String] = []
	for peer_id: int in multiplayer.get_peers():
		parts.append("%s=%s" % [peer_id, _format_peer_ping(peer_id)])
	return ", ".join(parts)


func _format_peer_ping(peer_id: int) -> String:
	if _peer_pings.has(peer_id):
		return "%sms" % _peer_pings[peer_id]
	return "pending"


func _probe_lobby_ping() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	for peer_id: int in multiplayer.get_peers():
		var nonce := _ping_nonce
		_ping_nonce += 1
		_pending_pings[nonce] = Time.get_ticks_msec()
		_lobby_ping_request.rpc_id(peer_id, nonce)


@rpc("any_peer", "unreliable")
func _lobby_ping_request(nonce: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_lobby_ping_response.rpc_id(sender, nonce)


@rpc("any_peer", "unreliable")
func _lobby_ping_response(nonce: int) -> void:
	if not _pending_pings.has(nonce):
		return
	var sent_msec: int = _pending_pings[nonce]
	_pending_pings.erase(nonce)
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	_peer_pings[sender] = Time.get_ticks_msec() - sent_msec


func _on_player_state_changed(_player_data = null) -> void:
	_refresh_controls()


func _online() -> Node:
	return get_node_or_null("/root/Online")


func _error_name(error: int) -> String:
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
			return "cannot join your own lobby"
		ERROR_STEAM_CONNECTION_ERROR:
			return "Steam connection error"
		_:
			return "unknown error"
