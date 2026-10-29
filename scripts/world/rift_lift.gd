class_name RiftLift
extends Area3D

@export var impulse: float = 24.0
@export var carry := Vector3.ZERO
var launches: int = 0
var _cooldowns: Dictionary = {}


func _ready() -> void:
	add_to_group("rift_lifts")
	collision_layer = 0
	collision_mask = 6
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 0.45
	collision.shape = shape
	collision.position.y = 0.22
	add_child(collision)
	var aperture := Node3D.new()
	aperture.position.y = 0.24
	aperture.rotation.x = -PI / 2
	add_child(aperture)
	var rim := RiftRenderer.new()
	aperture.add_child(rim)
	rim.set_path(GestureRecognizer.template(&"HOLLOW"))
	rim.set_tint(Color("92ab92"))
	rim.set_opening(0.8)
	SpatialEffects.well(aperture, 0.92, 0.18)
	for side in [-1.0, 1.0]:
		var fin := RiftRenderer.new()
		add_child(fin)
		fin.position.x = side * 1.05
		fin.set_path(PackedVector2Array([Vector2(0, 0.25), Vector2(side * 0.15, 1.20), Vector2(side * 0.35, 1.70)]))
		fin.set_tint(Color("92ab92"))
		fin.set_opening(0.35)
	body_entered.connect(_launch)


func _physics_process(delta: float) -> void:
	for key in _cooldowns.keys():
		_cooldowns[key] -= delta
		if _cooldowns[key] <= 0:
			_cooldowns.erase(key)


func _launch(body: Node3D) -> void:
	if not body is CharacterBody3D or not CombatRules.alive(body) or _cooldowns.has(body.get_instance_id()):
		return
	_cooldowns[body.get_instance_id()] = 1.0
	body.velocity.y = maxf(body.velocity.y, impulse)
	body.velocity.x += carry.x
	body.velocity.z += carry.z
	if body is PlayerController:
		body.air_jump_available = true
		var hud := get_tree().current_scene.get_node_or_null("HUD/Display")
		if hud != null:
			hud.notice = "RIFT LIFT / AIR JUMP READY"
			hud.notice_remaining = 0.8
	elif body is CombatBot:
		body.lift_remaining = 0.8
	launches += 1
