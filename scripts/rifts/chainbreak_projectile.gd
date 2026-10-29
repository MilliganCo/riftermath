class_name ChainbreakProjectile
extends RiftProjectile

var chain_started: bool = false
var chained_targets: Array[int] = []
@export var jump_distance: float = 9.0
@export var max_jumps: int = 3


func _ready() -> void:
	super._ready()
	actor_struck.connect(_on_first_hit)


func _on_first_hit(actor: Node3D, _killed: bool) -> void:
	if chain_started:
		return
	chain_started = true
	chained_targets.append(actor.get_instance_id())
	var point := CombatRules.aim_point(actor)
	var world := get_tree().current_scene as Node3D
	for step in range(max_jumps):
		await get_tree().create_timer(0.075).timeout
		var best: Node3D
		var distance := jump_distance
		for candidate: Node3D in CombatRules.actors(world):
			if chained_targets.has(candidate.get_instance_id()) or not CombatRules.can_hit(get_source(), candidate):
				continue
			var aim := CombatRules.aim_point(candidate)
			var next_distance := point.distance_to(aim)
			if next_distance < distance and CombatRules.clear_line(world, point, aim):
				distance = next_distance
				best = candidate
		if not is_instance_valid(best):
			break
		var aim := CombatRules.aim_point(best)
		RiftCaster.seam(world, point, aim, renderer.tint)
		var dealt := damage * pow(0.78, step + 1)
		var killed := CombatRules.hit(best, dealt, (aim - point).normalized(), global_basis.y, aim, family_id, get_source(), &"CHAINBREAK", reflected)
		chained_targets.append(best.get_instance_id())
		var applied := float(best.get_meta("last_rift_damage", dealt))
		if applied > 0: target_hit.emit(applied, killed)
		point = aim
