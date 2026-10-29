class_name BotPerception
extends RefCounted

var bot: CharacterBody3D
var clock: float = 0
var seen_events: int = 0
var heard_events: int = 0
var hearing_range: float = 22
var memory_duration: float = 4.5
var _memory: Dictionary = {}


func step(delta: float) -> void:
	clock += delta
	for id in _memory.keys():
		var record: Dictionary = _memory[id]
		var actor: Node = record["ref"].get_ref()
		if not CombatRules.alive(actor) or clock > record["until"]: _memory.erase(id)


func hostile(actor: Node3D) -> bool:
	if actor == bot or not CombatRules.alive(actor): return false
	if actor.has_method("combat_team") and actor.combat_team() == bot.team_id: return false
	return not is_instance_valid(bot.director) or bot.director.can_engage(bot, actor)


func can_see(actor: Node3D) -> bool:
	if not hostile(actor): return false
	var from: Vector3 = bot.combat_aim_point()
	var at := CombatRules.aim_point(actor)
	var offset := at - from
	if offset.length_squared() > pow(bot.vision_range(), 2): return false
	# Broad peripheral vision; only very close presences are sensed from behind.
	if offset.length() > 4 and bot.global_basis.z.dot(offset.normalized()) < -0.2588: return false
	return CombatRules.clear_line(bot, from, at)


func observe(actor: Node3D) -> bool:
	if not can_see(actor): return false
	if not has_memory(actor) or _memory[actor.get_instance_id()]["kind"] != "seen": seen_events += 1
	_remember(actor, actor.global_position, memory_duration, "seen")
	return true


func hear(actor: Node3D, sound_at: Vector3, loudness: float = 1.0) -> bool:
	if not hostile(actor): return false
	var range_limit := hearing_range * clampf(loudness, 0.3, 1.3)
	var from: Vector3 = bot.combat_aim_point()
	if not CombatRules.clear_line(bot, from, sound_at): range_limit *= 0.65
	if from.distance_to(sound_at) > range_limit: return false
	# Snapshot at the sound event. Subsequent hidden motion never updates it.
	_remember(actor, actor.global_position, 3.0, "heard")
	heard_events += 1
	bot._think = minf(bot._think, 0.08)
	return true


func _remember(actor: Node3D, at: Vector3, duration: float, kind: String) -> void:
	var until := clock + duration
	if _memory.has(actor.get_instance_id()): until = maxf(until, _memory[actor.get_instance_id()]["until"])
	_memory[actor.get_instance_id()] = {"ref": weakref(actor), "point": at, "until": until, "kind": kind}


func has_memory(actor: Node) -> bool:
	return is_instance_valid(actor) and _memory.has(actor.get_instance_id()) and _memory[actor.get_instance_id()]["until"] >= clock


func last_position(actor: Node) -> Vector3:
	return _memory[actor.get_instance_id()]["point"] if has_memory(actor) else bot.global_position


func clear() -> void:
	_memory.clear()
