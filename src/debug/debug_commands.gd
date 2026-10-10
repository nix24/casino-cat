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
	"help",
	"clear",
]
## How many recent battle events the console keeps for `log`.
const LOG_LIMIT := 50


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
	return " ".join(fields)
