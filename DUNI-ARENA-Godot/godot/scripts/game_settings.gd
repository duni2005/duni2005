class_name GameSettings
extends RefCounted
## Player preferences, stored apart from run saves in user://settings.cfg, in three groups:
## 게임플레이 (vibration, screen-shake strength, damage numbers, UI animation), 그래픽 (frame limit,
## particle quality) and 소리 (master / music / sound-effect volume on their own audio buses).
const PATH := "user://settings.cfg"
## Screen shake: 끄기 / 약하게 / 보통 / 강하게.
const SHAKE_LEVELS := ["끄기", "약하게", "보통", "강하게"]
const SHAKE_SCALES := [0.0, .5, 1.0, 1.5]
## Particle quality: 낮음 / 보통 / 높음 (share of particles drawn).
const PARTICLE_LEVELS := ["낮음", "보통", "높음"]
const PARTICLE_SCALES := [.35, .65, 1.0]
## Frame limit choices (0 = no limit beyond the display's refresh rate).
const FPS_CHOICES := [30, 60, 0]
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
static var vibration: bool = true
static var motion: bool = true
static var shake_level: int = 2
static var damage_numbers: bool = true
static var fps_limit: int = 0
static var particles: int = 2
static var master_volume: float = 1.0
static var music_volume: float = 1.0
static var sfx_volume: float = 1.0
static var loaded: bool = false
static func shake_scale() -> float:return SHAKE_SCALES[clampi(shake_level, 0, SHAKE_SCALES.size() - 1)]
static func particle_scale() -> float:return PARTICLE_SCALES[clampi(particles, 0, PARTICLE_SCALES.size() - 1)]

static func load_settings() -> void:
	loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		vibration = bool(file.get_value("gameplay", "vibration", file.get_value("ui", "vibration", true)))
		motion = bool(file.get_value("gameplay", "motion", file.get_value("ui", "motion", true)))
		# Older files kept shake as on/off.
		shake_level = clampi(int(file.get_value("gameplay", "shake_level", 2 if bool(file.get_value("ui", "shake", true)) else 0)), 0, 3)
		damage_numbers = bool(file.get_value("gameplay", "damage_numbers", true))
		fps_limit = int(file.get_value("graphics", "fps_limit", 0))
		if fps_limit not in FPS_CHOICES:fps_limit = 0
		particles = clampi(int(file.get_value("graphics", "particles", 2)), 0, 2)
		master_volume = clampf(float(file.get_value("audio", "master", 1.0)), 0, 1)
		music_volume = clampf(float(file.get_value("audio", "music", 1.0)), 0, 1)
		sfx_volume = clampf(float(file.get_value("audio", "sfx", 1.0)), 0, 1)
	apply()

static func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("gameplay", "vibration", vibration);file.set_value("gameplay", "motion", motion)
	file.set_value("gameplay", "shake_level", shake_level);file.set_value("gameplay", "damage_numbers", damage_numbers)
	file.set_value("graphics", "fps_limit", fps_limit);file.set_value("graphics", "particles", particles)
	file.set_value("audio", "master", master_volume);file.set_value("audio", "music", music_volume);file.set_value("audio", "sfx", sfx_volume)
	file.save(PATH);apply()

static func value(key: String):
	return {"vibration": vibration, "motion": motion, "shake": shake_level > 0, "shake_level": shake_level, "damage_numbers": damage_numbers,
		"fps_limit": fps_limit, "particles": particles, "master": master_volume, "music": music_volume, "sfx": sfx_volume}.get(key)

static func set_value(key: String, v) -> void:
	match key:
		"vibration":vibration = bool(v)
		"motion":motion = bool(v)
		"shake":shake_level = 2 if bool(v) else 0
		"shake_level":shake_level = clampi(int(v), 0, 3)
		"damage_numbers":damage_numbers = bool(v)
		"fps_limit":fps_limit = int(v) if int(v) in FPS_CHOICES else 0
		"particles":particles = clampi(int(v), 0, 2)
		"master":master_volume = clampf(float(v), 0, 1)
		"music":music_volume = clampf(float(v), 0, 1)
		"sfx":sfx_volume = clampf(float(v), 0, 1)
	save_settings()

## Music and sound-effect buses under Master (created once).
static func ensure_buses() -> void:
	for bus in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus();var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus);AudioServer.set_bus_send(i, "Master")
static func _volume(bus: String, v: float) -> void:
	var i: int = AudioServer.get_bus_index(bus)
	if i < 0:return
	AudioServer.set_bus_mute(i, v <= .001);AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, .001)))

static func apply() -> void:
	UiMotion.enabled = motion and DisplayServer.get_name() != "headless"
	Engine.max_fps = fps_limit
	ensure_buses()
	_volume("Master", master_volume);_volume(MUSIC_BUS, music_volume);_volume(SFX_BUS, sfx_volume)
