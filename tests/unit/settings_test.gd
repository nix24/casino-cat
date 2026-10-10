extends TestCase
## Settings: D41 defaults when no file exists, a save and load round trip, the reduced-motion
## gate, and clamped values. Writes only user://test_settings.cfg, which each test clears (T006).

const SETTINGS_SCRIPT = preload("res://src/run/settings.gd")
const TEST_PATH: String = "user://test_settings.cfg"


func test_defaults_when_file_missing() -> void:
	_clear_file()
	var settings := SETTINGS_SCRIPT.new()
	settings.config_path = TEST_PATH
	settings.load_from_disk()
	assert_eq(settings.master_volume, 1.0)
	assert_eq(settings.music_volume, 1.0)
	assert_eq(settings.sfx_volume, 1.0)
	assert_eq(settings.ui_volume, 1.0)
	assert_true(settings.screen_shake)
	assert_true(settings.pitch_stacking)
	assert_true(not settings.crt_filter)
	assert_true(not settings.reduced_flashing)
	assert_true(not settings.reduced_motion)
	assert_eq(settings.battle_speed, 0)
	assert_eq(settings.coach_seen, PackedStringArray())
	assert_true(not settings.fullscreen)
	_clear_file()


func test_save_and_load_round_trip() -> void:
	_clear_file()
	var settings := SETTINGS_SCRIPT.new()
	settings.config_path = TEST_PATH
	settings.sfx_volume = 0.25
	settings.crt_filter = true
	settings.battle_speed = 1
	settings.coach_seen = PackedStringArray(["first_fight"])
	settings.save()

	var loaded := SETTINGS_SCRIPT.new()
	loaded.config_path = TEST_PATH
	loaded.load_from_disk()
	assert_eq(loaded.sfx_volume, 0.25)
	assert_true(loaded.crt_filter)
	assert_eq(loaded.battle_speed, 1)
	assert_eq(loaded.coach_seen, PackedStringArray(["first_fight"]))
	_clear_file()


func test_motion_allowed_follows_reduced_motion() -> void:
	var settings := SETTINGS_SCRIPT.new()
	assert_true(settings.motion_allowed())
	settings.reduced_motion = true
	assert_true(not settings.motion_allowed())


func test_volume_clamped_to_0_1() -> void:
	var settings := SETTINGS_SCRIPT.new()
	settings.master_volume = 1.7
	assert_eq(settings.master_volume, 1.0)
	settings.master_volume = -0.5
	assert_eq(settings.master_volume, 0.0)


func test_battle_speed_clamped() -> void:
	var settings := SETTINGS_SCRIPT.new()
	settings.battle_speed = 5
	assert_eq(settings.battle_speed, 2)


func _clear_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)
