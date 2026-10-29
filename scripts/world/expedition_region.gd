class_name ExpeditionRegion
extends BattleArena

@export var seed_value: int = 117
var districts: Array[Dictionary] = []
var sites: Array[Dictionary] = []
var fingerprint: String = ""


func _ready() -> void:
	var profile: Variant = get_parent().get("profile")
	if profile is ExpeditionState:
		seed_value = profile.seed_value
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	_box("AshenMarches", Vector3(0, -0.7, 0), Vector3(192, 1.4, 192), concrete)
	for coordinate in [-90.0, -30.0, 30.0, 90.0]:
		_box("ProcessionalRoad", Vector3(coordinate, 0.012, 0), Vector3(8, 0.02, 190), dark, false)
		_box("ProcessionalRoad", Vector3(0, 0.014, coordinate), Vector3(190, 0.02, 8), dark, false)
	for side in [-1.0, 1.0]:
		_box("CliffBoundary", Vector3(side * 96, 4, 0), Vector3(2, 8, 194), dark)
		_box("CliffBoundary", Vector3(0, 4, side * 96), Vector3(194, 8, 2), dark)
	_refuge()
	var cells := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
	# Local seeded shuffle: ambient sound or combat RNG cannot change the map.
	for i in range(cells.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var swap: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	var names := ["ОССУАРИЙ", "МЁРТВЫЙ КВАРТАЛ", "ПЕПЕЛЬНЫЙ РАЗЛОМ", "КОЛОКОЛЬНЫЕ КРЫШИ", "ТИХИЙ САД", "СТАРЫЙ ТРАКТ", "БЕЗМОЛВНЫЙ КЛУАТР", "ПОКИНУТЫЙ РЫНОК"]
	for i in range(cells.size()):
		var cell: Vector2i = cells[i]
		var at := Vector3(cell.x * 60, 0, cell.y * 60)
		var district := {"index": i, "name": names[i], "center": at, "hostile": i < 4, "cell": cell}
		districts.append(district)
		match i:
			0: GothicArchitecture.crypt(self, at); _crypt_chapel(at)
			1: _borough(at, random)
			2: _ashen_rift(at, random)
			3: _borough(at, random)
			4: _garden(at)
			5: _causeway(at)
			6: GothicArchitecture.facade(self, at + Vector3(0, 0, -15), 3); _garden(at)
			7: _market(at)
		_sign(names[i], at + Vector3(0, 0.035, 23), 0.016, Color("b4a080"), true)
		fingerprint += "%d:%d,%d;" % [i, cell.x, cell.y]
		if i < 3:
			var position := at + Vector3(0, 0, -4)
			if i == 1: position.y = 9
			if i == 2: position.y = 3.5
			sites.append({"index": i, "name": names[i], "at": position, "required": [&"HOLLOW", &"SIMPLEX", &"CHAINBREAK"][i], "center": at})
	for side in [-1.0, 1.0]:
		for z in range(-84, 85, 24):
			WorldTheme._pillar(self, Vector3(side * 94, 0, z), Vector3(side * 94, 17, z), dark)


func _base_height(_at: Vector2) -> float:
	return 0.0


func _refuge() -> void:
	districts.append({"index": -1, "name": "УБЕЖИЩЕ ДЕВЯТОГО КОЛОКОЛА", "center": Vector3.ZERO, "hostile": false, "cell": Vector2i.ZERO})
	raised_deck("RefugeBellTerrace", Vector3(0, 6, -16), Vector2(24, 14))
	raised_ramp("RefugeStair", Vector3(-8, 0, -9), 6, 18, 6)
	GothicArchitecture.facade(self, Vector3(0, 6, -22), 3)
	GothicArchitecture.bell(self, Vector3(0, 11, -22))
	get_parent().set_meta("bell_position", Vector3(0, 11, -22))
	var lift := RiftLift.new()
	lift.carry = Vector3(-7, 0, -15)
	add_child(lift)
	lift.position = Vector3(14, 0.03, 14)
	_sign("NINTH BELL / REFUGE", Vector3(0, 0.035, 18), 0.017, Color("d6c6a4"), true)
	for side in [-1.0, 1.0]:
		WorldTheme._pillar(self, Vector3(side * 20, 0, -22), Vector3(side * 20, 12, -22), dark)
		WorldTheme._pillar(self, Vector3(side * 20, 12, -22), Vector3(0, 17, -22), pale)


func _borough(at: Vector3, random: RandomNumberGenerator) -> void:
	raised_deck("TenementRoof", at + Vector3(0, 9, 0), Vector2(20, 20))
	raised_ramp("RuinStair", at + Vector3(-5, 0, 10), 6, 18, 9)
	raised_deck("WatchtowerRoof", at + Vector3(12, 14, -8), Vector2(8, 10))
	raised_ramp("WatchtowerStair", at + Vector3(10, 9, -3), 5, 10, 5)
	GothicArchitecture.facade(self, at + Vector3(0, 0, -10), 3)
	for side in [-1.0, 1.0]:
		for z in [-6.0, 1.0, 8.0]:
			_cover(Vector2(at.x + side * 9.5, at.z + z), Vector2(0.7, 3.7), 7.2)
		for z in [-6.0, 6.0]:
			_cover(Vector2(at.x + side * 9, at.z + z), Vector2(0.8, 0.8), 8.3)
		for j in range(3):
			var x: float = side * random.randf_range(15, 23)
			var z := random.randf_range(-19, 14)
			_cover(Vector2(at.x + x, at.z + z), Vector2(1.5, 3.2), random.randf_range(2.5, 6.0))
	var lift := RiftLift.new()
	lift.carry = Vector3(-4, 0, -9)
	lift.impulse = 25
	add_child(lift)
	lift.position = at + Vector3(6, 0.02, 18)


func _crypt_chapel(at: Vector3) -> void:
	raised_deck("CryptVault", at + Vector3(12, 6, -12), Vector2(12, 16))
	raised_ramp("CryptRuinRamp", at + Vector3(12, 0, -4), 6, 18, 6)
	GothicArchitecture.facade(self, at + Vector3(12, 0, -20), 2)


func _ashen_rift(at: Vector3, random: RandomNumberGenerator) -> void:
	raised_deck("FracturedAltar", at + Vector3(0, 3.5, -4), Vector2(12, 12))
	raised_ramp("AshenRamp", at + Vector3(0, 0, 2), 6, 12, 3.5)
	for i in range(9):
		var angle := float(i) / 9 * TAU
		var x := cos(angle) * random.randf_range(17, 23)
		var z := sin(angle) * random.randf_range(17, 23)
		var height := random.randf_range(8, 18)
		_cover(Vector2(at.x + x, at.z + z), Vector2(0.9, 1.6), height)
		WorldTheme._pillar(self, at + Vector3(x, height, z), at + Vector3(x + 2, height + 3, z - 1), dark)


func _garden(at: Vector3) -> void:
	for side in [-1.0, 1.0]:
		for z in [-9.0, 9.0]:
			WorldTheme._pillar(self, at + Vector3(side * 8, 0, z), at + Vector3(side * 9, 6, z), pale)
			WorldTheme._pillar(self, at + Vector3(side * 9, 6, z), at + Vector3(side * 4, 9, z - 2), dark)
	_box("DryBasin", at + Vector3(0, 0.06, 0), Vector3(10, 0.10, 12), dark, false)


func _causeway(at: Vector3) -> void:
	raised_deck("PilgrimCauseway", at + Vector3(0, 5, 0), Vector2(8, 26))
	raised_ramp("CausewaySouth", at + Vector3(0, 0, 13), 6, 15, 5)
	raised_ramp("CausewayNorth", at + Vector3(0, 0, -13), 6, 15, 5, PI)
	GothicArchitecture.bell(self, at + Vector3(0, 7, 0))


func _market(at: Vector3) -> void:
	for side in [-1.0, 1.0]:
		for z in [-10.0, 0.0, 10.0]:
			_box("AbandonedStall", at + Vector3(side * 10, 2.8, z), Vector3(5, 0.22, 5), concrete, false)
			for edge in [-1.0, 1.0]:
				WorldTheme._pillar(self, at + Vector3(side * 10 + edge * 2, 0, z), at + Vector3(side * 10 + edge * 2, 2.8, z), dark)


func district_at(point: Vector3) -> Dictionary:
	var cell := Vector2i(clampi(roundi(point.x / 60), -1, 1), clampi(roundi(point.z / 60), -1, 1))
	for district in districts:
		if district["cell"] == cell: return district
	return districts[0]
