class_name DebugCommands
extends RefCounted
## The dev console's parser and command table (PRD §18.1, decisions D36). Pure: no nodes, no
## globals, so the tests can cover it. The console runs each command through the game's own APIs.

## Every command name the console knows. This is the only list of names.
const NAMES: PackedStringArray = [
	"seed",
	"give",
	"purrls",
	"hp",
	"mp",
	"force",
	"goto",
	"node",
	"enemy",
	"god",
	"log",
	"replay",
	"sandbox",
	"help",
	"clear",
]
## How many recent battle events the console keeps for `log`.
const LOG_LIMIT := 50
## The seed a sandbox battle uses when `sandbox moves` names none.
const SANDBOX_SEED: String = "SANDBOX"
## What `sandbox list` can print.
const SANDBOX_LISTS: PackedStringArray = ["moves", "enemies", "relics", "mods"]
## The options `sandbox moves` takes after the move list, each followed by one value.
const SANDBOX_OPTIONS: PackedStringArray = ["mods", "relics", "hp", "mp", "seed"]


## A sandbox build (T052): a throwaway run that is never saved, plus the MP to start with.
## [member error] is empty when the build is valid.
class SandboxSetup:
	extends RefCounted
	var run: RunState
	## MP the battle starts with, or -1 to keep the normal start.
	var mp: int = -1
	var error: String = ""


## Splits [param line] into a command name and its arguments. Words are split on spaces, and empty
## parts are dropped, so repeated spaces do nothing.
static func parse(line: String) -> Dictionary:
	var words: PackedStringArray = line.strip_edges().split(" ", false)
	if words.is_empty():
		return {"ok": false, "name": "", "args": PackedStringArray(), "error": "empty command"}
	var command_name: String = words[0]
	if not NAMES.has(command_name):
		return {
			"ok": false,
			"name": command_name,
			"args": PackedStringArray(),
			"error": "unknown command: %s" % command_name,
		}
	return {"ok": true, "name": command_name, "args": words.slice(1), "error": ""}


## An HP value the cat can be set to: at least 1 (the cat never starts a fight dead), at most
## [param max_hp].
static func clamp_hp(value: int, max_hp: int) -> int:
	return clampi(value, 1, max_hp)


## Faces from a comma list such as "3,4". Each must be an int from 1 to 6. Anything else gives an
## empty array, so the caller can print usage.
static func parse_dice_faces(text: String) -> Array[int]:
	var faces: Array[int] = []
	for part: String in text.split(","):
		var part_text: String = part.strip_edges()
		if not part_text.is_valid_int():
			return []
		var face: int = part_text.to_int()
		if face < 1 or face > 6:
			return []
		faces.append(face)
	return faces


## Card values from a comma list such as "10,7" (decisions D37), each 1 to 10. Anything else gives
## an empty array, so the caller can print usage.
static func parse_card_values(text: String) -> Array[int]:
	var values: Array[int] = []
	for part: String in text.split(","):
		var part_text: String = part.strip_edges()
		if not part_text.is_valid_int():
			return []
		var value: int = part_text.to_int()
		if value < 1 or value > CardFamily.CARD_VALUE_MAX:
			return []
		values.append(value)
	return values


## Coin sides from a list such as "H,H,T" (decisions D37): 1 for heads, 0 for tails. Anything else
## gives an empty array, so the caller can print usage.
static func parse_coin_sides(text: String) -> Array[int]:
	var sides: Array[int] = []
	for part: String in text.split(","):
		match part.strip_edges().to_upper():
			"H":
				sides.append(CoinFamily.FORCED_HEADS)
			"T":
				sides.append(0)
			_:
				return []
	return sides


## One line that shows every field of [param event] the kind uses, for `log` and the replay tests.
static func event_line(event: BattleEvent) -> String:
	var fields: PackedStringArray = [
		"%s" % BattleEvent.Kind.keys()[event.kind],
		"actor=%s" % BattleEvent.Actor.keys()[event.actor],
		"target=%s" % BattleEvent.Actor.keys()[event.target],
		"amount=%d" % event.amount,
		"value_after=%d" % event.value_after,
		"shield_after=%d" % event.shield_after,
		"absorbed=%d" % event.absorbed,
		"suit_from=%s" % Suit.Type.keys()[event.suit_from],
		"suit_to=%s" % Suit.Type.keys()[event.suit_to],
		"status=%s" % event.status,
		"turns=%d" % event.turns,
		"move_id=%s" % event.move_id,
		"reason=%s" % event.reason,
	]
	if event.gamble != null:
		var gamble: GambleEventData = event.gamble
		fields.append("faces=%s" % str(gamble.faces))
		fields.append("indices=%s" % str(gamble.indices))
		fields.append("tier=%s" % gamble.tier)
		fields.append("payout=%d" % gamble.payout)
		fields.append("is_heads=%s" % gamble.is_heads)
	return " ".join(fields)


## Builds a sandbox from the arguments after `sandbox moves`: a comma list of move ids, then any of
## `mods <move:mod,...>`, `relics <id,...>`, `hp N`, `mp N`, `seed <text>`. A mod's move is a move
## id (its first slot) or a slot number from 1. Unknown ids fail with a message.
static func parse_sandbox(args: PackedStringArray, db: ContentDb) -> SandboxSetup:
	var setup := SandboxSetup.new()
	var tuning: TuningData = db.tuning()
	if args.is_empty():
		setup.error = "sandbox moves: name 1 to %d moves" % tuning.equipped_moves
		return setup
	var options: Dictionary[String, String] = {}
	var index: int = 1
	while index < args.size():
		var option: String = args[index]
		if not SANDBOX_OPTIONS.has(option):
			setup.error = "unknown sandbox option: %s" % option
			return setup
		if index + 1 >= args.size():
			setup.error = "sandbox %s: missing value" % option
			return setup
		options[option] = args[index + 1]
		index += 2
	var run_seed: String = options["seed"] if options.has("seed") else SANDBOX_SEED
	setup.run = RunState.start(run_seed, tuning)
	setup.error = _sandbox_moves(setup.run, args[0], db)
	if setup.error.is_empty() and options.has("mods"):
		setup.error = _sandbox_mods(setup.run, options["mods"], db)
	if setup.error.is_empty() and options.has("relics"):
		setup.error = _sandbox_relics(setup.run, options["relics"], db)
	if setup.error.is_empty() and options.has("hp"):
		setup.error = _expect_int("hp", options["hp"])
		if setup.error.is_empty():
			setup.run.hp = clamp_hp(options["hp"].to_int(), setup.run.max_hp)
	if setup.error.is_empty() and options.has("mp"):
		setup.error = _expect_int("mp", options["mp"])
		if setup.error.is_empty():
			setup.mp = clampi(options["mp"].to_int(), 0, tuning.mp_max)
	return setup


## The ids `sandbox list` prints for [param kind] (one of SANDBOX_LISTS). Empty for any other kind.
static func sandbox_ids(kind: String, db: ContentDb) -> PackedStringArray:
	var ids: PackedStringArray = []
	match kind:
		"moves":
			for move: MoveData in db.all_moves():
				ids.append(move.id)
		"enemies":
			for enemy: EnemyData in db.all_enemies():
				ids.append(enemy.id)
		"relics":
			for relic: RelicData in db.all_relics():
				ids.append(relic.id)
		"mods":
			for modifier: ModifierData in db.all_modifiers():
				ids.append(modifier.id)
	return ids


## One line naming the sandbox loadout: "curl_up, scratch+thorny · relics pit_boss · hp 60".
static func sandbox_line(setup: SandboxSetup) -> String:
	var moves: PackedStringArray = []
	for instance: MoveInstance in setup.run.equipped:
		var parts: PackedStringArray = [String(instance.move_id)]
		for modifier_id: StringName in instance.modifier_ids:
			parts.append(String(modifier_id))
		moves.append("+".join(parts))
	var line: String = ", ".join(moves)
	if not setup.run.relics.is_empty():
		line += " · relics %s" % ", ".join(PackedStringArray(setup.run.relics))
	line += " · hp %d" % setup.run.hp
	if setup.mp >= 0:
		line += " · mp %d" % setup.mp
	return line


static func _sandbox_moves(run: RunState, text: String, db: ContentDb) -> String:
	var ids: PackedStringArray = text.split(",", false)
	if ids.is_empty() or ids.size() > db.tuning().equipped_moves:
		return "sandbox moves: name 1 to %d moves" % db.tuning().equipped_moves
	run.equipped.clear()
	for id: String in ids:
		if db.move(StringName(id)) == null:
			return "unknown move: %s" % id
		var instance := MoveInstance.new()
		instance.move_id = StringName(id)
		run.equipped.append(instance)
	return ""


static func _sandbox_mods(run: RunState, text: String, db: ContentDb) -> String:
	for pair: String in text.split(",", false):
		var halves: PackedStringArray = pair.split(":")
		if halves.size() != 2:
			return "sandbox mods: use move:mod, got %s" % pair
		var instance: MoveInstance = _sandbox_slot(run, halves[0])
		if instance == null:
			return "no such move in the sandbox loadout: %s" % halves[0]
		if db.modifier(StringName(halves[1])) == null:
			return "unknown mod: %s" % halves[1]
		instance.modifier_ids.append(StringName(halves[1]))
	return ""


## The loadout slot [param key] names: a slot number from 1, or the first slot with that move id.
static func _sandbox_slot(run: RunState, key: String) -> MoveInstance:
	if key.is_valid_int():
		var slot: int = key.to_int() - 1
		return run.equipped[slot] if slot >= 0 and slot < run.equipped.size() else null
	for instance: MoveInstance in run.equipped:
		if instance.move_id == StringName(key):
			return instance
	return null


static func _sandbox_relics(run: RunState, text: String, db: ContentDb) -> String:
	for id: String in text.split(",", false):
		if db.relic(StringName(id)) == null:
			return "unknown relic: %s" % id
		run.relics.append(StringName(id))
	return ""


static func _expect_int(option: String, value: String) -> String:
	return "" if value.is_valid_int() else "sandbox %s: not a number: %s" % [option, value]
