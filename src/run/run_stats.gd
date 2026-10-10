class_name RunStats
extends RefCounted
## Counters for one run, shown on the run-end screen and saved in run.json (arch §5, §6). The
## field names are this packet's choice (T005 R6).

const CONTEXT: String = "run.json stats"

var turns: int = 0
## HP the cat dealt across the run.
var damage_dealt: int = 0
## HP the cat lost across the run.
var damage_taken: int = 0
## Gamble plays per family (family id to count).
var gambles: Dictionary[StringName, int] = {}
var duration_s: int = 0


func to_dict() -> Dictionary:
	return {
		"turns": turns,
		"damage_dealt": damage_dealt,
		"damage_taken": damage_taken,
		"gambles": SaveReader.plain_counts(gambles),
		"duration_s": duration_s,
	}


## Returns null (after a warning) when [param d] has a missing key or a wrong type.
static func from_dict(d: Dictionary) -> RunStats:
	var reader := SaveReader.new(d, CONTEXT)
	var stats := RunStats.new()
	stats.turns = reader.int_at("turns")
	stats.damage_dealt = reader.int_at("damage_dealt")
	stats.damage_taken = reader.int_at("damage_taken")
	stats.gambles = reader.counts_at("gambles")
	stats.duration_s = reader.int_at("duration_s")
	if not reader.ok():
		reader.warn()
		return null
	return stats
