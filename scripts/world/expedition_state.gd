class_name ExpeditionState
extends RefCounted

var seed_value: int = 117
var stage: int = 0
var seals: Array[int] = []
var cleared: Array[String] = []
var path: String = "user://expedition.json"
var write_allowed: bool = true
var load_error: String = ""
var visited: Array[int] = []
var tracked: int = -2
var side_stage: int = 0
var echoes: Array[int] = []
var rune: StringName = &""
var _extra: Dictionary = {}


static func read(tree: SceneTree) -> ExpeditionState:
	var state := ExpeditionState.new()
	state.path = String(tree.get_meta("expedition_save_path")) if tree.has_meta("expedition_save_path") else ExpeditionLibrary.read(tree).active_path()
	if tree.has_meta("expedition_new_seed"):
		state.seed_value = clampi(int(tree.get_meta("expedition_new_seed")), 1, 2147483647)
		tree.remove_meta("expedition_new_seed")
		return state
	return load_path(state.path)


static func load_path(file_path: String) -> ExpeditionState:
	var state := ExpeditionState.new()
	state.path = file_path
	if not FileAccess.file_exists(state.path):
		state.seed_value = randi_range(1, 2147483647)
		return state
	var data: Variant = ExpeditionFiles.read_json(state.path)
	if not data is Dictionary or not ExpeditionFiles.integer(data.get("version"), 1, 2) or not ExpeditionFiles.integer(data.get("seed"), 1, 2147483647) or not ExpeditionFiles.integer(data.get("stage"), 0, 3) or not data.get("seals") is Array or not data.get("cleared") is Array:
		state.write_allowed = false
		state.load_error = "UNKNOWN SAVE / PRESERVED"
		return state
	var number: float = data["seed"]
	if not is_finite(number) or number < 1 or number > 2147483647 or data["stage"] < 0 or data["stage"] > 3:
		state.write_allowed = false
		state.load_error = "INVALID SAVE / PRESERVED"
		return state
	state.seed_value = int(number)
	state.stage = int(data["stage"])
	state._extra = data.duplicate(true)
	for seal in data["seals"]:
		if not ExpeditionFiles.integer(seal, 0, 2) or state.seals.has(int(seal)): return invalid(state)
		state.seals.append(int(seal))
	for id in data["cleared"]:
		if not id is String or id.is_empty() or id.length() >= 64 or state.cleared.has(id): return invalid(state)
		state.cleared.append(id)
	if state.cleared.size() > 128: return invalid(state)
	if int(data["version"]) == 2:
		if not data.get("visited") is Array or not data.get("echoes") is Array or not ExpeditionFiles.integer(data.get("tracked"), -2, 8) or not ExpeditionFiles.integer(data.get("side_stage"), 0, 3) or not data.get("rune") is String or data["rune"] not in ["", "fracture", "binding"]:
			state.write_allowed = false
			state.load_error = "INVALID SAVE V2 / PRESERVED"
			return state
		for district in data["visited"]:
			if not ExpeditionFiles.integer(district, -1, 7) or state.visited.has(int(district)): return invalid(state)
			state.visited.append(int(district))
		for echo in data["echoes"]:
			if not ExpeditionFiles.integer(echo, 0, 1) or state.echoes.has(int(echo)): return invalid(state)
			state.echoes.append(int(echo))
		state.tracked = int(data["tracked"])
		state.side_stage = int(data["side_stage"])
		state.rune = StringName(data["rune"])
	if (state.stage >= 2 and state.seals.size() != 3) or (state.stage == 0 and not state.seals.is_empty()):
		state.write_allowed = false
		state.load_error = "INCONSISTENT SAVE / PRESERVED"
	return state


static func invalid(state: ExpeditionState) -> ExpeditionState:
	state.write_allowed = false
	state.load_error = "INVALID SAVE DATA / PRESERVED"
	return state


func save() -> bool:
	if not write_allowed:
		return false
	var data := _extra.duplicate(true)
	data.merge({"version": 2, "seed": seed_value, "stage": stage, "seals": seals, "cleared": cleared, "visited": visited, "tracked": tracked, "side_stage": side_stage, "echoes": echoes, "rune": String(rune)}, true)
	var result := ExpeditionFiles.write_json(path, data, [1, 2])
	if result != OK:
		load_error = "SAVE WRITE FAILED"
		return false
	return true
