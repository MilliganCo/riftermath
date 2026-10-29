class_name RecoveryShard
extends Node3D

const MAX_SHARDS: int = 12
const LIFETIME: float = 12.0
const HEAL: float = 12.0
const ENERGY: float = 16.0
var player: PlayerController
var age: float = 0.0
var collected: bool = false
var visual: MeshInstance3D
var _anchor := Vector3.ZERO
var _seeking: bool = false


static func spawn(world: Node3D, at: Vector3, controller: PlayerController) -> RecoveryShard:
	var existing := world.get_tree().get_nodes_in_group("recovery_shards").filter(func(node: Node) -> bool: return not node.is_queued_for_deletion())
	if existing.size() >= MAX_SHARDS:
		existing[0].queue_free()
	var shard := RecoveryShard.new()
	shard.player = controller
	world.add_child(shard)
	shard.global_position = at
	shard._anchor = at
	return shard


func _ready() -> void:
	add_to_group("recovery_shards")
	visual = MeshInstance3D.new()
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := [Vector3(-0.16, 0, 0), Vector3(0, 0, -0.16), Vector3(0.16, 0, 0), Vector3(0, 0, 0.16)]
	for i in range(4):
		for point in [Vector3(0.04, 0.60, 0), ring[i], ring[(i + 1) % 4], Vector3(-0.04, -0.40, 0), ring[(i + 1) % 4], ring[i]]:
			mesh.add_vertex(point)
	mesh.generate_normals()
	visual.mesh = mesh.commit()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("efdcaf")
	material.emission_enabled = true
	material.emission = Color("e7c994")
	material.emission_energy_multiplier = 0.65
	material.roughness = 0.55
	visual.material_override = material
	add_child(visual)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	visual.rotation.y += delta * 1.7
	visual.rotation.z = sin(age * 2) * 0.18
	visual.scale = Vector3.ONE * minf(1.0, (LIFETIME - age) * 1.5)
	if not is_instance_valid(player) or player.dead or collected:
		return
	if player.hp >= player.max_hp and player.energy >= 99.9:
		_seeking = false
		global_position.y = _anchor.y + sin(age * 2.4) * 0.10
		return
	var aim := player.combat_aim_point()
	var distance := global_position.distance_to(aim)
	var clear := distance < 5.0 and CombatRules.clear_line(self, global_position, aim)
	if clear and distance < 0.95:
		_collect()
	elif clear:
		_seeking = true
		global_position = global_position.move_toward(aim, delta * 8.0)
		_anchor = global_position
	else:
		_seeking = false
		global_position.y = _anchor.y + sin(age * 2.4) * 0.10


func _collect() -> void:
	collected = true
	var health := minf(HEAL, player.max_hp - player.hp)
	var energy := minf(ENERGY, 100.0 - player.energy)
	player.hp += health
	player.energy += energy
	var world := get_tree().current_scene
	if world != null and world.has_node("HUD/Display"):
		world.get_node("HUD/Display").register_recovery(health, energy)
	queue_free()
