extends Node3D

var player: PlayerController
var legs: Array[MeshInstance3D] = []
var _clock: float = 0.0


func _ready() -> void:
	player = get_parent() as PlayerController
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("535a56")
	material.metallic = 0.55
	material.roughness = 0.45
	_part(Vector3(0, 1.32, 0.06), Vector3(0.46, 0.82, 0.30), material)
	for side in [-1.0, 1.0]:
		legs.append(_part(Vector3(side * 0.12, 0.52, 0.02), Vector3(0.16, 1.02, 0.20), material))
		_part(Vector3(side * 0.30, 1.22, 0.05), Vector3(0.12, 0.94, 0.15), material)


func _part(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = ConvexFracture.tapered_part(size, 0.70)
	node.material_override = material
	node.position = at
	add_child(node)
	return node


func _process(delta: float) -> void:
	_clock += delta * player.horizontal_speed()
	scale.y = lerpf(scale.y, 0.44 if player.sliding else 1.0, delta * 16.0)
	for i in range(legs.size()):
		legs[i].rotation.x = sin(_clock * 1.8 + float(i) * PI) * minf(player.horizontal_speed() / 25.0, 0.28) if player.is_on_floor() else 0.15
