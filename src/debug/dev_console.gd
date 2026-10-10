extends Control
## The dev console (PRD §18.1, decisions D36). Game adds it only in debug builds, so release builds
## never load it. Every command calls the game's own APIs (Game, the battle's debug accessors,
## Replay). The console computes nothing itself.

const DEBUG_LOG_PATH: String = "user://debug.log"
const GIVE_KINDS: PackedStringArray = ["move", "relic", "item", "mod"]
const FORCE_FAMILIES_LATER: PackedStringArray = [
	"coin", "cards", "cups", "scratch", "ticket", "ante"
]
const NO_RUN_MESSAGE: String = "no run; start one with seed <text>"

## Set by `god`. Applied to every battle that starts while it is on, and to the live one.
var _god_mode: bool = false
## The last BattleEvents the battles played, for `log`. Capped at DebugCommands.LOG_LIMIT.
var _event_buffer: Array[BattleEvent] = []
var _history: PackedStringArray = []
var _history_index: int = 0

@onready var _output: RichTextLabel = %Output
@onready var _input_line: LineEdit = %Input


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_input_line.text_submitted.connect(_on_text_submitted)
	_print_line("dev console: type help")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		_set_open(not visible)
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed(&"ui_up"):
		_step_history(-1)
	elif event.is_action_pressed(&"ui_down"):
		_step_history(1)
	else:
		return
	get_viewport().set_input_as_handled()


func _set_open(is_open: bool) -> void:
	visible = is_open
	# The screen behind the console gets no keys while it is open.
	var screen: Node = get_tree().current_scene
	if screen != null:
		screen.process_mode = Node.PROCESS_MODE_DISABLED if is_open else Node.PROCESS_MODE_INHERIT
	if is_open:
		_input_line.grab_focus()
	else:
		_input_line.release_focus()


func _step_history(step: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + step, 0, _history.size())
	_input_line.text = _history[_history_index] if _history_index < _history.size() else ""
	_input_line.caret_column = _input_line.text.length()


func _on_node_added(node: Node) -> void:
	var battle: BattleScene = node as BattleScene
	if battle == null:
		return
	battle.ready.connect(_on_battle_ready.bind(battle), CONNECT_ONE_SHOT)


func _on_battle_ready(battle: BattleScene) -> void:
	battle.debug_context().god_mode = _god_mode
	battle.events_applied.connect(_on_events_applied)


func _on_events_applied(events: Array[BattleEvent]) -> void:
	_event_buffer.append_array(events)
	while _event_buffer.size() > DebugCommands.LOG_LIMIT:
		_event_buffer.pop_front()


func _on_text_submitted(text: String) -> void:
	_input_line.clear()
	var line: String = text.strip_edges()
	if not line.is_empty():
		_history.append(line)
	_history_index = _history.size()
	_print_line("> %s" % line)
	var parsed: Dictionary = DebugCommands.parse(line)
	var is_ok: bool = parsed["ok"]
	if not is_ok:
		var error: String = parsed["error"]
		_print_line(error, true)
		return
	var command_name: String = parsed["name"]
	var args: PackedStringArray = parsed["args"]
	_run_command(command_name, args)


func _run_command(command_name: String, args: PackedStringArray) -> void:
	match command_name:
		"help":
			for listed_name: String in DebugCommands.NAMES:
				_print_line(_usage_of(listed_name))
		"clear":
			_output.clear()
		"seed":
			_seed(args)
		"give":
			_give(args)
		"purrls":
			_set_purrls(args)
		"hp":
			_set_hp(args)
		"mp":
			_set_mp(args)
		"force":
			_force(args)
		"goto", "node":
			_print_line("not available yet: %s" % command_name)
		"enemy":
			_enemy(args)
		"god":
			_toggle_god()
		"log":
			_log_events()
		"replay":
			_replay()


func _seed(args: PackedStringArray) -> void:
	if args.is_empty():
		_print_usage("seed")
		return
	Game.new_run(" ".join(args))
	_set_open(false)


func _give(args: PackedStringArray) -> void:
	if args.size() != 2 or not GIVE_KINDS.has(args[0]):
		_print_usage("give")
		return
	_print_line("not available yet: give %s" % args[0], true)


func _set_purrls(args: PackedStringArray) -> void:
	if not _is_one_int(args):
		_print_usage("purrls")
		return
	if Game.run == null:
		_print_line(NO_RUN_MESSAGE, true)
		return
	Game.run.purrls = maxi(args[0].to_int(), 0)
	Game.save_now()
	_print_line("purrls %d" % Game.run.purrls)


func _set_hp(args: PackedStringArray) -> void:
	if not _is_one_int(args):
		_print_usage("hp")
		return
	var battle: BattleScene = _current_battle()
	if battle != null:
		var cat: Combatant = battle.debug_state().cat
		cat.hp = DebugCommands.clamp_hp(args[0].to_int(), cat.max_hp)
		battle.debug_sync()
		_print_line("hp %d" % cat.hp)
		return
	if Game.run == null:
		_print_line(NO_RUN_MESSAGE, true)
		return
	Game.run.hp = DebugCommands.clamp_hp(args[0].to_int(), Game.run.max_hp)
	Game.save_now()
	_print_line("hp %d" % Game.run.hp)


func _set_mp(args: PackedStringArray) -> void:
	if not _is_one_int(args):
		_print_usage("mp")
		return
	var battle: BattleScene = _current_battle()
	if battle == null:
		_print_line("mp: only in a battle", true)
		return
	var mp_max: int = battle.debug_context().tuning.mp_max
	var state: BattleState = battle.debug_state()
	state.mp = clampi(args[0].to_int(), 0, mp_max)
	battle.debug_sync()
	_print_line("mp %d" % state.mp)


func _force(args: PackedStringArray) -> void:
	if args.is_empty():
		_print_usage("force")
		return
	var family: String = args[0]
	if family == "dice":
		_force_dice(args.slice(1))
	elif FORCE_FAMILIES_LATER.has(family):
		_print_line("not available yet: force %s" % family, true)
	else:
		_print_usage("force")


func _force_dice(args: PackedStringArray) -> void:
	var faces: Array[int] = []
	if args.size() == 1:
		faces = DebugCommands.parse_dice_faces(args[0])
	if faces.is_empty():
		_print_usage("force")
		return
	var battle: BattleScene = _current_battle()
	if battle == null:
		_print_line("force dice: only in a battle", true)
		return
	battle.debug_context().forced.assign(faces)
	_print_line("force dice %s" % str(faces))


func _enemy(args: PackedStringArray) -> void:
	if args.size() != 1:
		_print_usage("enemy")
		return
	if Game.run == null:
		_print_line(NO_RUN_MESSAGE, true)
		return
	var enemy_id: StringName = StringName(args[0])
	if Game.db.enemy(enemy_id) == null:
		_print_line("unknown enemy: %s" % enemy_id, true)
		return
	# node_payload is saved as JSON, so the id goes in as a plain String.
	Game.run.node_payload = {"enemy": String(enemy_id)}
	Game.goto(RunState.NodeState.BATTLE)
	_set_open(false)


func _toggle_god() -> void:
	_god_mode = not _god_mode
	var battle: BattleScene = _current_battle()
	if battle != null:
		battle.debug_context().god_mode = _god_mode
	_print_line("god mode %s" % ("on" if _god_mode else "off"))


func _log_events() -> void:
	if _event_buffer.is_empty():
		_print_line("no events yet")
		return
	var lines: PackedStringArray = []
	for event: BattleEvent in _event_buffer:
		lines.append(DebugCommands.event_line(event))
	for line: String in lines:
		_print_line(line)
	var write_error: String = _append_debug_log(lines)
	if not write_error.is_empty():
		_print_line(write_error, true)


## Appends [param lines] to the debug log. Returns a message for the console when the file cannot
## be written, or an empty string on success.
func _append_debug_log(lines: PackedStringArray) -> String:
	var mode: FileAccess.ModeFlags = (
		FileAccess.READ_WRITE if FileAccess.file_exists(DEBUG_LOG_PATH) else FileAccess.WRITE
	)
	var file: FileAccess = FileAccess.open(DEBUG_LOG_PATH, mode)
	if file == null:
		return "log: cannot write %s (error %d)" % [DEBUG_LOG_PATH, FileAccess.get_open_error()]
	file.seek_end()
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return ""


func _replay() -> void:
	if Game.run == null:
		_print_line(NO_RUN_MESSAGE, true)
		return
	if Game.run.node_state == RunState.NodeState.BATTLE:
		_print_line("replay: leave the battle first", true)
		return
	var replay: Replay = Replay.play(Game.run.run_seed, Game.run.action_log, Game.db)
	if not replay.error.is_empty():
		_print_line("replay failed: %s" % replay.error, true)
		return
	if replay.rng_states != Game.run.rng_states:
		_print_line("replay mismatch: rng states differ", true)
		return
	_print_line("replay ok: %d events" % replay.events.size())


func _is_one_int(args: PackedStringArray) -> bool:
	return args.size() == 1 and args[0].is_valid_int()


func _current_battle() -> BattleScene:
	return get_tree().current_scene as BattleScene


func _print_usage(command_name: String) -> void:
	_print_line("usage: %s" % _usage_of(command_name), true)


func _usage_of(command_name: String) -> String:
	var usage: String = command_name
	match command_name:
		"seed":
			usage = "seed <text>"
		"give":
			usage = "give <move|relic|item|mod> <id>"
		"purrls":
			usage = "purrls <n>"
		"hp":
			usage = "hp <n>"
		"mp":
			usage = "mp <n>  (battle only)"
		"force":
			usage = "force dice <a,b,...>  (battle only; faces 1-6)"
		"goto":
			usage = "goto <row> <col>"
		"node":
			usage = "node <type>"
		"enemy":
			usage = "enemy <id>"
		"god":
			usage = "god  (toggle invulnerability: the cat keeps at least 1 HP)"
		"log":
			usage = (
				"log  (last %d battle events, also written to %s)"
				% [DebugCommands.LOG_LIMIT, DEBUG_LOG_PATH]
			)
		"replay":
			usage = "replay  (rebuild the run from its seed and action log)"
		"help":
			usage = "help"
		"clear":
			usage = "clear"
	return usage


## Prints [param text] as BBCode-safe text. Errors go in red.
func _print_line(text: String, is_error: bool = false) -> void:
	var escaped: String = text.replace("[", "[lb]")
	if is_error:
		escaped = "[color=#ff6b6b]%s[/color]" % escaped
	_output.append_text(escaped + "\n")
