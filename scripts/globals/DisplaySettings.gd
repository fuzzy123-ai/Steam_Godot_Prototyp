extends Node

signal settings_changed(settings: Dictionary)

const CONFIG_PATH := "user://display_settings.cfg"
const MODE_WINDOWED := "windowed"
const MODE_BORDERLESS := "borderless"
const MODE_FULLSCREEN := "fullscreen"

const FALLBACK_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var current_mode: String = MODE_BORDERLESS
var current_resolution: Vector2i = Vector2i(1920, 1080)
var system_resolution: Vector2i = Vector2i(1920, 1080)
var available_resolutions: Array[Vector2i] = []


func _ready() -> void:
	system_resolution = _detect_system_resolution()
	current_resolution = system_resolution
	available_resolutions = _build_resolution_list(system_resolution)
	_load_settings()
	_apply_startup_settings.call_deferred()


func get_mode_options() -> Array[Dictionary]:
	return [
		{"id": MODE_BORDERLESS, "label": "Borderless Fullscreen"},
		{"id": MODE_FULLSCREEN, "label": "Fullscreen"},
		{"id": MODE_WINDOWED, "label": "Windowed"}
	]


func get_available_resolutions() -> Array[Vector2i]:
	return available_resolutions.duplicate()


func get_current_settings() -> Dictionary:
	return {
		"mode": current_mode,
		"resolution": current_resolution,
		"system_resolution": system_resolution
	}


func apply_settings(mode: String, resolution: Vector2i, should_save: bool = true) -> void:
	current_mode = _sanitize_mode(mode)
	current_resolution = _sanitize_resolution(resolution)

	match current_mode:
		MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(current_resolution)
			_center_window(current_resolution)
		MODE_FULLSCREEN:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_size(current_resolution)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			current_mode = MODE_BORDERLESS
			current_resolution = system_resolution
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	if should_save:
		_save_settings()
	settings_changed.emit(get_current_settings())


func cycle_mode() -> void:
	var next_mode := MODE_BORDERLESS
	match current_mode:
		MODE_BORDERLESS:
			next_mode = MODE_FULLSCREEN
		MODE_FULLSCREEN:
			next_mode = MODE_WINDOWED
		_:
			next_mode = MODE_BORDERLESS
	apply_settings(next_mode, current_resolution)


func refresh_system_resolution() -> void:
	system_resolution = _detect_system_resolution()
	available_resolutions = _build_resolution_list(system_resolution)
	if current_mode == MODE_BORDERLESS:
		current_resolution = system_resolution
	settings_changed.emit(get_current_settings())


func _apply_startup_settings() -> void:
	apply_settings(current_mode, current_resolution, false)


func _detect_system_resolution() -> Vector2i:
	var screen := DisplayServer.window_get_current_screen()
	var size := DisplayServer.screen_get_size(screen)
	if size.x <= 0 or size.y <= 0:
		return Vector2i(1920, 1080)
	return size


func _build_resolution_list(native_size: Vector2i) -> Array[Vector2i]:
	var resolutions: Array[Vector2i] = []
	for resolution: Vector2i in FALLBACK_RESOLUTIONS:
		if resolution.x <= native_size.x and resolution.y <= native_size.y:
			resolutions.append(resolution)
	if not resolutions.has(native_size):
		resolutions.append(native_size)
	resolutions.sort_custom(func(left: Vector2i, right: Vector2i) -> bool:
		if left.x == right.x:
			return left.y < right.y
		return left.x < right.x
	)
	return resolutions


func _sanitize_mode(mode: String) -> String:
	if mode == MODE_WINDOWED or mode == MODE_FULLSCREEN or mode == MODE_BORDERLESS:
		return mode
	return MODE_BORDERLESS


func _sanitize_resolution(resolution: Vector2i) -> Vector2i:
	if resolution.x <= 0 or resolution.y <= 0:
		return system_resolution
	if not available_resolutions.has(resolution):
		available_resolutions.append(resolution)
	return resolution


func _center_window(size: Vector2i) -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var centered := screen_position + Vector2i(
		maxi(0, (screen_size.x - size.x) / 2),
		maxi(0, (screen_size.y - size.y) / 2)
	)
	DisplayServer.window_set_position(centered)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	current_mode = _sanitize_mode(str(config.get_value("display", "mode", MODE_BORDERLESS)))
	current_resolution = Vector2i(
		int(config.get_value("display", "width", system_resolution.x)),
		int(config.get_value("display", "height", system_resolution.y))
	)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "mode", current_mode)
	config.set_value("display", "width", current_resolution.x)
	config.set_value("display", "height", current_resolution.y)
	config.save(CONFIG_PATH)
