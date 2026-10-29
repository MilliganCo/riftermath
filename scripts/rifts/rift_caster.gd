class_name RiftCaster
extends RefCounted

const SCAR_SCENE := preload("res://scenes/rift_projectile.tscn")
const COSTS := {&"SCAR": 4.0, &"FANG": 12.0, &"CHAINBREAK": 18.0, &"HOLLOW": 30.0, &"SIMPLEX": 22.0, &"FOLD": 16.0, &"HYPERCUT": 36.0}
const TINTS := {&"SCAR": Color("e2d7bd"), &"FANG": Color("c39473"), &"CHAINBREAK": Color("92ab92"), &"HOLLOW": Color("a591b6"), &"SIMPLEX": Color("b87969"), &"FOLD": Color("86b8bb"), &"HYPERCUT": Color("c69ba8")}
const EFFECTS := {&"SCAR": "ЛИНИЯ / РАЗРЕЗ", &"FANG": "V / КЛИН И ВЕЕР", &"CHAINBREAK": "Z / ЦЕПЬ", &"HOLLOW": "КРУГ / ПРИТЯЖЕНИЕ", &"SIMPLEX": "ТРЕУГОЛЬНИК / ВЗРЫВ", &"FOLD": "УГОЛ / ПЕРЕНАПРАВЛЕНИЕ", &"HYPERCUT": "КВАДРАТ / ОКНО"}
const SOUNDS := {&"SCAR": &"cast", &"FANG": &"heavy", &"CHAINBREAK": &"air_cut", &"HOLLOW": &"phase", &"SIMPLEX": &"heavy", &"FOLD": &"parry", &"HYPERCUT": &"quest"}


static func cast(world: Node3D, gesture: Dictionary, pose: Transform3D, eye: Vector3, source: Node3D = null, inherited: Vector3 = Vector3.ZERO) -> Node3D:
	var parent := world.get_node("Rifts")
	if parent.get_child_count() >= 48:
		return null
	var data := gesture.duplicate()
	data["source"] = source
	var ability: StringName = data.get("ability", &"SCAR")
	data["color"] = data.get("color", tint_for(ability))
	RiftRunes.prepare(data, source)
	var field: Node3D
	match ability:
		&"HOLLOW": field = HollowField.new()
		&"FOLD": field = FoldField.new()
		&"HYPERCUT": field = HypercutField.new()
	if field != null:
		var localized := SpatialEffects.localize(data, pose)
		parent.add_child(field)
		field.configure(localized["gesture"], localized["pose"], source)
		RiftRunes.apply_effect(field, source)
		if field is HollowField:
			field.rim.set_tint(data["color"])
			field.cavity.material_override.set_shader_parameter("rift_tint", data["color"])
		for visual in field.find_children("*", "Node3D", true, false):
			if visual is RiftRenderer:
				visual.set_tint(data["color"])
		return field
	var attack: RiftProjectile
	match ability:
		&"FANG":
			attack = FangProjectile.new()
		&"CHAINBREAK":
			attack = ChainbreakProjectile.new()
		&"SIMPLEX":
			attack = SimplexProjectile.new()
		_:
			attack = SCAR_SCENE.instantiate()
	if attack.get_child_count() == 0:
		var renderer := RiftRenderer.new()
		renderer.name = "RiftRenderer"
		attack.add_child(renderer)
	parent.add_child(attack)
	wire(attack, world, source)
	attack.configure(data, pose, eye, inherited)
	RiftRunes.apply_effect(attack, source)
	return attack


static func tint_for(ability: StringName) -> Color:
	return TINTS.get(ability, TINTS[&"SCAR"])


static func wire(attack: RiftProjectile, world: Node3D, source: Node) -> void:
	if source == world.get_node_or_null("Player") and world.has_node("HUD/Display"):
		var hud := world.get_node("HUD/Display")
		if not attack.target_hit.is_connected(hud.register_hit):
			attack.target_hit.connect(hud.register_hit)
		if not attack.fragment_cut.is_connected(hud.register_fragment_cut):
			attack.fragment_cut.connect(hud.register_fragment_cut)


static func seam(world: Node3D, from: Vector3, to: Vector3, color: Color = Color("80ffff")) -> RiftRenderer:
	var direction := (to - from).normalized()
	if direction.length_squared() < 0.1:
		return null
	var z_axis := direction.cross(Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT).normalized()
	var y_axis := z_axis.cross(direction).normalized()
	var rift := RiftRenderer.new()
	world.get_node("Rifts").add_child(rift)
	rift.global_transform = Transform3D(Basis(direction, y_axis, z_axis), from)
	var distance := from.distance_to(to)
	rift.set_path(PackedVector2Array([Vector2.ZERO, Vector2(distance * 0.3, 0.10), Vector2(distance * 0.7, -0.08), Vector2(distance, 0)]))
	rift.set_tint(color)
	rift._echo_duration = 0.26
	rift._echo_remaining = 0.26
	return rift
