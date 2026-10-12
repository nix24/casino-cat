class_name RunSummary
extends RefCounted
## The history entry for a finished run (PRD §12.3, arch §6, D32). Pure: the caller passes the date.

const RESULT_WON: String = "won"
const RESULT_LOST: String = "lost"


## The entry meta.json's history keeps: seed, result, act and row reached, the equipped build with
## modifiers, relics, duration, and [param date_iso] (YYYY-MM-DD).
static func build_entry(run: RunState, is_won: bool, date_iso: String) -> Dictionary:
	var build: Array[Dictionary] = []
	for instance: MoveInstance in run.equipped:
		(
			build
			. append(
				{
					"move_id": String(instance.move_id),
					"modifier_ids": SaveReader.plain_ids(instance.modifier_ids),
				}
			)
		)
	return {
		"seed": run.run_seed,
		"result": RESULT_WON if is_won else RESULT_LOST,
		"act": run.act,
		"row": run.position.x,
		"build": build,
		"relics": SaveReader.plain_ids(run.relics),
		"duration_s": run.stats.duration_s,
		"date": date_iso,
	}
