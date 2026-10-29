class_name QuestPylon
extends StaticBody3D

var director: Node
var site_index: int = 0
var required: StringName = &"HOLLOW"
var glyph: RiftRenderer
var status: Label3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var body := MeshInstance3D.new()
	body.mesh = ConvexFracture.tapered_part(Vector3(0.9, 3.7, 0.7), 0.42)
	body.position.y = 1.85
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("51473c")
	material.roughness = 0.9
	body.material_override = material
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = body.mesh.create_convex_shape()
	collision.position = body.position
	add_child(collision)
	glyph = RiftRenderer.new()
	add_child(glyph)
	glyph.position = Vector3(0, 3.0, 0.44)
	glyph.set_path(GestureRecognizer.template(required))
	glyph.scale = Vector3.ONE * 0.55
	glyph.set_tint(RiftCaster.tint_for(required))
	glyph.set_opening(0.50)
	status = Label3D.new()
	status.position.y = 4.3
	status.pixel_size = 0.008
	status.font_size = 40
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.visibility_range_end = 24
	add_child(status)
	refresh()


func refresh() -> void:
	var claimed: bool = director.profile.seals.has(site_index)
	status.text = "ПЕЧАТЬ ВОССТАНОВЛЕНА" if claimed else "ПЕЧАТЬ / " + String(required)
	glyph.set_opening(0.08 if claimed else 0.5)
	collision_layer = 1 if claimed else 4


func combat_team() -> int:
	return 1


func combat_alive() -> bool:
	return not director.profile.seals.has(site_index)


func combat_aim_point() -> Vector3:
	return global_position + Vector3.UP * 2.4


func can_receive_hit() -> bool:
	return combat_alive()


func rift_multiplier(ability: StringName, _direction: Vector3, _reflected: bool, source: Node) -> float:
	if source is PlayerController:
		director.try_seal(site_index, ability)
	return 0.0


func field_contact(ability: StringName, source: Node) -> void:
	if source is PlayerController:
		director.try_seal(site_index, ability)


func receive_scar(_amount: float, _direction: Vector3, _normal: Vector3, _point: Vector3 = Vector3.INF, _token: int = 0, _source: Node = null) -> bool:
	# This is an objective receiver, not an HP target; activation lives above.
	return false
