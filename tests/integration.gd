extends SceneTree

var checks: int = 0
var failures: int = 0
var completed_suites: int = 0
var game: Node3D
var player: PlayerController
var capture: GestureCapture


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	await frames(18)
	check(player.is_on_floor(), "Player settles on arena floor")
	check(get_nodes_in_group("targets").size() == 9, "Three training targets and six encounter enemies in the playable scene")
	await movement_checks()
	await gesture_checks()
	await combat_checks()
	check(completed_suites == 3, "All test suites reached their final assertions")
	await frames(900)
	check(game.get_node("Rifts").get_child_count() == 0, "Projectiles and geometric trails clean up")
	check(get_nodes_in_group("combat_debris").is_empty(), "Rigid fragments clean up")
	check(not (game.get_node("Targets").get_child(0) as EnemyController).dead, "Destroyed training target respawns")
	player.global_position.y = -20
	await frames(3)
	check(player.global_position.distance_to(player.spawn_transform.origin) < 0.5, "Falling out of arena respawns the player")
	var old_scene_id := game.get_instance_id()
	key(KEY_R)
	await frames(5)
	game = current_scene
	check(game.get_instance_id() != old_scene_id and game.get_node("Targets").get_child_count() == 9, "R restarts the actual main scene and resets targets")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("RIFTERMATH_TEST_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func movement_checks() -> void:
	Input.action_press("move_forward")
	await frames(40)
	check(player.horizontal_speed() > 10.5, "WASD accelerates to run speed")
	check(player.position.z < 10.5, "Movement changes real 3D position")
	Input.action_release("move_forward")
	player.velocity = Vector3(14, 0, 0)
	Input.action_press("jump")
	await frames(8)
	check(player.position.y > 0.4, "Ground jump")
	check(player.horizontal_speed() > 13.0, "Jump preserves horizontal momentum")
	Input.action_release("jump")
	await frames(20)
	Input.action_press("jump")
	await frames(2)
	check(not player.air_jump_available and player.velocity.y > 7.5, "One deliberate double jump")
	Input.action_release("jump")
	var before_air := player.velocity.z
	Input.action_press("move_forward")
	await frames(10)
	check(player.velocity.z < before_air - 0.5, "Air control adds projection-limited acceleration")
	Input.action_release("move_forward")
	player.respawn()
	await frames(14)
	player.velocity = Vector3(15, 0, 0)
	Input.action_press("jump")
	var ascending: int = 0
	var was_ascending := false
	for i in range(270):
		await frames(1)
		var now_ascending := player.velocity.y > 7.0
		if now_ascending and not was_ascending:
			ascending += 1
		was_ascending = now_ascending
	check(ascending >= 2, "Holding Space bunnyhops on landing")
	Input.action_release("jump")
	player.respawn()
	await frames(14)
	Input.action_press("dash")
	await frames(3)
	check(player.horizontal_speed() >= 24.5 and player.dash_remaining > 0, "Dash applies forward impulse")
	Input.action_release("dash")
	Input.action_press("dash")
	await frames(2)
	check(player.dash_cooldown_remaining < player.dash_cooldown - 0.01, "Dash cannot retrigger during cooldown")
	Input.action_release("dash")
	player.respawn()
	await frames(14)
	player.velocity = Vector3(0, 0, -12)
	Input.action_press("slide")
	await frames(3)
	check(player.sliding and (player.body_shape.shape as CapsuleShape3D).height < 1.1, "Slide lowers physical capsule")
	check(player.horizontal_speed() > 13, "Slide preserves and boosts momentum")
	player.global_position = Vector3(-5, 0.04, 20)
	player.velocity = Vector3.ZERO
	Input.action_release("slide")
	await frames(5)
	check(player.sliding, "Low ceiling prevents standing inside solid architecture")
	player.position.z = 23
	await frames(5)
	check(not player.sliding, "Capsule stands after leaving the gate")
	player.respawn()
	await frames(14)
	completed_suites += 1


func gesture_checks() -> void:
	# The headless 64px dummy window rescales relative events into the viewport.
	# Compare identical input in both modes, rather than assuming OS pixel scale.
	var before_normal := player.rotation.y
	mouse_motion(Vector2(8, 0))
	var normal_turn := absf(angle_difference(before_normal, player.rotation.y))
	player.respawn()
	mouse_button(true)
	check(capture.active and player.drawing, "LMB starts relative-motion capture")
	var yaw := player.rotation.y
	mouse_motion(Vector2(8, -3))
	await frames(2)
	check(capture.points.size() >= 2, "Relative mouse movement writes local-plane points")
	check(absf(absf(angle_difference(yaw, player.rotation.y)) / normal_turn - player.drawing_sensitivity) < 0.001, "Camera turns at 30 percent sensitivity during drawing")
	check(is_instance_valid(game.preview), "Incision is a Node3D attached to the camera")
	var mesh: ArrayMesh = game.preview.mesh_instance.mesh
	check(mesh.get_surface_count() == 3 and mesh.get_aabb().size.z > 0.25, "Incision has three mesh surfaces and actual cavity depth")
	var before := player.global_position
	Input.action_press("move_forward")
	Input.action_press("dash")
	await frames(8)
	check(capture.active and player.global_position.distance_to(before) > 0.3, "Movement and dash continue during incision")
	Input.action_release("dash")
	Input.action_release("move_forward")
	Input.action_press("jump")
	await frames(3)
	check(capture.active and player.velocity.y > 0, "Jump remains available while drawing")
	Input.action_release("jump")
	var pose: Transform3D = game.preview.global_transform
	mouse_button(false)
	var scar: RiftProjectile = game.last_projectile
	check(not capture.active and not player.drawing, "Release ends capture")
	check(scar.global_transform.is_equal_approx(pose), "Release bakes one camera snapshot without a position jump")
	await frames(8)
	var in_camera := player.camera.global_transform.affine_inverse() * scar.global_position
	check(in_camera.z < -1.4, "Released fracture inherits momentum and stays ahead during a dash")
	await frames(10)
	check(scar.phase == RiftProjectile.Phase.PROPAGATION, "Fracture advances to propagation")
	capture.begin()
	for i in range(600):
		capture.feed_relative(Vector2(13 if i % 2 == 0 else -12, -2))
	check(capture.points.size() <= capture.max_points, "Gesture sample count is bounded")
	capture.feed_relative(Vector2(NAN, 0))
	check(capture.points[-1].is_finite(), "Nonfinite mouse input is ignored")
	key(KEY_ESCAPE)
	await frames(2)
	check(not capture.active and not player.drawing, "Esc cancels drawing and frees cursor")
	check(not player.mouse_captured, "Esc releases logical mouse capture")
	mouse_button(true)
	mouse_button(false)
	check(player.mouse_captured and not capture.active, "First click recaptures without firing")
	var tap := GestureRecognizer.recognize(PackedVector2Array([Vector2.ZERO]), 0.01)
	check(tap["weak"] and tap["damage"] == 28.0 and tap["points"].size() == 2, "Tiny taps become valid weaker SCAR attacks")
	var short_stroke := GestureRecognizer.recognize(PackedVector2Array([Vector2.ZERO, Vector2(0.7, 0)]), 0.2)
	var long_stroke := GestureRecognizer.recognize(PackedVector2Array([Vector2.ZERO, Vector2(2.5, 0)]), 0.3)
	check(long_stroke["length"] > short_stroke["length"] and long_stroke["damage"] > short_stroke["damage"], "Stroke length changes attack geometry and damage")
	player.respawn()
	await frames(14)
	completed_suites += 1


func combat_checks() -> void:
	var cut := Vector3(1, 1, 0).normalized()
	var pieces := BoxFracture.split(Vector3(1.12, 1.10, 0.68), cut)
	check(pieces.size() == 2 and (pieces[1]["center"] - pieces[0]["center"]).dot(cut) > 0.1, "Torso separates into capped convex pieces along a diagonal stroke plane")
	check(pieces[0]["mesh"].get_aabb().size.is_finite() and pieces[1]["shape"].points.size() >= 4, "Procedural cut pieces have finite mesh bounds and convex collision hulls")
	# Clear the earlier input-driven shot before isolated collision scenarios.
	await frames(140)
	var target := game.get_node("Targets").get_child(0) as EnemyController
	target.hp = target.max_hp
	var horizontal := PackedVector2Array([Vector2(-2, 0), Vector2(2, 0)])
	var scar := shoot(horizontal, Vector3(0, 1.7, 3), 35.0)
	scar.speed = 3600.0
	await frames(4)
	check(is_equal_approx(target.hp, 65.0), "Swept volume hits a target crossed at 3600 m/s")
	await frames(12)
	check(is_equal_approx(target.hp, 65.0), "One SCAR damages a target only once")
	var extra := load("res://scenes/target.tscn").instantiate() as EnemyController
	game.get_node("Targets").add_child(extra)
	extra.position = Vector3(2.8, 0.25, -6)
	await frames(2)
	var vertical := PackedVector2Array([Vector2(0, -1.5), Vector2(0, 1.5)])
	shoot(vertical, Vector3(0, 1.7, 2), 20.0).speed = 3600.0
	await frames(5)
	check(is_equal_approx(extra.hp, 100.0), "Vertical stroke misses a laterally offset target")
	shoot(PackedVector2Array([Vector2(-3, 0), Vector2(3, 0)]), Vector3(0, 1.7, 2), 20.0).speed = 3600.0
	await frames(5)
	check(is_equal_approx(extra.hp, 80.0), "Horizontal cutting plane reaches the same lateral target")
	extra.queue_free()
	var wall := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12, 5, 0.2)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = Vector3(0, 2.5, 0)
	await frames(3)
	var hp := target.hp
	shoot(horizontal, Vector3(0, 1.7, 3), 15.0).speed = 3600.0
	await frames(5)
	check(is_equal_approx(target.hp, hp), "Wall truncates the sweep before targets behind it")
	var near_wall := shoot(horizontal, Vector3(0, 1.7, -2), 15.0, Vector3(0, 1.7, 1))
	await frames(3)
	check(near_wall.phase == RiftProjectile.Phase.COLLAPSE and is_equal_approx(target.hp, hp), "Drawing plane cannot spawn an attack through a nearby wall")
	wall.queue_free()
	await frames(3)
	shoot(horizontal, Vector3(0, 1.7, -9), 120.0)
	await frames(3)
	check(target.dead and target.hp == 0, "Spawn overlap deals damage and target can be killed")
	check(not target.visual.visible, "Destroyed target hides its intact model")
	check(get_nodes_in_group("combat_debris").size() >= 8, "Death emits physical low-poly fragments")
	check(game.hud.hits >= 3 and game.hud.kills >= 1, "Hit and kill feedback reaches HUD")
	completed_suites += 1


func shoot(points: PackedVector2Array, at: Vector3, damage: float, eye: Vector3 = Vector3.INF) -> RiftProjectile:
	var scar := load("res://scenes/rift_projectile.tscn").instantiate() as RiftProjectile
	game.get_node("Rifts").add_child(scar)
	scar.fracture_duration = 0.001
	scar.target_hit.connect(game.hud.register_hit)
	scar.fragment_cut.connect(game.hud.register_fragment_cut)
	scar.configure({"points": points, "damage": damage}, Transform3D(Basis.IDENTITY, at), at if eye == Vector3.INF else eye)
	return scar


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame


func mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
