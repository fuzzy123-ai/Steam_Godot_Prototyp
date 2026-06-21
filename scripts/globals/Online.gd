extends Node

const MAX_PLAYERS: int = 12
const PlayerDataResource := preload("res://scripts/player_data_resource.gd")
const STEAM_RESULT_OK: int = 1
const STEAM_LOBBY_TYPE_FRIENDS_ONLY: int = 1
const STEAM_P2P_SEND_RELIABLE: int = 2
const STEAM_RESPONSE_TIMEOUT_SECONDS := 10.0

enum ErrorCodes { NO_RESPONSE, SUCCESS, FAILED, CURRENTLY_BUSY, JOIN_FAILED_SAME_OWNER_ID, STEAM_CONNECTION_ERROR }

signal joined_lobby
signal connection_failed
signal steam_lobby_invite_received(lobby_id: int, sender_id: int)
signal lobby_hosting_response(error_code: ErrorCodes)
signal lobby_join_response(error_code: ErrorCodes)
signal player_connected(player_data)
signal player_disconnected(player_data)
signal server_disconnected

var is_busy: bool = false
var is_host: bool = false
var is_joining: bool = false
var steam_initialized: bool = false
var steam_initialization_attempted: bool = false
var steam_lobby_id: int = 0
var players: Dictionary: # Uses multiplayer ids as keys
	get: players.sort(); return players

func players_to_data_dicts() -> Array[Dictionary]: # Returns an array with all the players PlayerData resource in Dictionary format
	var value: Array[Dictionary]
	for player_data in players.values():
		if is_instance_valid(player_data): value.append(player_data.to_dict())
	return value

@onready var personal_player_data: Resource: get = _get_personal_player_data # Your PlayerData resource

func _ready() -> void:
	_setup_local_multiplayer()

func _process(_delta: float) -> void:
	var steam := _steam()
	if steam_initialized and steam:
		steam.run_callbacks()
	_process_steam_p2p_packets()

func leave_lobby() -> void:
	is_host = false
	if not steam_lobby_id and not multiplayer.has_multiplayer_peer(): return
	var steam := _steam()
	if steam and steam_lobby_id:
		steam.leaveLobby(steam_lobby_id)
	if multiplayer.multiplayer_peer: multiplayer.multiplayer_peer.close()
	steam_lobby_id = 0
	players.clear()
	player_disconnected.emit(personal_player_data)


func join_address(address: String, port: int = LOCAL_SERVER_PORT) -> ErrorCodes:
	if is_busy: return ErrorCodes.CURRENTLY_BUSY
	is_host = false
	var response: ErrorCodes = ErrorCodes.FAILED
	if is_host or steam_lobby_id != 0: leave_lobby()
	var new_multiplayer_peer := ENetMultiplayerPeer.new()
	var error := new_multiplayer_peer.create_client(address, port)
	is_busy = false
	if error != OK:
		printerr("Failed to join port %s with address: %s" % [port, address])
		return response
	multiplayer.multiplayer_peer = new_multiplayer_peer
	response = ErrorCodes.SUCCESS
	_register_player_data(personal_player_data.to_dict())
	joined_lobby.emit()
	return response

func _on_connected_to_server() -> void: _register_player_data.rpc_id(1,personal_player_data.to_dict()) # Sends a request to the server host to register and sync your PlayerData resource

func _on_connection_failed() -> void:
	is_host = false
	steam_lobby_id = 0
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_peer_disconnected(id: int) -> void: _handle_peer_disconnection(id)

func _on_server_disconnected() -> void:
	is_host = false
	players.clear()
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()

func _get_os_user_name() -> String:
	var username := "Player"
	if OS.has_environment("USER"): username = OS.get_environment("USER")
	elif OS.has_environment("USERNAME"): username = OS.get_environment("USERNAME")
	return username

func _handle_peer_disconnection(peer_id: int) -> void:
	if not players.has(peer_id): return
	var player_data = players[peer_id]
	players.erase(peer_id)
	player_disconnected.emit(player_data)

@rpc("any_peer", "reliable", "call_local")
func _register_player_data(player_data_dict: Dictionary):
	var player_data := PlayerDataResource.from_dict(player_data_dict)
	var mult_id: int = player_data.multiplayer_id
	if not players.has(mult_id):
		players[player_data.multiplayer_id] = player_data
		player_connected.emit.call_deferred(player_data)
		if is_host:
			# Registers the new player data to the other active players in the lobby
			for peer in multiplayer.get_peers():
				_register_player_data.rpc_id(peer,player_data_dict)
		
			# Syncs the current players data to the player that was just registred
			var sender_id := multiplayer.get_remote_sender_id()
			if sender_id != 0 and sender_id != multiplayer.get_unique_id():
				for data in players.values():
					_register_player_data.rpc_id(sender_id,data.to_dict())

func _get_personal_player_data() -> Resource:
	if not personal_player_data:
		personal_player_data = PlayerDataResource.new()
		var steam := _steam()
		if steam_initialized and steam:
			personal_player_data.steam_id = steam.getSteamID()
			personal_player_data.display_name = steam.getPersonaName()
		else:
			personal_player_data.steam_id = -1
			personal_player_data.display_name = _get_os_user_name()
	personal_player_data.multiplayer_id = 0 if not multiplayer.has_multiplayer_peer() else multiplayer.get_unique_id()
	return personal_player_data

#region STEAM P2P MULTIPLAYER
const STEAM_APP_ID: int = 480 # Default for the "Spacewar" game

func _steam() -> Object:
	if Engine.has_singleton("Steam"):
		return Engine.get_singleton("Steam")
	return null

func is_steam_available() -> bool:
	return steam_initialized and _steam() != null and ClassDB.class_exists("SteamMultiplayerPeer")

func ensure_steam_initialized() -> bool:
	if steam_initialized:
		return true
	if steam_initialization_attempted:
		return false
	steam_initialization_attempted = true
	multiplayer.server_relay = true
	var steam := _steam()
	if not steam:
		push_warning("GodotSteam singleton is not available. Steam multiplayer is disabled for this run.")
		return false
	OS.set_environment("SteamAppID", str(STEAM_APP_ID))
	OS.set_environment("SteamGameID", str(STEAM_APP_ID))
	steam.steamInit(false, STEAM_APP_ID) # For some reason the autocomplete for the values are inverted but this is the correct way for now.
	if steam.has_method("isSteamRunning") and not bool(steam.isSteamRunning()):
		steam_initialized = false
		push_warning("Steam client is not running or Steam API did not initialize. Steam multiplayer is disabled for this run.")
		return false
	steam_initialized = true
	if personal_player_data:
		personal_player_data.steam_id = steam.getSteamID()
		personal_player_data.display_name = steam.getPersonaName()
	steam.allowP2PPacketRelay(true)
	if not steam.lobby_created.is_connected(_on_steam_lobby_created):
		steam.lobby_created.connect(_on_steam_lobby_created)
	if not steam.lobby_joined.is_connected(_on_steam_lobby_join_response):
		steam.lobby_joined.connect(_on_steam_lobby_join_response)
	if not steam.join_requested.is_connected(_on_steam_join_requested):
		steam.join_requested.connect(_on_steam_join_requested)
	return true

func retry_steam_initialization() -> bool:
	steam_initialization_attempted = false
	return ensure_steam_initialized()

func _on_steam_lobby_created(connection_response: int, lobby_id: int) -> void:
	match connection_response:
		STEAM_RESULT_OK: 
			steam_lobby_id = lobby_id
			var steam := _steam()
			if steam:
				steam.setLobbyJoinable(lobby_id, true)
			lobby_hosting_response.emit.call_deferred(ErrorCodes.SUCCESS)
		_: lobby_hosting_response.emit(ErrorCodes.FAILED)

func _queue_lobby_host_timeout() -> void:
	var timer := get_tree().create_timer(STEAM_RESPONSE_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if is_busy and not is_host and steam_lobby_id == 0:
			lobby_hosting_response.emit(ErrorCodes.NO_RESPONSE)
	)

func _queue_lobby_join_timeout(lobby_id: int) -> void:
	var timer := get_tree().create_timer(STEAM_RESPONSE_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if is_busy and is_joining and steam_lobby_id == lobby_id:
			lobby_join_response.emit(ErrorCodes.NO_RESPONSE)
	)

func host_steam_lobby() -> ErrorCodes:
	if is_busy: return ErrorCodes.CURRENTLY_BUSY
	if not ensure_steam_initialized(): return ErrorCodes.STEAM_CONNECTION_ERROR
	if not is_steam_available(): return ErrorCodes.STEAM_CONNECTION_ERROR
	is_host = false
	is_busy = true
	var new_steam_peer := _create_steam_peer()
	if not new_steam_peer:
		is_busy = false
		return ErrorCodes.STEAM_CONNECTION_ERROR
	var host_error: int = new_steam_peer.create_host(0)
	var error_response := ErrorCodes.NO_RESPONSE
	match host_error:
		Error.OK:
			_queue_lobby_host_timeout()
			_steam().createLobby(STEAM_LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)
			var hosting_response: ErrorCodes = await lobby_hosting_response
			error_response = hosting_response
			match hosting_response:
				ErrorCodes.SUCCESS:
					is_host = true
					multiplayer.multiplayer_peer = new_steam_peer
					_register_player_data(personal_player_data.to_dict())
					joined_lobby.emit()
		_: error_response = ErrorCodes.FAILED
	is_busy = false
	return error_response

func _on_steam_join_requested(lobby_id: int, _steam_id: int) -> void: join_steam_lobby(lobby_id)

func join_steam_lobby(lobby_id: int = 0) -> ErrorCodes:
	if is_busy: return ErrorCodes.CURRENTLY_BUSY
	if not ensure_steam_initialized(): return ErrorCodes.STEAM_CONNECTION_ERROR
	if not is_steam_available(): return ErrorCodes.STEAM_CONNECTION_ERROR
	is_joining = true
	if lobby_id != steam_lobby_id and steam_lobby_id != 0: leave_lobby()
	is_host = false
	steam_lobby_id = lobby_id
	is_busy = true
	_steam().joinLobby(lobby_id)
	_queue_lobby_join_timeout(lobby_id)
	var error: ErrorCodes = await lobby_join_response
	is_joining = false
	if error == ErrorCodes.SUCCESS: joined_lobby.emit()
	is_busy = false
	return error

func _on_steam_lobby_join_response(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	var steam := _steam()
	if not steam:
		lobby_join_response.emit(ErrorCodes.STEAM_CONNECTION_ERROR)
		return
	var lobby_owner_id: int = steam.getLobbyOwner(lobby_id)
	if lobby_owner_id == steam.getSteamID(): lobby_join_response.emit(ErrorCodes.JOIN_FAILED_SAME_OWNER_ID); return
	if response != STEAM_RESULT_OK: lobby_join_response.emit(ErrorCodes.STEAM_CONNECTION_ERROR); return
	var new_steam_peer := _create_steam_peer()
	if not new_steam_peer:
		lobby_join_response.emit(ErrorCodes.STEAM_CONNECTION_ERROR)
		return
	var error: int = new_steam_peer.create_client(lobby_owner_id, 0)
	match error:
		OK:
			steam_lobby_id = lobby_id
			multiplayer.multiplayer_peer = new_steam_peer
			_register_player_data.call_deferred(personal_player_data.to_dict())
			lobby_join_response.emit(ErrorCodes.SUCCESS)
		_:
			new_steam_peer.close()
			steam.leaveLobby(steam_lobby_id)
			lobby_join_response.emit(ErrorCodes.FAILED)

func _create_steam_peer() -> MultiplayerPeer:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	var new_peer := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	if not new_peer:
		return null
	new_peer.set("server_relay", true)
	return new_peer

func _process_steam_p2p_packets() -> void:
	var steam := _steam()
	if not steam_initialized or not steam: return
	var packet_size: int = steam.getAvailableP2PPacketSize(0)
	if packet_size == 0: return
	var packet: Dictionary = steam.readP2PPacket(packet_size, 0)
	var packet_data: Variant = bytes_to_var(packet["data"])
	_handle_incoming_packet(packet_data)

#endregion

#region LOCAL MULTIPLAYER

const LOCAL_SERVER_ADDRESS: String = "127.0.0.1"
const LOCAL_SERVER_PORT: int = 8080

signal _local_host_check_response(has_host: bool)

var _check_timer: Timer

func _setup_local_multiplayer() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server) # Only emitted on clients

func host_local_lobby() -> ErrorCodes:
	if is_busy: return ErrorCodes.CURRENTLY_BUSY
	is_busy = true
	is_host = true
	
	var new_peer := ENetMultiplayerPeer.new()
	var error := new_peer.create_server(LOCAL_SERVER_PORT, MAX_PLAYERS)
	match error:
		OK:
			multiplayer.multiplayer_peer = new_peer
			_register_player_data(personal_player_data.to_dict())
			is_busy = false
			return ErrorCodes.SUCCESS
		_:
			is_host = false
			return ErrorCodes.FAILED

func join_local_lobby() -> ErrorCodes:
	if is_busy: return ErrorCodes.CURRENTLY_BUSY
	is_busy = true
	var has_local_host := await check_if_host_exists(LOCAL_SERVER_ADDRESS,LOCAL_SERVER_PORT)
	is_busy = false
	if not has_local_host: return ErrorCodes.FAILED
	else: return join_address(LOCAL_SERVER_ADDRESS, LOCAL_SERVER_PORT)

func check_if_host_exists(ip_address: String, port: int) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(ip_address, port)
	if error != OK: return false
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_host_found)
	multiplayer.connection_failed.connect(_on_host_missing)
	_check_timer = Timer.new()
	add_child(_check_timer)
	_check_timer.wait_time = 2.0
	_check_timer.one_shot = true
	_check_timer.timeout.connect(_on_host_missing)
	_check_timer.start()
	var has_host: bool = await _local_host_check_response
	peer.close()
	_local_cleanup()
	return has_host

func _on_host_found(): _local_host_check_response.emit(true)

func _on_host_missing(): _local_host_check_response.emit(false)

func _local_cleanup():
	if is_instance_valid(_check_timer): _check_timer.queue_free()
	if multiplayer.connected_to_server.is_connected(_on_host_found):
		multiplayer.connected_to_server.disconnect(_on_host_found)
	if multiplayer.connection_failed.is_connected(_on_host_missing):
		multiplayer.connection_failed.disconnect(_on_host_missing)
	multiplayer.multiplayer_peer = null
#endregion


#region DATA PAYLOAD LOGIC
class DataPayload extends Resource:
	enum Types { UNDEFINED, STEAM_LOBBY_INVITE }
	
	func _init() -> void: header = "DATA_PAYLOAD"
	
	var header: String:
		set(value): if header != value: header = value; _update_content("header",value)
	var lobby_invite_address: String:
		set(value): if lobby_invite_address != value: lobby_invite_address = value; _update_content("lobby_invite_address",value)
	var type: Types = Types.UNDEFINED:
		set(value): if type != value: type = value; _update_content("type",value)
	var steam_target_id: int = 0:
		set(value): if steam_target_id != value: steam_target_id = value; _update_content("steam_target_id",value)
	var steam_sender_id: int = 0:
		set(value): if steam_sender_id != value: steam_sender_id = value; _update_content("steam_sender_id",value)
	var steam_send_type: int = STEAM_P2P_SEND_RELIABLE:
		set(value): if steam_send_type != value: steam_send_type = value; _update_content("steam_send_type",value)
	var steam_packet_channel: int = 0:
		set(value): if steam_packet_channel != value: steam_packet_channel = value; _update_content("steam_packet_channel",value)

	var content: Dictionary
	var packet_data: PackedByteArray: get = _get_packet_data
	
	func _get_packet_data() -> PackedByteArray:
		var data: Dictionary = {}
		for key in content:
			data.set(key,str(content.get(key)))
		return var_to_bytes(data)
	
	func _update_content(content_key: String,value: Variant) -> bool:
		if not value: content.erase(content_key)
		else: content.set(content_key,value)
		return true
	
	static func create_steam_invite_payload(invite_address: Variant, steam_id_to_invite: int, invite_send_type: int = STEAM_P2P_SEND_RELIABLE, invite_packet_channel: int = 0) -> DataPayload:
		invite_address = str(invite_address)
		if not invite_address: return
		var invite_payload := DataPayload.new()
		invite_payload.type = Types.STEAM_LOBBY_INVITE
		invite_payload.lobby_invite_address = invite_address
		invite_payload.steam_target_id = steam_id_to_invite
		var steam := Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null
		invite_payload.steam_sender_id = steam.getSteamID() if steam else -1
		invite_payload.steam_send_type = invite_send_type
		invite_payload.steam_packet_channel = invite_packet_channel
		return invite_payload

	static func from_dict(dict: Dictionary) -> DataPayload:
		# Instantiates a DataPayload and configures it based on the given dictionary.
		var new_payload := DataPayload.new()
		for key in dict:
			var value: Variant = dict.get(key)
			if value == null: continue
			new_payload.set(key,value)
		return new_payload

	func send() -> bool:
		var tree := Engine.get_main_loop() as SceneTree
		if not tree:
			return false
		var online := tree.root.get_node_or_null("/root/Online")
		if not online:
			return false
		return online._send_steam_data_payload(self)

func _handle_incoming_packet(data: Dictionary) -> void:
	match data.get("header"):
		"DATA_PAYLOAD": _handle_payload_received(DataPayload.from_dict(data))

func _handle_payload_received(payload: DataPayload) -> void:
	match payload.type:
		payload.Types.STEAM_LOBBY_INVITE:
			var invite_steam_lobby_id: int = int(payload.lobby_invite_address)
			var sender_id: int = payload.steam_sender_id
			steam_lobby_invite_received.emit(invite_steam_lobby_id, sender_id)

func _send_steam_data_payload(payload: DataPayload) -> bool:
	var steam := _steam()
	if not steam:
		return false
	var target_steam_id: int = payload.steam_target_id
	for player in players.values():
		if player.steam_id == target_steam_id:
			var target_persona_name: String = steam.getFriendPersonaName(player.steam_id)
			print_rich("[color=red][b]Lobby Error:[/b][/color] Failed to invite '%s' (Already in lobby)." % target_persona_name)
			return false
	var success: bool = steam.sendP2PPacket(target_steam_id, payload.packet_data, payload.steam_send_type, payload.steam_packet_channel)
	if payload.type == payload.Types.STEAM_LOBBY_INVITE:
		steam.inviteUserToLobby(int(payload.lobby_invite_address), payload.steam_target_id) # This triggers the direct message invite in the Steam App
	return success
#endregion
