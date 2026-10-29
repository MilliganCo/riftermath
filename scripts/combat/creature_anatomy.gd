class_name CreatureAnatomy
extends RefCounted

static var _cache: Dictionary = {}


static func parts(variant: int = 0) -> Array[Dictionary]:
	if _cache.has(variant):
		return _cache[variant]
	var result: Array[Dictionary] = []
	var bend := -0.22 if variant % 2 else 0.18
	# Overlapping convex anatomical sections form a connected living silhouette,
	# while retaining closed, cuttable pieces for death and subsequent air cuts.
	_bone(result, Vector3(0, 2.0, 0), Vector3(bend, 3.65, -0.12), 0.54, 0.38, 1.30, "thorax")
	_bone(result, Vector3(0, 1.72, 0.10), Vector3(0, 2.28, 0), 0.43, 0.33, 0.70, "pelvis")
	_bone(result, Vector3(bend, 3.48, -0.12), Vector3(bend * 2.2, 4.35, -0.24), 0.15, 0.18, 0.65, "neck")
	_bone(result, Vector3(bend * 2.2, 4.20, -0.24), Vector3(bend * 1.2, 5.05, -0.01), 0.36, 0.30, 0.55, "skull")
	_bone(result, Vector3(bend * 1.6, 4.5, 0.04), Vector3(bend * 0.9, 4.18, 0.15), 0.16, 0.20, 0.22, "jaw")
	for side in [-1.0, 1.0]:
		_bone(result, Vector3(bend * 1.6 + side * 0.06, 4.62, 0.025), Vector3(bend * 1.5 + side * 0.07, 4.82, 0.005), 0.035, 0.04, 0.5, "eye")
	for side in [-1.0, 1.0]:
		var hip := Vector3(side * 0.16, 1.90, 0.08)
		var knee := Vector3(side * 0.30, 1.05, -0.25)
		var ankle := Vector3(side * 0.21, 0.18, 0.08)
		_bone(result, hip, knee, 0.20, 0.23, 0.62, "thigh")
		_bone(result, knee, ankle, 0.14, 0.18, 0.50, "shin")
		_bone(result, ankle, Vector3(side * 0.25, 0.10, 0.48), 0.18, 0.17, 0.30, "foot")
		var shoulder := Vector3(bend + side * 0.43, 3.50 - side * 0.12, -0.10)
		var elbow := Vector3(side * 0.73, 2.52 + side * 0.16, 0.03)
		var wrist := Vector3(side * 0.57, 1.50 + side * 0.14, 0.28)
		_bone(result, Vector3(bend, 3.47, -0.10), shoulder, 0.20, 0.20, 0.75, "clavicle")
		_bone(result, shoulder, elbow, 0.17, 0.21, 0.67, "upper_arm")
		_bone(result, elbow, wrist, 0.12, 0.16, 0.55, "forearm")
		for finger in range(3):
			var tip := wrist + Vector3(side * (0.02 + finger * 0.07), -0.38 - finger * 0.07, 0.16 + finger * 0.015)
			_bone(result, wrist, tip, 0.045, 0.055, 0.12, "claw")
		for rib in range(3):
			var y := 2.64 + rib * 0.25
			_bone(result, Vector3(bend * 0.5, y, 0.06), Vector3(side * 0.30 + bend * 0.6, y + 0.14, -0.05), 0.055, 0.075, 0.65, "rib")
		if variant >= 3:
			var crest_height := 5.55 if variant == 4 else 5.18
			_bone(result, Vector3(bend * 1.6 + side * 0.12, 4.65, -0.08), Vector3(side * (0.42 if variant == 3 else 0.29), crest_height, -0.22), 0.10, 0.13, 0.22, "crest")
		if variant == 4:
			_bone(result, Vector3(side * 0.28, 3.25, -0.12), Vector3(side * 0.83, 2.3, -0.28), 0.10, 0.13, 0.55, "upper_arm")
			_bone(result, Vector3(side * 0.83, 2.3, -0.28), Vector3(side * 0.46, 1.18, -0.12), 0.08, 0.11, 0.35, "forearm")
		if variant == 5:
			_bone(result, Vector3(side * 0.18, 3.30, 0.12), Vector3(side * 0.35, 2.70, 0.28), 0.12, 0.17, 0.3, "bell")
	_cache[variant] = result
	return result


static func _bone(result: Array[Dictionary], from: Vector3, to: Vector3, width: float, depth: float, taper: float, tag: String) -> void:
	var axis := (to - from).normalized()
	var x_axis := Vector3.FORWARD.cross(axis).normalized()
	if x_axis.length_squared() < 0.1:
		x_axis = Vector3.RIGHT.cross(axis).normalized()
	var z_axis := x_axis.cross(axis).normalized()
	var source := ConvexFracture.tapered_part(Vector3(width, from.distance_to(to), depth), taper)
	var tool := SurfaceTool.new()
	tool.append_from(source, 0, Transform3D(Basis(x_axis, axis, z_axis), Vector3.ZERO))
	var mesh := tool.commit()
	result.append({"at": (from + to) * 0.5, "from": from, "to": to, "mesh": mesh, "shape": mesh.create_convex_shape(), "tag": tag})
