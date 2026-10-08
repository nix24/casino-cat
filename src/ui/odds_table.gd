class_name OddsTable
extends PanelContainer
## Read-only outcome table for a gamble (PRD §6.0 rule 2). It lists the rows the rules gave it and
## computes nothing: probability and payout are shown as they are.

@onready var _rows: VBoxContainer = %Rows


## Rebuilds the table from [param odds]. A Luck header shows when Luck is not zero.
func set_odds(odds: GambleOdds) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if odds.luck != 0:
		_add_line("Luck %s%d" % ["+" if odds.luck > 0 else "", odds.luck])
	for row: GambleOddsRow in odds.rows:
		_add_line(row_text(row))


## One table line, e.g. "Snake eyes  2.8%  0  −4 HP". The probability has one decimal place.
static func row_text(row: GambleOddsRow) -> String:
	var line: String = "%s  %.1f%%  %d" % [row.label, row.probability * 100.0, row.payout]
	if row.backfire > 0:
		line += "  −%d HP" % row.backfire
	return line


func _add_line(line: String) -> void:
	var label := Label.new()
	label.text = line
	_rows.add_child(label)
