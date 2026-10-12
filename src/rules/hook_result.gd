class_name HookResult
extends RefCounted
## The summed effect of every hook that fired for one trigger (arch §4). Percent fields use
## 100 = ×1.0. Callers apply the numbers; events lists RELIC_TRIGGERED in application order.

var max_hp: int = 0
var luck: int = 0
var flat_damage: int = 0
var damage_mult_pct: int = 100
var shield: int = 0
## HEAL: flat HP, or for ON_DAMAGE_DEALT a percent of [member HookContext.damage].
var heal: int = 0
var gain_mp: int = 0
var rerolls: int = 0
var due_pips: int = 0
var mp_cost_delta: int = 0
var repeat_shift: int = 0
## FREE_PEEK count (Peeking Monocle). Read by the Cups family (T023).
var free_peeks: int = 0
var payout_mult_pct: int = 100
var backfire_mult_pct: int = 100
## Ids of every modifier and relic that contributed, in application order.
var sources: Array[StringName] = []
## RELIC_TRIGGERED events, one per relic that fired, in acquisition order.
var events: Array[BattleEvent] = []
