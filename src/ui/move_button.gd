class_name MoveButton
extends Button
## One of the cat's move buttons (PRD §13.3). It shows what the move would do right now, from a
## MovePreview the rules built. It computes no damage, odds, or triangle of its own.

## Loadout slot this button uses, 0 to 3.
var slot: int = 0
## The move content on this button.
var move: MoveData
## The rules' preview from the last refresh. Null until the first one.
var preview: MovePreview


## Sets the slot and move. The preview arrives later through set_preview.
func setup(button_slot: int, button_move: MoveData) -> void:
	slot = button_slot
	move = button_move
	text = button_move.display_name


## Shows [param new_preview] as three lines. An unaffordable move gets a "need N more MP" tooltip.
func set_preview(new_preview: MovePreview) -> void:
	preview = new_preview
	text = "\n".join(preview_lines(move, preview))
	tooltip_text = ("need %d more MP" % preview.missing_mp) if preview.missing_mp > 0 else ""


## Whether the last preview says the cat can pay for this move.
func can_pay() -> bool:
	return preview != null and preview.affordable


## The three lines of a move button: name and suit, the hit or cost, and the enemy's next hit
## against this suit. Static so tests can check the text without a scene tree.
static func preview_lines(move_data: MoveData, move_preview: MovePreview) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("%s %s" % [move_data.display_name, Strings.suit_glyph(move_data.suit)])
	lines.append(_effect_line(move_data, move_preview))
	lines.append("their hit %s" % Strings.mult(move_preview.incoming_mult))
	return lines


static func _effect_line(move_data: MoveData, move_preview: MovePreview) -> String:
	match move_data.category:
		MoveData.Category.BASIC:
			var mult_text: String = Strings.mult(move_preview.triangle_mult)
			return "%s → %d (%s)" % [_base_text(move_data), move_preview.damage, mult_text]
		MoveData.Category.GAMBLE:
			return "%d MP · odds" % move_preview.mp_cost
	if move_data.effects.is_empty():
		return ""
	return Strings.effect_text(move_data.effects[0])


## Base damage as printed: "6", or "6×2" for a move that hits twice.
static func _base_text(move_data: MoveData) -> String:
	if move_data.hits > 1:
		return "%d×%d" % [move_data.base_damage, move_data.hits]
	return str(move_data.base_damage)
