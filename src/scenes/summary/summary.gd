class_name SummaryScene
extends Control
## The run summary (PRD §13.8): result, where the run ended, the final build, and the relics.
## Shown once a run is over; Game owns what happens after Continue.

## Emitted when the player leaves the summary, so Game can return to the title.
signal finished

var _entry: Dictionary = {}
var _db: ContentDb

@onready var _title: Label = %Title
@onready var _line: Label = %Line
@onready var _build: Label = %Build
@onready var _relics: Label = %Relics
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.text = Strings.EVENT_CONTINUE
	_continue_button.pressed.connect(finished.emit)
	if _db != null:
		_render()
	_continue_button.grab_focus.call_deferred()


## Shows the run history [param entry]; [param db] turns ids into display names.
func show_summary(entry: Dictionary, db: ContentDb) -> void:
	_entry = entry
	_db = db
	if is_node_ready():
		_render()


func _render() -> void:
	var is_won: bool = _entry["result"] == "won"
	_title.text = Strings.SUMMARY_TITLE_WON if is_won else Strings.SUMMARY_TITLE_LOST
	var duration_s: int = _entry["duration_s"]
	_line.text = (
		Strings.SUMMARY_LINE_FORMAT
		% [_entry["act"], _entry["row"], duration_s / 60, duration_s % 60, _entry["seed"]]
	)
	var build_lines: PackedStringArray = [Strings.SUMMARY_BUILD_LABEL]
	for slot: Dictionary in _entry["build"]:
		build_lines.append(_slot_text(slot))
	_build.text = "\n".join(build_lines)
	var relic_names: PackedStringArray = []
	for relic_id: String in _entry["relics"]:
		var relic: RelicData = _db.relic(StringName(relic_id))
		relic_names.append(relic.display_name if relic != null else relic_id)
	var relics_text: String = (
		", ".join(relic_names) if not relic_names.is_empty() else Strings.SUMMARY_NONE
	)
	_relics.text = "%s %s" % [Strings.SUMMARY_RELICS_LABEL, relics_text]


## One build line: the move name, then its modifier names in parentheses if it has any.
func _slot_text(slot: Dictionary) -> String:
	var move_id: String = slot["move_id"]
	var move: MoveData = _db.move(StringName(move_id))
	var text: String = move.display_name if move != null else move_id
	var modifier_names: PackedStringArray = []
	for modifier_id: String in slot["modifier_ids"]:
		var modifier: ModifierData = _db.modifier(StringName(modifier_id))
		modifier_names.append(modifier.display_name if modifier != null else modifier_id)
	if modifier_names.is_empty():
		return text
	return "%s (%s)" % [text, ", ".join(modifier_names)]
