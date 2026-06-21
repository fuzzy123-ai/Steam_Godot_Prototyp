extends Control

signal quit_game_requested

@onready var settings_button: Button = $SettingsButton
@onready var local_display_settings: Node = $DisplaySettings
@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/Panel/Margin/Content/TitleLabel
@onready var system_resolution_label: Label = $Overlay/Panel/Margin/Content/SystemResolutionLabel
@onready var resume_button: Button = $Overlay/Panel/Margin/Content/PauseActions/ResumeButton
@onready var options_button: Button = $Overlay/Panel/Margin/Content/PauseActions/OptionsButton
@onready var quit_button: Button = $Overlay/Panel/Margin/Content/PauseActions/QuitButton
@onready var options_container: VBoxContainer = $Overlay/Panel/Margin/Content/OptionsContainer
@onready var mode_option: OptionButton = $Overlay/Panel/Margin/Content/OptionsContainer/ModeRow/ModeOption
@onready var resolution_option: OptionButton = $Overlay/Panel/Margin/Content/OptionsContainer/ResolutionRow/ResolutionOption
@onready var apply_button: Button = $Overlay/Panel/Margin/Content/OptionsContainer/ApplyButton
@onready var quit_confirm: ConfirmationDialog = $QuitConfirm

var _display_settings: Node
var _mode_ids: Array[String] = []
var _resolution_items: Array[Vector2i] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.hide()
	_display_settings = _ensure_display_settings()
	settings_button.pressed.connect(_on_settings_pressed)
	resume_button.pressed.connect(_close_menu)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(_on_quit_pressed)
	quit_confirm.confirmed.connect(_on_quit_confirmed)
	mode_option.item_selected.connect(_on_mode_selected)
	apply_button.pressed.connect(_apply_selected_settings)
	if _display_settings != null and _display_settings.has_signal("settings_changed"):
		_display_settings.connect("settings_changed", Callable(self, "_on_display_settings_changed"))
	_populate_display_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay.visible:
			_close_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()


func _on_settings_pressed() -> void:
	_open_options_menu()


func _open_pause_menu() -> void:
	title_label.text = "Pause"
	options_container.hide()
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open_options_menu() -> void:
	title_label.text = "Optionen"
	options_container.show()
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_populate_display_controls()


func _show_options() -> void:
	title_label.text = "Optionen"
	options_container.show()
	_populate_display_controls()


func _close_menu() -> void:
	overlay.hide()


func _on_quit_pressed() -> void:
	quit_confirm.popup_centered()


func _on_quit_confirmed() -> void:
	quit_game_requested.emit()


func _populate_display_controls() -> void:
	if _display_settings == null:
		system_resolution_label.text = "DisplaySettings nicht geladen"
		mode_option.clear()
		resolution_option.clear()
		return

	var settings: Dictionary = _display_settings.call("get_current_settings")
	var system_resolution: Vector2i = settings.get("system_resolution", Vector2i.ZERO)
	system_resolution_label.text = "Systemaufloesung: %d x %d" % [system_resolution.x, system_resolution.y]

	_mode_ids.clear()
	mode_option.clear()
	var modes: Array = _display_settings.call("get_mode_options")
	for mode: Dictionary in modes:
		_mode_ids.append(str(mode["id"]))
		mode_option.add_item(str(mode["label"]))

	var current_mode := str(settings.get("mode", "borderless"))
	var mode_index := maxi(0, _mode_ids.find(current_mode))
	mode_option.select(mode_index)

	_resolution_items = _display_settings.call("get_available_resolutions")
	resolution_option.clear()
	for resolution: Vector2i in _resolution_items:
		resolution_option.add_item("%d x %d" % [resolution.x, resolution.y])

	var current_resolution: Vector2i = settings.get("resolution", system_resolution)
	var resolution_index := _resolution_items.find(current_resolution)
	if resolution_index < 0:
		resolution_index = _resolution_items.find(system_resolution)
	resolution_option.select(maxi(0, resolution_index))
	_sync_resolution_enabled()


func _on_mode_selected(_index: int) -> void:
	_sync_resolution_enabled()


func _sync_resolution_enabled() -> void:
	var selected_mode := _selected_mode()
	resolution_option.disabled = selected_mode == "borderless"


func _apply_selected_settings() -> void:
	if _display_settings == null:
		return
	_display_settings.call("apply_settings", _selected_mode(), _selected_resolution())
	_populate_display_controls()


func _selected_mode() -> String:
	var selected := mode_option.selected
	if selected >= 0 and selected < _mode_ids.size():
		return _mode_ids[selected]
	return "borderless"


func _selected_resolution() -> Vector2i:
	var selected := resolution_option.selected
	if selected >= 0 and selected < _resolution_items.size():
		return _resolution_items[selected]
	if _display_settings != null:
		var settings: Dictionary = _display_settings.call("get_current_settings")
		return settings.get("system_resolution", Vector2i(1920, 1080))
	return Vector2i(1920, 1080)


func _on_display_settings_changed(_settings: Dictionary) -> void:
	if overlay.visible:
		_populate_display_controls()


func cycle_display_mode() -> void:
	if _display_settings != null and _display_settings.has_method("cycle_mode"):
		_display_settings.call("cycle_mode")


func _ensure_display_settings() -> Node:
	var existing := get_node_or_null("/root/DisplaySettings")
	if existing != null:
		return existing
	return local_display_settings
