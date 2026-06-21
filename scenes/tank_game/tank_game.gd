extends Node

@onready var world: Node3D = %World
@onready var lobby_start_screen: Control = %LobbyStartScreen

var match_started: bool = false


func _ready() -> void:
	world.hide()
	lobby_start_screen.start_match_requested.connect(_on_start_match_requested)


func _on_start_match_requested() -> void:
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return
		_start_match.rpc()
	else:
		_start_match()


@rpc("authority", "reliable", "call_local")
func _start_match() -> void:
	if match_started:
		return
	match_started = true
	lobby_start_screen.hide()
	world.show()
