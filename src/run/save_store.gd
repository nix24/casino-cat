class_name SaveStore
extends RefCounted
## The only code that touches user:// (arch §6, PRD §17.4). Writes are atomic: the new text is
## checked before the old file moves to .bak, so a failed write never leaves a broken main file.
## Reads fall back to .bak. The save code is the same JSON as a copy-paste string.

enum Result { OK, MISSING, UNREADABLE, TOO_NEW, WRITE_FAILED }

const SAVE_CODE_PREFIX: String = "CC1:"
const CRC_POLYNOMIAL: int = 0xEDB88320
## One entry per byte value, built once. Keeps crc32() to one table lookup per byte.
static var _crc_table: PackedInt64Array = _build_crc_table()

## Folder for save files. Tests point this at user://test_saves/.
var base_dir: String = "user://"
## Outcome of the last read_json or write_json call.
var last_result: Result = Result.OK


## Writes [param data] to [param file_name] under [member base_dir]. Steps 0-5 are the order from
## arch §6; a failure at any step leaves the main file and .bak as they were.
func write_json(file_name: String, data: Dictionary) -> Result:
	# Step 0: JSON would silently turn StringName, Vector2i, and int keys into other values.
	if not is_plain(data):
		return _reject(Result.WRITE_FAILED, "%s: data is not plain JSON" % file_name)
	var path := base_dir.path_join(file_name)
	var bak_path := path + ".bak"
	var tmp_path := path + ".tmp"
	# Step 1: never overwrite a file a newer build wrote (D40).
	if _is_newer_build_file(path):
		return _reject(Result.TOO_NEW, "%s: written by a newer build, not overwritten" % path)
	# Step 2: write the tmp file.
	DirAccess.make_dir_recursive_absolute(base_dir)
	var tmp_file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		return _reject(Result.WRITE_FAILED, "%s: cannot open for writing" % tmp_path)
	tmp_file.store_string(JSON.stringify(data))
	tmp_file.close()
	# Step 3: the tmp file must parse back to a Dictionary before it can replace anything.
	var reparsed: Variant = _parse_file(tmp_path)
	if not reparsed is Dictionary:
		DirAccess.remove_absolute(tmp_path)
		return _reject(Result.WRITE_FAILED, "%s: tmp file did not parse back" % path)
	# Steps 4 and 5 are in their own function to keep write_json under the max-returns lint.
	return _swap_in_tmp_file(path, bak_path, tmp_path)


## Steps 4 and 5 of write_json: the current file becomes .bak, then the tmp file takes its place.
## A failure at step 5 leaves the .bak fallback in place, so reads still succeed.
func _swap_in_tmp_file(path: String, bak_path: String, tmp_path: String) -> Result:
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		if DirAccess.rename_absolute(path, bak_path) != OK:
			DirAccess.remove_absolute(tmp_path)
			return _reject(Result.WRITE_FAILED, "%s: cannot move to .bak" % path)
	if DirAccess.rename_absolute(tmp_path, path) != OK:
		return _reject(Result.WRITE_FAILED, "%s: cannot rename tmp file" % path)
	last_result = Result.OK
	return Result.OK


## Reads [param file_name], then its .bak. Returns the first usable file, migrated to the current
## version. Returns {} on failure and sets [member last_result].
func read_json(file_name: String) -> Dictionary:
	var path := base_dir.path_join(file_name)
	var bak_path := path + ".bak"
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(bak_path):
		last_result = Result.MISSING
		return {}
	for candidate: String in [path, bak_path]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = _parse_file(candidate)
		if not parsed is Dictionary:
			push_warning("%s: not a JSON object" % candidate)
			continue
		var saved: Dictionary = parsed
		var reader := SaveReader.new(saved, file_name)
		var version: int = reader.int_at("version")
		if not reader.ok():
			reader.warn()
			continue
		# A newer build wrote this file, so its .bak is not a safe fallback either.
		if version > SaveMigrations.CURRENT_VERSION:
			last_result = Result.TOO_NEW
			push_warning("%s: version %d is newer than this build" % [candidate, version])
			return {}
		var migrated: Dictionary = SaveMigrations.upgrade(saved)
		if migrated.is_empty():
			continue
		last_result = Result.OK
		return migrated
	last_result = Result.UNREADABLE
	push_warning("%s: no usable file, main or .bak" % path)
	return {}


## Save code: "CC1:" + base64 of the JSON + ":" + 8 lowercase hex digits of the base64 text's CRC.
static func encode_save_code(data: Dictionary) -> String:
	var body := Marshalls.utf8_to_base64(JSON.stringify(data))
	return "%s%s:%08x" % [SAVE_CODE_PREFIX, body, crc32(body.to_utf8_buffer())]


## Parses a save code. Returns {} with a warning on a bad prefix, bad CRC, or bad JSON. The
## version is not checked here; the caller passes the result through SaveMigrations.upgrade.
static func decode_save_code(code: String) -> Dictionary:
	if not code.begins_with(SAVE_CODE_PREFIX):
		push_warning("save code: missing %s prefix" % SAVE_CODE_PREFIX)
		return {}
	var rest := code.trim_prefix(SAVE_CODE_PREFIX)
	var separator := rest.rfind(":")
	if separator < 0:
		push_warning("save code: no CRC suffix")
		return {}
	var body := rest.substr(0, separator)
	# Comparing against the full formatted text checks length, digits, and case in one step.
	if rest.substr(separator + 1) != "%08x" % crc32(body.to_utf8_buffer()):
		push_warning("save code: CRC mismatch")
		return {}
	var json := JSON.new()
	if json.parse(Marshalls.base64_to_utf8(body)) != OK:
		push_warning("save code: payload is not JSON")
		return {}
	var payload: Variant = json.data
	if not payload is Dictionary:
		push_warning("save code: payload is not a JSON object")
		return {}
	var decoded: Dictionary = payload
	return decoded


## CRC-32/IEEE (reflected polynomial 0xEDB88320, init and final XOR 0xFFFFFFFF).
static func crc32(bytes: PackedByteArray) -> int:
	var crc: int = 0xFFFFFFFF
	for byte: int in bytes:
		crc = (crc >> 8) ^ _crc_table[(crc ^ byte) & 0xFF]
	return crc ^ 0xFFFFFFFF


## True for values JSON round-trips unchanged: null, bool, int, finite float, String, and arrays
## or String-keyed dictionaries of those. StringName, Vector2i, INF, and objects are not plain.
static func is_plain(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			var number: float = value
			return is_finite(number)
		TYPE_ARRAY:
			var array: Array = value
			for item: Variant in array:
				if not is_plain(item):
					return false
			return true
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			for key: Variant in dictionary:
				if not key is String or not is_plain(dictionary[key]):
					return false
			return true
	return false


static func _build_crc_table() -> PackedInt64Array:
	var table := PackedInt64Array()
	table.resize(256)
	for index: int in 256:
		var value: int = index
		for _bit: int in 8:
			if (value & 1) == 1:
				value = (value >> 1) ^ CRC_POLYNOMIAL
			else:
				value >>= 1
		table[index] = value
	return table


## True when the file at [param path] parses to a save version newer than this build reads.
func _is_newer_build_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return _version_of(_parse_file(path)) > SaveMigrations.CURRENT_VERSION


## The "version" of a parsed save, or -1 when it is not a dictionary or has no integral version.
## Silent on purpose: callers decide whether a bad file is worth a warning.
static func _version_of(parsed: Variant) -> int:
	if not parsed is Dictionary:
		return -1
	var saved: Dictionary = parsed
	var reader := SaveReader.new(saved, "save")
	var version: int = reader.int_at("version")
	if not reader.ok():
		return -1
	return version


## Parses the JSON file at [param path]. Returns null after a warning when it is unreadable or not
## JSON. Callers check the file exists first, so a missing file is not reported here.
func _parse_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("%s: cannot open for reading" % path)
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("%s: not JSON, line %d" % [path, json.get_error_line()])
		return null
	return json.data


## Records [param result] as the last outcome, warns with [param reason], returns [param result].
func _reject(result: Result, reason: String) -> Result:
	last_result = result
	push_warning("SaveStore: " + reason)
	return result
