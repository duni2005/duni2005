class_name GameSettings
extends RefCounted
## Player preferences, stored apart from run saves in user://settings.cfg.
const PATH := "user://settings.cfg"
static var vibration: bool = true
static var motion: bool = true
static var shake: bool = true
static var loaded: bool = false

static func load_settings() -> void:
	loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		vibration = bool(file.get_value("ui", "vibration", true))
		motion = bool(file.get_value("ui", "motion", true))
		shake = bool(file.get_value("ui", "shake", true))
	apply()

static func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("ui", "vibration", vibration);file.set_value("ui", "motion", motion);file.set_value("ui", "shake", shake)
	file.save(PATH);apply()

static func value(key: String) -> bool:
	return {"vibration": vibration, "motion": motion, "shake": shake}.get(key, false)

static func set_value(key: String, on: bool) -> void:
	match key:
		"vibration":vibration = on
		"motion":motion = on
		"shake":shake = on
	save_settings()

static func apply() -> void:
	UiMotion.enabled = motion and DisplayServer.get_name() != "headless"
