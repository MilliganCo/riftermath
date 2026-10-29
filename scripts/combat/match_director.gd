class_name MatchDirector
extends Node

enum Mode { FREE_FOR_ALL, TEAMS, SURVIVAL }
const MODE_NAMES := ["DEATHMATCH / КАЖДЫЙ ЗА СЕБЯ", "TEAM DEATHMATCH / КОМАНДЫ", "SURVIVAL / ВЫЖИВАНИЕ", "ЭКСПЕДИЦИЯ / ПЕПЕЛЬНЫЕ МАРКИ"]

@export var score_limit: int = 12
@export var time_limit: float = 180.0
var mode: int = Mode.FREE_FOR_ALL
var actors: Array[Node3D] = []
var scores: Dictionary = {}
var team_scores: Array[int] = [0, 0]
var wave: int = 0
var ended: bool = false
var winner: String = ""
var elapsed: float = 0.0
var respawns: int = 0
var world: Node3D
var navigation: BattleNavigation
var _wave_wait: float = -1.0
var _bot_serial: int = 0
var spawns: Array[Vector3] = [Vector3(-29, 0.1, 29), Vector3(29, 0.1, -29), Vector3(-29, 0.1, -29), Vector3(29, 0.1, 29), Vector3(0, 0.1, -28), Vector3(0, 0.1, 28), Vector3(-29, 0.1, 0), Vector3(29, 0.1, 0)]


func start(level: Node3D, selected_mode: int, nav: BattleNavigation) -> void:
	world = level
	mode = clampi(selected_mode, 0, 2)
	if mode == Mode.TEAMS:
		spawns = [Vector3(-29, 0.1, 29), Vector3(-29, 0.1, 10), Vector3(-29, 0.1, -10), Vector3(-29, 0.1, -29), Vector3(29, 0.1, -29), Vector3(29, 0.1, -10), Vector3(29, 0.1, 10), Vector3(29, 0.1, 29)]
	navigation = nav
	for i in range(spawns.size()):
		spawns[i].y = navigation.arena.floor_height(Vector2(spawns[i].x, spawns[i].z)) + 0.1
	var player := world.get_node("Player") as PlayerController
	player.auto_respawn = false
	player.team_id = 0
	player.collision_mask = 5
	player.add_to_group("combatants")
	player.invulnerability = 2.0
	actors.append(player)
	_add_score(player, "YOU / ASH" if mode == Mode.TEAMS else "YOU", 0)
	player.killed.connect(func(attacker: Node): _on_elimination(player, attacker))
	if mode == Mode.SURVIVAL:
		_next_wave()
	else:
		for i in range(7):
			var mirrored_kind := (3 + i % 3 if i < 6 else 0) if mode == Mode.TEAMS else -1
			_spawn_bot((0 if i < 3 else 1) if mode == Mode.TEAMS else i + 1, spawns[(i + 1) % spawns.size()], mirrored_kind)


func _process(delta: float) -> void:
	if ended:
		return
	elapsed += delta
	if mode != Mode.SURVIVAL and elapsed >= time_limit:
		finish("TIME / " + leader())
	if _wave_wait >= 0:
		_wave_wait -= delta
		if _wave_wait <= 0:
			_wave_wait = -1
			_next_wave()


func _spawn_bot(team: int, at: Vector3, kind_override: int = -1, elite: bool = false) -> CombatBot:
	var bot := CombatBot.new()
	bot.team_id = team
	bot.elite = elite
	bot.kind = (kind_override if kind_override >= 0 else _bot_serial % 6) as CombatBot.Kind
	bot.bot_name = ["WRETCH", "PENITENT", "CHOIR", "OSSUARY", "VEIL", "CANTOR"][int(bot.kind)] + " %02d" % (_bot_serial + 1)
	if mode == Mode.TEAMS:
		bot.bot_name = ("ASH / " if team == 0 else "BONE / ") + bot.bot_name
	bot.director = self
	bot.navigation = navigation
	bot.invulnerability = 1.0
	world.get_node("Targets").add_child(bot)
	bot.global_position = at
	bot.home_position = at
	actors.append(bot)
	_add_score(bot, bot.bot_name, team)
	bot.eliminated.connect(_on_elimination)
	_bot_serial += 1
	return bot


func _add_score(actor: Node, label: String, team: int) -> void:
	scores[actor.get_instance_id()] = {"name": label, "team": team, "kills": 0, "deaths": 0}


func _on_elimination(victim: Node, attacker: Node) -> void:
	if ended:
		return
	var victim_id := victim.get_instance_id()
	if scores.has(victim_id):
		scores[victim_id]["deaths"] += 1
	if victim is CombatBot and attacker is PlayerController:
		RecoveryShard.spawn(world, victim.global_position + Vector3.UP * 0.9, attacker)
	if is_instance_valid(attacker) and attacker != victim and scores.has(attacker.get_instance_id()):
		var score: Dictionary = scores[attacker.get_instance_id()]
		score["kills"] += 1
		if mode == Mode.TEAMS:
			team_scores[score["team"]] += 1
			if team_scores[score["team"]] >= score_limit:
				finish("TEAM " + ("ASH" if score["team"] == 0 else "BONE"))
		elif mode == Mode.FREE_FOR_ALL and score["kills"] >= score_limit:
			finish(score["name"])
	if mode == Mode.SURVIVAL:
		if victim is PlayerController:
			finish("SURVIVED %d WAVES" % maxi(0, wave - 1))
		else:
			_remove_later(victim)
			if living_enemies() == 0 and _wave_wait < 0:
				_wave_wait = 3.0
				var player := world.get_node("Player") as PlayerController
				player.hp = minf(player.max_hp, player.hp + 25)
	else:
		_respawn_later(victim)


func _respawn_later(actor: Node3D) -> void:
	await get_tree().create_timer(2.5).timeout
	if ended or not is_instance_valid(actor):
		return
	var at := safest_spawn(actor.combat_team())
	if actor is PlayerController:
		actor.spawn_transform.origin = at
		actor.respawn()
	else:
		actor.rebuild(at)
	respawns += 1


func _remove_later(actor: Node3D) -> void:
	await get_tree().create_timer(2.0).timeout
	actors.erase(actor)
	if is_instance_valid(actor):
		actor.queue_free()


func _next_wave() -> void:
	wave += 1
	for i in range(mini(2 + wave * 2, 14)):
		_spawn_bot(1, safest_spawn(1))


func living_enemies() -> int:
	var total := 0
	for actor in actors:
		if actor is CombatBot and CombatRules.alive(actor):
			total += 1
	return total


func safest_spawn(team: int) -> Vector3:
	var best := spawns[0]
	var best_distance := -1.0
	for point in spawns:
		if mode == Mode.TEAMS and ((team == 0 and point.x > 0) or (team == 1 and point.x < 0)):
			continue
		var distance := 100000.0
		for actor in actors:
			if CombatRules.alive(actor):
				var separation := point.distance_to(actor.global_position)
				if actor.combat_team() != team:
					separation *= 0.6
				distance = minf(distance, separation)
		if distance > best_distance:
			best = point
			best_distance = distance
	return best


func leader() -> String:
	if mode == Mode.TEAMS:
		return "DRAW" if team_scores[0] == team_scores[1] else ("TEAM ASH" if team_scores[0] > team_scores[1] else "TEAM BONE")
	var best := "DRAW"
	var highest := -1
	var tied := false
	for row: Dictionary in scores.values():
		if row["kills"] > highest:
			highest = row["kills"]
			best = row["name"]
			tied = false
		elif row["kills"] == highest:
			tied = true
	return "DRAW" if tied else best


func can_engage(_bot: CombatBot, _actor: Node3D) -> bool:
	return true


func notify_cast(source: Node3D, at: Vector3, loudness: float = 1.0) -> void:
	for actor in actors:
		if actor is CombatBot and CombatRules.alive(actor): actor.perception.hear(source, at, loudness)


func blocks_player_damage(_player: PlayerController) -> bool:
	return false


func status_text() -> String:
	var text := "WAVE %d / LEFT %d" % [wave, living_enemies()] if mode == 2 else "%03d s / LIMIT %d" % [maxi(0, int(time_limit - elapsed)), score_limit]
	if mode == 1: text += " / ASH %d : %d BONE" % [team_scores[0], team_scores[1]]
	return text


func finish(result: String) -> void:
	if ended:
		return
	ended = true
	winner = result
	for actor in actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor._cancel_drawing()
	var player := world.get_node("Player") as PlayerController
	player.allow_click_capture = false
	player.invulnerability = 100000
	player.velocity = Vector3.ZERO
	player.set_mouse_captured(false)
	for node in world.get_node("Rifts").get_children() + world.get_node("HostileProjectiles").get_children():
		node.queue_free()
	world.show_results(result)


func board_text() -> String:
	var rows: Array = scores.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["kills"] > b["kills"])
	var text := "NAME                  K / D\n"
	for row: Dictionary in rows.slice(0, 10):
		text += "%-21s %02d / %02d\n" % [row["name"], row["kills"], row["deaths"]]
	return text
