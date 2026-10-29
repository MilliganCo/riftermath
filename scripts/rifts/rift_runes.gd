class_name RiftRunes
extends RefCounted

const NAMES := {&"fracture": "КЛЯТВА РАСКОЛА", &"binding": "КЛЯТВА УЗ"}


static func prepare(data: Dictionary, source: Node) -> void:
	if not source is PlayerController: return
	if source.rune == &"fracture" and data.get("ability") in [&"FANG", &"SIMPLEX"]:
		data["damage"] *= 1.18


static func apply_effect(effect: Node3D, source: Node) -> void:
	if not source is PlayerController: return
	if source.rune == &"fracture" and effect is SimplexProjectile:
		effect.blast_damage *= 1.18
	elif source.rune == &"binding":
		if effect is HollowField:
			effect.radius = minf(5.5, effect.radius * 1.15)
			effect.lifetime *= 1.25
		elif effect is FoldField:
			effect.lifetime *= 1.35
