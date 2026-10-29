extends "res://tests/integration.gd"


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	await frames(20)
	await longer_and_shape_checks()
	await air_cut_checks()
	await encounter_checks()
	check(completed_suites == 3, "All expansion suites completed")
	await frames(900)
	check(get_nodes_in_group("combat_debris").is_empty(), "Recursively cut debris expires without leaving bodies")
	check(get_nodes_in_group("enemy_bolts").is_empty(), "Hostile projectiles expire or are cleared on respawn")
	player.set_mouse_captured(false)
	print("RIFTERMATH_EXPANSION_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func longer_and_shape_checks() -> void:
	check(GestureRecognizer.MAX_SCAR_LENGTH == 9.0 and capture.plane_extents.x > 2.5, "Drawing budget and plane extent are increased")
	capture.begin()
	capture.feed_relative(Vector2(10000, 0))
	capture.feed_relative(Vector2(-10000, 0))
	capture.feed_relative(Vector2(0, -10000))
	var length := GestureRecognizer.path_length(capture.points)
	check(length > 8.9 and length <= 9.001, "Actual relative-motion path reaches nine metres and stays bounded")
	var recognized := GestureRecognizer.recognize(capture.points, 0.5)
	check(absf(recognized["length"] - length) < 0.001, "Long incision is not shortened on release")
	capture.cancel()
	check(player.standing_height > 2.3 and (player.body_shape.shape as CapsuleShape3D).radius < 0.3, "Player capsule is taller and narrower")
	check(player.camera.global_position.y > 2.0 and player.has_node("BodyVisual"), "Player has raised eye height and a visible elongated body")
	var target := game.get_node("Targets").get_child(0) as EnemyController
	var torso := target.visual.get_child(0) as MeshInstance3D
	var bounds := torso.mesh.get_aabb().size
	check(bounds.y > bounds.x * 1.8 and torso.mesh is ArrayMesh, "Enemy torso is a long tapered polygonal mesh")
	check((target.collision.shape as CapsuleShape3D).height > 3.6, "Enemy collision fits the elongated silhouette")
	var floor_mesh := game.get_node("Arena/Foundation") as MeshInstance3D
	check(floor_mesh.mesh.size.x * floor_mesh.mesh.size.z > 52 * 64 * 3, "Arena surface is more than three times larger")
	check(get_nodes_in_group("combat_zones").size() == 2, "Both live-fire courts exist")
	completed_suites += 1


func air_cut_checks() -> void:
	shoot(PackedVector2Array([Vector2(-1, 0), Vector2(1, 0)]), Vector3(0, 2.05, -9), 120)
	await frames(5)
	var piece := largest_piece(0)
	check(is_instance_valid(piece) and piece.linear_velocity.y > 2.0 and piece.global_position.y > 1, "Enemy death produces airborne cuttable convex pieces")
	if not is_instance_valid(piece):
		return
	check(not piece.receive_scar(100, Vector3.FORWARD, Vector3.UP, piece.global_position, piece.immune_scar_id), "A fragment ignores the same SCAR that created it")
	var target_position := piece.global_position
	var projectile := shoot(PackedVector2Array([Vector2(-1.2, 0), Vector2(1.2, 0)]), target_position + Vector3.BACK * 2, 80)
	projectile.speed = 3600
	await frames(4)
	var child := largest_piece(1)
	check(is_instance_valid(child), "A second swept SCAR actually slices a moving airborne fragment")
	check(game.hud.air_cuts > 0, "Air cuts have their own HUD feedback")
	if not is_instance_valid(child):
		return
	var second := shoot(PackedVector2Array([Vector2(0, -1.2), Vector2(0, 1.2)]), child.global_position + Vector3.BACK * 2, 80)
	second.speed = 3600
	await frames(4)
	check(is_instance_valid(largest_piece(2)), "A fragment descendant can be cut again with a different orientation")
	var mesh := ConvexFracture.tapered_part(Vector3(0.8, 1.6, 0.6))
	var material := StandardMaterial3D.new()
	var probe := SeverableDebris.spawn(game.get_node("Debris"), mesh, mesh.create_convex_shape(), material, Transform3D(Basis.IDENTITY, Vector3(0, 8, 20)), Vector3.ZERO, Vector3.ZERO, 3)
	check(not probe.receive_scar(100, Vector3.FORWARD, Vector3.UP), "Maximum cut generation prevents infinite subdivision")
	var missed := ConvexFracture.split_mesh(mesh, Vector3.UP, 50)
	check(missed.is_empty(), "A plane outside a fragment does not fabricate a cut")
	var thin := ConvexFracture.tapered_part(Vector3(0.8, 0.2, 0.5), 1.0)
	var curved_target := SeverableDebris.spawn(game.get_node("Debris"), thin, thin.create_convex_shape(), material, Transform3D(Basis.IDENTITY, Vector3(0, 6, 20)), Vector3.ZERO, Vector3.ZERO)
	var curve := PackedVector2Array([Vector2(-1, 0.23), Vector2(1, 0.23), Vector2(1, 0), Vector2(-1, 0)])
	shoot(curve, Vector3(0, 6, 22), 80).speed = 3600
	await frames(4)
	check(not is_instance_valid(curved_target), "A grazing segment does not prevent a later segment from cutting the same fragment")
	var count := get_nodes_in_group("combat_debris").size()
	for i in range(SeverableDebris.MAX_PIECES - count):
		SeverableDebris.spawn(game.get_node("Debris"), mesh, mesh.create_convex_shape(), material, Transform3D(Basis.IDENTITY, Vector3(0, 9, 30)), Vector3.ZERO, Vector3.ZERO)
	var overflow := SeverableDebris.spawn(game.get_node("Debris"), mesh, mesh.create_convex_shape(), material, Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO)
	check(overflow == null and get_nodes_in_group("combat_debris").size() == SeverableDebris.MAX_PIECES, "Global physical-fragment budget is enforced")
	for body in get_nodes_in_group("combat_debris"):
		body.queue_free()
	await frames(3)
	completed_suites += 1


func encounter_checks() -> void:
	player.respawn()
	await frames(150)
	var west := game.get_node("CombatZones").get_child(0) as CombatZone
	var east := game.get_node("CombatZones").get_child(1) as CombatZone
	check(not west.active and not east.active and total_shots() == 0, "Central range stays safe and enemies do not fire before entry")
	player.global_position = east.global_position + Vector3.UP * 0.05
	await frames(5)
	check(east.active and not west.active and east.enemies[0].attack_enabled, "Entering an Area3D enables only its linked enemies")
	check(game.hud.active_zone == "EAST", "HUD identifies the active live-fire court")
	await frames(45)
	check(total_shots() == 0, "Enemies give a readable warning before their first shot")
	await frames(180)
	check(total_shots() >= 2, "Zone enemies fire actual projectiles at the player")
	check(player.hp < player.max_hp and player.hp > 0, "Hostile projectiles can reduce player health")
	player.global_position = Vector3(0, 0.05, 24)
	player.velocity = Vector3.ZERO
	await frames(5)
	var shots := total_shots()
	check(not east.active and not east.enemies[0].attack_enabled, "Leaving the zone disables its shooters")
	await frames(190)
	check(total_shots() == shots, "Inactive zone does not continue spawning shots")
	player.global_position = west.global_position + Vector3.UP * 0.05
	await frames(5)
	check(west.active and not east.active, "The other court activates independently")
	player.invulnerability = 0
	var deaths_before := player.deaths
	player.receive_damage(1000)
	await frames(5)
	check(player.deaths == deaths_before + 1 and player.hp == player.max_hp, "Lethal damage rebuilds the player with full health")
	check(not west.active and not east.active and get_nodes_in_group("enemy_bolts").is_empty(), "Death resets encounters and clears hostile shots")
	check(player.global_position.distance_to(player.spawn_transform.origin) < 0.3 and not capture.active, "Combat respawn returns to the safe start and cancels drawing")
	await frames(140)
	var enemy := game.get_node("Targets").get_child(0) as EnemyController
	enemy.player = player
	var wall := make_wall(Vector3(0, 3, 0))
	await frames(3)
	enemy.set_attack_enabled(true)
	enemy._fire_clock = 0.0
	var before := enemy.shots_fired
	await frames(3)
	check(enemy.shots_fired == before, "Shooter line of sight is blocked by solid cover")
	wall.queue_free()
	await frames(3)
	enemy._fire_clock = 0.0
	await frames(3)
	check(enemy.shots_fired == before + 1, "Shooter fires when cover no longer blocks the player")
	enemy.set_attack_enabled(false)
	for bolt in game.get_node("HostileProjectiles").get_children():
		bolt.queue_free()
	player.invulnerability = 0
	player.hp = player.max_hp
	var bolt := EnemyBolt.new()
	game.get_node("HostileProjectiles").add_child(bolt)
	bolt.configure(player.global_position + Vector3(0, 1.25, -8), player.global_position + Vector3.UP * 1.25, 3600)
	await frames(3)
	check(player.hp == player.max_hp - 14, "Hostile ShapeCast hits without tunnelling at 3600 m/s")
	player.invulnerability = 0
	var hp := player.hp
	wall = make_wall(player.global_position + Vector3(0, 3, -4))
	await frames(3)
	bolt = EnemyBolt.new()
	game.get_node("HostileProjectiles").add_child(bolt)
	bolt.configure(player.global_position + Vector3(0, 1.25, -8), player.global_position + Vector3.UP * 1.25, 3600)
	await frames(3)
	check(player.hp == hp, "Hostile projectile cannot damage the player through a wall")
	wall.queue_free()
	completed_suites += 1


func largest_piece(level: int) -> SeverableDebris:
	var chosen: SeverableDebris
	var volume := 0.0
	for body in get_nodes_in_group("combat_debris"):
		var piece := body as SeverableDebris
		if piece.spent or piece.generation != level:
			continue
		var bounds := piece.geometry.get_aabb().size
		var value := bounds.x * bounds.y * bounds.z
		if value > volume:
			chosen = piece
			volume = value
	return chosen


func total_shots() -> int:
	var count := 0
	for enemy: EnemyController in get_nodes_in_group("targets"):
		count += enemy.shots_fired
	return count


func make_wall(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(14, 7, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = at
	return wall
