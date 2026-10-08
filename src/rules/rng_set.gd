class_name RngSet
extends RefCounted
## The named random streams of one run (PRD §17.3). Each system draws only from its own stream,
## so browsing the shop never changes the next dice roll.

var map: SeededRng
var battle: SeededRng
var gamble: SeededRng
var reward: SeededRng
var shop: SeededRng
var event: SeededRng


## Builds every stream from [param run_seed]. The same seed always gives the same streams.
static func for_seed(run_seed: String) -> RngSet:
	var rngs := RngSet.new()
	rngs.map = SeededRng.derive(run_seed, "map")
	rngs.battle = SeededRng.derive(run_seed, "battle")
	rngs.gamble = SeededRng.derive(run_seed, "gamble")
	rngs.reward = SeededRng.derive(run_seed, "reward")
	rngs.shop = SeededRng.derive(run_seed, "shop")
	rngs.event = SeededRng.derive(run_seed, "event")
	return rngs
