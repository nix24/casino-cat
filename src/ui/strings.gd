class_name Strings
extends RefCounted
## Every glyph, colour, and format string the battle UI shows (architecture §8). Presentation only:
## every number comes from the rules, and these functions only turn it into text.

const SUIT_GLYPH: PackedStringArray = ["♠", "♥", "♦", "♣"]
## Grey-box colours, not the final palette (T039, T040).
const SUIT_COLOR: Array[Color] = [
	Color("#5fb7ff"),
	Color("#ff6b8a"),
	Color("#ffa84a"),
	Color("#c9c5e0"),
]
const ATTACK_GLYPH: String = "⚔"
const SHIELD_GLYPH: String = "🛡"
const DEBUFF_GLYPH: String = "▼"
const NO_STATUS_TEXT: String = "—"
const PIP_FULL: String = "●"
const PIP_EMPTY: String = "○"
const HEAL_COLOR: Color = Color("#7be08a")
const SHIELD_COLOR: Color = Color("#9fd8ff")
const BACKFIRE_COLOR: Color = Color("#ff5a5a")
const TICK_COLOR: Color = Color("#f2e7b2")
const RUN_INFO_FORMAT: String = "Seed %s · HP %d/%d · %d Purrls"
const SAVE_UNAVAILABLE: String = "Save unavailable here. Recent progress may be lost."
const TITLE_UNREADABLE: String = "Save unreadable. Start a new run?"


## Glyph for [param suit]: ♠ ♥ ♦ ♣.
static func suit_glyph(suit: Suit.Type) -> String:
	return SUIT_GLYPH[suit]


static func suit_color(suit: Suit.Type) -> Color:
	return SUIT_COLOR[suit]


## Multiplier as the buttons and odds show it: ×1.0, ×0.75, ×1.5. Always at least one decimal.
static func mult(value: float) -> String:
	var text: String = String.num(value, 2)
	if not text.contains("."):
		text += ".0"
	return "×" + text


## One intent line from an INTENT_SHOWN event: "⚔ ♠ 5", "🛡 6", "▼ weak 2", "MP −10".
## [param suit] is the enemy's suit, which the event doesn't carry.
static func intent_text(event: BattleEvent, suit: Suit.Type) -> String:
	match event.reason:
		&"attack", &"multi_attack":
			return "%s %s %d" % [ATTACK_GLYPH, suit_glyph(suit), event.amount]
		&"guard":
			return "%s %d" % [SHIELD_GLYPH, event.amount]
		&"debuff":
			return "%s %s %d" % [DEBUFF_GLYPH, event.status, event.turns]
		&"steal_mp":
			return "MP −%d" % event.amount
		_:
			return "? %s" % event.reason


## Short text for one move effect: "+10 shield", "+5 HP", "+6 MP", "weak 2". Empty for the
## effect kinds the grey-box doesn't show.
static func effect_text(effect: EffectData) -> String:
	match effect.kind:
		EffectData.Kind.SHIELD:
			return "+%d shield" % effect.amount
		EffectData.Kind.HEAL:
			return "+%d HP" % effect.amount
		EffectData.Kind.MP_GAIN:
			return "+%d MP" % effect.amount
		EffectData.Kind.STATUS:
			return "%s %d" % [effect.status, effect.turns]
		_:
			return ""


## The statuses on one combatant as "weak 2 · regen 1", or "—" when there are none.
static func status_text(statuses: Dictionary[StringName, int]) -> String:
	if statuses.is_empty():
		return NO_STATUS_TEXT
	var parts := PackedStringArray()
	for status: StringName in statuses:
		parts.append("%s %d" % [status, statuses[status]])
	return " · ".join(parts)


## The Due meter as pips: "Due ●●○○" for 2 of 4 (PRD §6.0 rule 7).
static func due_text(pips: int, pips_max: int) -> String:
	return "Due %s%s" % [PIP_FULL.repeat(pips), PIP_EMPTY.repeat(pips_max - pips)]


static func speed_text(at_speed: int) -> String:
	match at_speed:
		EventPlayer.SPEED_NORMAL:
			return "speed: 1×"
		EventPlayer.SPEED_DOUBLE:
			return "speed: 2×"
		_:
			return "speed: instant"
