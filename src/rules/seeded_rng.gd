class_name SeededRng
extends RefCounted
## Deterministic random numbers that stay identical across Godot versions.
##
## Godot's RandomNumberGenerator documents its algorithm as an implementation detail, so a saved
## run seed could replay differently after an engine upgrade. This generator is fully defined
## here: FNV-1a (32-bit) hashes seed text, xorshift32 produces the stream. Every run owns one
## seed and derives named sub-streams ("map", "battle", "gamble", "shop") so that, for example,
## browsing the shop never changes the next dice roll. See docs/PRD.md "Randomness and seeds".

const _MASK_32: int = 0xFFFFFFFF
const _FNV_OFFSET: int = 0x811C9DC5
const _FNV_PRIME: int = 0x01000193

var _state: int


## Creates a stream from [param seed_text], e.g. a run seed or "<run seed>:battle".
func _init(seed_text: String) -> void:
	_state = hash_text(seed_text)
	if _state == 0:
		_state = _FNV_OFFSET  # xorshift must never hold zero


## FNV-1a over the UTF-8 bytes of [param text]. Stable by definition, unlike String.hash().
static func hash_text(text: String) -> int:
	var h: int = _FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		h = ((h ^ byte) * _FNV_PRIME) & _MASK_32
	return h


## Returns an independent stream for [param stream_name] derived from [param run_seed].
static func derive(run_seed: String, stream_name: String) -> SeededRng:
	return SeededRng.new(run_seed + ":" + stream_name)


## Next raw 32-bit value (xorshift32, period 2^32 - 1).
func next_u32() -> int:
	var x: int = _state
	x = (x ^ (x << 13)) & _MASK_32
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & _MASK_32
	_state = x
	return x


## Uniform integer in [param low]..[param high], both inclusive.
func range_int(low: int, high: int) -> int:
	assert(low <= high, "range_int: low must be <= high")
	return low + next_u32() % (high - low + 1)


## Uniform float in [0, 1).
func next_float() -> float:
	return float(next_u32()) / 4294967296.0


## True with probability [param chance] (0.0 to 1.0).
func chance(probability: float) -> bool:
	return next_float() < probability


## The raw xorshift state. Save it with the run so a stream resumes exactly where it stopped.
func get_state() -> int:
	return _state


## Restores a state from [method get_state]. Zero is the one state xorshift can never leave.
func set_state(state: int) -> void:
	assert(state != 0, "xorshift state must be non-zero")
	_state = state
