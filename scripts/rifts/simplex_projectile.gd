class_name SimplexProjectile
extends RiftProjectile

var pinned: bool = false
var fuse: float = 0.65
var exploded: bool = false
var host: WeakRef
var host_offset := Vector3.ZERO
var core: MeshInstance3D
var blast_radius: float = 4.5
var blast_damage: float = 105.0


func _ready() -> void:
	super._ready()
	actor_struck.connect(_pin_to_actor)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [Vector3(-0.7, -0.55, 0), Vector3(0.7, -0.55, 0), Vector3(0, 0.8, 0), Vector3(0, 0, -0.95)]
	for index in [0, 1, 2, 0, 3, 1, 1, 3, 2, 2, 3, 0]:
		tool.add_vertex(vertices[index])
	tool.generate_normals()
	core = MeshInstance3D.new()
	core.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("07141c")
	material.metallic = 0.7
	material.roughness = 0.25
	core.material_override = material
	add_child(core)


func configure(gesture: Dictionary, pose: Transform3D, eye: Vector3, inherited: Vector3 = Vector3.ZERO) -> void:
	super.configure(gesture, pose, eye, inherited)
	damage *= 0.30
	renderer.cavity_depth = 0.4
	var points := GestureRecognizer.simplify(gesture["points"], 0.10)
	if points.size() >= 3:
		var a := Vector3(points[0].x, points[0].y, 0)
		var b := Vector3(points[1].x, points[1].y, 0)
		var c := Vector3(points[2].x, points[2].y, 0)
		var area := (b - a).cross(c - a).length() * 0.5
		var apex := (a + b + c) / 3 + Vector3.FORWARD * clampf(sqrt(area), 0.5, 1.5)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex in [a, b, c, a, apex, b, b, apex, c, c, apex, a]:
			tool.add_vertex(vertex)
		tool.generate_normals()
		core.mesh = tool.commit()
		blast_radius = clampf(3.0 + area * 0.8, 3.2, 5.5)


func _physics_process(delta: float) -> void:
	if pinned:
		fuse -= delta
		var actor: Node3D = host.get_ref() if host != null else null
		if is_instance_valid(actor):
			global_position = actor.global_position + host_offset
		rotate_z(delta * 1.1)
		renderer.set_opening(1.0 + sin(fuse * 35.0) * 0.18, 1.6)
		if fuse <= 0:
			detonate()
		return
	super._physics_process(delta)
	if phase == Phase.COLLAPSE:
		pinned = true


func _pin_to_actor(actor: Node3D, _killed: bool) -> void:
	if pinned:
		return
	pinned = true
	host = weakref(actor)
	global_position = CombatRules.aim_point(actor) + global_basis.z * 0.5
	host_offset = global_position - actor.global_position


func detonate() -> void:
	if exploded:
		return
	exploded = true
	SpatialEffects.burst(get_tree().current_scene, global_position, blast_radius, blast_damage, get_source(), family_id, &"SIMPLEX")
	queue_free()
