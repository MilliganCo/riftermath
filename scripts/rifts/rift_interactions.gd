class_name RiftInteractions
extends Node

var reactions: int = 0
var reinforcements: int = 0
var _clock: float = 0.0
var _pairs: Dictionary = {}
var closed_pockets: int = 0


func _physics_process(delta: float) -> void:
	_clock -= delta
	if _clock > 0:
		return
	_clock = 0.08
	_closed_combinations()
	var attacks := get_tree().get_nodes_in_group("rift_projectiles")
	for i in range(attacks.size()):
		var a := attacks[i] as RiftProjectile
		if not is_instance_valid(a) or a.is_queued_for_deletion() or a.phase != RiftProjectile.Phase.PROPAGATION:
			continue
		for j in range(i + 1, attacks.size()):
			var b := attacks[j] as RiftProjectile
			if not is_instance_valid(b) or b.is_queued_for_deletion() or b.phase != RiftProjectile.Phase.PROPAGATION or a.family_id == b.family_id:
				continue
			if a.global_position.distance_squared_to(b.global_position) > 1.44:
				continue
			var key := "%d:%d" % [a.get_instance_id(), b.get_instance_id()]
			if _pairs.has(key):
				continue
			_pairs[key] = true
			if _pairs.size() > 128:
				_pairs.erase(_pairs.keys()[0])
			var alignment := a.global_basis.z.dot(b.global_basis.z)
			var plane := absf(a.global_basis.y.dot(b.global_basis.y))
			if plane > 0.9 and alignment > 0.8:
				a.speed = minf(74, a.speed * 1.15)
				b.speed = minf(74, b.speed * 1.15)
				a.damage = minf(140, a.damage * 1.15)
				b.damage = minf(140, b.damage * 1.15)
				reinforcements += 1
			elif plane < 0.6 or alignment < -0.6:
				var point := (a.global_position + b.global_position) * 0.5
				var source := a.get_source()
				if b.get_source() is PlayerController:
					source = b.get_source()
				SpatialEffects.burst(get_tree().current_scene, point, 2.6, 24.0, source, a.family_id)
				reactions += 1


func _closed_combinations() -> void:
	if get_tree().get_nodes_in_group("spatial_pockets").size() >= 2: return
	for field in get_tree().get_nodes_in_group("spatial_fields"):
		if not field is HollowField or field.is_queued_for_deletion() or field.age < 0.35: continue
		var source: Node = field.source_ref.get_ref() if field.source_ref != null else null
		if not is_instance_valid(source): continue
		for attack in get_tree().get_nodes_in_group("rift_projectiles"):
			if attack is SimplexProjectile and try_pocket(field, attack): return


func try_pocket(field: HollowField, attack: SimplexProjectile) -> bool:
	if field.is_queued_for_deletion() or attack.is_queued_for_deletion() or field.age < 0.35 or get_tree().get_nodes_in_group("spatial_pockets").size() >= 2: return false
	var source: Node = field.source_ref.get_ref() if field.source_ref != null else null
	if not is_instance_valid(source) or attack.get_source() != source: return false
	var closest := Geometry3D.get_closest_point_to_segment(field.global_position, attack.previous_position, attack.global_position)
	if closest.distance_to(field.global_position) > field.radius * 0.65: return false
	var pocket := SpatialPocket.new()
	var world := get_tree().current_scene as Node3D
	world.get_node("Rifts").add_child(pocket)
	pocket.configure(field.global_position, field.radius, source)
	field.collapsed = true
	field.queue_free()
	attack.queue_free()
	closed_pockets += 1
	if source is PlayerController:
		world.hud._award(70, "CLOSED POCKET")
		world.hud.notice = "КАРМАН / КРУГ + ТРЕУГОЛЬНИК"
		world.hud.notice_remaining = 1.5
		world.get_node("Audio").play_cue(&"phase")
	return true
