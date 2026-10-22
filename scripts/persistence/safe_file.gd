class_name SafeFile
extends RefCounted
## Crash-tolerant JSON persistence.
##
## Writes go to "<path>.tmp" first, the previous good file is kept as
## "<path>.bak", and the temp file is then renamed into place. Reads fall back
## to the backup when the primary file is missing, unparsable or rejected by
## the caller's validator.


static func write_json(path: String, data: Dictionary) -> bool:
	var tmp_path := path + ".tmp"
	var bak_path := path + ".bak"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SafeFile: cannot open %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()
	# Verify what actually landed on disk before replacing the good copy.
	var verify := _parse(tmp_path)
	if verify.is_empty():
		push_error("SafeFile: verification failed for %s" % tmp_path)
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		DirAccess.rename_absolute(path, bak_path)
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("SafeFile: rename failed for %s (%s)" % [path, error_string(err)])
		return false
	return true


## Returns {"data": Dictionary, "source": "primary"|"backup"|"none"}.
## `validator` receives the parsed Dictionary and returns true when usable.
static func read_json(path: String, validator: Callable = Callable()) -> Dictionary:
	for candidate in [[path, "primary"], [path + ".bak", "backup"]]:
		var data := _parse(candidate[0])
		if data.is_empty():
			continue
		if validator.is_valid() and not validator.call(data):
			push_warning("SafeFile: %s rejected by validator" % candidate[0])
			continue
		return {"data": data, "source": candidate[1]}
	return {"data": {}, "source": "none"}


static func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


static func delete_all(path: String) -> void:
	for p in [path, path + ".tmp", path + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
