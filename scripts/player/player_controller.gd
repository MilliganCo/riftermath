class_name PlayerController
extends CharacterBody3D

signal respawned
signal mouse_capture_changed(captured: bool)
signal damaged(amount: float)
signal killed(attacker: Node)

@export_group("Movement")
@export var run_speed: float = 11.0
@export var ground_acceleration: float = 85.0
@export var ground_friction: float = 7.0
@export var air_acceleration: float = 24.0
@export var air_wish_speed: float = 3.2
@export var max_horizontal_speed: float = 32.0
@export var gravity_force: float = 25.0
@export var jump_speed: float = 9.4
@export var coyote_duration: float = 0.10
@export var jump_buffer_duration: float = 0.13
@export var standing_height: float = 2.35
@export var eye_height: float = 2.08
@export var max_hp: float = 100.0
@export_group("Dash / slide")
@export var dash_speed: float = 25.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.70
@export var slide_duration: float = 0.90
@export var slide_impulse: float = 3.5
@export var slide_friction: float = 0.55
@export_group("View")
@export var mouse_sensitivity: float = 0.0020
@export_range(0.05, 1.0) var drawing_sensitivity: float = 0.30
@export var base_fov: float = 91.0
@export var capture_on_start: bool = true
@export var auto_respawn: bool = true
@export var allow_click_capture: bool = true

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_shape: CollisionShape3D = $BodyShape
@onready var standing_clearance: ShapeCast3D = $StandingClearance

var drawing: bool = false
var mouse_captured: bool = false
var sliding: bool = false
var dash_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0
var slide_remaining: float = 0.0
var air_jump_available: bool = true
var spawn_transform: Transform3D
var _jump_buffer: float = 0.0
var _coyote: float = 0.0
var _dash_direction := Vector3.FORWARD
var _kick: float = 0.0
var _land_kick: float = 0.0
var _was_grounded: bool = false
var hp: float = 100.0
var deaths: int = 0
var invulnerability: float = 0.0
var dead: bool = false
var team_id: int = 0
var energy: float = 100.0
var combat_fov_bonus: float = 0.0
var rune: StringName = &""


func _ready() -> void:
	spawn_transform = global_transform
	hp = max_hp
	Input.use_accumulated_input = false
	# Each player owns its mutable capsule (also safe for repeated test instances).
	body_shape.shape = body_shape.shape.duplicate()
	if capture_on_start:
		set_mouse_captured(true)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		set_mouse_captured(not mouse_captured)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not mouse_captured and allow_click_capture:
			set_mouse_captured(true)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and mouse_captured:
		var sensitivity := mouse_sensitivity * (drawing_sensitivity if drawing else 1.0)
		rotate_y(-event.relative.x * sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sensitivity, -1.48, 1.48)


func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	energy = minf(100.0, energy + delta * 23.0)
	if dead:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	var controls := mouse_captured
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_coyote = coyote_duration if grounded else maxf(0.0, _coyote - delta)
	if grounded:
		air_jump_available = true
		if not _was_grounded:
			_land_kick = 0.07
	if controls and Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_duration
	var input_axis := Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if controls else Vector2.ZERO
	var wish := (global_basis * Vector3(input_axis.x, 0, input_axis.y)).normalized()
	var wants_jump := controls and (_jump_buffer > 0.0 or Input.is_action_pressed("jump"))
	var jumped := false
	if wants_jump and (grounded or _coyote > 0.0):
		velocity.y = jump_speed
		_jump_buffer = 0.0
		_coyote = 0.0
		jumped = true
	elif controls and Input.is_action_just_pressed("jump") and air_jump_available:
		velocity.y = jump_speed * 0.92
		air_jump_available = false
		_jump_buffer = 0.0
		jumped = true

	if controls and Input.is_action_just_pressed("slide") and grounded and horizontal_speed() > 4.0:
		sliding = true
		slide_remaining = slide_duration
		velocity += Vector3(velocity.x, 0, velocity.z).normalized() * slide_impulse
	if sliding:
		slide_remaining -= delta
		if (slide_remaining <= 0.0 or not Input.is_action_pressed("slide") or jumped) and _can_stand():
			sliding = false
	_set_capsule_height(1.08 if sliding else standing_height)

	if controls and Input.is_action_just_pressed("dash") and dash_cooldown_remaining <= 0.0:
		_dash_direction = wish if wish.length_squared() > 0.01 else -global_basis.z
		dash_remaining = dash_duration
		dash_cooldown_remaining = dash_cooldown
	if dash_remaining > 0.0:
		dash_remaining = maxf(0.0, dash_remaining - delta)
		var speed := maxf(dash_speed, horizontal_speed())
		velocity.x = _dash_direction.x * speed
		velocity.z = _dash_direction.z * speed
		velocity.y = maxf(velocity.y, 0.0)
	else:
		if grounded and not jumped:
			_apply_friction(slide_friction if sliding else ground_friction, delta)
			_accelerate(wish, run_speed, ground_acceleration * (0.18 if sliding else 1.0), delta)
		else:
			# Projection-limited acceleration preserves momentum and rewards strafe jumps.
			_accelerate(wish, air_wish_speed, air_acceleration, delta)
		velocity.y -= gravity_force * delta
	var horizontal := Vector2(velocity.x, velocity.z).limit_length(max_horizontal_speed)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	move_and_slide()
	_was_grounded = grounded
	_update_view(delta)
	if global_position.y < -14.0:
		respawn()


func _accelerate(wish: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	var projected := Vector3(velocity.x, 0, velocity.z).dot(wish)
	var add_speed := wish_speed - projected
	if add_speed > 0.0:
		velocity += wish * minf(add_speed, acceleration * delta)


func _apply_friction(friction: float, delta: float) -> void:
	var speed := horizontal_speed()
	if speed > 0.001:
		var factor := maxf(0.0, speed - maxf(speed, 3.0) * friction * delta) / speed
		velocity.x *= factor
		velocity.z *= factor


func _can_stand() -> bool:
	standing_clearance.force_shapecast_update()
	return not standing_clearance.is_colliding()


func _set_capsule_height(height: float) -> void:
	var capsule := body_shape.shape as CapsuleShape3D
	if not is_equal_approx(capsule.height, height):
		capsule.height = height
		body_shape.position.y = height * 0.5


func _update_view(delta: float) -> void:
	_kick = move_toward(_kick, 0.0, delta * 1.3)
	_land_kick = move_toward(_land_kick, 0.0, delta * 0.45)
	head.position.y = lerpf(head.position.y, (0.90 if sliding else eye_height) - _land_kick, 14.0 * delta)
	camera.position.z = _kick
	camera.rotation.z = lerpf(camera.rotation.z, -Input.get_axis("move_left", "move_right") * 0.014, 7.0 * delta)
	var speed_fov := clampf(horizontal_speed() - run_speed, 0.0, 15.0) * 0.6
	var target_fov := minf(112.0, base_fov + speed_fov + combat_fov_bonus)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-5.0 * delta))


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func set_mouse_captured(captured: bool) -> void:
	# The logical state also works with Godot's headless DisplayServer, which has no cursor.
	mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	mouse_capture_changed.emit(captured)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		set_mouse_captured(false)


func attack_feedback(strength: float = 1.0) -> void:
	_kick = minf(0.08, 0.035 * strength)


func respawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	head.rotation = Vector3.ZERO
	sliding = false
	dash_remaining = 0.0
	dash_cooldown_remaining = 0.0
	air_jump_available = true
	_jump_buffer = 0.0
	_coyote = 0.0
	hp = max_hp
	dead = false
	energy = 100.0
	collision_layer = 2
	invulnerability = 1.0
	respawned.emit()


func receive_damage(amount: float, attacker: Node = null) -> void:
	if dead or invulnerability > 0.0 or amount <= 0.0 or _safe_area():
		return
	hp = maxf(0.0, hp - amount)
	invulnerability = 0.22
	damaged.emit(amount)
	if hp <= 0.0:
		deaths += 1
		dead = true
		killed.emit(attacker)
		if auto_respawn:
			respawn()
		else:
			collision_layer = 0
			velocity = Vector3.ZERO
			mouse_capture_changed.emit(false)


func combat_team() -> int:
	return team_id


func combat_alive() -> bool:
	return not dead


func can_receive_hit() -> bool:
	return not dead and invulnerability <= 0.0 and not _safe_area()


func _safe_area() -> bool:
	var world := get_tree().current_scene
	var rules := world.get_node_or_null("MatchDirector") if world != null else null
	return rules != null and rules.has_method("blocks_player_damage") and rules.blocks_player_damage(self)


func combat_aim_point() -> Vector3:
	return global_position + Vector3.UP * (0.6 if sliding else 1.3)


func receive_scar(amount: float, _direction: Vector3, _normal: Vector3, _point: Vector3 = Vector3.INF, _token: int = 0, attacker: Node = null) -> bool:
	var before := deaths
	receive_damage(amount, attacker)
	return deaths > before
