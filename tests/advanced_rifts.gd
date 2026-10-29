extends "res://tests/live_combat.gd"


func _run() -> void:
	await load_level("res://scenes/battle.tscn", 0)
	await hollow_checks()
	await load_level("res://scenes/main.tscn")
	await simplex_checks()
	await load_level("res://scenes/main.tscn")
	await fold_and_hypercut_checks()
	await load_level("res://scenes/main.tscn")
	await interaction_and_surf_checks()
	check(completed_suites == 4, "Every advanced-rift suite completed")
	await frames(650)
	check(get_nodes_in_group("spatial_fields").is_empty(), "Stationary spatial fields expire")
	player.set_mouse_captured(false)
	print("RIFTERMATH_ADVANCED_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func hollow_checks() -> void:
	var bot := game.get_node("MatchDirector").actors[1] as CombatBot
	for actor in game.match_director.actors:
		if actor is CombatBot:
			actor._attack_cooldown = 10000
	bot.director = null
	bot._route.clear()
	bot.invulnerability = 0
	bot.global_position = Vector3(22.5, 0.1, 0)
	bot.velocity = Vector3.ZERO
	var field := cast_ability(&"HOLLOW", Vector3(20, 2.5, 0)) as HollowField
	field.age = 0.5
	var before := bot.global_position.x
	await frames(50)
	check(field.affected > 0 and bot.global_position.x < before - 0.15, "HOLLOW physically pulls a live enemy toward its aperture")
	var hp := bot.hull.hp
	field.collapse()
	await frames(2)
	check(bot.hull.hp < hp or bot.dead, "HOLLOW collapse releases damaging spatial pressure")
	completed_suites += 1


func simplex_checks() -> void:
	var target := game.get_node("Targets").get_child(0) as EnemyController
	var attack := cast_ability(&"SIMPLEX", Vector3(0, 2.9, -6)) as SimplexProjectile
	await frames(40)
	check(attack.pinned and target.hp < 100 and target.hp > 0, "SIMPLEX pyramid attaches on contact and arms its fuse")
	await frames(100)
	check(target.dead and not is_instance_valid(attack), "Attached SIMPLEX detonates, kills, and cleans up")
	completed_suites += 1


func fold_and_hypercut_checks() -> void:
	var fold := cast_ability(&"FOLD", Vector3(0, 3, 4)) as FoldField
	var bolt := EnemyBolt.new()
	game.get_node("HostileProjectiles").add_child(bolt)
	bolt.configure(Vector3(0, 3, 5), Vector3(0, 3, -8), 24)
	await frames(12)
	check(fold.redirects == 1 and absf(bolt.global_basis.z.x) > 0.8, "FOLD redirects an incoming projectile by the drawn corner angle")
	check(bolt.get_source() == player and bolt.reflected, "FOLD transfers hostile projectile ownership for a return attack")
	fold.queue_free()
	bolt.queue_free()
	await frames(2)
	var wall := make_wall(Vector3(0, 3, 1))
	var window := cast_ability(&"HYPERCUT", Vector3(0, 2.5, 4)) as HypercutField
	var target := game.get_node("Targets").get_child(0) as EnemyController
	await frames(2)
	var shot := GestureRecognizer.recognize(GestureRecognizer.template(&"SCAR"), 0.2)
	shot["damage"] = 25.0
	RiftCaster.cast(game, shot, Transform3D(Basis.IDENTITY, Vector3(0, 2.5, 6)), Vector3(0, 2.5, 6), player)
	await frames(60)
	check(window.exit_valid and window.transports == 1 and target.hp == 75, "HYPERCUT transports a SCAR across a limited solid obstacle")
	var wire := window.get_child(2) as TesseractVisual
	if wire == null:
		for child in window.get_children():
			if child is TesseractVisual:
				wire = child
	check(wire != null and wire.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 64, "Pseudo-4D visual projects all 32 tesseract edges into 3D")
	var fast := RiftCaster.cast(game, shot, Transform3D(Basis.IDENTITY, Vector3(0, 2.5, 6)), Vector3(0, 2.5, 6), player) as RiftProjectile
	fast.speed = 3600
	fast.fracture_duration = 0.001
	await frames(4)
	check(window.transports == 2 and target.hp == 50, "HYPERCUT preserves swept approach and exit hits at 3600 m/s")
	var before_entry := make_wall(Vector3(0, 3, 5))
	await frames(2)
	fast = RiftCaster.cast(game, shot, Transform3D(Basis.IDENTITY, Vector3(0, 2.5, 6)), Vector3(0, 2.5, 6), player) as RiftProjectile
	fast.speed = 3600
	fast.fracture_duration = 0.001
	await frames(4)
	check(window.transports == 2 and target.hp == 50, "A wall before HYPERCUT entry cannot be bypassed")
	before_entry.queue_free()
	await frames(2)
	var block_exit := make_wall(Vector3(0, 3, -2))
	await frames(2)
	var health := target.hp
	RiftCaster.cast(game, shot, Transform3D(Basis.IDENTITY, Vector3(0, 2.5, 6)), Vector3(0, 2.5, 6), player)
	await frames(60)
	check(not window.exit_valid and target.hp == health, "Blocked HYPERCUT exit cannot place an attack inside solid architecture")
	wall.queue_free()
	block_exit.queue_free()
	completed_suites += 1


func interaction_and_surf_checks() -> void:
	player.global_position = Vector3(0, 2, 12)
	player.velocity = Vector3.ZERO
	await frames(3)
	var wall := make_wall(Vector3(0, 4, 10))
	await frames(2)
	var pose := player.camera.global_transform.translated_local(Vector3(0, 0, -2))
	var data := GestureRecognizer.recognize(GestureRecognizer.template(&"SCAR"), 0.2)
	RiftCaster.cast(game, data, pose, player.camera.global_position, player)
	await frames(3)
	check(player.velocity.y > 0 and player.has_meta("last_rift_surf"), "Nearby airborne SCAR collapse produces a real Rift Surf impulse")
	wall.queue_free()
	var a := cast_ability(&"SCAR", Vector3(15, 3, 10)) as RiftProjectile
	var b := cast_ability(&"SCAR", Vector3(15, 3, 10)) as RiftProjectile
	a.phase = RiftProjectile.Phase.PROPAGATION
	b.phase = RiftProjectile.Phase.PROPAGATION
	a._muzzle_checked = true
	b._muzzle_checked = true
	a.speed = 0
	b.speed = 0
	b.basis = b.basis.rotated(Vector3.FORWARD, PI / 2)
	await frames(15)
	check(game.get_node("RiftInteractions").reactions == 1, "Intersecting independent rift planes trigger one spatial reaction")
	completed_suites += 1


func cast_ability(ability: StringName, at: Vector3) -> Node3D:
	var gesture := GestureRecognizer.recognize(GestureRecognizer.template(ability), 0.3)
	return RiftCaster.cast(game, gesture, Transform3D(Basis.IDENTITY, at), at, player)


func make_wall(at: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(14, 7, 0.3)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = at
	return wall
