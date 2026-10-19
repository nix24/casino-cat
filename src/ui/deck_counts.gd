class_name DeckCounts
extends GridContainer
## Cards left in the battle deck per value, as "7 ●○" (PRD §6.3: counts are always visible). It
## shows the counts it is given and computes nothing.


## Shows [param counts] (index 0 = value 1). Builds one label per value on first use.
func show_counts(counts: PackedInt32Array) -> void:
	while get_child_count() < counts.size():
		add_child(Label.new())
	for index: int in counts.size():
		(get_child(index) as Label).text = Strings.deck_count_text(index + 1, counts[index])
