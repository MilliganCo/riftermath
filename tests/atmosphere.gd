extends "res://tests/live_combat.gd"


func _run() -> void:
	await load_level("res://scenes/main.tscn")
	await palette_and_tempo_checks()
	await load_level("res://scenes/battle.tscn", 1)
	await threat_checks()
	check(completed_suites == 2, "Both atmosphere suites reached completion")
	player.set_mouse_captured(false)
	print("RIFTERMATH_ATMOSPHERE_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func palette_and_tempo_checks() -> void:
	var atmosphere := game.atmosphere as CombatAtmosphere
	atmosphere.reset()
	check(atmosphere.pixel_size == 2 and atmosphere.post_material.get_shader_parameter("pixel_size") == 2.0 and atmosphere.environment.sky.sky_material is ShaderMaterial, "World uses crisp two-pixel blocks with a palette-controlled sky")
	check(atmosphere.sample_threat() == 0.0, "Inactive training targets do not create combat pressure")
	var quiet_light := atmosphere.environment.ambient_light_color
	check(quiet_light.r > quiet_light.g and quiet_light.g > quiet_light.b, "Quiet world lighting has a warm bone palette")
	var quiet_density := atmosphere.environment.fog_density
	game._release_scar(GestureRecognizer.template(&"SCAR"), player.camera.global_transform.translated_local(Vector3(0, 0, -2)), 0.2)
	check(is_instance_valid(game.last_cast) and atmosphere.activity > 0.09, "An actual spatial-rift cast feeds the combat memory")
	game.hud.register_fragment_cut()
	game.hud.register_parry()
	check(atmosphere.activity > 0.42, "Air cuts and successful parries contribute to the tempo")
	player.invulnerability = 0
	var before := atmosphere.activity
	player.receive_damage(14)
	check(atmosphere.activity > before, "Actual received damage increases combat pressure")
	atmosphere.reset()
	var time_scale := Engine.time_scale
	var sensitivity := player.drawing_sensitivity
	var highest := 0.0
	for i in range(360):
		if i % 20 == 0:
			game.hud.register_cast(&"FANG")
			game.hud.register_hit(25, true)
		await frames(1)
		highest = maxf(highest, atmosphere.intensity)
	check(highest > 0.90 and atmosphere.pressure > 0.85, "Sustained real combat events smoothly reach the dark-fog state")
	check(atmosphere.environment.fog_density > quiet_density * 5, "Peak pressure increases actual 3D environment fog")
	check(atmosphere.environment.ambient_light_energy < 0.46, "Peak pressure dims the world lights")
	check(player.camera.fov > player.base_fov + 8 and player.camera.fov <= 112.0, "Peak combat gradually expands the gameplay camera FOV within its cap")
	check(Engine.time_scale == time_scale and player.drawing_sensitivity == sensitivity, "Atmosphere preserves game speed and drawing sensitivity")
	var peak := atmosphere.intensity
	await frames(1)
	check(absf(atmosphere.intensity - peak) < 0.02, "One quiet frame cannot abruptly snap the visual state")
	await frames(1800)
	check(atmosphere.intensity < 0.08 and atmosphere.pressure == 0.0, "Leaving combat naturally recovers the clear warm world")
	check(absf(player.camera.fov - player.base_fov) < 0.8, "FOV recovers after combat without changing the base setting")
	atmosphere.add_impulse(100)
	check(atmosphere.activity == 1.0, "Extreme event bursts are bounded")
	atmosphere.intensity = 1.0
	atmosphere.apply_visuals()
	player.respawn()
	check(atmosphere.intensity == 0 and atmosphere.activity == 0 and player.combat_fov_bonus == 0, "Respawn clears pressure and the combat FOV offset")
	completed_suites += 1


func threat_checks() -> void:
	var atmosphere := game.atmosphere as CombatAtmosphere
	var director := game.match_director as MatchDirector
	player.invulnerability = 10000
	# The x=4 lane stays clear of the central pillar, including projectile LOS.
	player.global_position = Vector3(4, 3.1, 4)
	player.velocity = Vector3.ZERO
	for actor in director.actors:
		if actor is CombatBot:
			actor.set_physics_process(false)
			actor.global_position = Vector3(32, 0.1, -32)
	var ally := director.actors[1] as CombatBot
	var enemy := director.actors[4] as CombatBot
	ally.global_position = Vector3(0, 3.1, -3)
	await frames(3)
	check(atmosphere.sample_threat() == 0.0, "Nearby teammates do not count as hostile presence")
	enemy.global_position = Vector3(2, 3.1, -3)
	await frames(3)
	check(atmosphere.sample_threat() > 0.05, "A nearby visible live enemy creates pressure")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(16, 10, 0.5)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.global_position = Vector3(0, 6, 0)
	await frames(3)
	check(atmosphere.sample_threat() == 0.0, "Solid cover shields the atmosphere from hidden enemies")
	wall.queue_free()
	enemy.global_position = Vector3(32, 0.1, -32)
	await frames(3)
	var bolt := EnemyBolt.new()
	game.get_node("HostileProjectiles").add_child(bolt)
	bolt.source_ref = weakref(ally)
	bolt.configure(player.camera.global_position + Vector3.FORWARD * 6, player.camera.global_position, 0)
	await frames(2)
	check(atmosphere.sample_threat() == 0.0, "Friendly projectiles cannot raise the danger response")
	bolt.source_ref = weakref(enemy)
	check(atmosphere.sample_threat() > 0.10, "A hostile projectile headed toward the player adds danger")
	bolt.source_ref = weakref(player)
	check(atmosphere.sample_threat() == 0.0, "Player-owned reflected projectiles no longer create incoming danger")
	atmosphere.intensity = 1
	atmosphere.apply_visuals()
	player.invulnerability = 0
	player.receive_damage(10000, enemy)
	check(atmosphere.activity == 0 and atmosphere.intensity == 0 and player.combat_fov_bonus == 0, "Player death clears the atmosphere state")
	completed_suites += 1
