class_name EnemyController
extends StaticBody3D

signal damaged(amount: float, remaining: float)
signal destroyed

@export var max_hp: float = 100.0
@export var respawn_delay: float = 3.5
@export var target_name: String = "SENTINEL"
@export var fire_interval: float = 1.45
@export var warning_duration: float = 0.80
@export var bolt_speed: float = 18.0
@export var auto_respawn: bool = true
@export var anatomy_variant: int = 0

@onready var visual: Node3D = $Visual
@onready var status: Label3D = $Status
@onready var collision: CollisionShape3D = $CollisionShape3D

var hp: float = 100.0
var dead: bool = false
var _flash: float = 0.0
var _impact := Vector3.ZERO
var _clock: float = 0.0
var _shell: StandardMaterial3D
var _core: StandardMaterial3D
var _parts: Array[Dictionary] = []
var attack_enabled: bool = false
var player: PlayerController
var shots_fired: int = 0
var _fire_clock: float = 0.0
var animator := CreatureAnimator.new()


func _ready() -> void:
	animator.hull = self
	hp = max_hp
	_shell = _material(Color("a1a8a3"), 0.0)
	_core = _material(Color("c7d4cd"), 0.8)
	var recess := _material(Color("080b0a"), 0)
	for section in CreatureAnatomy.parts(anatomy_variant):
		var node := MeshInstance3D.new()
		node.mesh = section["mesh"]
		node.position = section["at"]
		node.material_override = recess if section["tag"] == "eye" else (_core if section["tag"] == "rib" else _shell)
		visual.add_child(node)
		_parts.append({"at": section["at"], "from": section["from"], "to": section["to"], "tag": section["tag"], "node": node, "mesh": section["mesh"], "shape": section["shape"], "material": node.material_override})
	_update_status()
	status.visibility_range_end = 24


func _process(delta: float) -> void:
	_clock += delta
	if dead:
		return
	_flash = maxf(0.0, _flash - delta * 4.5)
	_shell.albedo_color = Color("a1a8a3").lerp(Color("f4fff8"), _flash)
	_shell.emission_enabled = _flash > 0.01
	_shell.emission = Color(0.7, 0.8, 0.75) * _flash
	_impact = _impact.move_toward(Vector3.ZERO, delta * 2.0)
	visual.position = _impact + Vector3(0, sin(_clock * 1.7) * 0.035, 0)
	visual.rotation.z = _impact.x * -0.3
	_core.emission_energy_multiplier = 2.4 + (4.0 * clampf(1.0 - _fire_clock / 0.5, 0.0, 1.0) if attack_enabled else 0.0)
	animator.step(delta)


func _physics_process(delta: float) -> void:
	if not attack_enabled or dead or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), delta * 5.0)
	_fire_clock -= delta
	if _fire_clock > 0.0:
		return
	_fire_clock = fire_interval
	var muzzle := global_position + Vector3.UP * 2.55 + global_basis.z * 0.45
	var aim := player.global_position + Vector3.UP * 1.25
	var query := PhysicsRayQueryParameters3D.create(muzzle, aim, 3)
	var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty() and obstruction["collider"] != player:
		return
	var world := get_tree().current_scene
	if world == null or not world.has_node("HostileProjectiles"):
		return
	var parent := world.get_node("HostileProjectiles")
	if parent.get_child_count() >= 64:
		return
	var bolt := EnemyBolt.new()
	parent.add_child(bolt)
	bolt.source_ref = weakref(self)
	bolt.configure(muzzle, aim, bolt_speed)
	shots_fired += 1


func set_attack_enabled(enabled: bool, stagger: float = 0.0) -> void:
	attack_enabled = enabled
	_fire_clock = warning_duration + stagger


func receive_scar(amount: float, direction: Vector3, cut_normal: Vector3, plane_point: Vector3 = Vector3.INF, scar_id: int = 0, _attacker: Node = null) -> bool:
	if dead:
		return false
	hp = maxf(0.0, hp - amount)
	_flash = 1.0
	_impact = direction * 0.18
	damaged.emit(amount, hp)
	_update_status()
	if hp <= 0.0:
		dead = true
		visual.hide()
		collision.set_deferred("disabled", true)
		status.text = "SEVERED  //  REBUILDING"
		_spawn_fragments(direction, cut_normal, plane_point, scar_id)
		destroyed.emit()
		if auto_respawn:
			_restore_later()
		return true
	return false


func combat_alive() -> bool:
	return not dead


func _restore_later() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	hp = max_hp
	dead = false
	_fire_clock = warning_duration
	visual.show()
	collision.set_deferred("disabled", false)
	_update_status()


func _spawn_fragments(direction: Vector3, cut_normal: Vector3, plane_point: Vector3, scar_id: int) -> void:
	var world := get_tree().current_scene
	var parent := world.get_node("Debris") if world != null and world.has_node("Debris") else get_parent()
	for i in range(_parts.size()):
		var part := _parts[i]
		var pose: Transform3D = part["node"].global_transform if part.has("node") else global_transform.translated_local(part["at"])
		# World planes enter a scaled/animated local frame through B-transpose.
		var normal := (pose.basis.transposed() * cut_normal).normalized()
		var offset := normal.dot(pose.affine_inverse() * plane_point) if plane_point.is_finite() else 0.0
		var pieces := ConvexFracture.split_mesh(part["mesh"], normal, offset)
		if pieces.is_empty():
			pieces = [{"mesh": part["mesh"], "shape": part["shape"], "center": Vector3.ZERO}]
		for piece in pieces:
			_spawn_piece(parent, pose.translated_local(piece["center"]), piece["mesh"], piece["shape"], part["material"], direction, cut_normal, i, plane_point, scar_id)


func _spawn_piece(parent: Node, pose: Transform3D, mesh: Mesh, shape: Shape3D, material: Material, direction: Vector3, cut_normal: Vector3, index: int, plane_point: Vector3, scar_id: int) -> void:
	var offset := pose.origin - (plane_point if plane_point.is_finite() else to_global(Vector3(0, 2.3, 0)))
	var side := 1.0 if offset.dot(cut_normal) >= 0.0 else -1.0
	var motion := direction * 2.0 + cut_normal * side * 2.2 + Vector3(0, 4.8 + index * 0.04, 0)
	SeverableDebris.spawn(parent, mesh, shape, material.duplicate(), pose, motion, Vector3(0.4, side * 0.8, 0.3), 0, scar_id)


func _update_status() -> void:
	status.text = "%s  /  %03d" % [target_name, int(hp)]


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	material.metallic = 0.35
	material.emission_enabled = emission > 0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material


func _part(at: Vector3, size: Vector3, material: Material, taper: float = 0.65) -> void:
	var node := MeshInstance3D.new()
	var mesh := ConvexFracture.tapered_part(size, taper)
	node.mesh = mesh
	node.position = at
	node.material_override = material
	visual.add_child(node)
	_parts.append({"at": at, "mesh": mesh, "shape": mesh.create_convex_shape(), "material": material})
