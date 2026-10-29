class_name CombatBot
extends CharacterBody3D

signal eliminated(victim: Node, attacker: Node)

enum Kind { RUSHER, STRAFER, SWARM, TANK, PHASE_ENTITY, CANTOR }
const HULL_SCENE := preload("res://scenes/target.tscn")

var team_id: int = 1
var bot_name: String = "EXILE"
var kind: Kind = Kind.STRAFER
var dead: bool = false
var hull: EnemyController
var director: Node
var navigation: BattleNavigation
var invulnerability: float = 0.0
var casts_completed: int = 0
var windups_started: int = 0
var distance_travelled: float = 0.0
var nav_replans: int = 0
var target: Node3D
var _shape: CollisionShape3D
var _route := PackedVector3Array()
var _waypoint: int = 0
var _think: float = 0.0
var _attack_cooldown: float = 0.9
var _windup: float = 0.0
var _draw_update: float = 0.0
var _telegraph: RiftRenderer
var _attack_shape := PackedVector2Array()
var _elapsed: float = 0.0
var _stuck: float = 0.0
var _last_attacker: WeakRef
var _speed: float = 5.5
var tactics := BotTactics.new()
var traits := EnemyTraits.new()
var lift_remaining: float = 0.0
var home_position := Vector3.ZERO
var home_radius: float = 0.0
var elite: bool = false
var elite_phase: int = 1
var phase_changes: int = 0
var _base_speed: float = 0
var perception := BotPerception.new()
var searching: bool = false
var patrol_steps: int = 0
var _patrol_until: float = 0


func _ready() -> void:
	tactics.bot = self
	perception.bot = self
	add_to_group("combatants")
	collision_layer = 4
	collision_mask = 5
	floor_snap_length = 0.4
	_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 3.30 if kind == Kind.SWARM else (6.15 if kind in [Kind.TANK, Kind.CANTOR] else (5.6 if kind == Kind.PHASE_ENTITY else 5.10))
	capsule.radius = 0.31 if kind == Kind.SWARM else (0.68 if kind == Kind.TANK else 0.43)
	_shape.shape = capsule
	_shape.position.y = capsule.height / 2 + 0.05
	add_child(_shape)
	hull = HULL_SCENE.instantiate() as EnemyController
	hull.name = "Anatomy"
	hull.auto_respawn = false
	hull.anatomy_variant = int(kind)
	hull.target_name = bot_name
	hull.max_hp = [85, 100, 65, 260, 115, 145][int(kind)]
	if elite: hull.max_hp *= 1.55
	hull.collision_layer = 0
	add_child(hull)
	hull.collision.disabled = true
	if kind == Kind.SWARM:
		hull.scale = Vector3.ONE * 0.65
		floor_snap_length = 0.0
	elif kind == Kind.TANK:
		hull.scale = Vector3(1.5, 1.18, 1.3)
	elif kind == Kind.PHASE_ENTITY:
		hull.scale = Vector3(0.75, 1.0, 0.8)
	elif kind == Kind.CANTOR:
		hull.scale = Vector3(0.95, 1.18, 1.0)
	_speed = [7.6, 5.8, 7.0, 3.5, 6.6, 4.6][int(kind)]
	_base_speed = _speed
	traits.configure(self)
	hull.destroyed.connect(_on_destroyed)
	_attack_cooldown += float(get_instance_id() % 10) * 0.09


func _physics_process(delta: float) -> void:
	if dead:
		return
	_elapsed += delta
	invulnerability = maxf(0.0, invulnerability - delta)
	_attack_cooldown -= delta
	lift_remaining = maxf(0, lift_remaining - delta)
	traits.step(delta)
	perception.step(delta)
	_update_elite_phase()
	tactics.update(delta)
	_think -= delta
	if _think <= 0.0:
		_think = 0.45 + float(get_instance_id() % 4) * 0.035
		_choose_target_and_route()
	var before := global_position
	var move_direction := Vector3.ZERO
	if _waypoint < _route.size():
		var offset := _route[_waypoint] - global_position
		if Vector2(offset.x, offset.z).length() < 0.65:
			_waypoint += 1
		else:
			move_direction = Vector3(offset.x, 0, offset.z).normalized()
	if is_instance_valid(director):
		for actor in director.actors:
			if actor == self or not CombatRules.alive(actor):
				continue
			var separation: Vector3 = global_position - actor.global_position
			separation.y = 0
			if separation.length_squared() < 2.2 and separation.length_squared() > 0.001:
				move_direction += separation.normalized() * 0.8
	move_direction = move_direction.limit_length(1.0)
	velocity.x = move_toward(velocity.x, move_direction.x * _speed, delta * 24.0)
	velocity.z = move_toward(velocity.z, move_direction.z * _speed, delta * 24.0)
	if tactics.dodge_remaining > 0.0:
		velocity.x = tactics.dodge_velocity.x
		velocity.z = tactics.dodge_velocity.z
	if kind == Kind.SWARM and navigation != null and lift_remaining <= 0:
		var ground := navigation.arena.support_height(global_position)
		var hover := ground + 1.55 + sin(_elapsed * 2.1) * 0.20
		velocity.y = clampf((hover - global_position.y) * 4.0, -5.0, 5.0)
	else:
		velocity.y -= 25.0 * delta
	if _stuck > 0.85 and is_on_floor():
		velocity.y = 7.0
		_stuck = 0.0
	move_and_slide()
	var travelled := global_position.distance_to(before)
	distance_travelled += travelled
	_stuck = _stuck + delta if travelled < delta * 0.3 and move_direction.length_squared() > 0.2 else 0.0
	hull.visual.rotation.x = sin(_elapsed * 5.0) * 0.018
	if global_position.y < -8:
		receive_scar(10000, Vector3.UP, Vector3.UP)
		return
	if not CombatRules.alive(target):
		_cancel_drawing()
		if move_direction.length_squared() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(move_direction.x, move_direction.z), minf(1, delta * 5))
		else:
			rotation.y += delta * 0.45
		return
	var detected := perception.observe(target)
	if not detected:
		if not searching: _think = 0
		searching = true
		_cancel_drawing()
		if perception.has_memory(target):
			var remembered := perception.last_position(target) - global_position
			if Vector2(remembered.x, remembered.z).length() > 1.2:
				rotation.y = lerp_angle(rotation.y, atan2(remembered.x, remembered.z), minf(1, delta * 5))
			else: rotation.y += sin(_elapsed * 1.4) * delta
		return
	if searching: _think = 0
	searching = false
	var aim := CombatRules.aim_point(target)
	var direction := aim - combat_aim_point()
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 8)
	var muzzle := combat_aim_point() + global_basis.z * 0.7
	var visible := CombatRules.clear_line(self, muzzle, aim)
	if not visible or direction.length() > vision_range():
		_cancel_drawing()
		return
	if _windup <= 0.0 and _attack_cooldown <= 0.0:
		_begin_drawing()
	if _windup > 0.0:
		_windup += delta
		_draw_update -= delta
		var predicted := aim
		if target is CharacterBody3D:
			predicted += target.velocity * 0.10
		var toward := (predicted - muzzle).normalized()
		_telegraph.global_transform = Transform3D(Basis.looking_at(toward, Vector3.UP if absf(toward.y) < 0.95 else Vector3.RIGHT), muzzle)
		if _draw_update <= 0.0:
			_draw_update = 0.05
			var length := GestureRecognizer.path_length(_attack_shape)
			_telegraph.set_path(GestureRecognizer.trim_path(_attack_shape, maxf(0.04, length * minf(1.0, _windup / windup_duration()))))
		if _windup >= windup_duration():
			_release_rift(muzzle)


func _choose_target_and_route() -> void:
	if not is_instance_valid(director) or navigation == null:
		return
	var best: Node3D
	var score := INF
	for actor: Node3D in director.actors:
		if not perception.hostile(actor):
			continue
		perception.observe(actor)
		if not perception.has_memory(actor): continue
		var next := global_position.distance_to(perception.last_position(actor))
		if actor == target:
			next *= 0.78
		if next < score:
			score = next
			best = actor
	target = best
	if target == null:
		searching = false
		_patrol()
		return
	searching = not perception.can_see(target)
	var goal := perception.last_position(target) if searching else tactics.firing_goal(target, navigation)
	_route = navigation.route(global_position, goal)
	_waypoint = 1 if _route.size() > 1 else 0
	nav_replans += 1


func _patrol() -> void:
	if _waypoint < _route.size() and perception.clock < _patrol_until: return
	var goal := home_position
	if home_radius > 0:
		var angle := float(get_instance_id() % 8 + patrol_steps * 3) * TAU / 8
		goal += Vector3(cos(angle), 0, sin(angle)) * minf(home_radius * 0.35, 11)
	else:
		var routes := [Vector3(0, 3, 15), Vector3(-18, 0, 0), Vector3(18, 0, 0), Vector3(0, 3, -15), Vector3(-28, 7, 0), Vector3(28, 7, 0), Vector3(16, 11, -25)]
		goal = routes[(int(get_instance_id() % routes.size()) + patrol_steps) % routes.size()]
	_route = navigation.route(global_position, goal)
	_waypoint = 1 if _route.size() > 1 else 0
	_patrol_until = perception.clock + 6.0
	patrol_steps += 1
	nav_replans += 1


func _begin_drawing() -> void:
	_windup = 0.001
	_draw_update = 0.0
	windups_started += 1
	var ability := attack_ability()
	_attack_shape = GestureRecognizer.template(ability)
	_telegraph = RiftRenderer.new()
	get_tree().current_scene.get_node("Rifts").add_child(_telegraph)
	_telegraph.set_tint(_rift_color())
	_telegraph.set_opening(0.38)
	if kind in [Kind.TANK, Kind.CANTOR, Kind.PHASE_ENTITY]:
		get_tree().current_scene.get_node("Audio").play_spatial(&"bell" if kind == Kind.CANTOR else &"phase", combat_aim_point(), -20)


func _release_rift(muzzle: Vector3) -> void:
	var gesture := GestureRecognizer.recognize(_attack_shape, _windup)
	gesture["ability"] = attack_ability()
	gesture["damage"] = 21.0 if elite else 18.0
	gesture["color"] = _rift_color()
	var attack := RiftCaster.cast(get_tree().current_scene, gesture, _telegraph.global_transform, muzzle, self, velocity * 0.25)
	if attack is RiftProjectile:
		attack.speed = 22.0
		attack.flight_lifetime = 1.6
		if attack is SimplexProjectile:
			attack.blast_damage = 26.0
			attack.fuse = 0.95
			attack.blast_radius = 3.8
	if attack is HollowField:
		var at := CombatRules.aim_point(target)
		if CombatRules.clear_line(self, muzzle, at):
			attack.global_position = at
			attack.age = 0.4
		attack.collapse_damage = 24.0
		attack.lifetime = 2.2
	if kind == Kind.CANTOR:
		for angle in [-0.10, 0.10]:
			var data := GestureRecognizer.recognize(GestureRecognizer.template(&"SCAR"), 0.3)
			data["damage"] = 12.0
			data["color"] = _rift_color()
			var pose := _telegraph.global_transform.translated_local(Vector3(0, 0, -1.6))
			pose.basis = pose.basis.rotated(Vector3.UP, angle)
			var shard := RiftCaster.cast(get_tree().current_scene, data, pose, muzzle, self) as RiftProjectile
			if shard != null:
				shard.speed = 18.0
				shard.flight_lifetime = 1.5
	casts_completed += 1
	if is_instance_valid(director) and is_instance_valid(attack): director.notify_cast(self, muzzle)
	_cancel_drawing()
	_attack_cooldown = (1.7 if elite and elite_phase == 2 else (3.2 if kind in [Kind.TANK, Kind.PHASE_ENTITY, Kind.CANTOR] else 1.6)) + float(get_instance_id() % 4) * 0.20


func _cancel_drawing() -> void:
	_windup = 0
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _rift_color() -> Color:
	return RiftCaster.tint_for(attack_ability()).lerp(Color("ae8792"), 0.18 if team_id != 0 else 0.0)


func attack_ability() -> StringName:
	if elite and elite_phase == 2:
		return &"FANG" if kind == Kind.TANK else &"CHAINBREAK"
	return [&"SCAR", &"FANG", &"CHAINBREAK", &"SIMPLEX", &"HOLLOW", &"FOLD"][int(kind)]


func windup_duration() -> float:
	if elite: return 0.80 if elite_phase == 2 else 1.05
	return 0.95 if kind in [Kind.TANK, Kind.PHASE_ENTITY, Kind.CANTOR] else 0.65


func _update_elite_phase() -> void:
	if not elite or elite_phase == 2 or hull.hp > hull.max_hp * 0.5: return
	elite_phase = 2
	phase_changes += 1
	_speed = _base_speed * 1.35
	_cancel_drawing()
	_attack_cooldown = 0.55
	traits.expose(1.1, null, "")
	var world := get_tree().current_scene as Node3D
	world.get_node("Audio").play_spatial(&"bell", combat_aim_point(), -17)
	for side in [-1.0, 1.0]:
		RiftCaster.seam(world, combat_aim_point() + Vector3(side * 0.5, -0.8, 0.3), combat_aim_point() + Vector3(side * 0.8, 1.3, 0), RiftCaster.tint_for(attack_ability()))
	if world.has_node("HUD/Display"):
		world.hud.notice = "ЭХО / ВТОРАЯ ФАЗА"
		world.hud.notice_remaining = 1.3


func rift_multiplier(ability: StringName, direction: Vector3, reflected: bool, source: Node) -> float:
	return traits.multiplier(ability, direction, reflected, source)


func field_contact(ability: StringName, source: Node) -> void:
	traits.field_contact(ability, source)


func _on_destroyed() -> void:
	dead = true
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	_cancel_drawing()
	tactics.reset()
	eliminated.emit(self, _last_attacker.get_ref() if _last_attacker != null else null)


func rebuild(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	dead = false
	collision_layer = 4
	_shape.set_deferred("disabled", false)
	hull.hp = hull.max_hp
	hull.dead = false
	hull.visual.show()
	hull._update_status()
	invulnerability = 1.0
	_attack_cooldown = 1.2
	_think = 0
	tactics.reset()
	traits.reset()
	perception.clear()
	searching = false
	_patrol_until = 0
	elite_phase = 1
	_speed = _base_speed


func receive_scar(amount: float, direction: Vector3, normal: Vector3, point: Vector3 = Vector3.INF, token: int = 0, attacker: Node = null) -> bool:
	if dead or invulnerability > 0:
		return false
	_last_attacker = weakref(attacker) if is_instance_valid(attacker) else null
	return hull.receive_scar(amount, direction, normal, point, token, attacker)


func combat_team() -> int:
	return team_id


func vision_range() -> float:
	var world := get_tree().current_scene
	var atmosphere := world.get_node_or_null("CombatAtmosphere") as CombatAtmosphere if world != null else null
	return lerpf(30.0, 19.0, atmosphere.pressure) if atmosphere != null else 30.0


func combat_alive() -> bool:
	return not dead


func can_receive_hit() -> bool:
	return invulnerability <= 0 and not dead


func combat_aim_point() -> Vector3:
	return global_position + Vector3.UP * (1.7 if kind == Kind.SWARM else 2.5)
