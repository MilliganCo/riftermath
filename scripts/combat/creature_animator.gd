class_name CreatureAnimator
extends RefCounted

var hull: Node3D
var clock: float = 0.0
var locomotion: float = 0.0
var casting: float = 0.0
var pose_updates: int = 0


func step(delta: float) -> void:
	var actor := hull.get_parent() as CharacterBody3D
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length() if actor != null else 0.0
	locomotion = lerpf(locomotion, minf(1, speed / 5.0), 1.0 - exp(-delta * 9))
	clock += delta * (1.5 + speed * 0.80)
	var windup := minf(1, actor._windup / actor.windup_duration()) if actor is CombatBot else 0.0
	casting = maxf(windup, casting - delta * 3.8)
	for part: Dictionary in hull._parts:
		if not part.has("from"):
			continue
		var node := part["node"] as Node3D
		var from: Vector3 = part["from"]
		var to: Vector3 = part["to"]
		var a := pose_point(from, part["tag"], actor)
		var b := pose_point(to, part["tag"], actor)
		var original := to - from
		var posed := b - a
		if original.length_squared() < 0.00001 or posed.length_squared() < 0.00001:
			continue
		var stretch := Basis.from_scale(Vector3(1, posed.length() / original.length(), 1))
		node.basis = axes(posed.normalized()) * stretch * axes(original.normalized()).inverse()
		node.position = (a + b) * 0.5
	pose_updates += 1


func pose_point(rest: Vector3, tag: String, actor: CharacterBody3D) -> Vector3:
	var point := rest
	var side := -1.0 if rest.x < 0 else 1.0
	var phase := clock + (PI if side < 0 else 0.0)
	var stride := 0.68 * locomotion
	if actor is CombatBot and actor.kind == CombatBot.Kind.TANK:
		stride *= 0.62
	if tag in ["thigh", "shin", "foot"]:
		var weight := clampf(1.0 - rest.y / 2.0, 0, 1)
		point.z += sin(phase) * stride * weight
		point.y += maxf(0, cos(phase)) * locomotion * 0.32 * weight
	elif tag in ["upper_arm", "forearm", "claw"]:
		var weight := clampf((3.55 - rest.y) / 2.0, 0, 1.2)
		point.z -= sin(phase) * stride * 0.72 * weight
		point.y += casting * weight * 1.18
		point.z += casting * weight * 0.65
		point.x += side * sin(casting * PI) * weight * 0.12
	if rest.y > 1.8:
		point.y += sin(clock * 0.8) * 0.035 * rest.y / 5
		point.z += casting * maxf(0, rest.y - 2) * 0.10
		point.x += hull._impact.x * (rest.y - 1.8) * 0.18
	if tag == "jaw":
		point.y -= casting * maxf(0, 4.65 - rest.y) * 0.35
	if tag == "bell":
		point.z += sin(clock * 1.5) * 0.08 + casting * 0.22
	return point


static func axes(axis: Vector3) -> Basis:
	var x := Vector3.FORWARD.cross(axis).normalized()
	if x.length_squared() < 0.01:
		x = Vector3.RIGHT.cross(axis).normalized()
	return Basis(x, axis, x.cross(axis).normalized())
