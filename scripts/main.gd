extends Node3D

const PROJECTILE := preload("res://scenes/rift_projectile.tscn")
const TARGET := preload("res://scenes/target.tscn")

@onready var player: PlayerController = $Player
@onready var capture: GestureCapture = $Player/GestureCapture
@onready var hud: Control = $HUD/Display

var preview: RiftRenderer
var last_projectile: RiftProjectile
var last_cast: Node3D
var match_director: Node
var atmosphere: CombatAtmosphere


func _ready() -> void:
	_bind_gameplay()
	_create_training_targets()


func _bind_gameplay() -> void:
	atmosphere = WorldTheme.apply(self)
	var audio_node := SynthAudio.new()
	audio_node.name = "Audio"
	add_child(audio_node)
	var soundscape := GothicSoundscape.new()
	soundscape.name = "Soundscape"
	add_child(soundscape)
	soundscape.configure(self)
	var interactions := RiftInteractions.new()
	interactions.name = "RiftInteractions"
	add_child(interactions)
	capture.incision_started.connect(_start_incision)
	capture.path_changed.connect(_update_incision)
	capture.gesture_released.connect(_release_scar)
	capture.cancelled.connect(_cancel_incision)
	hud.bind(player, capture)
	hud.combat_activity.connect(atmosphere.add_impulse)
	player.respawned.connect(_reset_encounters)
	$Player/Parry.parried.connect(hud.register_parry)


func _create_training_targets() -> void:
	var locations := [Vector3(0, 0.25, -9), Vector3(-17, 3.25, -8), Vector3(16, 5.05, -15)]
	for i in range(locations.size()):
		var target := TARGET.instantiate() as EnemyController
		target.target_name = "SENTINEL %02d" % (i + 1)
		$Targets.add_child(target)
		target.position = locations[i]
	_create_encounter("WEST", Vector3(-36, 0, -5), [Vector3(-44, 0, -12), Vector3(-38, 0, 3), Vector3(-31, 0, -15)])
	_create_encounter("EAST", Vector3(36, 0, -20), [Vector3(43, 0, -27), Vector3(43, 0, -13), Vector3(31, 0, -23)])


func _create_encounter(label: String, at: Vector3, locations: Array) -> void:
	var zone := CombatZone.new()
	zone.zone_name = label
	$CombatZones.add_child(zone)
	zone.position = at
	for i in range(locations.size()):
		var enemy := TARGET.instantiate() as EnemyController
		enemy.target_name = "LANCER %s-%d" % [label, i + 1]
		enemy.player = player
		$Targets.add_child(enemy)
		enemy.position = locations[i]
		zone.enemies.append(enemy)
	zone.activation_changed.connect(_zone_changed)


func _zone_changed(_active: bool) -> void:
	hud.active_zone = ""
	for zone: CombatZone in $CombatZones.get_children():
		if zone.active:
			hud.active_zone = zone.zone_name


func _reset_encounters() -> void:
	if is_instance_valid(match_director):
		return
	for zone: CombatZone in $CombatZones.get_children():
		zone.set_active(false)
	for bolt in $HostileProjectiles.get_children():
		bolt.queue_free()


func _start_incision() -> void:
	_cancel_incision()
	preview = RiftRenderer.new()
	player.camera.add_child(preview)
	preview.position = Vector3(0, 0, -capture.plane_distance)
	preview.set_tint(RiftCaster.tint_for(&"SCAR"))


func _update_incision(path: PackedVector2Array) -> void:
	hud.preview_ability = GestureRecognizer.recognize(path, capture.duration)["ability"]
	if is_instance_valid(preview):
		preview.set_tint(RiftCaster.tint_for(hud.preview_ability))
		preview.set_path(path)


func _cancel_incision() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null


func _release_scar(path: PackedVector2Array, pose: Transform3D, duration: float) -> void:
	var gesture := GestureRecognizer.recognize(path, duration)
	var cost: float = RiftCaster.COSTS.get(gesture["ability"], 4.0)
	if player.dead or player.energy < cost:
		hud.notice = "RIFT RECHARGING"
		hud.notice_remaining = 1.0
		_cancel_incision()
		return
	# Bound transient geometry even with an extreme input event stream.
	if $Rifts.get_child_count() >= 32:
		hud.notice = "SPACE SATURATED"
		hud.notice_remaining = 0.8
		_cancel_incision()
		return
	last_cast = RiftCaster.cast(self, gesture, pose, player.camera.global_position, player, player.velocity)
	if is_instance_valid(last_cast):
		player.energy -= cost
		hud.register_cast(gesture["ability"])
		if is_instance_valid(match_director): match_director.notify_cast(player, player.camera.global_position, 0.6 if gesture["weak"] else 1.0)
	if last_cast is RiftProjectile:
		last_projectile = last_cast
	_cancel_incision()
	player.attack_feedback(0.6 if gesture["weak"] else 1.2)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		elif event.physical_keycode == KEY_TAB:
			hud.show_scoreboard = not hud.show_scoreboard
			if hud.show_scoreboard: hud.show_help = false
		elif event.physical_keycode == KEY_H:
			hud.show_help = not hud.show_help
			if hud.show_help: hud.show_scoreboard = false
