class_name ExpeditionDirector
extends MatchDirector

var profile: ExpeditionState
var region: ExpeditionRegion
var keeper: Bellkeeper
var pylons: Array[QuestPylon] = []
var _wake_clock: float = 0
var _survey_clock: float = 0
var map_view: ExpeditionMap
var scribe: Bellkeeper


func start(level: Node3D, _selected_mode: int, nav: BattleNavigation) -> void:
	world = level
	mode = 3
	navigation = nav
	region = nav.arena as ExpeditionRegion
	profile = world.profile
	var player := world.get_node("Player") as PlayerController
	player.auto_respawn = false
	player.team_id = 0
	player.invulnerability = 2
	player.max_hp = 120 if profile.stage == 3 else 100
	player.hp = player.max_hp
	player.rune = profile.rune
	actors.append(player)
	_add_score(player, "YOU", 0)
	player.killed.connect(func(attacker: Node): _on_elimination(player, attacker))
	keeper = Bellkeeper.new()
	world.add_child(keeper)
	keeper.position = Vector3(8, 0.1, 8)
	scribe = Bellkeeper.new()
	scribe.npc_label = "ПЕПЕЛЬНЫЙ ПИСАРЬ"
	scribe.anatomy = 4
	scribe.scribe_mode = true
	world.add_child(scribe)
	for district in region.districts:
		if district["index"] == 7: scribe.global_position = district["center"] + Vector3(0, 0.1, 6)
	for site in region.sites:
		var pylon := QuestPylon.new()
		pylon.director = self
		pylon.site_index = site["index"]
		pylon.required = site["required"]
		world.get_node("Targets").add_child(pylon)
		pylon.global_position = site["at"]
		pylons.append(pylon)
		actors.append(pylon)
	_spawn_encounters()
	if profile.side_stage == 1: _spawn_echoes()
	map_view = ExpeditionMap.new()
	map_view.name = "ExpeditionMap"
	map_view.director = self
	world.hud.add_child(map_view)
	if not profile.load_error.is_empty():
		world.hud.notice = profile.load_error
		world.hud.notice_remaining = 6
	else:
		profile.save()


func _spawn_encounters() -> void:
	var layouts := [
		[[CombatBot.Kind.TANK, Vector3(-7, 0, 6)], [CombatBot.Kind.CANTOR, Vector3(7, 0, -9)], [CombatBot.Kind.RUSHER, Vector3(0, 0, 14)]],
		[[CombatBot.Kind.STRAFER, Vector3(-6, 9, -3)], [CombatBot.Kind.TANK, Vector3(5, 9, 4)], [CombatBot.Kind.PHASE_ENTITY, Vector3(12, 14, -8)], [CombatBot.Kind.CANTOR, Vector3(6, 0, 21)]],
		[[CombatBot.Kind.SWARM, Vector3(-7, 0, 9)], [CombatBot.Kind.SWARM, Vector3(7, 0, 9)], [CombatBot.Kind.SWARM, Vector3(0, 0, -15)], [CombatBot.Kind.RUSHER, Vector3(0, 0, 18)]],
		[[CombatBot.Kind.CANTOR, Vector3(-6, 9, -3)], [CombatBot.Kind.PHASE_ENTITY, Vector3(12, 14, -8)]]]
	for district in region.districts:
		var site: int = district["index"]
		if site < 0 or site > 3: continue
		var layout: Array = layouts[site]
		for i in range(layout.size()):
			var id := "guard_%d_%d" % [site, i]
			if profile.cleared.has(id): continue
			var at: Vector3 = district["center"] + layout[i][1] + Vector3.UP * 0.12
			var bot := _spawn_bot(1, at, int(layout[i][0]))
			bot.set_meta("guard_id", id)
			bot.set_meta("site_index", site)
			bot.home_position = at
			bot.home_radius = 33
			bot.set_physics_process(false)


func _process(delta: float) -> void:
	elapsed += delta


func _physics_process(delta: float) -> void:
	var player := world.get_node("Player") as PlayerController
	_survey_clock -= delta
	if _survey_clock <= 0 and not player.dead:
		_survey_clock = 0.35
		var district: Dictionary = region.district_at(player.global_position)
		var id := int(district["index"])
		if not profile.visited.has(id):
			profile.visited.append(id)
			profile.save()
			_message("ОТКРЫТО: " + String(district["name"]), 2.2)
	world.hud.context_hint = ""
	if not player.dead:
		if scribe.can_talk(player): world.hud.context_hint = "E — ГОВОРИТЬ С ПИСАРЕМ"
		elif keeper.can_talk(player): world.hud.context_hint = "E — ГОВОРИТЬ С ХРАНИТЕЛЕМ"
	_wake_clock -= delta
	if _wake_clock <= 0:
		_wake_clock = 0.45
		for actor in actors:
			if actor is CombatBot:
				var active: bool = not actor.dead and actor.global_position.distance_to(player.global_position) < 61
				if not active: actor._cancel_drawing()
				actor.set_physics_process(active)


func can_engage(bot: CombatBot, actor: Node3D) -> bool:
	if actor is PlayerController:
		return not safe_at(actor.global_position) and actor.global_position.distance_to(bot.home_position) < bot.home_radius
	return true


func safe_at(at: Vector3) -> bool:
	return not region.district_at(at)["hostile"]


func blocks_player_damage(player: PlayerController) -> bool:
	return safe_at(player.global_position)


func _on_elimination(victim: Node, attacker: Node) -> void:
	if victim is PlayerController:
		scores[victim.get_instance_id()]["deaths"] += 1
		_return_to_refuge(victim)
		return
	if victim is CombatBot:
		var id: String = victim.get_meta("guard_id", "")
		if not id.is_empty() and not profile.cleared.has(id):
			profile.cleared.append(id)
		var echo := int(victim.get_meta("echo_id", -1))
		if echo >= 0 and not profile.echoes.has(echo):
			profile.echoes.append(echo)
			if profile.echoes.size() == 2:
				profile.side_stage = 2
				profile.tracked = 3
			_message("ЭХА УМОЛКЛИ / ВЕРНИСЬ К ПИСАРЮ", 3)
		if attacker is PlayerController:
			scores[attacker.get_instance_id()]["kills"] += 1
			RecoveryShard.spawn(world, victim.global_position + Vector3.UP * 0.9, attacker)
		profile.save()


func _return_to_refuge(player: PlayerController) -> void:
	await get_tree().create_timer(2.5).timeout
	if not is_instance_valid(player): return
	player.spawn_transform.origin = Vector3(0, 0.15, 14)
	player.respawn()
	respawns += 1


func guards_left(site: int) -> int:
	var count := 0
	for actor in actors:
		if actor is CombatBot and not actor.dead and int(actor.get_meta("site_index", -1)) == site:
			count += 1
	return count


func try_seal(site: int, ability: StringName) -> bool:
	if site < 0 or site >= pylons.size() or profile.seals.has(site): return false
	if profile.stage == 0:
		_message("Сначала поговори с Хранителем.")
		return false
	if guards_left(site) > 0:
		_message("Стражей печати осталось: %d" % guards_left(site))
		return false
	if ability != pylons[site].required:
		_message("Печать просит: " + RiftCaster.EFFECTS[pylons[site].required])
		return false
	profile.seals.append(site)
	if profile.seals.size() == 3: profile.stage = 2
	if profile.tracked == site:
		profile.tracked = -1
		for next in range(3):
			if not profile.seals.has(next):
				profile.tracked = next
				break
	pylons[site].refresh()
	profile.save()
	world.get_node("Audio").play_spatial(&"quest", pylons[site].combat_aim_point(), -14)
	_message("ПЕЧАТЬ ВОССТАНОВЛЕНА / %d ИЗ 3" % profile.seals.size())
	return true


func interact() -> bool:
	var player := world.get_node("Player") as PlayerController
	if not player.dead and scribe.can_talk(player): return _interact_scribe(player)
	if player.dead or not keeper.can_talk(player): return false
	match profile.stage:
		0:
			profile.stage = 1
			profile.tracked = 0
			_message("Три колокола молчат. Очисти их печати.\nОссуарий — круг. Квартал — треугольник. Пепел — Z.\nВернись, когда они снова прозвучат. Tab — журнал.", 8)
		1: _message("Сначала победи стражей, затем нарисуй символ печати.\nНайдено: %d из 3. Tab показывает направления и расстояния." % profile.seals.size(), 6)
		2:
			profile.stage = 3
			player.max_hp = 120
			player.hp = player.max_hp
			player.energy = 100
			profile.tracked = 3
			world.get_node("Audio").play_cue(&"quest")
			_message("Девятый колокол снова звучит.\nКЛЯТВА ХРАНИТЕЛЯ: максимум здоровья +20.\nНа покинутом рынке ждёт Писарь. Он знает путь эха.", 8)
		3:
			player.hp = player.max_hp
			player.energy = 100
			_message("Убежище помнит тебя.\nОстанься на звон колокола — или исследуй крыши и тихие районы.", 6)
	profile.save()
	return true


func echo_locations() -> Array[Vector3]:
	var roof := Vector3.ZERO
	for district in region.districts:
		if district["index"] == 3: roof = district["center"] + Vector3(4, 9.12, -2)
	return [roof, region.sites[2]["center"] + Vector3(4, 3.62, -3)]


func _spawn_echoes() -> void:
	var locations := echo_locations()
	for i in range(2):
		if profile.echoes.has(i): continue
		var exists := false
		for actor in actors:
			if actor is CombatBot and int(actor.get_meta("echo_id", -1)) == i: exists = true
		if exists: continue
		var bot := _spawn_bot(1, locations[i], CombatBot.Kind.TANK if i == 0 else CombatBot.Kind.PHASE_ENTITY, true)
		bot.bot_name = "ЭХО КОЛОКОЛА" if i == 0 else "ЭХО ПЕПЛА"
		bot.hull.target_name = bot.bot_name
		bot.hull._update_status()
		bot.set_meta("guard_id", "echo_%d" % i)
		bot.set_meta("echo_id", i)
		bot.home_position = locations[i]
		bot.home_radius = 36
		bot.set_physics_process(false)


func _interact_scribe(_player: PlayerController) -> bool:
	if profile.stage < 3:
		_message("Сначала верни звон Хранителю.\nПотом мы поговорим о тех, кто отвечает из пепла.", 6)
		return true
	match profile.side_stage:
		0:
			profile.side_stage = 1
			profile.tracked = 4
			_spawn_echoes()
			_message("Два эха держат путь: на колокольных крышах и в пепле.\nСломи их. Смотри, как меняется рисунок после ранения.\nВернись — я свяжу одну клятву с твоими разломами.", 9)
		1: _message("Эха умолкли: %d из 2.\nTab — карта и выбранная цель. Не отвечай на каждый разлом линией." % profile.echoes.size(), 7)
		2: _message("Выбери одну клятву:\n1 — РАСКОЛ: +18% урона FANG и SIMPLEX.\n2 — УЗЫ: HOLLOW +15% радиус / +25% время, FOLD +35% время.\nНажми 1 или 2 рядом со мной. Выбор останется в этом походе.", 12)
		3: _message("Твоя клятва: " + String(RiftRunes.NAMES.get(profile.rune, "")) + ".\nПепел помнит выбор. Остальные дороги принадлежат тебе.", 7)
	profile.save()
	return true


func choose_rune(choice: StringName) -> bool:
	var player := world.get_node("Player") as PlayerController
	if profile.side_stage != 2 or profile.echoes.size() != 2 or not RiftRunes.NAMES.has(choice) or player.dead or not scribe.can_talk(player): return false
	profile.rune = choice
	profile.side_stage = 3
	profile.tracked = 3
	if not profile.save():
		profile.rune = &""
		profile.side_stage = 2
		_message("КЛЯТВА НЕ СОХРАНЕНА / ПОВТОРИ ВЫБОР", 4)
		return false
	player.rune = choice
	world.get_node("Audio").play_cue(&"quest")
	_message("ПОЛУЧЕНА " + String(RiftRunes.NAMES[choice]), 4)
	world.hud.dialog_remaining = 0
	return true


func _message(text: String, duration: float = 2.0) -> void:
	if text.contains("\n"):
		world.hud.dialog_text = text
		world.hud.dialog_remaining = duration
	else:
		world.hud.notice = text
		world.hud.notice_remaining = duration


func status_text() -> String:
	var at: Vector3 = world.get_node("Player").global_position
	return String(region.district_at(at)["name"]) + " / " + ["E: ХРАНИТЕЛЬ", "ПЕЧАТИ %d/3" % profile.seals.size(), "ВЕРНИСЬ К ХРАНИТЕЛЮ", "КЛЯТВА ПОЛУЧЕНА"][profile.stage]


func board_text() -> String:
	var player := world.get_node("Player") as PlayerController
	var text := "ДЕВЯТЫЙ КОЛОКОЛ / ЖУРНАЛ\n"
	text += "Хранитель: убежище в центре региона\n"
	for site in region.sites:
		var offset: Vector3 = site["at"] - player.global_position
		var bearing := ExpeditionMap.bearing(offset)
		text += "%s / %s / %dm %s\n" % [site["required"], "ГОТОВО" if profile.seals.has(site["index"]) else site["name"], int(offset.length()), bearing]
	text += "\nE разговор / H фигуры / F7 палитра\nСмерть возвращает в убежище; печати сохраняются."
	return text


func journal_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"id": -1, "name": "ХРАНИТЕЛЬ / УБЕЖИЩЕ", "at": keeper.global_position, "status": "E — РАЗГОВОР", "color": Color("d6c6a4")}]
	if profile.stage > 0 and profile.stage < 3:
		for site in region.sites:
			var id := int(site["index"])
			result.append({"id": id, "name": site["name"], "at": site["at"], "status": "ГОТОВО" if profile.seals.has(id) else String(site["required"]), "color": RiftCaster.tint_for(site["required"])})
	if profile.stage == 3 or profile.visited.has(7):
		result.append({"id": 3, "name": "ПИСАРЬ / РЫНОК", "at": scribe.global_position, "status": "E — КЛЯТВА" if profile.side_stage == 2 else "E — РАЗГОВОР", "color": Color("d6c6a4")})
	if profile.side_stage == 1:
		var locations := echo_locations()
		for i in range(2):
			if not profile.echoes.has(i): result.append({"id": 4 + i, "name": "ЭХО / КОЛОКОЛЬНЫЕ КРЫШИ" if i == 0 else "ЭХО / ПЕПЕЛ", "at": locations[i], "status": "ЭЛИТА / ДВЕ ФАЗЫ", "color": RiftCaster.tint_for(&"SIMPLEX" if i == 0 else &"HOLLOW")})
	return result


func track_target(id: int) -> bool:
	if id == -2:
		profile.tracked = -2
		profile.save()
		return true
	for target in journal_targets():
		if int(target["id"]) == id:
			profile.tracked = id
			profile.save()
			return true
	return false


func navigation_hint() -> String:
	var player := world.get_node("Player") as PlayerController
	for target in journal_targets():
		if int(target["id"]) != profile.tracked: continue
		var offset: Vector3 = target["at"] - player.global_position
		var angle := wrapf(atan2(offset.x, -offset.z) + player.rotation.y, -PI, PI)
		return "%s %s / %d м / %s" % ["←" if angle < -0.15 else ("→" if angle > 0.15 else "↑"), target["name"], int(offset.length()), ExpeditionMap.bearing(offset)]
	return "TAB — КАРТА И ЖУРНАЛ"
