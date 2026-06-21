extends Node

@onready var world: Node3D = %World
@onready var lobby_start_screen: Control = %LobbyStartScreen
@onready var match_status_label: Label = %MatchStatusLabel

var match_started: bool = false


func _ready() -> void:
	world.hide()
	match_status_label.hide()
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
	if lobby_start_screen.has_method("show_loading"):
		lobby_start_screen.call("show_loading", "Start signal received", 35.0)
	await get_tree().create_timer(0.25).timeout
	if lobby_start_screen.has_method("show_loading"):
		lobby_start_screen.call("show_loading", "Preparing match world", 65.0)
	await get_tree().create_timer(0.25).timeout
	lobby_start_screen.hide()
	world.show()
	match_status_label.text = "Match loaded | Terrain placeholder active | Tank preview spawned"
	match_status_label.show()
