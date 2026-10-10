class_name SaveMigrations
extends RefCounted
## Brings saved JSON up to CURRENT_VERSION (arch §6). Each future version step is one function,
## `_v1_to_v2`, with its own test. No step exists yet, so only the current version is accepted.

# ponytail: one version number covers run.json and meta.json until they diverge. Then add a
# file-kind parameter to upgrade() and a version per kind.
## Version every save file is written at (arch §6).
const CURRENT_VERSION: int = 1


## Returns [param data] unchanged when it is at CURRENT_VERSION. Returns {} (with a warning) when
## the version is missing, malformed, or not CURRENT_VERSION. The caller reports "save unreadable".
static func upgrade(data: Dictionary) -> Dictionary:
	var reader := SaveReader.new(data, "save")
	var version: int = reader.int_at("version")
	if not reader.ok():
		reader.warn()
		return {}
	if version == CURRENT_VERSION:
		return data
	push_warning("save: version %d unsupported (build reads %d)" % [version, CURRENT_VERSION])
	return {}
