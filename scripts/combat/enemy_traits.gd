class_name EnemyTraits
extends RefCounted

var bot: CharacterBody3D
var exposed: float = 0.0
var phase_clock: float = 0.0
var heal_clock: float = 2.8
var heals_sent: int = 0
var counters: int = 0
var last_ability: StringName = &""
var combo_window: float = 0.0
var shield: MeshInstance3D
var ghosts: Array[Node3D] = []


func configure(actor: CharacterBody3D) -> void:
	bot = actor
	if bot.kind == CombatBot.Kind.TANK:
		shield = MeshInstance3D.new()
		shield.mesh = ConvexFracture.tapered_part(Vector3(1.35, 2.7, 0.22), 0.56)
		shield.position = Vector3(0, 2.9, 0.64)
		var plate := StandardMaterial3D.new()
		plate.albedo_color = Color("5f584b")
		plate.metallic = 0.6
		plate.roughness = 0.48
		shield.material_override = plate
		bot.hull.visual.add_child(shield)
	if bot.kind == CombatBot.Kind.PHASE_ENTITY:
		var ghost_material := StandardMaterial3D.new()
		ghost_material.albedo_color = Color(0.64, 0.59, 0.64, 0.22)
		ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for side in [-1.0, 1.0]:
			var projection := Node3D.new()
			projection.position = Vector3(side * 0.62, 0.12, -0.12)
			bot.hull.visual.add_child(projection)
			ghosts.append(projection)
			for part: Dictionary in CreatureAnatomy.parts(int(bot.kind)):
				if part["tag"] not in ["thorax", "neck", "skull", "forearm", "shin"]:
					continue
				var mesh := MeshInstance3D.new()
				mesh.mesh = part["mesh"]
				mesh.position = part["at"]
				mesh.material_override = ghost_material
				projection.add_child(mesh)


func step(delta: float) -> void:
	exposed = maxf(0, exposed - delta)
	combo_window = maxf(0, combo_window - delta)
	phase_clock += delta
	if shield != null:
		shield.rotation.z = lerpf(shield.rotation.z, -0.85 if exposed > 0 else 0.0, minf(1, delta * 7))
	for i in range(ghosts.size()):
		ghosts[i].visible = phased()
		ghosts[i].position.x = (-1.0 if i == 0 else 1.0) * (0.56 + sin(phase_clock * 2.4) * 0.16)
	if bot.kind == CombatBot.Kind.CANTOR:
		heal_clock -= delta
		if heal_clock <= 0:
			heal_clock = 4.8
			if exposed <= 0:
				_heal_allies()


func phased() -> bool:
	return bot.kind == CombatBot.Kind.PHASE_ENTITY and exposed <= 0 and fmod(phase_clock, 4.8) < 3.0


func reset() -> void:
	exposed = 0
	phase_clock = 0
	combo_window = 0
	last_ability = &""
	heal_clock = 2.8


func multiplier(ability: StringName, direction: Vector3, reflected: bool, source: Node) -> float:
	var shape := &"FANG" if ability == &"FANG_SHARD" else ability
	var factor := 1.0
	if bot.kind == CombatBot.Kind.TANK and exposed <= 0 and direction.dot(bot.global_basis.z) < -0.30:
		if reflected or shape in [&"FANG", &"SIMPLEX", &"HYPERCUT", &"SPATIAL_COMBO"]:
			expose(2.2, source, "ARMOR OPEN")
			factor = 1.45 if shape == &"SIMPLEX" else 1.15
		elif shape == &"SCAR":
			factor = 0.22
		else:
			factor = 0.65
	elif phased():
		if reflected or shape in [&"CHAINBREAK", &"HOLLOW", &"HYPERCUT", &"SPATIAL_COMBO"]:
			expose(2.4, source, "PHASE ANCHORED")
			factor = 1.25
		elif shape == &"SIMPLEX":
			factor = 0.65
		else:
			factor = 0.12
	elif bot.kind == CombatBot.Kind.CANTOR and bot._windup > 0:
		if reflected or shape == &"CHAINBREAK":
			expose(2.0, source, "CHANT BROKEN")
			bot._cancel_drawing()
			bot._attack_cooldown = 1.7
			factor = 1.5
		elif shape == &"SCAR":
			factor = 0.65
	if combo_window > 0 and last_ability != shape and source is PlayerController:
		factor *= 1.15
		if bot.kind in [CombatBot.Kind.TANK, CombatBot.Kind.PHASE_ENTITY]:
			expose(1.5, source, "GEOMETRY BREAK")
	last_ability = shape
	combo_window = 1.8
	return factor


func expose(duration: float, source: Node, message: String) -> void:
	var newly_open := exposed <= 0
	exposed = maxf(exposed, duration)
	if newly_open:
		counters += 1
		var world := bot.get_tree().current_scene
		if source is PlayerController and world != null and world.has_node("HUD/Display"):
			var hud := world.get_node("HUD/Display")
			hud.notice = message
			hud.notice_remaining = 1.0
			hud._award(35, message)


func field_contact(ability: StringName, source: Node) -> void:
	if ability in [&"HOLLOW", &"SPATIAL_POCKET"]:
		expose(0.8, source, "SPACE ANCHORED")


func _heal_allies() -> void:
	if not is_instance_valid(bot.director):
		return
	var world := bot.get_tree().current_scene as Node3D
	for other in bot.director.actors:
		if other == bot or not other is CombatBot or not CombatRules.alive(other) or other.team_id != bot.team_id:
			continue
		if other.hull.hp >= other.hull.max_hp or bot.global_position.distance_to(other.global_position) > 11.0:
			continue
		if not CombatRules.clear_line(bot, bot.combat_aim_point(), other.combat_aim_point()):
			continue
		other.hull.hp = minf(other.hull.max_hp, other.hull.hp + 14)
		other.hull._update_status()
		RiftCaster.seam(world, bot.combat_aim_point(), other.combat_aim_point(), Color("c4b9a4"))
		heals_sent += 1


func hint() -> String:
	match bot.kind:
		CombatBot.Kind.TANK: return "OPEN / FOLLOW UP" if exposed > 0 else "ARMOR / V, TRIANGLE, REAR"
		CombatBot.Kind.PHASE_ENTITY: return "ANCHORED / CUT" if not phased() else "PHASE / Z, CIRCLE, WINDOW"
		CombatBot.Kind.CANTOR: return "CANTOR / BREAK CHANT, REFLECT"
	return ""
