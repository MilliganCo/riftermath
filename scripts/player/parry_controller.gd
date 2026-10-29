class_name ParryController
extends Node

signal parried
@export var duration: float = 0.20
@export var cooldown: float = 0.65
@export var radius: float = 3.4
var remaining: float = 0.0
var cooldown_remaining: float = 0.0
var count: int = 0
var player: PlayerController


func _ready() -> void:
	player = get_parent() as PlayerController
	player.respawned.connect(func(): remaining = 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("parry") and player.mouse_captured and not player.dead:
		activate()


func activate() -> bool:
	if cooldown_remaining > 0:
		return false
	remaining = duration
	cooldown_remaining = cooldown
	var visual := RiftRenderer.new()
	player.camera.add_child(visual)
	visual.position.z = -1.2
	visual.set_path(PackedVector2Array([Vector2(-0.65, -0.15), Vector2(-0.35, 0.12), Vector2(0.35, 0.12), Vector2(0.65, -0.15)]))
	visual._echo_remaining = duration
	visual._echo_duration = duration
	return true


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0, cooldown_remaining - delta)
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		return
	var projectiles := get_tree().get_nodes_in_group("rift_projectiles") + get_tree().get_nodes_in_group("enemy_bolts")
	for attack: Node3D in projectiles:
		if not is_instance_valid(attack) or not attack.has_method("reflect_by") or attack.reflected:
			continue
		if attack.has_method("get_source") and not CombatRules.can_hit(attack.get_source(), player):
			continue
		var offset := attack.global_position - player.camera.global_position
		if offset.length() <= radius and offset.normalized().dot(-player.camera.global_basis.z) > 0.20:
			if not CombatRules.clear_line(player, player.camera.global_position, attack.global_position):
				continue
			attack.reflect_by(player)
			remaining = 0
			count += 1
			player.hp = minf(player.max_hp, player.hp + 8)
			parried.emit()
			break
