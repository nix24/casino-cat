class_name RngSet
extends RefCounted
## The named random streams of one run (PRD §17.3). Each system draws only from its own stream,
## so browsing the shop never changes the next dice roll.

const STREAM_NAMES: Array[StringName] = [&"map", &"battle", &"gamble", &"reward", &"shop", &"event"]

var map: SeededRng
var battle: SeededRng
var gamble: SeededRng
var reward: SeededRng
var shop: SeededRng
var event: SeededRng


## Builds every stream from [param run_seed]. The same seed always gives the same streams.
static func for_seed(run_seed: String) -> RngSet:
	var rngs := RngSet.new()
	rngs.map = SeededRng.derive(run_seed, "map")
	rngs.battle = SeededRng.derive(run_seed, "battle")
	rngs.gamble = SeededRng.derive(run_seed, "gamble")
	rngs.reward = SeededRng.derive(run_seed, "reward")
	rngs.shop = SeededRng.derive(run_seed, "shop")
	rngs.event = SeededRng.derive(run_seed, "event")
	return rngs


## Every stream's raw state, keyed by stream name, for the run save (arch §5, §6).
func to_states() -> Dictionary[StringName, int]:
	var states: Dictionary[StringName, int] = {}
	for stream_name: StringName in STREAM_NAMES:
		states[stream_name] = _stream(stream_name).get_state()
	return states


## Restores saved states. This is a save-file boundary, so a bad value never reaches
## set_state: the stream keeps its derived state and a warning names it. Unknown keys are ignored.
func apply_states(states: Dictionary[StringName, int]) -> void:
	for stream_name: StringName in states:
		if not STREAM_NAMES.has(stream_name):
			push_warning("unknown rng stream in save: %s" % stream_name)
	for stream_name: StringName in STREAM_NAMES:
		if not states.has(stream_name):
			push_warning("rng stream %s missing from save; keeping derived state" % stream_name)
			continue
		var state: int = states[stream_name]
		if state < 1 or state > 0xFFFFFFFF:
			push_warning(
				"rng stream %s has invalid state %d; keeping derived state" % [stream_name, state]
			)
			continue
		_stream(stream_name).set_state(state)


func _stream(stream_name: StringName) -> SeededRng:
	var streams: Dictionary[StringName, SeededRng] = {
		&"map": map,
		&"battle": battle,
		&"gamble": gamble,
		&"reward": reward,
		&"shop": shop,
		&"event": event,
	}
	return streams[stream_name]
