class_name MetaState
extends RefCounted
## Progress that outlives a run: unlocks, seen entries, gamble outcomes, and run history (D8,
## arch §6). Lives in meta.json and is saved through the same atomic path as run.json.

const CONTEXT: String = "meta.json"
## Most history entries kept, newest last (PRD §12.3).
const HISTORY_LIMIT: int = 20

var version: int = 1
var unlocked_signatures: Array[StringName] = []
var seen_moves: Array[StringName] = []
var seen_relics: Array[StringName] = []
var seen_items: Array[StringName] = []
var seen_enemies: Array[StringName] = []
## Move id to times used across all runs (D8).
var used: Dictionary[StringName, int] = {}
var beaten_enemies: Array[StringName] = []
## Gamble family to outcome to count, for example dice to cold to 3.
var gamble_outcomes: Dictionary[StringName, Dictionary] = {}
## Run summaries, shaped as arch §6. T020 writes them; only "is a Dictionary" is checked here.
var history: Array[Dictionary] = []


## Adds [param move_id] to the unlocked signatures. Returns true only when it was newly unlocked,
## so an unlock reward fires once (T019).
func unlock_signature(move_id: StringName) -> bool:
	if unlocked_signatures.has(move_id):
		return false
	unlocked_signatures.append(move_id)
	return true


## Appends a copy of [param entry], then drops the oldest entries past HISTORY_LIMIT (PRD §12.3).
func append_history(entry: Dictionary) -> void:
	history.append(entry.duplicate(true))
	while history.size() > HISTORY_LIMIT:
		history.pop_front()


func to_dict() -> Dictionary:
	return {
		"version": version,
		"unlocked_signatures": SaveReader.plain_ids(unlocked_signatures),
		"seen":
		{
			"moves": SaveReader.plain_ids(seen_moves),
			"relics": SaveReader.plain_ids(seen_relics),
			"items": SaveReader.plain_ids(seen_items),
			"enemies": SaveReader.plain_ids(seen_enemies),
		},
		"used": SaveReader.plain_counts(used),
		"beaten_enemies": SaveReader.plain_ids(beaten_enemies),
		"gamble_outcomes": _plain_gamble_outcomes(),
		"history": history.duplicate(true),
	}


## Returns null (after a warning) when [param d] has a missing key or a wrong type.
static func from_dict(d: Dictionary) -> MetaState:
	var reader := SaveReader.new(d, CONTEXT)
	var meta := MetaState.new()
	meta.version = reader.int_at("version")
	meta.unlocked_signatures = reader.ids_at("unlocked_signatures")
	var seen: Dictionary = reader.dict_at("seen")
	meta.used = reader.counts_at("used")
	meta.beaten_enemies = reader.ids_at("beaten_enemies")
	var outcome_source: Dictionary = reader.dict_at("gamble_outcomes")
	meta.history = reader.dicts_at("history")
	if not reader.ok():
		reader.warn()
		return null
	var outcome_reader := SaveReader.new(outcome_source, CONTEXT)
	for family: String in outcome_source:
		meta.gamble_outcomes[StringName(family)] = outcome_reader.counts_at(family)
	if not outcome_reader.ok():
		outcome_reader.warn()
		return null
	var seen_reader := SaveReader.new(seen, CONTEXT)
	meta.seen_moves = seen_reader.ids_at("moves")
	meta.seen_relics = seen_reader.ids_at("relics")
	meta.seen_items = seen_reader.ids_at("items")
	meta.seen_enemies = seen_reader.ids_at("enemies")
	if not seen_reader.ok():
		seen_reader.warn()
		return null
	return meta


func _plain_gamble_outcomes() -> Dictionary:
	var plain: Dictionary = {}
	for family: StringName in gamble_outcomes:
		plain[String(family)] = SaveReader.plain_counts(gamble_outcomes[family])
	return plain
