extends Node
## Player settings, saved to user://settings.cfg (arch §5, decisions D41). An autoload named
## Settings. It holds plain values only; screens read and write them and nothing here touches the
## scene tree. A missing file or key gives the D41 defaults, so a fresh install needs no setup.

const SECTION: String = "settings"

## Where the settings file lives. Tests point this at a scratch file.
var config_path: String = "user://settings.cfg"

var master_volume: float = 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
var music_volume: float = 1.0:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
var ui_volume: float = 1.0:
	set(value):
		ui_volume = clampf(value, 0.0, 1.0)

var screen_shake: bool = true
var pitch_stacking: bool = true
var crt_filter: bool = false
var reduced_flashing: bool = false
var reduced_motion: bool = false
## 0 = 1×, 1 = 2×, 2 = instant (EventPlayer.SPEED_*).
var battle_speed: int = 0:
	set(value):
		battle_speed = clampi(value, 0, 2)
## Ids of the one-time coach bubbles the player has dismissed (T037).
var coach_seen: PackedStringArray = PackedStringArray()
## Desktop only. The web build ignores it.
var fullscreen: bool = false


func _ready() -> void:
	load_from_disk()


## Reads every key from [member config_path]. Each key keeps its current value as the default, so a
## missing key or file keeps the D41 defaults.
func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	var error: Error = cfg.load(config_path)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_warning("settings: cannot read %s (error %d); using defaults" % [config_path, error])
		return
	master_volume = _read(cfg, "master_volume", master_volume)
	music_volume = _read(cfg, "music_volume", music_volume)
	sfx_volume = _read(cfg, "sfx_volume", sfx_volume)
	ui_volume = _read(cfg, "ui_volume", ui_volume)
	screen_shake = _read(cfg, "screen_shake", screen_shake)
	pitch_stacking = _read(cfg, "pitch_stacking", pitch_stacking)
	crt_filter = _read(cfg, "crt_filter", crt_filter)
	reduced_flashing = _read(cfg, "reduced_flashing", reduced_flashing)
	reduced_motion = _read(cfg, "reduced_motion", reduced_motion)
	battle_speed = _read(cfg, "battle_speed", battle_speed)
	coach_seen = _read(cfg, "coach_seen", coach_seen)
	fullscreen = _read(cfg, "fullscreen", fullscreen)


## The value of [param key], or [param current] when the file holds another type. A hand-edited
## file must not break the boot; a whole number is fine where a volume (float) is expected.
func _read(cfg: ConfigFile, key: String, current: Variant) -> Variant:
	var value: Variant = cfg.get_value(SECTION, key, current)
	if typeof(value) == typeof(current):
		return value
	if typeof(current) == TYPE_FLOAT and typeof(value) == TYPE_INT:
		return float(value as int)
	push_warning("settings: %s has the wrong type; using %s" % [key, current])
	return current


## Writes every setting to [member config_path]. A failed write warns; values stay in memory.
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "ui_volume", ui_volume)
	cfg.set_value(SECTION, "screen_shake", screen_shake)
	cfg.set_value(SECTION, "pitch_stacking", pitch_stacking)
	cfg.set_value(SECTION, "crt_filter", crt_filter)
	cfg.set_value(SECTION, "reduced_flashing", reduced_flashing)
	cfg.set_value(SECTION, "reduced_motion", reduced_motion)
	cfg.set_value(SECTION, "battle_speed", battle_speed)
	cfg.set_value(SECTION, "coach_seen", coach_seen)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	var error: Error = cfg.save(config_path)
	if error != OK:
		push_warning("settings: cannot write %s (error %d)" % [config_path, error])


## True when motion effects may play. Reduced motion turns them off everywhere.
func motion_allowed() -> bool:
	return not reduced_motion
