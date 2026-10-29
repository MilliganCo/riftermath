class_name BattleArena
extends "res://scripts/world/arena.gd"

var obstacles: Array[Rect2] = []
var obstacle_volumes: Array[Dictionary] = []
var decks: Array[Dictionary] = []
var ramps: Array[Dictionary] = []


func _ready() -> void:
	_box("Foundation", Vector3(0, -0.7, 0), Vector3(74, 1.4, 74), concrete)
	for side in [-1.0, 1.0]:
		_box("OuterWall", Vector3(side * 37, 5, 0), Vector3(1.3, 10, 74), dark)
		_box("OuterWall", Vector3(0, 5, side * 37), Vector3(74, 10, 1.3), dark)
	_box("Altar", Vector3(0, 1.5, 0), Vector3(14, 3, 14), pale)
	_ramp("SouthStair", Vector3(0, 0, 7), 8, 9, 3)
	_ramp("NorthStair", Vector3(0, 0, -7), 8, 9, 3, PI)
	for location in [Vector2(-13, -8), Vector2(13, 8), Vector2(-12, 15), Vector2(12, -15)]:
		_cover(location, Vector2(2, 10), 5.0)
	for location in [Vector2(-24, -22), Vector2(24, 22), Vector2(-25, 22), Vector2(25, -22)]:
		_cover(location, Vector2(3, 3), 7.0)
	_cover(Vector2.ZERO, Vector2(1.8, 1.8), 13.0, 3.0)
	for x in range(-32, 33, 8):
		_box("Seam", Vector3(x, 0.008, 0), Vector3(0.035, 0.01, 70), dark, false)
	for z in [-30.0, 30.0]:
		_sign("M O R T U A R Y   /   R I F T H O U S E", Vector3(0, 0.025, z), 0.011, Color("9ca69f"), true)
	_sign("T H E   S E V E R E D   C A T H E D R A L", Vector3(0, 7.5, -36.25), 0.035, Color("adb7b0"))
	_vertical_routes()
	GothicArchitecture.crypt(self, Vector3(-17, 0, -26))
	GothicArchitecture.facade(self, Vector3(0, 0, -35.5), 5)
	GothicArchitecture.bell(self, Vector3(16, 14.1, -28.5))
	WorldTheme.arches(self, 37, 37)


func _cover(at: Vector2, size: Vector2, height: float, floor_y: float = 0.0) -> void:
	var node := MeshInstance3D.new()
	node.mesh = ConvexFracture.tapered_part(Vector3(size.x, height, size.y), 0.72)
	node.material_override = dark
	node.position = Vector3(at.x, floor_y + height / 2, at.y)
	add_child(node)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = node.mesh.create_convex_shape()
	shape.position = node.position
	body.add_child(shape)
	add_child(body)
	obstacles.append(Rect2(at - size / 2, size))
	obstacle_volumes.append({"rect": Rect2(at - size / 2, size), "bottom": floor_y, "top": floor_y + height})


func floor_height(at: Vector2) -> float:
	var highest := 0.0
	for height in walkable_heights(at):
		highest = maxf(highest, height)
	return highest


func _base_height(at: Vector2) -> float:
	if absf(at.x) <= 7 and absf(at.y) <= 7:
		return 3.0
	if absf(at.x) <= 4 and absf(at.y) > 7 and absf(at.y) < 16:
		return (16 - absf(at.y)) / 9.0 * 3.0
	return 0.0


func _vertical_routes() -> void:
	for side in [-1.0, 1.0]:
		raised_deck("ChoirGallery", Vector3(side * 28, 7, 0), Vector2(8, 30))
		raised_ramp("GallerySouthRamp", Vector3(side * 28, 0, 15), 5, 18, 7)
		raised_ramp("GalleryNorthRamp", Vector3(side * 28, 0, -15), 5, 18, 7, PI)
		for z in [-10.0, 10.0]:
			_cover(Vector2(side * 31, z), Vector2(0.8, 0.8), 6.3)
		var lift := RiftLift.new()
		lift.carry = Vector3(side * 4.5, 0, -9)
		add_child(lift)
		lift.position = Vector3(side * 20, 0.02, 24)
		_sign("CHOIR GALLERY / 7m", Vector3(side * 28, 7.025, 10), 0.012, Color("d4c5a5"), true)
	raised_deck("ChoirCrossing", Vector3(0, 7, -10), Vector2(48, 4))
	raised_deck("BellTowerRoof", Vector3(16, 11, -25), Vector2(12, 10))
	raised_ramp("BellRoofStair", Vector3(16, 7, -20), 4, 8, 4)
	for x in [11.0, 21.0]:
		for z in [-29.0, -21.0]:
			_cover(Vector2(x, z), Vector2(0.65, 0.65), 10.3)
		WorldTheme._pillar(self, Vector3(x, 11, -28.6), Vector3(x, 16, -28.6), dark)
		WorldTheme._pillar(self, Vector3(x, 16, -28.6), Vector3(16, 19, -28.6), pale)
	_sign("THE BROKEN BELL / 11m", Vector3(16, 11.03, -25), 0.012, Color("d4c5a5"), true)


func raised_deck(label: String, top: Vector3, size: Vector2) -> void:
	_box(label, top - Vector3.UP * 0.35, Vector3(size.x, 0.7, size.y), pale)
	decks.append({"rect": Rect2(Vector2(top.x, top.z) - size / 2, size), "height": top.y})


func raised_ramp(label: String, high_end: Vector3, width: float, length: float, height: float, yaw: float = 0) -> void:
	_ramp(label, high_end, width, length, height, yaw)
	ramps.append({"at": high_end, "width": width, "length": length, "height": height, "yaw": yaw})


func _ramp_height(ramp: Dictionary, at: Vector2) -> float:
	var local: Vector3 = Basis(Vector3.UP, -float(ramp["yaw"])) * (Vector3(at.x, 0, at.y) - Vector3(ramp["at"].x, 0, ramp["at"].z))
	if absf(local.x) > ramp["width"] / 2 or local.z < 0 or local.z > ramp["length"]:
		return -INF
	return ramp["at"].y + (1.0 - local.z / float(ramp["length"])) * ramp["height"]


func walkable_heights(at: Vector2) -> PackedFloat32Array:
	var result := PackedFloat32Array([_base_height(at)])
	for ramp in ramps:
		var y := _ramp_height(ramp, at)
		if is_finite(y):
			if ramp["at"].y <= 0.01:
				result.clear()
			if not result.has(y): result.append(y)
	for deck in decks:
		if deck["rect"].has_point(at) and not result.has(deck["height"]):
			result.append(deck["height"])
	return result


func support_height(at: Vector3) -> float:
	var heights := walkable_heights(Vector2(at.x, at.z))
	var best: float = heights[0]
	for height in heights:
		if height <= at.y + 0.8 and (best > at.y + 0.8 or height > best):
			best = height
	return best


func navigation_blocked(at: Vector2, feet: float) -> bool:
	for obstacle in obstacle_volumes:
		if obstacle["rect"].grow(0.66).has_point(at) and feet < obstacle["top"] - 0.04 and feet + 6.2 > obstacle["bottom"]:
			return true
	for deck in decks:
		if deck["rect"].has_point(at) and feet < deck["height"] - 0.04 and feet >= deck["height"] - 0.71:
			return true
		if deck["rect"].has_point(at) and feet < deck["height"] - 0.71 and feet + 6.2 > deck["height"] - 0.71:
			return true
	for ramp in ramps:
		var top := _ramp_height(ramp, at)
		if is_finite(top) and feet >= ramp["at"].y - 0.06 and feet < top - 0.06:
			return true
		if is_finite(top) and feet < ramp["at"].y - 0.1 and feet + 6.2 > ramp["at"].y:
			return true
	return false


func walk_transition(from: Vector3, to: Vector3) -> bool:
	# Endpoint heights alone permit entering the vertical side of a ramp.
	var distance := Vector2(to.x - from.x, to.z - from.z).length()
	var steps := maxi(2, ceili(distance / 0.20))
	var previous := from.y - 0.05
	var limit := distance / steps * 0.8 + 0.04
	for i in range(1, steps + 1):
		var sample := from.lerp(to, float(i) / steps)
		var point := Vector2(sample.x, sample.z)
		var best := INF
		var difference := INF
		for height in walkable_heights(point):
			if navigation_blocked(point, height + 0.05): continue
			var change := absf(height - previous)
			if change < difference:
				best = height
				difference = change
		if not is_finite(best) or difference > limit: return false
		previous = best
	return absf(previous - (to.y - 0.05)) < 0.1
