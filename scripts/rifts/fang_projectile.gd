class_name FangProjectile
extends RiftProjectile

var burst: bool = false
var spread_angle: float = 0.30


func configure(gesture: Dictionary, pose: Transform3D, eye: Vector3, inherited: Vector3 = Vector3.ZERO) -> void:
	super.configure(gesture, pose, eye, inherited)
	var shape: PackedVector2Array = gesture["points"]
	var width := 0.0
	for p in shape:
		width = maxf(width, absf(p.x - shape[0].x))
	spread_angle = clampf(width * 0.22, 0.14, 0.65)
	renderer.half_aperture = 0.16
	renderer.cavity_depth = 0.40
	damage *= 0.75


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if phase == Phase.PROPAGATION and _phase_age > 0.18 and not burst:
		burst = true
		var world := get_tree().current_scene as Node3D
		for i in range(5):
			if get_parent().get_child_count() >= 48:
				break
			var shard := RiftProjectile.new()
			var visual := RiftRenderer.new()
			visual.name = "RiftRenderer"
			visual.half_aperture = 0.055
			visual.cavity_depth = 0.15
			shard.add_child(visual)
			get_parent().add_child(shard)
			var angle := lerpf(-spread_angle, spread_angle, float(i) / 4)
			var pose := global_transform
			pose.basis = pose.basis.rotated(global_basis.y, angle)
			var shape := PackedVector2Array([Vector2(-0.15, -0.10), Vector2(0, 0.22), Vector2(0.15, -0.10), Vector2(-0.15, -0.10)])
			shard.fracture_duration = 0.015
			shard.flight_lifetime = 0.48
			shard.speed = speed * 1.2
			shard.configure({"points": shape, "damage": damage * 0.42, "source": get_source(), "family_id": family_id, "ability": &"FANG_SHARD", "color": renderer.tint}, pose, pose.origin)
			RiftCaster.wire(shard, world, get_source())
