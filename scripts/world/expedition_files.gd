class_name ExpeditionFiles
extends RefCounted


static func read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 131072: return null
	return JSON.parse_string(file.get_as_text())


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	var number := float(value)
	return is_finite(number) and number == floor(number) and number >= minimum and number <= maximum


static func write_json(path: String, data: Dictionary, supported: Array[int]) -> Error:
	# Never truncate the destination: validate, flush a sibling, then replace it.
	if FileAccess.file_exists(path):
		var previous: Variant = read_json(path)
		if not previous is Dictionary or not integer(previous.get("version"), 0, 10000) or not supported.has(int(previous["version"])): return ERR_INVALID_DATA
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK: return error
	var temporary := path + ".tmp-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK: return error
	if FileAccess.file_exists(path):
		var backup := path + ".bak"
		if FileAccess.file_exists(backup):
			var existing: Variant = read_json(backup)
			if not existing is Dictionary or not supported.has(int(existing.get("version", -1))):
				backup += "-" + str(Time.get_ticks_usec())
		error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup))
		if error != OK: return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
