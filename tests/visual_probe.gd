extends SceneTree

# Real GPU-rendered verification. Evidence is intentionally kept out of source control.
var game: Node3D
var player: PlayerController
var capture: GestureCapture
var output: String
const INPUT_GUARD := preload("res://tests/input_guard.gd")
var native_guard: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual probe needs an actual graphical renderer.")
		quit(1)
		return
	output = ProjectSettings.globalize_path("res://.local/visual-qa")
	DirAccess.make_dir_recursive_absolute(output)
	root.title = "RIFTERMATH / graphical verification"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	capture = player.get_node("GestureCapture")
	native_guard = INPUT_GUARD.new()
	root.add_child(native_guard)
	await frames(25)
	player.set_mouse_captured(true)
	print("VISUAL_RENDERER: ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_current_rendering_method())
	print("OS_MOUSE_CAPTURED: ", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	await snapshot("01-arena")
	button(true)
	for i in range(6):
		motion(Vector2(27, -12))
		await frames(2)
	await snapshot("02-incision")
	var before := player.global_position
	Input.action_press("move_forward")
	Input.action_press("dash")
	await frames(5)
	Input.action_release("move_forward")
	Input.action_release("dash")
	print("DRAWING_WITH_DASH: ", capture.active and player.global_position.distance_to(before) > 0.3)
	button(false)
	await frames(4)
	await snapshot("03-fracture")
	var scar: RiftProjectile = game.last_projectile
	# Freeze only the test object to inspect its cavity from a second camera.
	scar.set_physics_process(false)
	var observer := Camera3D.new()
	game.add_child(observer)
	var focus := scar.global_transform * Vector3(0.5, 0.25, 0)
	observer.global_position = focus + scar.global_basis * Vector3(0.9, 0.75, 1.9)
	observer.look_at(focus, scar.global_basis.y)
	observer.fov = 64
	observer.make_current()
	await frames(3)
	await snapshot("04-fracture-oblique")
	player.camera.make_current()
	observer.queue_free()
	scar.set_physics_process(true)
	await frames(8)
	await snapshot("05-propagation")
	await frames(90)
	player.respawn()
	player.set_mouse_captured(true)
	await frames(20)
	# Four actual clicks exercise the input path and kill the central training target.
	for i in range(4):
		player.set_mouse_captured(true)
		player.rotation.y = 0
		player.head.rotation.x = 0
		button(true)
		await frames(1)
		button(false)
		await frames(35)
	await snapshot("06-target-severed")
	print("VISUAL_HITS: ", game.hud.hits, " KILLS: ", game.hud.kills)
	if game.hud.hits < 4 or game.hud.kills < 1:
		push_error("Visual click scenario did not hit and kill the training target.")
		quit(1)
		return
	# Elevated arena view validates ramps, decks, shadows and boundaries.
	player.global_position = Vector3(-17, 3.1, 0)
	player.rotation.y = -0.62
	player.head.rotation.x = -0.12
	await frames(3)
	await snapshot("07-upper-route")
	player.set_mouse_captured(false)
	print("RIFTERMATH_VISUAL_RESULT: 7 GPU screenshots saved to .local/visual-qa")
	quit()


func snapshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(output.path_join(label + ".png"))
	if error != OK:
		push_error("Screenshot failed: " + label)
	else:
		print("VISUAL_CAPTURE: ", label, " ", image.get_size())


func frames(count: int) -> void:
	for i in range(count):
		await process_frame


func button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.set_meta("riftermath_qa", true)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.set_meta("riftermath_qa", true)
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()
