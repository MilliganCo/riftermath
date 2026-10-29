class_name RiftProjectile
extends Node3D

signal target_hit(damage: float, killed: bool)
signal fragment_cut
signal phase_changed(phase: StringName)
signal actor_struck(actor: Node3D, killed: bool)

enum Phase { FRACTURE, PROPAGATION, COLLAPSE }

@export var speed: float = 48.0
@export var fracture_duration: float = 0.115
@export var flight_lifetime: float = 0.85
@export var collapse_duration: float = 0.14
@export var collision_half_width: float = 0.16
@export var collision_depth: float = 0.30
@export var max_collision_segments: int = 20

@onready var renderer: RiftRenderer = $RiftRenderer

var phase: Phase = Phase.FRACTURE
var damage: float = 60.0
var _age: float = 0.0
var _phase_age: float = 0.0
var _points := PackedVector2Array()
var _hit_ids: Dictionary = {}
var _initialized: bool = false
var _muzzle_checked: bool = false
var _camera_origin := Vector3.ZERO
var _trail_clock: float = 0.0
var _echoes: int = 0
var _carry_velocity := Vector3.ZERO
var source_ref: WeakRef
var family_id: int = 0
var ability: StringName = &"SCAR"
var reflected: bool = false
var previous_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("rift_projectiles")


func configure(gesture: Dictionary, pose: Transform3D, camera_origin: Vector3, inherited_velocity: Vector3 = Vector3.ZERO) -> void:
	global_transform = pose
	previous_position = global_position
	damage = gesture["damage"]
	if is_instance_valid(gesture.get("source")):
		source_ref = weakref(gesture["source"])
	family_id = gesture.get("family_id", get_instance_id())
	ability = gesture.get("ability", &"SCAR")
	var raw: PackedVector2Array = gesture["points"]
	_points = GestureRecognizer.sample_path(raw, mini(max_collision_segments + 1, maxi(2, raw.size())))
	renderer.set_path(raw)
	_camera_origin = camera_origin
	_carry_velocity = inherited_velocity
	_initialized = true
	phase_changed.emit(&"FRACTURE")
	if gesture.has("color"):
		renderer.set_tint(gesture["color"])


func _physics_process(delta: float) -> void:
	if not _initialized:
		return
	previous_position = global_position
	_age += delta
	_phase_age += delta
	if not _muzzle_checked:
		_muzzle_checked = true
		# Sweep the camera-to-plane gap too, preventing release through a nearby wall.
		var start := global_transform
		start.origin = _camera_origin
		var motion := global_position - _camera_origin
		var fraction := _sweep(start, motion)
		if fraction < 1.0:
			global_position = _camera_origin + motion * fraction
			_begin_collapse()
	match phase:
		Phase.FRACTURE:
			# Preserve the release momentum so a dashing player cannot overtake the
			# two-metre incision during its brief opening and fill the whole camera.
			var carry_motion := _carry_velocity * delta
			if carry_motion.length_squared() > 0.000001:
				var fraction := _sweep(global_transform, carry_motion)
				global_position += carry_motion * fraction
				if fraction < 1.0:
					_begin_collapse()
					return
			var t := clampf(_phase_age / fracture_duration, 0.0, 1.0)
			renderer.set_opening(lerpf(0.45, 1.8, sin(t * PI * 0.65)), 1.5)
			if _phase_age >= fracture_duration:
				phase = Phase.PROPAGATION
				_phase_age = 0.0
				phase_changed.emit(&"PROPAGATION")
		Phase.PROPAGATION:
			var motion := -global_basis.z * speed * delta
			for field in get_tree().get_nodes_in_group("spatial_fields"):
				if field is HypercutField:
					motion = field.transport_step(self, motion)
			var fraction := _sweep(global_transform, motion)
			global_position += motion * fraction
			renderer.set_opening(lerpf(1.25, 0.60, _phase_age / flight_lifetime), 1.0)
			_trail_clock += delta
			if _trail_clock >= 0.055 and _echoes < 3:
				_trail_clock = 0.0
				_echoes += 1
				renderer.echo(get_parent())
			if fraction < 1.0 or _phase_age >= flight_lifetime:
				_begin_collapse()
		Phase.COLLAPSE:
			renderer.set_opening(1.0 - clampf(_phase_age / collapse_duration, 0.0, 1.0), 0.65)
			if _phase_age >= collapse_duration:
				queue_free()


func _begin_collapse() -> void:
	phase = Phase.COLLAPSE
	_phase_age = 0.0
	phase_changed.emit(&"COLLAPSE")
	var source := get_source()
	if ability == &"SCAR" and source is PlayerController and not source.is_on_floor() and global_position.distance_to(source.global_position) < 4.0:
		var previous: int = source.get_meta("last_rift_surf", -1000)
		if Time.get_ticks_msec() - previous > 350:
			source.set_meta("last_rift_surf", Time.get_ticks_msec())
			source.velocity += Vector3.UP * 4.5 + (-source.global_basis.z) * 3.5
			var world := get_tree().current_scene
			if world.has_node("HUD/Display"):
				world.get_node("HUD/Display")._award(35, "RIFT SURF")


func _sweep(pose: Transform3D, motion: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var wall_fraction := 1.0
	var segments: Array[Transform3D] = []
	var lengths: Array[float] = []
	# Every path segment is an oriented prism, not a center ray or spherical hitbox.
	for i in range(1, _points.size()):
		var a := _points[i - 1]
		var b := _points[i]
		var tangent := (b - a).normalized()
		if tangent.length_squared() < 0.01:
			continue
		var x_axis := Vector3(tangent.x, tangent.y, 0)
		var y_axis := Vector3(-tangent.y, tangent.x, 0)
		var midpoint := (a + b) * 0.5
		var local_pose := Transform3D(Basis(x_axis, y_axis, Vector3.BACK), Vector3(midpoint.x, midpoint.y, 0))
		var segment_pose := pose * local_pose
		var length := a.distance_to(b) + 0.035
		segments.append(segment_pose)
		lengths.append(length)
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, collision_half_width * 2.0, collision_depth)
		query.shape = shape
		query.transform = segment_pose
		query.collision_mask = 1
		query.margin = 0.002
		if not space.intersect_shape(query, 1).is_empty():
			wall_fraction = 0.0
		else:
			query.motion = motion
			var fractions := space.cast_motion(query)
			if fractions.size() == 2:
				wall_fraction = minf(wall_fraction, fractions[0])
	# A convex hull of start/end prisms is the exact swept volume for translation.
	# Also works for the short oblique camera-to-plane sweep on the first frame.
	for i in range(segments.size()):
		var segment_pose := segments[i]
		var half := Vector3(lengths[i] / 2.0, collision_half_width, collision_depth / 2.0)
		var local_motion := segment_pose.basis.inverse() * motion * wall_fraction
		var corners := PackedVector3Array()
		for x in [-1.0, 1.0]:
			for y in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					var corner := half * Vector3(x, y, z)
					corners.append(corner)
					corners.append(corner + local_motion)
		var hull := ConvexPolygonShape3D.new()
		hull.points = corners
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = hull
		query.transform = segment_pose
		query.collision_mask = 14
		query.margin = 0.003
		for result in space.intersect_shape(query, 32):
			var collider: Node3D = result["collider"]
			var id: int = result["collider_id"]
			if _hit_ids.has(id) or not collider.has_method("receive_scar"):
				continue
			if not CombatRules.can_hit(get_source(), collider):
				continue
			var cut_normal := segment_pose.basis.y
			var hit_ability := &"HYPERCUT" if get_meta("phase_pierce", false) else ability
			var severed := CombatRules.hit(collider, damage, -pose.basis.z, cut_normal, segment_pose.origin, family_id, get_source(), hit_ability, reflected)
			if collider is SeverableDebris:
				if severed:
					_hit_ids[id] = true
					fragment_cut.emit()
			else:
				_hit_ids[id] = true
				var applied := float(collider.get_meta("last_rift_damage", damage))
				if applied > 0: target_hit.emit(applied, severed)
				actor_struck.emit(collider, severed)
	return wall_fraction


func get_source() -> Node:
	return source_ref.get_ref() if source_ref != null else null


func reflect_by(actor: Node3D) -> void:
	var previous := get_source() as Node3D
	var direction := (CombatRules.aim_point(previous) - global_position).normalized() if CombatRules.alive(previous) else -actor.global_basis.z
	source_ref = weakref(actor)
	look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT)
	speed *= 1.25
	damage *= 1.4
	reflected = true
	RiftCaster.wire(self, get_tree().current_scene, actor)
	_hit_ids.clear()
	renderer.set_tint(Color("b8ffff"))
