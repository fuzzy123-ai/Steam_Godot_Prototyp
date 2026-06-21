extends Control

signal start_match_requested

const ERROR_NO_RESPONSE := 0
const ERROR_SUCCESS := 1
const ERROR_FAILED := 2
const ERROR_CURRENTLY_BUSY := 3
const ERROR_JOIN_FAILED_SAME_OWNER_ID := 4
const ERROR_STEAM_CONNECTION_ERROR := 5

@onready var host_button: Button = %HostButton
@onready var lobby_id_input: LineEdit = %LobbyIdInput
@onready var copy_button: Button = %CopyButton
@onready var paste_button: Button = %PasteButton
@onready var join_button: Button = %JoinButton
@onready var start_match_button: Button = %StartMatchButton
@onready var status_label: Label = %StatusLabel


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

	_set_status("Ready. Start Steam, host a lobby, or paste a lobby ID.")
	_refresh_controls()


func _process(_delta: float) -> void:
	_refresh_controls()


func _on_host_pressed() -> void:
	var online := _online()
	if not online:
		_set_status("Online autoload missing.")
		return

	_set_busy(true, "Creating Steam lobby...")
	var error: int = await online.host_steam_lobby()
	_set_busy(false)
	if error == ERROR_SUCCESS:
		lobby_id_input.text = str(online.steam_lobby_id)
		_set_status("Lobby hosted. Copy the ID or start the match.")
	else:
		_set_status("Host failed: %s" % _error_name(error))


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
	var error: int = await online.join_steam_lobby(int(lobby_id))
	_set_busy(false)
	if error == ERROR_SUCCESS:
		_set_status("Joined lobby. Waiting for host to start.")
	else:
		_set_status("Join failed: %s" % _error_name(error))


func _on_start_match_pressed() -> void:
	if not _can_start_match():
		_set_status("Only the host can start the match.")
		return
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


func _can_start_match() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _set_status(message: String) -> void:
	status_label.text = message


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
