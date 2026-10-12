class_name SaveCode
extends RefCounted
## Both saves as one save code (PRD §17.4, D55): {"run": <run dict or null>, "meta": <meta dict>}
## in the D40 "CC1:" format. Pure: the caller does the file writes.

enum Error { NONE, BAD_CODE, TOO_NEW }


## What import_code found. [member run] is {} when the code carries no run.
class Imported:
	var error: SaveCode.Error = SaveCode.Error.NONE
	var run: Dictionary = {}
	var meta: Dictionary = {}


## Packs [param run_dict] (empty when there is no run) and [param meta_dict] into one code.
static func export_code(run_dict: Dictionary, meta_dict: Dictionary) -> String:
	var run_part: Variant = run_dict if not run_dict.is_empty() else null
	return SaveStore.encode_save_code({"run": run_part, "meta": meta_dict})


## Reads a code made by export_code. Checks both parts' versions before touching either, then
## upgrades them. Any malformed part is BAD_CODE, a part from a newer build is TOO_NEW.
static func import_code(code: String) -> Imported:
	var imported := Imported.new()
	var bundle: Dictionary = SaveStore.decode_save_code(code.strip_edges())
	var meta_part: Variant = bundle.get("meta")
	var run_part: Variant = bundle.get("run")
	var has_run: bool = run_part != null
	if not meta_part is Dictionary or (has_run and not run_part is Dictionary):
		imported.error = Error.BAD_CODE
		return imported
	var meta_dict: Dictionary = meta_part
	var run_dict: Dictionary = run_part if has_run else {}
	if meta_dict.is_empty() or (has_run and run_dict.is_empty()):
		imported.error = Error.BAD_CODE
		return imported
	if _version_of(meta_dict) > SaveMigrations.CURRENT_VERSION:
		imported.error = Error.TOO_NEW
		return imported
	if has_run and _version_of(run_dict) > SaveMigrations.CURRENT_VERSION:
		imported.error = Error.TOO_NEW
		return imported
	imported.meta = SaveMigrations.upgrade(meta_dict)
	if has_run:
		imported.run = SaveMigrations.upgrade(run_dict)
	if imported.meta.is_empty() or (has_run and imported.run.is_empty()):
		imported.error = Error.BAD_CODE
		imported.meta = {}
		imported.run = {}
	return imported


## The "version" of a save part, or 0 when it has none (upgrade() then rejects it).
static func _version_of(part: Dictionary) -> int:
	var reader := SaveReader.new(part, "save code")
	var version: int = reader.int_at("version")
	return version if reader.ok() else 0
