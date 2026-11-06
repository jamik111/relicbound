extends Node
## Player settings, stored in user://settings.cfg. Not part of the sim.

enum QualityTier { LITE, STANDARD, HIGH }
enum TouchScheme { SWIPE, STICK, DPAD }

const PATH: String = "user://settings.cfg"
## Renamed from "touch_scheme" when the D-pad became the default (playtest 5), so everyone moves to it once.
const SCHEME_KEY: String = "touch_scheme_v2"

var quality_tier: QualityTier = QualityTier.STANDARD
var touch_scheme: TouchScheme = TouchScheme.DPAD
var haptics_enabled: bool = true
var assist_mode: bool = false
var music_volume: float = 0.8
var sfx_volume: float = 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality_tier = cfg.get_value("video", "quality_tier", quality_tier) as QualityTier
	touch_scheme = cfg.get_value("input", SCHEME_KEY, touch_scheme) as TouchScheme
	haptics_enabled = cfg.get_value("input", "haptics", haptics_enabled) as bool
	assist_mode = cfg.get_value("game", "assist_mode", assist_mode) as bool
	music_volume = cfg.get_value("audio", "music", music_volume) as float
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume) as float


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality_tier", quality_tier)
	cfg.set_value("input", SCHEME_KEY, touch_scheme)
	cfg.set_value("input", "haptics", haptics_enabled)
	cfg.set_value("game", "assist_mode", assist_mode)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(PATH)
	Events.settings_changed.emit()


func set_quality_tier(tier: QualityTier) -> void:
	if tier == quality_tier:
		return
	quality_tier = tier
	save_settings()
	Events.quality_tier_changed.emit(tier)
