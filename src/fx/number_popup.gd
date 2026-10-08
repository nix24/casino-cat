class_name NumberPopup
extends Label
## A floating number over a combatant (PRD §13.3). It rises 12 px and fades over the step's
## duration, then frees itself. Positions snap to whole pixels so the text stays crisp.

const RISE_PIXELS: float = 12.0


## Shows [param message] in [param color] for [param seconds]. Set [member Control.position] first.
## A zero or negative duration frees the popup at once.
func play(message: String, color: Color, seconds: float) -> void:
	text = message
	add_theme_color_override(&"font_color", color)
	if seconds <= 0.0:
		queue_free()
		return
	var base_y: float = position.y
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_method(_rise_to.bind(base_y), 0.0, RISE_PIXELS, seconds)
	tween.parallel().tween_property(self, "modulate:a", 0.0, seconds)
	tween.tween_callback(queue_free)


func _rise_to(rise: float, base_y: float) -> void:
	position.y = roundf(base_y - rise)
