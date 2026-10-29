class_name Bellkeeper
extends StaticBody3D

var hull: EnemyController
var npc_label: String = "ХРАНИТЕЛЬ"
var anatomy: int = 5
var scribe_mode: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 5.1
	capsule.radius = 0.45
	collision.shape = capsule
	collision.position.y = 2.6
	add_child(collision)
	hull = preload("res://scenes/target.tscn").instantiate() as EnemyController
	hull.anatomy_variant = anatomy
	hull.auto_respawn = false
	hull.target_name = npc_label
	hull.collision_layer = 0
	add_child(hull)
	hull.collision.disabled = true
	hull.scale = Vector3(0.78, 0.92, 0.85)
	hull.status.text = npc_label + " / E"
	hull.status.visibility_range_end = 28
	var cloak := MeshInstance3D.new()
	cloak.mesh = ConvexFracture.tapered_part(Vector3(0.86, 2.7, 0.60), 0.45)
	cloak.position.y = 1.65
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("352e28")
	cloth.roughness = 1
	cloak.material_override = cloth
	hull.visual.add_child(cloak)
	if scribe_mode:
		var book := MeshInstance3D.new()
		book.mesh = ConvexFracture.tapered_part(Vector3(0.52, 0.09, 0.38), 0.8)
		book.position = Vector3(0.12, 2.05, 0.63)
		var cover := StandardMaterial3D.new()
		cover.albedo_color = Color("8e795c")
		cover.roughness = 0.9
		book.material_override = cover
		hull.visual.add_child(book)


func _process(_delta: float) -> void:
	if scribe_mode and hull != null:
		hull.animator.casting = 0.4 + sin(float(Time.get_ticks_msec()) * 0.0017) * 0.08


func can_talk(player: PlayerController) -> bool:
	var target := global_position + Vector3.UP * 2.6
	var offset := target - player.camera.global_position
	if offset.length() > 6.0 or offset.normalized().dot(-player.camera.global_basis.z) < 0.1:
		return false
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, target, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
