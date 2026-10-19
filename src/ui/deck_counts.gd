class_name DeckCounts
extends VBoxContainer
## Cards left in the battle deck per value, as "7 ●○" under a "Deck" header (PRD §6.3: counts are
## always visible). It shows the counts it is given and computes nothing.

@onready var _header: Label = $Header
@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	_header.text = Strings.DECK_HEADER
	tooltip_text = Strings.DECK_TOOLTIP


## Shows [param counts] (index 0 = value 1). Builds one label per value on first use.
func show_counts(counts: PackedInt32Array) -> void:
	while _grid.get_child_count() < counts.size():
		_grid.add_child(Label.new())
	for index: int in counts.size():
		(_grid.get_child(index) as Label).text = Strings.deck_count_text(index + 1, counts[index])
