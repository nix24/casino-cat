class_name SaveReader
extends RefCounted
## Typed reads out of a parsed save dictionary (T005 R4). RunState, RunStats, and MetaState use it
## so every rejected field fails the same way. Records the first failing key; later reads return
## zero values and never replace that key. The plain_* helpers are the to_dict side of the same
## format.

## Largest integer a JSON number holds exactly (2^53). Bigger floats are not treated as integers.
const MAX_EXACT_INTEGER: float = 9007199254740992.0

var _source: Dictionary
var _context: String
var _failed_key: String = ""
var _reason: String = ""


func _init(source: Dictionary, context: String) -> void:
	_source = source
	_context = context


## True until a read fails.
func ok() -> bool:
	return _failed_key.is_empty()


## Warns about the first failing read. Does nothing when every read passed.
func warn() -> void:
	if ok():
		return
	push_warning("%s: %s: %s" % [_context, _failed_key, _reason])


func int_at(key: String) -> int:
	var value: Variant = _fetch(key)
	if not ok():
		return 0
	return _as_integer(key, value)


func string_at(key: String) -> String:
	var value: Variant = _fetch(key)
	if not ok():
		return ""
	if value is String:
		return value
	_fail(key, "wrong type")
	return ""


func dict_at(key: String) -> Dictionary:
	var value: Variant = _fetch(key)
	if not ok():
		return {}
	if value is Dictionary:
		return value
	_fail(key, "wrong type")
	return {}


func array_at(key: String) -> Array:
	var value: Variant = _fetch(key)
	if not ok():
		return []
	if value is Array:
		return value
	_fail(key, "wrong type")
	return []


## An array whose every element is a String, as StringName ids.
func ids_at(key: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	var values: Array = array_at(key)
	if not ok():
		return ids
	for value: Variant in values:
		if not value is String:
			_fail(key, "wrong type")
			return []
		var text: String = value
		ids.append(StringName(text))
	return ids


## An array whose every element is a Dictionary.
func dicts_at(key: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var values: Array = array_at(key)
	if not ok():
		return entries
	for value: Variant in values:
		if not value is Dictionary:
			_fail(key, "wrong type")
			return []
		var entry: Dictionary = value
		entries.append(entry)
	return entries


## An array of exactly [param count] integral numbers, such as a map position [row, col].
func ints_at(key: String, count: int) -> Array[int]:
	var ints: Array[int] = []
	var values: Array = array_at(key)
	if not ok():
		return ints
	if values.size() != count:
		_fail(key, "wrong length")
		return []
	for value: Variant in values:
		ints.append(_as_integer(key, value))
	if not ok():
		return []
	return ints


## A dictionary of string keys to integral numbers, such as Due pips or RNG states.
func counts_at(key: String) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {}
	var source_counts: Dictionary = dict_at(key)
	if not ok():
		return counts
	for name_text: Variant in source_counts:
		if not name_text is String:
			_fail(key, "wrong type")
			return {}
		var name_key: String = name_text
		counts[StringName(name_key)] = _as_integer(key, source_counts[name_text])
		if not ok():
			return {}
	return counts


## Plain copy of ids for to_dict. JSON has no StringName, so each id becomes a String.
static func plain_ids(ids: Array[StringName]) -> Array[String]:
	var plain: Array[String] = []
	for id: StringName in ids:
		plain.append(String(id))
	return plain


## Plain copy of a count map for to_dict. StringName keys become String.
static func plain_counts(counts: Dictionary) -> Dictionary:
	var plain: Dictionary = {}
	for key: Variant in counts:
		var key_text: String = key
		plain[key_text] = counts[key]
	return plain


func _fetch(key: String) -> Variant:
	if not ok():
		return null
	if not _source.has(key):
		_fail(key, "missing")
		return null
	return _source[key]


## JSON gives every number as a float, so 41.0 is accepted as 41 and 41.5 is rejected.
func _as_integer(key: String, value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		var number: float = value
		if is_finite(number) and number == floorf(number) and absf(number) <= MAX_EXACT_INTEGER:
			return int(number)
		_fail(key, "not an integer")
		return 0
	_fail(key, "wrong type")
	return 0


func _fail(key: String, reason: String) -> void:
	if not ok():
		return
	_failed_key = key
	_reason = reason
