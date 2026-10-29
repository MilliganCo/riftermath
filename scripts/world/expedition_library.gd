class_name ExpeditionLibrary
extends RefCounted

var path: String = "user://expedition_index.json"
var worlds_dir: String = "user://expeditions"
var legacy_path: String = "user://expedition.json"
var entries: Array[Dictionary] = []
var active_id: String = ""
var error: String = ""
var writable: bool = true
var _extra: Dictionary = {}


static func read(tree: SceneTree) -> ExpeditionLibrary:
	var library := ExpeditionLibrary.new()
	library.path = String(tree.get_meta("expedition_library_path", library.path))
	library.worlds_dir = String(tree.get_meta("expedition_worlds_dir", library.worlds_dir))
	library.legacy_path = String(tree.get_meta("expedition_legacy_path", library.legacy_path))
	if FileAccess.file_exists(library.path):
		var data: Variant = ExpeditionFiles.read_json(library.path)
		if not data is Dictionary or data.get("version", -1) != 1 or not data.get("worlds") is Array or not data.get("active") is String or data["worlds"].size() > 64:
			library.writable = false
			library.error = "Индекс походов не распознан; файл сохранён."
			return library
		library._extra = data.duplicate(true)
		for row in data["worlds"]:
			if not row is Dictionary or not row.get("id") is String or not _safe_id(row["id"]) or not ExpeditionFiles.integer(row.get("seed"), 1, 2147483647):
				library.writable = false
				library.error = "Некорректный список походов; файл сохранён."
				return library
			library.entries.append(row.duplicate(true))
		library.active_id = data["active"]
	# Register the old single-world save without modifying its bytes.
	if FileAccess.file_exists(library.legacy_path) and not library.has_id("legacy"):
		var old: Variant = ExpeditionFiles.read_json(library.legacy_path)
		if old is Dictionary and int(old.get("version", -1)) in [1, 2] and ExpeditionFiles.integer(old.get("seed"), 1, 2147483647):
			library.entries.push_front({"id": "legacy", "seed": int(old["seed"])})
			if library.active_id.is_empty(): library.active_id = "legacy"
	if not library.has_id(library.active_id) and not library.entries.is_empty():
		library.active_id = library.entries[0]["id"]
	return library


static func _safe_id(id: String) -> bool:
	if id.is_empty() or id.length() > 72: return false
	for character in id:
		if not ((character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "_"): return false
	return true


func has_id(id: String) -> bool:
	for row in entries:
		if row["id"] == id: return true
	return false


func world_path(id: String) -> String:
	if not _safe_id(id): return ""
	return legacy_path if id == "legacy" else worlds_dir.path_join(id + ".json")


func active_path() -> String:
	return world_path(active_id) if has_id(active_id) else legacy_path


func save() -> bool:
	if not writable: return false
	var data := _extra.duplicate(true)
	data.merge({"version": 1, "active": active_id, "worlds": entries}, true)
	var result := ExpeditionFiles.write_json(path, data, [1])
	if result != OK: error = "Не удалось сохранить список походов."
	return result == OK


func select(id: String) -> bool:
	if not writable or not has_id(id) or not FileAccess.file_exists(world_path(id)): return false
	if not ExpeditionState.load_path(world_path(id)).write_allowed:
		error = "Сохранение повреждено или не распознано; исходный файл сохранён."
		return false
	var before := active_id
	active_id = id
	if save(): return true
	active_id = before
	return false


func create(seed: int) -> String:
	if not writable or entries.size() >= 64 or seed < 1 or seed > 2147483647:
		error = "Нужен seed от 1 до 2147483647; максимум 64 похода."
		return ""
	var id := "march_%d_%d" % [seed, Time.get_ticks_usec()]
	while FileAccess.file_exists(world_path(id)): id += "_n"
	var state := ExpeditionState.new()
	state.seed_value = seed
	state.path = world_path(id)
	if not state.save():
		error = state.load_error
		return ""
	var previous := active_id
	entries.append({"id": id, "seed": seed})
	active_id = id
	if not save():
		entries.pop_back()
		active_id = previous
		return ""
	return id


func label(row: Dictionary) -> String:
	var data: Variant = ExpeditionFiles.read_json(world_path(row["id"]))
	if not data is Dictionary: return "МАРКИ %d / ФАЙЛ НЕДОСТУПЕН" % row["seed"]
	var count: int = data.get("seals", []).size() if data.get("seals") is Array else 0
	return "МАРКИ %d / ПЕЧАТИ %d/3%s" % [row["seed"], count, " / КЛЯТВА" if data.get("stage", 0) == 3 else ""]
