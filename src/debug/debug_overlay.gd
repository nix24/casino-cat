extends Label
## The always-on debug readout (PRD §18.2, decisions D36): FPS, the run's node state, and the
## position of each RNG stream. Game adds it only in debug builds. F3 toggles it.

const NO_RUN_TEXT: String = "no run"


func _input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != KEY_F3:
		return
	visible = not visible
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	text = _readout()


func _readout() -> String:
	var streams: Dictionary[StringName, int] = _stream_states()
	return (
		"FPS %d · %s · map %d battle %d gamble %d reward %d shop %d event %d"
		% [
			Engine.get_frames_per_second(),
			_node_state_name(),
			streams.get(&"map", 0),
			streams.get(&"battle", 0),
			streams.get(&"gamble", 0),
			streams.get(&"reward", 0),
			streams.get(&"shop", 0),
			streams.get(&"event", 0),
		]
	)


## The live battle's streams when a battle is on screen, otherwise the streams saved in the run.
func _stream_states() -> Dictionary[StringName, int]:
	var battle: BattleScene = get_tree().current_scene as BattleScene
	if battle != null:
		return battle.debug_rngs().to_states()
	if Game.run == null:
		return {}
	return Game.run.rng_states


func _node_state_name() -> String:
	if Game.run == null:
		return NO_RUN_TEXT
	return RunState.NodeState.keys()[Game.run.node_state]
