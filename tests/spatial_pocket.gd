extends "res://tests/advanced_rifts.gd"


func _run() -> void:
	await load_level("res://scenes/battle.tscn", 0)
	player.global_position = Vector3(10, 0.1, 10)
	player.invulnerability = 10000
	for actor in game.match_director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(-32, 0.1, -32)
	var bot := game.match_director.actors[1] as CombatBot
	bot.global_position = Vector3(22, 0.1, 0)
	bot.director = null
	bot.target = null
	bot._route = PackedVector3Array([Vector3(22, 0.1, 0), Vector3(30, 0.1, 0)])
	bot._waypoint = 1
	bot._think = 10000
	bot._attack_cooldown = 10000
	bot.invulnerability = 0
	bot.set_physics_process(true)
	var center := Vector3(20, 2.6, 0)
	var circle := cast_ability(&"HOLLOW", center) as HollowField
	circle.age = 0.5
	var triangle := cast_ability(&"SIMPLEX", center + Vector3(0, 0, 0.2)) as SimplexProjectile
	triangle.speed = 0
	await frames(18)
	check(game.get_node("RiftInteractions").closed_pockets == 1 and get_nodes_in_group("spatial_pockets").size() == 1, "A real triangle inside a circular aperture forms one closed spatial pocket")
	check(not is_instance_valid(circle) and not is_instance_valid(triangle), "The combination consumes its two parent effects")
	if get_nodes_in_group("spatial_pockets").is_empty():
		print("RIFTERMATH_POCKET_RESULT: %d checks, %d failures" % [checks, failures])
		quit(1)
		return
	var pocket := get_nodes_in_group("spatial_pockets")[0] as SpatialPocket
	check(pocket.get_child_count() == 12 and pocket.metric(Vector3(0, 1, 0)) > 1, "The pocket uses twelve recessed 3D edges and an octahedral volume")
	var bolt := EnemyBolt.new()
	game.get_node("HostileProjectiles").add_child(bolt)
	bolt.source_ref = weakref(bot)
	bolt.configure(center + Vector3(0, 0, 1), center, 18)
	var own := cast_ability(&"SCAR", center + Vector3(0, 0, -2.5)) as RiftProjectile
	own.speed = 0
	await frames(4)
	check(pocket.snared.size() == 1 and not bolt.is_physics_processing(), "The closed pocket physically suspends an incoming hostile attack")
	check(own.is_physics_processing(), "The owner's own attack remains free")
	var farthest := 0.0
	for i in range(75):
		await frames(1)
		farthest = maxf(farthest, pocket.metric(bot.combat_aim_point() - center))
	check(pocket.contained > 0 and farthest < pocket.radius * 1.15, "The pocket contains a live moving enemy through velocity constraints")
	check(game.get_node("RiftInteractions").closed_pockets == 1, "A consumed pair cannot recursively produce more pockets")
	var health := bot.hull.hp
	check(not bot.dead, "Containment keeps the live enemy available for a separate collapse event")
	await frames(250)
	check(not is_instance_valid(pocket) and get_nodes_in_group("spatial_pockets").is_empty(), "The pocket expires and its geometry cleans up")
	check(bot.hull.hp < health, "Pocket collapse releases real spatial damage")
	check(is_instance_valid(bolt) and bolt.get_source() == player and bolt.reflected and bolt.is_physics_processing(), "Collapse releases the trapped projectile with player ownership")
	var interrupted := SpatialPocket.new()
	game.get_node("Rifts").add_child(interrupted)
	interrupted.configure(Vector3(12, 3, 12), 3.5, player)
	var held := cast_ability(&"SCAR", Vector3(12, 3, 12)) as RiftProjectile
	held.source_ref = weakref(bot)
	await frames(2)
	await load_level("res://scenes/main.tscn")
	check(get_nodes_in_group("spatial_pockets").is_empty(), "Changing levels safely releases or frees suspended attacks")
	player.set_mouse_captured(false)
	print("RIFTERMATH_POCKET_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
