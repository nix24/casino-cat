class_name GambleRules
extends RefCounted
## The shared gamble engine (PRD §6.0). Preview and resolve both build outcome rows through
## outcome_row, so the odds on screen are the odds the code rolls (rule 2). Pure: no randomness.

## Highest chance a gamble may show or roll (PRD §6.0 rule 3).
## ponytail: mirrors TuningData.probability_cap because odds() takes no context. Upgrade: pass the
## cap in from ctx once a caller needs it tuned.
const PROBABILITY_CAP: float = 0.95
## Luck lost while the cat is Rattled (gamble-math.md, PRD §4.7).
const RATTLED_LUCK: int = -10


## Chance that one die's Luck reroll fires: Luck as a fraction, capped (PRD §6.0 rule 3). Negative
## Luck gives 0, because it cuts the payout instead (rule 6).
static func luck_chance(luck_points: int) -> float:
	return clampf(float(luck_points) / 100.0, 0.0, PROBABILITY_CAP)


## Luck for a gamble of [param family] right now (PRD §6.0 rule 6, gamble-math.md). Relic Luck and
## House Edge join later. For now this is the Due term and Rattled.
static func luck(family: StringName, state: BattleState, ctx: BattleContext) -> int:
	var due_pips: int = ctx.due.get(family, 0)
	var rattled: int = RATTLED_LUCK if state.cat.statuses.has(&"rattled") else 0
	return ctx.luck_bonus + ctx.tuning.luck_per_pip * due_pips + rattled


## Payout multiplier from statuses: Weak on the cat lowers it, Exposed on the enemy raises it.
## Gamble moves are ♣, so the suit triangle never applies.
static func status_mult(state: BattleState) -> float:
	var mult: float = 1.0
	if state.cat.statuses.has(&"weak"):
		mult *= Damage.WEAK_MULTIPLIER
	if state.enemy.statuses.has(&"exposed"):
		mult *= Damage.EXPOSED_MULTIPLIER
	return mult


## Most HP one gamble can cost the cat: 12% of max HP, rounded down (PRD §6.0 rule 8, D15).
static func backfire_cap(state: BattleState, ctx: BattleContext) -> int:
	return floori(float(state.cat.max_hp * ctx.tuning.backfire_cap_pct_max_hp) / 100.0)


## The odds the player sees for [param gamble] right now, after Luck and statuses (PRD §6.0 rule 2).
static func preview(gamble: GambleData, state: BattleState, ctx: BattleContext) -> GambleOdds:
	var luck_now: int = luck(gamble.family, state, ctx)
	return odds(gamble, luck_now, status_mult(state), backfire_cap(state, ctx))


## Exact outcome table for [param gamble] at a fixed Luck and payout multiplier.
static func odds(
	gamble: GambleData, luck_points: int, payout_mult: float, max_backfire: int
) -> GambleOdds:
	var dice: DiceGambleData = gamble as DiceGambleData
	assert(dice != null, "only dice gambles have odds in T002")
	var table := GambleOdds.new()
	table.luck = luck_points
	table.rows = DiceFamily.odds(dice, luck_points, payout_mult, max_backfire)
	return table


## Payout for one outcome. Negative Luck cuts it by 1% per point; Luck never raises a payout here,
## because positive Luck works through rerolls. Rounded once, at the end (PRD §6.0 rule 6).
static func final_payout(
	base: int, multiplier: float, luck_points: int, payout_mult: float = 1.0
) -> int:
	var luck_factor: float = 1.0
	if luck_points < 0:
		luck_factor = maxf(0.0, 1.0 - float(-luck_points) / 100.0)
	return Damage.round_half_up(float(base) * multiplier * luck_factor * payout_mult)


## The one place an outcome row is built. Preview (odds) and resolve (DiceFamily.score) both call
## it, so a row's label, payout, backfire, and Due step cannot differ between them.
static func outcome_row(
	label: StringName,
	base: int,
	multiplier: float,
	backfire: int,
	due_step: GambleData.DueStep,
	luck_points: int,
	payout_mult: float,
	max_backfire: int,
) -> GambleOddsRow:
	var row := GambleOddsRow.new()
	row.label = label
	row.payout = final_payout(base, multiplier, luck_points, payout_mult)
	row.backfire = mini(backfire, max_backfire)
	row.due_step = due_step
	return row


## Due pips after one resolved outcome (PRD §6.0 rule 7). A bottom outcome adds a pip up to the
## cap, and a top outcome empties the meter.
static func due_after(pips: int, due_step: GambleData.DueStep, tuning: TuningData) -> int:
	match due_step:
		GambleData.DueStep.BOTTOM:
			return mini(pips + 1, tuning.due_pips_max)
		GambleData.DueStep.TOP:
			return 0
	return pips
