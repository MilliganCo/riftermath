class_name CombatZone
extends Area3D

signal activation_changed(active: bool)

@export var radius: float = 12.0
@export var vertical_reach: float = 20.0
@export var zone_name: String = "LIVE FIRE"
var active: bool = false
var enemies: Array[EnemyController] = []
var _material: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	add_to_group("combat_zones")
	collision_layer = 0
	collision_mask = 2
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = vertical_reach
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = vertical_reach * 0.5
	add_child(collision)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.08
	mesh.outer_radius = radius + 0.08
	mesh.rings = 48
	mesh.ring_segments = 6
	ring.mesh = mesh
	ring.position.y = 0.08
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color("8f9992")
	_material.emission_enabled = true
	_material.emission = Color("8f9992")
	_material.emission_energy_multiplier = 1.3
	ring.material_override = _material
	add_child(ring)
	_label = Label3D.new()
	_label.text = zone_name + " / ENTER TO ENGAGE"
	_label.pixel_size = 0.018
	_label.font_size = 48
	_label.outline_size = 0
	_label.position = Vector3(0, 0.05, radius * 0.8)
	_label.rotation.x = -PI / 2
	add_child(_label)
	body_entered.connect(_entered)
	body_exited.connect(_exited)


func _entered(body: Node3D) -> void:
	if body is PlayerController:
		set_active(true)


func _exited(body: Node3D) -> void:
	if body is PlayerController:
		set_active(false)


func set_active(enabled: bool) -> void:
	if active == enabled:
		return
	active = enabled
	for i in range(enemies.size()):
		if is_instance_valid(enemies[i]):
			enemies[i].set_attack_enabled(active, float(i) * 0.23)
	_material.albedo_color = Color("e3e8e4") if active else Color("8f9992")
	_material.emission = _material.albedo_color
	_label.text = zone_name + (" / LIVE FIRE" if active else " / ENTER TO ENGAGE")
	activation_changed.emit(active)
